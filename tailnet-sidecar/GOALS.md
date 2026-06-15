# Tailnet Sidecar — Goals & Design

## Why this exists

The host Tailscale.app is signed in to the **work** tailnet, but this Mac still needs the
**personal tailnet / homelab**. The sidecar (a second userspace `tailscaled`) provides that
as a local SOCKS/HTTP proxy, without disconnecting the host. Every goal below means
*"works while the host is on the work tailnet."*

Key constraint: both tailnets share `100.64.0.0/10`, so the host cannot route to both by IP
at once. A userspace sidecar avoids the collision — it has its own netstack and reaches
personal peers over their public/DERP endpoints, exposed only via the proxy.

## Goals & how they're met

*(All validated 2026-06-15 with the host on the work tailnet.)*

1. **`*.internal.rajrajhans.com`** ✅ — a PAC routes the domain through the proxy
   (`PROXY/SOCKS5 127.0.0.1:1055`), everything else `DIRECT`. `https://…internal/` → 200.
2. **SSH to personal-tailnet nodes** — via a SOCKS `ProxyCommand`
   (`nc -X 5 -x 127.0.0.1:1055 %h %p`). *(pending: add to `~/.ssh/config`)*
3. **Syncthing (P0)** ✅ — the Mac dials the homelab hub out through the proxy; live
   `tcp-client → <hub-tailnet-ip>:32000`, syncing.

## Key decisions & learnings

### Nix-native, not Docker
Originally authored as a Docker compose (tailscale + an `ncat` forwarder). Switched to a
home-manager launchd `tailscaled` (userspace + SOCKS) because: only the SOCKS proxy is
actually needed (Syncthing → `ALL_PROXY`, internal URLs → PAC, SSH → `ProxyCommand`), so
the forwarder/`ncat`/Dockerfile machinery is unnecessary; a launchd agent is always-on
(vs. Docker Desktop having to be running); and it fits the all-Nix repo. Prototyped first:
a 2nd userspace `tailscaled` runs on darwin, coexists with Tailscale.app (separate
`--socket`/`--statedir`), and reaches the personal tailnet independently of host routing.

### Syncthing: native host Syncthing scoped through the sidecar
Topology: this Mac syncs only with the always-on homelab hub
**winterfell**, which runs in the winterfell k3s cluster
(`~/projects/winterfell`). Phone + old laptop sync via winterfell, not directly with this
Mac. All peers are on the personal tailnet.
- The Mac is always the dialer; a single Mac-initiated TCP connection carries sync both
  ways, so no inbound is needed. `ALL_PROXY=socks5://127.0.0.1:1055` forces it through the
  sidecar (process-global — safe only because every peer is on the personal tailnet).
- winterfell's Syncthing BEP is reachable on the tailnet as a **k3s NodePort 32000**
  (`winterfell/kubernetes-files/apps/syncthing/syncthing-service.yaml`), so the Mac uses a
  static `tcp://<hub-tailnet-ip>:32000` (raw IP = no DNS; `tcp://` forces TCP, since QUIC can't
  cross SOCKS). **No homelab change was needed.** kube-proxy SNATs the source to the node
  IP, which is fine — Syncthing authenticates by device ID, not source IP.
- Mac discovery + relay disabled; winterfell's stored address for `rajsmbp` set to
  `dynamic` (its old static address was the Mac's now-defunct personal-tailnet IP).
- *Rejected — Option A (Syncthing in a tun-mode container):* full P2P/QUIC, but macOS
  Docker bind-mount inotify is unreliable → not "seamless". Revisit only if the topology
  gains intermittent peers that must dial the Mac.

### PAC served over http, not file://
Chrome (Chromium) refuses to load PAC scripts from `file://` URLs. So the PAC
(`tailnet-sidecar.pac`, the single source of truth) is served over `http://127.0.0.1:1056`
by a `caddy` launchd agent, and both the macOS system auto-proxy and Firefox point at that
URL. (Safari/macOS and Firefox accept `file://` too, but http is used uniformly.)

### nix-darwin activation gotcha
nix-darwin only runs its predefined activation hooks — arbitrarily-named
`system.activationScripts.<name>` entries are silently ignored (unlike NixOS). That is why
an earlier `system.activationScripts.tailnetSidecarProxy` never applied; the system-proxy
setup now lives in `system.activationScripts.postActivation`. (Note: the repo's existing
`system.activationScripts.nixApps` has the same latent issue — it never runs;
`/Applications/Nix Apps` works via nix-darwin's built-in app linking instead.)

## Out of scope (decided)

- **k3s / kubectl cluster admin** — stays LAN-only. The master is a LAN IP
  (`192.168.x.y:6443`), not exposed over the tailnet.

## Not tailnet-dependent (not goals)

- **Wakapi** (localhost:5050) — local only.
- **Atuin shell history sync** — uses the public Atuin server; would only become a goal if
  self-hosted on the homelab later.
