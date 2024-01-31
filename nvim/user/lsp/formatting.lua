-- customize lsp formatting options
return {
  -- control auto formatting on save
  format_on_save = {
    enabled = false, -- enable or disable format on save globally
    allow_filetypes = { -- enable format on save for specified filetypes only
      -- "go",
    },
    ignore_filetypes = { -- disable format on save for specified filetypes
      -- "python",
    },
  },
  disabled = { -- disable formatting capabilities for the listed language servers
    -- disable lua_ls formatting capability if you want to use StyLua to format your lua code
  },
  filter = function(client) -- fully override the default formatting function
    local formatter_filter = { "null-ls" }
    local result = require("user.utils.tableUtil").includes(formatter_filter, client.name)
    vim.notify(client.name .. " mapping => " .. tostring(result))
    return result
  end,
  --timeout_ms = 1000, -- default format timeout
}
