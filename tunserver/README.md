# tunserver docker stack

Docker Compose for **tunserver** (headscale coordination + tailnet DNS host). **Not managed by Flux** — reference/backup only.

Services:
- **nginx-proxy-manager** — reverse proxy
- **pihole** — tailnet DNS (ad-block + filtering) on 100.64.0.1:53
- **unbound** — recursive resolver + DNSSEC (pihole upstream, 172.20.0.53), keeps DNS off third parties
- **headscale** / **headplane** — self-hosted tailscale control plane

Secrets live in a local `.env` on the host (NOT committed); compose references them as `${VARS}`.
All images are digest-pinned.
