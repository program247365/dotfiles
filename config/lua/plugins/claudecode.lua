return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  config = function()
    require("claudecode").setup({
      terminal_cmd = "~/.claude/local/claude",
    })
  end,
  keys = {
    { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
  },
}