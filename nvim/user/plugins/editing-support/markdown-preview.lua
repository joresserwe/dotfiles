return {
  "iamcco/markdown-preview.nvim",
  build = "cd app && npm install",
  ft = "markdown",
  config = function()
    require("astronvim.utils").set_mappings {
      n = {
        ["sp"] = {
          "<cmd>MarkdownPreviewToggle<cr>",
          desc = "Toggle Markdown Preview",
        },
      },
    }
  end,
}
