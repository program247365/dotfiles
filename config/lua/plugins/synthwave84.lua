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

      -- Set colorscheme
      vim.cmd([[colorscheme synthwave84]])

      -- Set up custom highlights for plugins
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "synthwave84",
        callback = function()
          -- Telescope highlights
          vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = "#1a0d26", fg = "#f7f1ff" })
          vim.api.nvim_set_hl(0, "TelescopeBorder", { bg = "#1a0d26", fg = "#ff7edb" })
          vim.api.nvim_set_hl(0, "TelescopePromptNormal", { bg = "#2a1b3d", fg = "#f7f1ff" })
          vim.api.nvim_set_hl(0, "TelescopePromptBorder", { bg = "#2a1b3d", fg = "#72f1b8" })
          vim.api.nvim_set_hl(0, "TelescopeSelection", { bg = "#ff7edb", fg = "#1a0d26" })
          vim.api.nvim_set_hl(0, "TelescopeSelectionCaret", { fg = "#fe4450" })

          -- Neo-tree highlights
          vim.api.nvim_set_hl(0, "NeoTreeNormal", { bg = "#1a0d26", fg = "#f7f1ff" })
          vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { bg = "#1a0d26", fg = "#f7f1ff" })
          vim.api.nvim_set_hl(0, "NeoTreeDirectoryName", { fg = "#72f1b8" })
          vim.api.nvim_set_hl(0, "NeoTreeFileName", { fg = "#f7f1ff" })
          vim.api.nvim_set_hl(0, "NeoTreeFileNameOpened", { fg = "#ff7edb" })

          -- ClaudeCode highlights (for the window you mentioned)
          vim.api.nvim_set_hl(0, "FloatBorder", { bg = "#1a0d26", fg = "#ff7edb" })
          vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#1a0d26", fg = "#f7f1ff" })
        end,
      })
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
