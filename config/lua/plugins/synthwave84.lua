return {
  -- Add Synthwave84 theme
  {
    "artanikin/vim-synthwave84",
    name = "synthwave84",
    lazy = false,
    priority = 1000,
    config = function()
      -- Enable glow effect for neon colors (optional but recommended for synthwave aesthetic)
      vim.g.synthwave84_glow = 1
    end,
  },

  -- Configure LazyVim to use Synthwave84 as default
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "synthwave84",
    },
  },
}