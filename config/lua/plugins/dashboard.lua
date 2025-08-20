return {
  {
    "folke/snacks.nvim",
    opts = function()
      -- Find the random-quotes binary using which
      local which_handle = io.popen("which random-quotes")
      local binary_path = ""
      local random_message = ""
      
      if which_handle then
        binary_path = which_handle:read("*a"):gsub("%s+$", "")
        which_handle:close()
      end
      
      -- If we found the binary, use it to get a quote
      if binary_path ~= "" then
        local quote_handle = io.popen(binary_path)
        if quote_handle then
          random_message = quote_handle:read("*a")
          quote_handle:close()
          -- Remove trailing newlines
          random_message = random_message:gsub("%s+$", "")
        end
      end
      
      -- Fallback message if the program isn't available or fails
      if random_message == "" then
        random_message = "Code with passion, debug with patience 🔍"
      end
      
      return {
        dashboard = {
          preset = {
            header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝

]] .. random_message,
            -- stylua: ignore
            ---@type snacks.dashboard.Item[]
            keys = {
              { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
              { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
              { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
              { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
              { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
              { icon = " ", key = "s", desc = "Restore Session", section = "session" },
              { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
              { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
              { icon = " ", key = "q", desc = "Quit", action = ":qa" },
            },
          },
        },
      }
    end,
  },
}

