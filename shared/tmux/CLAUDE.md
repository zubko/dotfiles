# tmux

## tmux.conf

- Our hooks use slot 10: `set-hook -g <hook>[10] ...`. Never write a hook without a slot, which writes slot 0, and never use `set-hook -a`. Slot 0 is left for plugins and stock tmux, so neither side overwrites the other. A fixed slot is written again on every reload, while `-a` adds one more copy each time. When one hook needs a second command of ours, use slot 11, 12 and so on.

## Cheat sheet

`cheatsheet.html` is a one-page A4 print of the vital tmux keys. It is written by hand, not built from `tmux.conf`. `cheatsheet.pdf` is made from it and is gitignored.

After a change to a key binding in `tmux.conf`, or to `tm` in `shared/zsh/tmux-menu.zsh`:

1. Check the new binding on a throwaway tmux server first (see the root `CLAUDE.md`). The sheet must show only what tmux really does.
2. Update the row in `cheatsheet.html`, or add one when the key is vital.
3. Run `shared/tmux/render-cheatsheet.sh`. It writes the PDF, fails when the PDF is not one page or a web font is missing, and writes a PNG preview to `.tmp/`. Look at the preview: rows must not wrap or overlap.

Content rules:

- Only vital keys. When a new row does not fit, drop a less useful row.
- A key from `tmux.conf` or the zsh config, not from stock tmux, gets the `mine` class and shows yellow. The header note "yellow keys are your own" explains it.
- No `tmux.conf` section, no pane border section, no legend for `C-x` / `M-x` / `‹name›`, no config path.

Style: a Japanese manga and Japanese web site look, white background, made for a color printer.

- Page: `@page { size: A4 portrait; margin: 0 }`, `.page` is 210×297 mm.
- Fonts from Google Fonts: Dela Gothic One for titles, M PLUS 1 Code for keys and commands, Zen Kaku Gothic New for text. The render needs the network to load them.
- Colors are in `:root`: ink `#111`, red `#e60033`, yellow `#ffe100`, and one color per panel: sessions blue, windows orange, panes green, misc purple, copy pink, mouse cyan.
- Header: a manga panel with speed lines, the big "tmux" title with a red offset shadow, the vertical katakana ティーマックス, and the prefix in a speech bubble with a ポチッ sound effect.
- Panels: a thick black border, a round colored number, a halftone dot strip that fades across the header, and a katakana tag (セッション, ウィンドウ, ペイン, その他, コピー, マウス).
- Keys are `<kbd>` caps with a black outline and a hard shadow. `kbd.word` is for long names like `C-Space`. Shell commands are `.cmd`, tmux commands are `.cmd.colon`.
- Important words in a description go in `<b>`. They get a yellow marker underline.
- The speed lines and the dot strips are inline SVG that a one-off script made. Edit the HTML by hand and keep the SVG as it is.
