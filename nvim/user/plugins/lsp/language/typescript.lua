local utils = require "astronvim.utils"

local function on_file_remove(args)
  local ts_clients = vim.lsp.get_active_clients { name = "tsserver" }
  for _, ts_client in ipairs(ts_clients) do
    ts_client.request("workspace/executeCommand", {
      command = "_typescript.applyRenameFile",
      arguments = {
        {
          sourceUri = vim.uri_from_fname(args.source),
          targetUri = vim.uri_from_fname(args.destination),
        },
      },
    })
  end
end

return {
  { import = "astrocommunity.pack.json" },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if opts.ensure_installed ~= "all" then
        opts.ensure_installed =
          utils.list_insert_unique(opts.ensure_installed, { "javascript", "typescript", "tsx", "jsdoc" })
      end
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, { "tsserver", "eslint" })
    end,
  },
  {
    "jay-babu/mason-null-ls.nvim",
    opts = function(_, opts)
      opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, { "eslint_d" })
      if not opts.handlers then opts.handlers = {} end
      opts.handlers.eslint_d = function()
        local null_ls = require "null-ls"
        null_ls.register(null_ls.builtins.formatting.eslint_d)
      end
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = function(_, opts) opts.ensure_installed = utils.list_insert_unique(opts.ensure_installed, "js") end,
  },
  {
    "vuki656/package-info.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {},
    event = "BufRead package.json",
  },
  {
    "jose-elias-alvarez/typescript.nvim",
    init = function() astronvim.lsp.skip_setup = utils.list_insert_unique(astronvim.lsp.skip_setup, "tsserver") end,
    ft = {
      "typescript",
      "typescriptreact",
      "javascript",
      "javascriptreact",
    },
    opts = function() return { server = require("astronvim.utils.lsp").config "tsserver" } end,
  },
  {
    "jose-elias-alvarez/null-ls.nvim",
    opts = function(_, opts)
      opts.sources = utils.list_insert_unique(opts.sources, require "typescript.extensions.null-ls.code-actions")
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      local events = require "neo-tree.events"
      if not opts.event_handlers then opts.event_handlers = {} end
      vim.list_extend(opts.event_handlers, {
        { event = events.FILE_MOVED, handler = on_file_remove },
        { event = events.FILE_RENAMED, handler = on_file_remove },
      })
    end,
  },
  {
    "dmmulroy/tsc.nvim",
    cmd = { "TSC" },
    opts = {},
  },
  -- {
  --   "kristijanhusak/vim-js-file-import",
  --   dependencies = {
  --     "ludovicchabant/vim-gutentags",
  --   },
  --   ft = {
  --     "typescript",
  --     "typescriptreact",
  --     "javascript",
  --     "javascriptreact",
  --   },
  --   keys = {
  --     { ";i", mode = "n", "<Cmd>JsFileImport<CR>", desc = "JS File Import" },
  --   },
  --   config = function()
  --     vim.g.js_file_import_no_mappings = 1
  --     vim.g.js_file_import_use_fzf = 1
  --     --require("vim-js-file-import").setup()
  --   end,
  -- },
  -- {
  --   "Galooshi/vim-import-js",
  --   ft = {
  --     "typescript",
  --     "typescriptreact",
  --     "javascript",
  --     "javascriptreact",
  --   },
  -- },
}
