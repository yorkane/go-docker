package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	// Version info (set via ldflags at build time)
	Version   = "dev"
	Commit    = "none"
	BuiltAt   = "unknown"
	BuiltBy   = "unknown"
	startTime = time.Now()
)

func shortCommit(c string) string {
	if len(c) > 7 {
		return c[:7]
	}
	return c
}

var rootCmd = &cobra.Command{
	Use:   "yourapp",
	Short: "A production-ready Go application with s6-overlay",
	Long: `A production-ready Go application containerized with
debian:stable-slim and s6-overlay for process supervision.
Features non-root execution with proper signal handling.`,
	Run: runServer,
	Version: Version,
}

func init() {
	// Setup logging
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = zerolog.New(os.Stdout).With().Timestamp().Caller().Logger()

	// Configure viper
	viper.SetEnvPrefix("APP")
	viper.AutomaticEnv()

	// Flags
	rootCmd.PersistentFlags().String("config", "/etc/yourapp/config.yaml", "config file path")
	rootCmd.PersistentFlags().String("log-level", "info", "log level (debug, info, warn, error)")
	rootCmd.PersistentFlags().Int("port", 8080, "http server port")
	rootCmd.PersistentFlags().String("graceful-shutdown", "30s", "graceful shutdown timeout")

	// Bind flags to viper
	viper.BindPFlag("config", rootCmd.PersistentFlags().Lookup("config"))
	viper.BindPFlag("log.level", rootCmd.PersistentFlags().Lookup("log-level"))
	viper.BindPFlag("server.port", rootCmd.PersistentFlags().Lookup("port"))
	viper.BindPFlag("server.graceful_shutdown", rootCmd.PersistentFlags().Lookup("graceful-shutdown"))

	// Version flag
	rootCmd.SetVersionTemplate("{{.Version}}\ncommit: {{.Commit}}\nbuilt: {{.BuiltAt}}\nby: {{.BuiltBy}}\n")
	rootCmd.Version = fmt.Sprintf("%s (%s)", Version, shortCommit(Commit))
}

func runServer(cmd *cobra.Command, args []string) {
	// Initialize config
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			log.Warn().Err(err).Msg("Error reading config file, using defaults")
		}
	}

	// Setup log level
	level, err := zerolog.ParseLevel(viper.GetString("log.level"))
	if err != nil {
		level = zerolog.InfoLevel
	}
	zerolog.SetGlobalLevel(level)

	log.Info().
		Str("version", Version).
		Str("commit", shortCommit(Commit)).
		Str("log_level", level.String()).
		Msg("Starting yourapp")

	// Create HTTP server
	port := viper.GetInt("server.port")
	mux := http.NewServeMux()

	// Health check endpoint
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/ready", readyHandler)

	// Example routes
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"status":"ok","version":"%s","uptime":"%s"}`,
			Version, time.Since(startTime).Round(time.Second))
	})

	// Graceful shutdown support
	idleConnsClosed := make(chan struct{})
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", port),
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Info().Int("port", port).Msg("HTTP server listening")
		if err := srv.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatal().Err(err).Msg("HTTP server failed")
		}
		close(idleConnsClosed)
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info().Msg("Shutting down server...")

	// Graceful shutdown
	timeout := viper.GetDuration("server.graceful_shutdown")
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Error().Err(err).Msg("Server forced to shutdown")
	}

	<-idleConnsClosed
	log.Info().Msg("Server exited")
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, `{"status":"healthy"}`)
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
	// Add readiness checks here (DB, cache, etc.)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, `{"status":"ready"}`)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		log.Fatal().Err(err).Msg("Application error")
	}
}
