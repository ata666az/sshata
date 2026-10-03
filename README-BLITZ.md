# vmesssh — blitz.cloud build

This variant keeps the original Node.js panel, SSH account management, WebSocket SSH proxy, Stunnel, Mux, BadVPN UDPGW, Xray/core and Cloudflare tunnel logic, while changing the container startup for blitz.cloud.

## Why this variant is different

- `cloudflared` and the Xray/core binary are downloaded during Docker build, not at runtime.
- BadVPN is compiled in a builder stage.
- Runtime-generated Dropbear/Stunnel state is stored in `/tmp`.
- Kernel `sysctl` tweaks were removed because the hosting sandbox owns the kernel.
- The main HTTP port is configurable with `PORT` and defaults to `8081`.
- The internal proxy ports remain private inside the container and are reached through Cloudflare tunneling.
- SSH users are still managed dynamically with `useradd`/`chpasswd` as in the original application.

## Blitz deployment

Build/publish the image as `linux/amd64` and make the Docker Hub repository public. In blitz.cloud, deploy the public image and use port `8081`.

Set the environment variables you normally use, for example:

- `TOKEN` — optional Cloudflare Tunnel token used by the panel's named-tunnel controls.
- `UUID` — optional VLESS/VMess/Trojan UUID.
- `NAME` — optional node name.
- `CFIP` / `CFPORT` — optional CDN endpoint values used by the config generator.
- `ADMIN_PASSWORD` — optional initial admin password.
- `BLITZ_URL` — optional provider URL/SNI label shown in the panel.

## Important Blitz free-tier limitation

The current free plan is no-card and has a shared memory allowance. blitz.cloud documentation also states that free apps can sleep after two hours without human visitors; automated requests do not keep a sleeping app awake. That means a persistent tunnel can become unavailable while the app is asleep. This build does not attempt to bypass that platform rule.
