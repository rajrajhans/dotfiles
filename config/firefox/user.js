// Managed by dotfiles (nixpkgs/home-manager/mbp.nix → home.activation.firefoxProxyUserJs).
// Firefox doesn't reliably follow the macOS system proxy, so point it at the PAC
// directly. The PAC routes *.internal.rajrajhans.com through the tailnet sidecar
// proxy (127.0.0.1:1055); everything else goes DIRECT. See tailnet-sidecar/GOALS.md.
user_pref("network.proxy.type", 2);
user_pref("network.proxy.autoconfig_url", "http://127.0.0.1:1056/tailnet-sidecar.pac");
// For the SOCKS5 leg of the PAC return value, resolve proxied hostnames remotely
// (on the personal-tailnet side) rather than locally.
user_pref("network.proxy.socks_remote_dns", true);
