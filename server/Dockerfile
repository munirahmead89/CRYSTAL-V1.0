# ===================================================================
# Crystal Messenger real-time server - production container
#
# Build:  docker build -t crystal-server .
# Run:    docker run -p 8081:8081 \
#           -e SUPABASE_JWT_SECRET=your_secret \
#           -v crystal-data:/data \
#           crystal-server
#
# TLS termination is typically done by your reverse proxy / load
# balancer (Caddy, Traefik, nginx, ALB) in front of this container.
# Alternatively mount certs and set CRYSTAL_WS_CERTFILE/KEYFILE.
# ===================================================================

FROM erlang:27-alpine AS build

WORKDIR /build

COPY rebar.config ./
COPY src/ src/
RUN rebar3 compile

FROM erlang:27-alpine

LABEL maintainer="Crystal Messenger Team"
LABEL description="Crystal Messenger real-time WebSocket server"
LABEL version="1.3.0"

# wget ships with alpine and powers the built-in healthcheck.
RUN addgroup -S crystal && adduser -S crystal -G crystal

WORKDIR /app
COPY --from=build /build/_build/default/lib/ _build/default/lib/

ENV CRYSTAL_WS_PORT=8081 \
    CRYSTAL_DATA_DIR=/data

RUN mkdir -p /data && chown -R crystal:crystal /data /app
USER crystal
VOLUME ["/data"]

EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${CRYSTAL_WS_PORT}/health || exit 1

CMD ["erl", "-pa", "_build/default/lib/*/ebin", "-noshell", "-eval", "application:ensure_all_started(crystal_server)"]
