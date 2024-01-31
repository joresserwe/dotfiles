local utils = require "astronvim.utils"

return {
  {
    "jay-babu/mason-null-ls.nvim",
    opts = function(_, opts)
      opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, { "prettierd" })
      if not opts.handlers then opts.handlers = {} end

      local has_prettier = function(util)
        return util.root_has_file ".prettierrc"
          or util.root_has_file ".prettierrc.json"
          or util.root_has_file ".prettierrc.yml"
          or util.root_has_file ".prettierrc.yaml"
          or util.root_has_file ".prettierrc.json5"
          or util.root_has_file ".prettierrc.js"
          or util.root_has_file ".prettierrc.cjs"
          or util.root_has_file "prettier.config.js"
          or util.root_has_file ".prettierrc.mjs"
          or util.root_has_file "prettier.config.mjs"
          or util.root_has_file "prettier.config.cjs"
          or util.root_has_file ".prettierrc.toml"
      end

      local has_eslint_plugin_prettier = function(util) return end

      opts.handlers.prettierd = function()
        local null_ls = require "null-ls"
        null_ls.register(null_ls.builtins.formatting.prettierd.with {
          condition = has_prettier,
          disabled_filetypes = { "json", "jsonc" },
        })
      end
    end,
  },
}
