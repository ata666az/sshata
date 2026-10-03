# syntax=docker/dockerfile:1
# blitz.cloud runs x86 servers; publish this image as linux/amd64.

FROM ubuntu:22.04 AS badvpn-builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl tar cmake make gcc g++ \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN curl -fsSL https://github.com/ambrop72/badvpn/archive/refs/tags/1.999.130.tar.gz | tar -xz \
    && cd badvpn-1.999.130 \
    && mkdir build && cd build \
    && cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 \
    && make -j"$(nproc)" badvpn-udpgw

FROM node:20-bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive \
    NODE_ENV=production \
    BLITZ_PACKAGED=1 \
    FILE_PATH=/tmp/vmesssh \
    PORT=8081 \
    ARGO_PORT=8001 \
    WS_PORT=8880 \
    MUX_PORT=8881 \
    SSL_INTERNAL_PORT=2443

# Runtime packages. The image intentionally keeps root because the original
# panel creates/removes Linux SSH users with useradd/chpasswd.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl openssl dropbear stunnel4 bash procps net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# cloudflared is baked into the image so runtime does not depend on downloading
# an executable. The original app uses the amd64 Linux release.
RUN curl -fsSL -o /usr/local/bin/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    && chmod 0755 /usr/local/bin/cloudflared

# Xray/core binary used by the original application. It is fetched at BUILD
# time and copied to a fixed executable path for Blitz's container runtime.
RUN mkdir -p /opt/vmesssh/bin \
    && curl -fsSL -o /opt/vmesssh/bin/web https://amd64.ssss.nyc.mn/web \
    && chmod 0755 /opt/vmesssh/bin/web

COPY --from=badvpn-builder /src/badvpn-1.999.130/build/udpgw/badvpn-udpgw /usr/local/bin/badvpn-udpgw
RUN chmod 0755 /usr/local/bin/badvpn-udpgw

WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY . .
RUN chmod 0755 start.sh \
    && rm -f .env

# blitz.cloud discovers the first EXPOSEd HTTP port. The public app is the
# Node.js panel/gateway; Cloudflare tunnels handle the internal proxy ports.
EXPOSE 8081

CMD ["./start.sh"]
