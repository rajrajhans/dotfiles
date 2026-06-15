# Tailnet Sidecar

Reach the **personal tailnet / homelab** from this Mac while the host Tailscale.app stays
signed in to the **work** tailnet — without disconnecting either.

A second `tailscaled` runs in **userspace mode** (no tun, no root) as a launchd agent,
joined to the personal tailnet, exposing a local SOCKS5/HTTP proxy on `127.0.0.1:1055`.
Everything that needs the personal tailnet routes through that one proxy.

Why a userspace proxy and not host routing: both tailnets live in `100.64.0.0/10`, so the
host can't route to both by IP at once. The sidecar has its own netstack and reaches
personal peers over their public/DERP endpoints, so it's immune to that collision — it
keeps working no matter which tailnet the host app is on.

## Pieces (all managed by Nix)

| Piece | Where |
|-------|-------|
| `tailscaled` userspace + SOCKS proxy | `nixpkgs/home-manager/mbp.nix` → `launchd.agents.tailnetSidecar` |
| `caddy` agent serving the PAC over http | `nixpkgs/home-manager/mbp.nix` → `launchd.agents.tailnetSidecarPac` |
| PAC (single source of truth) | `tailnet-sidecar.pac`, served at `http://127.0.0.1:1056/tailnet-sidecar.pac` |
| System auto-proxy → PAC | `nixpkgs/darwin/configuration.nix` → `system.activationScripts.postActivation` |
| Firefox → PAC | `config/firefox/user.js` (written to every profile by a home-manager activation) |
| Syncthing → proxy | `mbp.nix` Syncthing agent: `ALL_PROXY=socks5://127.0.0.1:1055` |
| `tsidecar` CLI wrapper | `scripts/tsidecar` → `~/.local/bin/tsidecar` |

Runtime state (node key, logs) lives in `~/.local/state/tailnet-sidecar/`, outside the repo.

## One-time setup

```sh
./setup_nix.sh                                # apply everything
tsidecar up --hostname=mac-tailnet-sidecar    # opens a login URL — authorize it
```

The node persists on disk, reconnects automatically, and the launchd agent keeps it
running (`KeepAlive`). The auth key is intentionally **not** stored in Nix.

## How each goal is served

- **`*.internal.rajrajhans.com`** — the PAC sends `*.internal.rajrajhans.com` through the
  proxy and everything else `DIRECT`, preserving the original URL/Host/SNI. Chrome & Safari
  use the macOS system auto-proxy; Firefox uses its own `user.js`. The PAC is served over
  **http** because Chrome refuses to load `file://` PAC URLs.
- **Syncthing** — the Mac's native Syncthing dials the homelab hub (`winterfell`) out
  through the proxy at a static address `tcp://<hub-tailnet-ip>:32000` (winterfell's k3s
  NodePort for the Syncthing BEP port). `ALL_PROXY` forces that connection through the
  sidecar; one Mac-initiated TCP connection carries sync both ways. See `GOALS.md`.
- **SSH to personal-tailnet nodes** — configured in `~/.ssh/config` (kept out of this repo,
  by choice), routing through the sidecar with a `ProxyCommand`. `nc`'s SOCKS5 resolves the
  MagicDNS names remotely, so no local DNS is needed:
  ```
  Host *.<your-tailnet>.ts.net
      ProxyCommand /usr/bin/nc -X 5 -x 127.0.0.1:1055 %h %p
  ```

## Operations

```sh
tsidecar status                                   # sidecar tailnet state + peers
tsidecar up --hostname=mac-tailnet-sidecar        # (re)authenticate
tail -f ~/.local/state/tailnet-sidecar/tailscaled.log
tail -f ~/.local/state/tailnet-sidecar/caddy-pac.log
launchctl list | grep tailnet-sidecar
```

Quick checks:

```sh
curl -x socks5h://127.0.0.1:1055 https://syncthing.internal.rajrajhans.com/   # → 200
curl http://127.0.0.1:1056/tailnet-sidecar.pac                                 # the PAC
```

## Gotchas

- **Chrome ignores `file://` PACs** — hence the http PAC server. Don't switch it back to file://.
- The SOCKS proxy (tailscaled) and the PAC server (caddy) are two separate launchd agents;
  both must be up. They start at login and restart on failure.
- `ALL_PROXY` on Syncthing is process-global — safe only because every Syncthing peer is on
  the personal tailnet.
