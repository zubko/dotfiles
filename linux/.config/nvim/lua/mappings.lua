require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

map("n", "<leader>W", "<cmd>wa<cr>", { desc = "Save all files" })
map("n", "<leader>fs", "<cmd>wa<cr>", { desc = "Save all files" })

return
