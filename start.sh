#!/bin/bash
set -u

# ================================================================
# vmesssh - blitz.cloud runtime bootstrap
# The container is designed for blitz.cloud's Docker/gVisor runtime.
# No kernel sysctl tuning is attempted because the sandbox owns the kernel.
# ================================================================

export BLITZ_PACKAGED="1"
export FILE_PATH="${FILE_PATH:-/tmp/vmesssh}"
export WS_PORT="${WS_PORT:-8880}"
export SSL_INTERNAL_PORT="${SSL_INTERNAL_PORT:-2443}"
export MUX_PORT="${MUX_PORT:-8881}"
export ARGO_PORT="${ARGO_PORT:-8001}"
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=128}"

mkdir -p "$FILE_PATH" /tmp/dropbear /tmp/stunnel

ulimit -n 65535 2>/dev/null || true
ulimit -s unlimited 2>/dev/null || true

# ---------------------------------------------------------------
# Dropbear: runtime-generated host key and banner in /tmp.
# This keeps startup independent from persistent /etc state.
# ---------------------------------------------------------------
DROPBEAR_KEY="/tmp/dropbear/dropbear_rsa_host_key"
DROPBEAR_BANNER="/tmp/dropbear/banner"

cat > "$DROPBEAR_BANNER" <<'BANNER'
==================================================
       SELAMAT MENIKMATI - SSH SERVER
==================================================
 Multiplexer : NODE.JS / JAVASCRIPT ENGINE
 OS Platform : UBUNTU
 SSH Service : DROPBEAR
 Platform    : blitz.cloud
==================================================
BANNER

if [ ! -s "$DROPBEAR_KEY" ]; then
    dropbearkey -t rsa -s 2048 -f "$DROPBEAR_KEY" >/dev/null 2>&1 || true
fi

# Kill stale processes if an image is restarted in-place.
pkill -x dropbear 2>/dev/null || true
pkill -x stunnel4 2>/dev/null || true
pkill -f 'ws-proxy.js' 2>/dev/null || true
pkill -f 'mux.js' 2>/dev/null || true
pkill -f 'badvpn-udpgw' 2>/dev/null || true

if [ -s "$DROPBEAR_KEY" ]; then
    echo "[*] Starting Dropbear on 127.0.0.1:22"
    /usr/sbin/dropbear -E -p 127.0.0.1:22 -r "$DROPBEAR_KEY" -b "$DROPBEAR_BANNER" -W 262144 -K 15 -I 300 &
else
    echo "[!] Dropbear host key generation failed; Dropbear will not start."
fi

# ---------------------------------------------------------------
# Stunnel: all generated state lives in /tmp.
# ---------------------------------------------------------------
STUNNEL_PEM="/tmp/stunnel/stunnel.pem"
STUNNEL_CONF="/tmp/stunnel/stunnel.conf"
STUNNEL_PID="/tmp/stunnel/stunnel.pid"

if [ ! -s "$STUNNEL_PEM" ]; then
    echo "[*] Generating ephemeral Stunnel certificate..."
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=BlitzSSH/CN=localhost" \
        -keyout "$STUNNEL_PEM" -out "$STUNNEL_PEM" >/dev/null 2>&1 || true
    chmod 600 "$STUNNEL_PEM" 2>/dev/null || true
fi

cat > "$STUNNEL_CONF" <<EOF2
pid = $STUNNEL_PID
foreground = no
debug = 0

[ssh-ssl]
accept = 127.0.0.1:$SSL_INTERNAL_PORT
connect = 127.0.0.1:22
cert = $STUNNEL_PEM
EOF2

rm -f "$STUNNEL_PID" 2>/dev/null || true
if [ -s "$STUNNEL_PEM" ]; then
    echo "[*] Starting Stunnel on 127.0.0.1:$SSL_INTERNAL_PORT"
    stunnel4 "$STUNNEL_CONF" >/tmp/stunnel/stunnel.log 2>&1 || true
fi

# ---------------------------------------------------------------
# WebSocket SSH proxy
# ---------------------------------------------------------------
echo "[*] Starting WebSocket SSH proxy on :$WS_PORT"
node ws-proxy.js >/tmp/ws-proxy.log 2>&1 &

# ---------------------------------------------------------------
# BadVPN UDP gateway (internal only)
# ---------------------------------------------------------------
if [ -x /usr/local/bin/badvpn-udpgw ]; then
    BADVPN_MAX_CLIENTS="${BADVPN_MAX_CLIENTS:-300}"
    BADVPN_MAX_CONN="${BADVPN_MAX_CONN:-30}"
    echo "[*] Starting BadVPN UDPGW on 127.0.0.1:7300"
    /usr/local/bin/badvpn-udpgw \
        --listen-addr 127.0.0.1:7300 \
        --max-clients "$BADVPN_MAX_CLIENTS" \
        --max-connections-for-client "$BADVPN_MAX_CONN" \
        >/tmp/badvpn-udpgw.log 2>&1 &
fi

# ---------------------------------------------------------------
# Mux TCP splitter
# mux.js uses its existing public-port variable below.
# ---------------------------------------------------------------
export MUX_PORT

echo "[*] Starting Mux on :$MUX_PORT"
node mux.js >/tmp/mux.log 2>&1 &

# ---------------------------------------------------------------
# Main Node.js application. It also starts packaged Xray and the
# Cloudflare Quick Tunnel. TOKEN-based named tunnel handling remains
# in server.js via /api/set-token and TOKEN startup support.
# ---------------------------------------------------------------
echo "[*] Starting main server on :${PORT:-8081}"
exec node server.js
