return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      markdown = { "markdownlint-cli2", "prettier" },
    },
    formatters = {
      ["markdownlint-cli2"] = {
        command = "markdownlint-cli2",
        args = { "--fix", "$FILENAME" },
        stdin = false,
      },
    },
  },
}
