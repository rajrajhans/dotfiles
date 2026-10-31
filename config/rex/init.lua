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

-- Cmd+K clears, as iTerm2's Clear Buffer does; Rex defaults it to the session
-- switcher, which moves to Cmd+Shift+O. At a shell prompt, reset wipes screen
-- and scrollback and Ctrl+L redraws the prompt. Inside other programs (Claude
-- Code, vim) only Ctrl+L is sent, since reset would drop the modes they set.
local terminal = "com.superlogical.terminal"
local shells = { zsh = true, bash = true, sh = true, fish = true }

rex.action{
  name  = "clear_buffer",
  title = "Clear Buffer",
  run   = function(ctx, args)
    local proc = rex.block.call(terminal, "process", { block_id = ctx.block_id })
    if proc and proc.foreground and shells[proc.foreground.name] then
      rex.block.call(terminal, "reset", { block_id = ctx.block_id })
    end
    -- "\12" is Ctrl+L; Rex's Lua has no \x escapes.
    rex.block.call(terminal, "write", { block_id = ctx.block_id, data = "\12" })
  end,
}

rex.bind("cmd+k", "clear_buffer")
rex.bind("cmd+shift+o", "session.switch")
