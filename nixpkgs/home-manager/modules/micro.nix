{ pkgs, ... }:
{
  home.packages = with pkgs; [
    micro
  ];

  home.sessionVariables = {
    EDITOR = "micro";
    VISUAL = "micro";
  };

  home.file.".config/micro/settings.json".text = builtins.toJSON {
    # Appearance
    colorscheme = "gruvbox-tc";
    cursorline = true;
    diffgutter = true;
    ruler = true;
    scrollbar = false;
    scrollmargin = 5;
    scrollspeed = 2;
    statusline = true;

    # Editing
    autoclose = true;
    autoindent = true;
    keepautoindent = true;
    matchbrace = true;
    tabsize = 2;
    tabstospaces = true;
    rmtrailingws = true;
    trailingws = true;

    # Search
    hlsearch = true;
    incsearch = true;

    # Behavior
    autosave = 0;
    encoding = "utf-8";
    mkparents = true;
    mouse = true;
    savecursor = true;
    saveundo = true;
    softwrap = true;
  };
}
