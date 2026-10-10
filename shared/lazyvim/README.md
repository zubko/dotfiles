# LazyVim

A LazyVim config to compare with the NvChad config in `shared/nvim`. `install.sh` does not link it.

Source: the Omarchy LazyVim setup (`/usr/share/omarchy-nvim/config`) from the Omarchy laptop, without the Omarchy theme parts.

Own edits:

- `lua/plugins/neo-tree.lua`: show dotfiles and gitignored files, `<leader>bf` focuses Neo-tree.
- `lua/plugins/snacks.lua`: no scroll animation (the Omarchy default), and the picker shows dotfiles and gitignored files.

Kept from Omarchy: `lua/config/options.lua` (no relative numbers), `lua/plugins/disable-news-alert.lua`, the neo-tree extra in `lazyvim.json`.

Left out, because they need Omarchy: `all-themes.lua`, `omarchy-theme-hotreload.lua`, the `theme.lua` link to the current Omarchy theme and `plugin/after/transparency.lua`. Without them LazyVim uses its default tokyonight theme.

Try it next to the main nvim config, with its own plugin and state dirs:

```
ln -s ~/dotfiles/shared/lazyvim ~/.config/lazyvim
NVIM_APPNAME=lazyvim nvim
```
