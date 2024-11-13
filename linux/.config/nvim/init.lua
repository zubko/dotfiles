vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

vim.opt.scrolloff = 5

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "nvchad.autocmds"

vim.schedule(function()
  require "mappings"
end)

-- Autocommand to save session on exit
-- vim.api.nvim_create_autocmd("VimLeavePre", {
--   callback = function()
--     require("persistence").save()
--   end,
-- })
--
-- Autoload last session when opening Neovim with no arguments
-- vim.api.nvim_create_autocmd("VimEnter", {
--   callback = function()
--     -- Only load the session if nvim was started with no args
--     if vim.fn.argc() == 0 then
--       require("persistence").load({ last = true })
--     end
--   end,
-- })


