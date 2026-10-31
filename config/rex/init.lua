-- Rex config, read by the Rex server (the Mac app's local one). Apply edits
-- with `rex config reload`; validate with `rex config check`.
--
-- Mirrors the iTerm2 profile keymap (config/iterm2) so muscle memory carries
-- over while Rex runs alongside iTerm2. Shift+Enter is deliberately unbound:
-- libghostty speaks the kitty keyboard protocol, so Claude Code and Codex get
-- a distinct Shift+Enter without the escape-sequence hack iTerm2 needs.

-- Natural text editing (iTerm2's preset): word and line motions for zsh.
rex.bind("alt+left", "pane.send_key", { key = "alt+b" })
rex.bind("alt+right", "pane.send_key", { key = "alt+f" })
rex.bind("cmd+left", "pane.send_key", { key = "ctrl+a" })
rex.bind("cmd+right", "pane.send_key", { key = "ctrl+e" })
rex.bind("alt+backspace", "pane.send_key", { key = "alt+backspace" })
rex.bind("cmd+backspace", "pane.send_key", { key = "ctrl+u" })

-- Cmd+\ splits side by side, as in iTerm2.
rex.bind("cmd+\\", "pane.split", { direction = "right" })

-- Cmd+Opt+Left/Right cycle tabs, as in iTerm2.
rex.bind("cmd+alt+left", "client.tab.previous")
rex.bind("cmd+alt+right", "client.tab.next")
