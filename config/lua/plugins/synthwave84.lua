return {
  -- Add Synthwave84 theme
  {
    "artanikin/vim-synthwave84",
    name = "synthwave84",
    lazy = false,
    priority = 1000,
    config = function()
      -- Authentic Synthwave84 color palette
      local colors = {
        -- Background colors from authentic theme
        bg_primary = "#262335",    -- Main dark background
        bg_secondary = "#2C2540",  -- Secondary dark background
        bg_accent = "#3E3B4B",     -- Darker accent background

        -- Foreground colors
        fg_primary = "#ECEBED",    -- Light text/foreground
        fg_secondary = "#D4D3D7",  -- Light gray text
        fg_muted = "#888690",      -- Gray text

        -- Authentic accent colors from theme
        yellow = "#FEDE5D",        -- Bright yellow
        magenta = "#D884C7",       -- Magenta
        red = "#E55A5E",           -- Red
        orange = "#EA9652",        -- Orange
        green = "#90DEB6",         -- Green
        light_red = "#EB8F82",     -- Light red
        cyan = "#40ffff",          -- Cyan/identifier color
      }

      -- Enable glow effect for neon colors (optional but recommended for synthwave aesthetic)
      vim.g.synthwave84_glow = 1

      -- Set colorscheme
      vim.cmd([[colorscheme synthwave84]])

      -- Set up custom highlights for plugins
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "synthwave84",
        callback = function()
          -- Telescope highlights
          vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = colors.bg_primary, fg = colors.fg_primary })
          vim.api.nvim_set_hl(0, "TelescopeBorder", { bg = colors.bg_primary, fg = colors.magenta })
          vim.api.nvim_set_hl(0, "TelescopePromptNormal", { bg = colors.bg_secondary, fg = colors.fg_primary })
          vim.api.nvim_set_hl(0, "TelescopePromptBorder", { bg = colors.bg_secondary, fg = colors.green })
          vim.api.nvim_set_hl(0, "TelescopeSelection", { bg = colors.magenta, fg = colors.bg_primary })
          vim.api.nvim_set_hl(0, "TelescopeSelectionCaret", { fg = colors.red })

          -- Neo-tree highlights
          vim.api.nvim_set_hl(0, "NeoTreeNormal", { bg = colors.bg_primary, fg = colors.fg_primary })
          vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { bg = colors.bg_primary, fg = colors.fg_primary })
          vim.api.nvim_set_hl(0, "NeoTreeDirectoryName", { fg = colors.green })
          vim.api.nvim_set_hl(0, "NeoTreeFileName", { fg = colors.fg_primary })
          vim.api.nvim_set_hl(0, "NeoTreeFileNameOpened", { fg = colors.magenta })

          -- Lualine (statusline) highlights using authentic theme colors
          vim.api.nvim_set_hl(0, "lualine_a_normal", { bg = colors.magenta, fg = colors.bg_primary, bold = true })
          vim.api.nvim_set_hl(0, "lualine_b_normal", { bg = colors.bg_secondary, fg = colors.green })
          vim.api.nvim_set_hl(0, "lualine_c_normal", { bg = colors.bg_primary, fg = colors.fg_primary })
          vim.api.nvim_set_hl(0, "lualine_a_insert", { bg = colors.green, fg = colors.bg_primary, bold = true })
          vim.api.nvim_set_hl(0, "lualine_a_visual", { bg = colors.yellow, fg = colors.bg_primary, bold = true })
          vim.api.nvim_set_hl(0, "lualine_a_command", { bg = colors.red, fg = colors.bg_primary, bold = true })
          vim.api.nvim_set_hl(0, "lualine_a_replace", { bg = colors.orange, fg = colors.bg_primary, bold = true })

          -- ClaudeCode highlights
          vim.api.nvim_set_hl(0, "FloatBorder", { bg = colors.bg_primary, fg = colors.magenta })
          vim.api.nvim_set_hl(0, "NormalFloat", { bg = colors.bg_primary, fg = colors.fg_primary })
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
