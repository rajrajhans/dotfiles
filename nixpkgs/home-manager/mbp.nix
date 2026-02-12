{ config, pkgs, home-manager, ... }:

{
  imports = [
    ./modules/home-manager.nix
    ./modules/common.nix
    ./modules/yazi.nix
  ];

  home.homeDirectory = "/Users/rajrajhans";
  home.username = "rajrajhans";
  home.stateVersion = "22.05";

  fonts.fontconfig.enable = true;
} 