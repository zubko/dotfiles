local config = require "nvchad.configs.cmp"
local cmp = require "cmp"

config.mapping["<CR>"] = cmp.mapping.confirm {
  behavior = cmp.ConfirmBehavior.Insert,
  select = false,
}

config.mapping["<Up>"] = cmp.mapping.select_prev_item()
config.mapping["<Down>"] = cmp.mapping.select_next_item()

config.completion = {
  completeopt = "menu,menuone,noselect"
}

config.preselect = cmp.PreselectMode.None

return config
