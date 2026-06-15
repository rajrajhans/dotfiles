function FindProxyForURL(url, host) {
  if (dnsDomainIs(host, ".internal.rajrajhans.com") ||
      host === "internal.rajrajhans.com") {
    return "PROXY 127.0.0.1:1055; SOCKS5 127.0.0.1:1055";
  }

  return "DIRECT";
}
