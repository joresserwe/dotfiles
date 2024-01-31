return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = function(_, opts)
    opts.filesystem.filtered_items = {
      hide_gitignored = false,
    }
    opts.window.mappings = {
      ["l"] = "child_or_open",
      ["h"] = "close_node",
      ["\\"] = "open_vsplit",
      ["-"] = "open_split",
      ["s"] = { "show_help", nowait = false, config = { title = "Order by", prefix_key = "s" } },
      ["sc"] = "order_by_created",
      ["sd"] = "order_by_diagnostics",
      ["sg"] = "order_by_git_status",
      ["sm"] = "order_by_modified",
      ["sn"] = "order_by_name",
      ["ss"] = "order_by_size",
      ["st"] = "order_by_type",
      ["o"] = "child_or_open",
      ["c"] = "add",
      ["oc"] = false,
      ["od"] = false,
      ["og"] = false,
      ["om"] = false,
      ["on"] = false,
      ["os"] = false,
      ["ot"] = false,
      ["S"] = false,
      ["C"] = false,
    }
  end,
}
