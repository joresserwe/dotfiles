return {
  -- Add the community repository of plugin specifications
  "AstroNvim/astrocommunity",
  -- example of importing a plugin, comment out to use it or add your own
  -- available plugins can be found at https://github.com/AstroNvim/astrocommunity

  -- { import = "astrocommunity.colorscheme.catppuccin" },
  -- { import = "astrocommunity.completion.copilot-lua-cmp" },
  --
  { import = "astrocommunity.bars-and-lines.lualine-nvim" },

  { import = "astrocommunity.color.mini-hipatterns" },

  -- { import = "astrocommunity.diagnostics.lsp_lines-nvim" },
  -- { import = "astrocommunity.diagnostics.trouble-nvim" },

  { import = "astrocommunity.editing-support.rainbow-delimiters-nvim" },
  { import = "astrocommunity.editing-support.refactoring-nvim" },

  -- zoxide(가장 빈번히 방문한 디렉토리)를 telescope와 결합해서 사용할 수 있다.
  { import = "astrocommunity.fuzzy-finder.telescope-zoxide" },

  -- Git
  { import = "astrocommunity.git.neogit" },
  { import = "astrocommunity.git.diffview-nvim" },

  { import = "astrocommunity.pack.java" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.go" },
  { import = "astrocommunity.pack.kotlin" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.docker" },
  { import = "astrocommunity.pack.markdown" },
  -- { import = "astrocommunity.pack.json" },
  -- { import = "astrocommunity.pack.typescript" },
  -- { import = "astrocommunity.pack.helm" },

  { import = "astrocommunity.motion.nvim-surround" },

  { import = "astrocommunity.utility.noice-nvim" },

  -- LSP garbage collection
  { import = "astrocommunity.lsp.garbage-day-nvim" },
  -- { import = "astrocommunity.lsp.lsp-signature-nvim" },
}
