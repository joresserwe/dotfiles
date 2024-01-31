return {
  "smoka7/multicursors.nvim",
  event = "VeryLazy",
  dependencies = {
    "smoka7/hydra.nvim",
  },
  opts = {
    normal_keys = {
      ["m"] = {
        method = function() require("multicursors.normal_mode").find_next() end,
        opts = { desc = "Find next" },
      },
      ["M"] = {
        method = function() require("multicursors.normal_mode").find_prev() end,
        opts = { desc = "Find prev" },
      },
      ["n"] = { method = false },
    },
  },
}
