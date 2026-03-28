# =============================================================================
# Stage: Pre-built binary (compiled on host)
# =============================================================================
FROM debian:stable-slim AS runtime

LABEL org.opencontainers.image.title="yourapp" \
      org.opencontainers.image.description="Production Go application" \
      org.opencontainers.image.source="https://github.com/yorkane/go-docker" \
      org.opencontainers.image.version="latest" \
      maintainer="yorkane"

ENV APP_NAME="yourapp" \
    APP_VERSION="latest" \
    APP_HOME="/app" \
    TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "${APP_HOME}" /var/log/yourapp /var/lib/yourapp

ARG UID=10001
ARG GID=10001

RUN groupadd --gid ${GID} appgroup && \
    useradd --uid ${UID} --gid ${GID} --shell /bin/false --create-home appuser

RUN chown -R appuser:appgroup "${APP_HOME}" /var/log/yourapp /var/lib/yourapp

COPY yourapp "${APP_HOME}/"
COPY config.yaml "${APP_HOME}/config.yaml"

RUN chmod +x "${APP_HOME}/yourapp"

EXPOSE 8080

USER appuser
WORKDIR ${APP_HOME}

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["/app/yourapp", "--config", "/app/config.yaml"]
