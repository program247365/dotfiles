return {
  "stevearc/oil.nvim",
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {},
  dependencies = { { "nvim-mini/mini.icons", opts = {} } },
  lazy = false,
  keys = {
    { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
  },
}
