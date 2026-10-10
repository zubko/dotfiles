return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        visible = true, -- show filtered items
        hide_dotfiles = false,
        hide_gitignored = false, -- optional
      },
    },
  },
  keys = {
    { "<leader>bf", "<cmd>Neotree focus<cr>", desc = "Focus Neo-tree" },
  },
}
