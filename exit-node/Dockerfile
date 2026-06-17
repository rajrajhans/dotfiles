# Build image.nix with Nix inside nixos/nix; the runtime closure is pinned nixpkgs.
FROM nixos/nix:latest

COPY image.nix /build/image.nix
# sandbox/seccomp off: its BPF setup fails under QEMU emulation (e.g. local amd64
# buildx); no effect on the output.
RUN nix-build /build/image.nix -o /opt/env \
      --option filter-syscalls false --option sandbox false

COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh

ENV PATH=/opt/env/bin
ENV SSL_CERT_FILE=/opt/env/etc/ssl/certs/ca-bundle.crt

ENTRYPOINT ["/opt/env/bin/bash", "/opt/start.sh"]
