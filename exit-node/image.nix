# Runtime closure (x86_64-linux), nixpkgs pinned to the repo's flake.lock.
let
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/fdc7b8f7b30fdbedec91b71ed82f36e1637483ed.tar.gz";
    sha256 = "0h19f2gy632baa2g0infji3nbr0s3mfaqis34gskdc2haiksvvvb";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };
in
pkgs.buildEnv {
  name = "exit-node-env";
  paths = with pkgs; [
    bashInteractive
    coreutils
    procps        # sysctl
    iproute2
    iptables      # tailscaled needs it for exit-node routing
    tailscale
    gost
    cacert        # TLS roots
  ];
}
