return {
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
  },
  {
    "piersolenski/telescope-import.nvim",
    dependencies = "nvim-telescope/telescope.nvim",
  },
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, config)
      local utils = require "astronvim.utils"
      local telescope = require "telescope"
      local action = require "telescope.actions"
      local fb_action = require "telescope._extensions.file_browser.actions"
      local opts = {
        defaults = {
          --initial_mode = "normal",
          mappings = {
            n = {
              ["\\"] = action.select_vertical,
              ["-"] = action.select_horizontal,
              ["<C-k>"] = action.move_selection_previous,
              ["<C-j>"] = action.move_selection_next,
              ["o"] = action.select_default,
            },
          },
        },
        extensions = {
          file_browser = {
            theme = "dropdown",
            hijack_netrw = true,
            path = "%:p:h",
            cwd = vim.fn.expand "%:p:h",
            respect_gitignore = false,
            hidden = true,
            grouped = true,
            previewer = false,
            initial_mode = "normal",
            layout_config = { height = 20 },
            mappings = {
              n = {
                ["."] = fb_action.change_cwd,
                ["h"] = fb_action.goto_parent_dir,
                ["l"] = action.select_default,
                ["o"] = action.select_default,
                ["O"] = fb_action.open,
                ["r"] = fb_action.rename,
                ["H"] = fb_action.toggle_hidden,
                ["<bs>"] = fb_action.backspace,
              },
            },
          },
          import = {
            -- Add imports to the top of the file keeping the cursor in place
            insert_at_top = true,
            -- Support additional languages
            custom_languages = {
              {
                -- The regex pattern for the import statement
                regex = [[^(?:import(?:[\"'\s]*([\w*{}\n, ]+)from\s*)?[\"'\s](.*?)[\"'\s].*)]],
                -- The Vim filetypes
                filetypes = { "typescript", "typescriptreact", "javascript", "react" },
                -- The filetypes that ripgrep supports (find these via `rg --type-list`)
                extensions = { "js", "ts" },
              },
            },
          },
        },
      }

      utils.conditional_func(telescope.load_extension, pcall(require, "import"), "import")
      utils.conditional_func(telescope.load_extension, pcall(require, "file_browser"), "file_browser")
      return utils.extend_tbl(config, opts)
    end,
  },
}
