# syntax=docker/dockerfile:1

# Build stage
FROM golang:1.26-bookworm AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libfido2-dev \
    libssl-dev \
    libcbor-dev \
    libsecret-1-dev \
    pkg-config \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy module files first for layer caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Patch listener to bind on 0.0.0.0 so ports are reachable from outside the container
RUN sed -i 's/constants.Host, port/"0.0.0.0", port/g' internal/services/imapsmtpserver/listener.go && \
    sed -i '/github.com\/ProtonMail\/proton-bridge\/v3\/internal\/constants/d' internal/services/imapsmtpserver/listener.go

# Generate required code artifacts before building
RUN cd utils && ./credits.sh bridge

# Build the bridge binary (no GUI, no launcher)
# CGO_ENABLED=1 is required for libfido2 and sqlite3
RUN CGO_ENABLED=1 CGO_LDFLAGS="-lfido2 -lcbor -lssl -lcrypto" \
    go build -ldflags '-s -w -X github.com/ProtonMail/proton-bridge/v3/internal/constants.Version=3.25.0+git' -o bridge ./cmd/Desktop-Bridge/

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libfido2-1 \
    libssl3 \
    libcbor0.8 \
    libsecret-1-0 \
    pass \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Set XDG dirs so all data lives in one place for volume mounting
ENV XDG_CONFIG_HOME=/data/config \
    XDG_DATA_HOME=/data/data \
    XDG_CACHE_HOME=/data/cache

# Create data directories
RUN mkdir -p /data/config /data/data /data/cache

WORKDIR /bridge

COPY --from=builder /build/bridge /bridge/bridge
COPY docker-start.sh /bridge/docker-start.sh

RUN chmod +x /bridge/bridge /bridge/docker-start.sh

# Default IMAP/SMTP ports (bridge scans upward from 1143/1025 if taken)
EXPOSE 1143 1025

VOLUME ["/data"]

ENTRYPOINT ["/bridge/docker-start.sh"]
CMD []
