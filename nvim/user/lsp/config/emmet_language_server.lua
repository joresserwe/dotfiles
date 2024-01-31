return {
  on_attach = function()
    require("astronvim.utils").set_mappings {
      i = {
        ["<>"] = {
          "<></><left><left><left>",
          desc="which_key_ignore"
        },
      },
    }
  end,
}
