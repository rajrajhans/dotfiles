{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";

    plugins = {
      full-border = pkgs.yaziPlugins.full-border;
      toggle-pane = pkgs.yaziPlugins.toggle-pane;
    };

    initLua = ''
      require("full-border"):setup {
        type = ui.Border.ROUNDED,
      }
    '';

    settings = {
      mgr = {
        ratio = [1 4 3];
        sort_by = "natural";
        sort_dir_first = true;
        linemode = "size";
        show_hidden = true;
        show_symlink = true;
        scrolloff = 5;
      };
    };

    keymap = {
      mgr.prepend_keymap = [
        {
          on = ["T"];
          run = "plugin toggle-pane max-preview";
          desc = "Maximize or restore preview pane";
        }
      ];
    };

    theme = builtins.fromTOML (builtins.readFile ../../../config/yazi/theme.toml);
  };
}
