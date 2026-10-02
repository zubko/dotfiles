return {
  {
    "stevearc/conform.nvim",
    event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
  	"nvim-treesitter/nvim-treesitter",
  	opts = {
  		ensure_installed = {
  			"vim", "lua", "vimdoc",
        "html", "css", "c", "cpp",
        "typescript"
  		},
  	},
  },

  {
    "hrsh7th/nvim-cmp",
    opts = function()
      return require "configs.cmp"
    end
  },

  -- {
  --   "hrsh7th/nvim-cmp",
  --   opts = function()
  --     local cmp = require "cmp"
  --
  --     return {
  --       mapping = {
  --         ["<Up>"] = cmp.mapping.select_prev_item(),
  --         ["<Down>"] = cmp.mapping.select_next_item(),
  --       },
  --     }
  --   end,
  -- },

  -- {
  --   "folke/persistence.nvim",
  --   event = "BufReadPre",
  --   opts = {
  --     dir = vim.fn.expand(vim.fn.stdpath("state") .. "/sessions/"), -- directory where session files are saved
  --     options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals" }, -- sessionoptions used for saving
  --     pre_save = nil, -- function to run before saving the session
  --     save_empty = false, -- don't save if there are no open file buffers
  --   },
  --   keys = {
  --     -- add keymaps for managing sessions
  --     { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
  --     { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
  --     { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
  --   },
  -- },

}
