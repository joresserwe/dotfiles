return {
  -- https://github.com/folke/noice.nvim
  "folke/noice.nvim",
  opts = {
    lsp = {
      hover = {
        -- Set not show a message if hover is not available
        silent = true,
      },
    },
    config = {
      lsp = {
        signature = {
          enable = false,
        },
      },
    },
    presets = {
      lsp_doc_border = true,
    },
  },
}
