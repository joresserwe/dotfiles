return {
  -- alpha 옵션 사용자 정의
  {
    "goolord/alpha-nvim",
    opts = function(_, opts)
      -- 대시보드 헤더 사용자 정의
      opts.section.header.val = {
        " █████  ███████ ████████ ██████   ██████",
        "██   ██ ██         ██    ██   ██ ██    ██",
        "███████ ███████    ██    ██████  ██    ██",
        "██   ██      ██    ██    ██   ██ ██    ██",
        "██   ██ ███████    ██    ██   ██  ██████",
        " ",
        "    ███    ██ ██    ██ ██ ███    ███",
        "    ████   ██ ██    ██ ██ ████  ████",
        "    ██ ██  ██ ██    ██ ██ ██ ████ ██",
        "    ██  ██ ██  ██  ██  ██ ██  ██  ██",
        "    ██   ████   ████   ██ ██      ██",
      }
      return opts
    end,
  },

  -- 기본 플러그인 비활성화 방법:
  -- { "max397574/better-escape.nvim", enabled = false },
  --
  -- 플러그인의 setup 호출 외부에서 추가적인 설정을 쉽게 사용자 정의 가능:
  -- {
  --   "L3MON4D3/LuaSnip",
  --   config = function(plugin, opts)
  --     require "plugins.configs.luasnip"(plugin, opts) -- setup 호출을 하는 기본 astronvim 구성 포함
  --     -- 파일 타입 확장이나 사용자 정의 스니펫 등 추가적인 LuaSnip 구성
  --     local luasnip = require "luasnip"
  --     luasnip.filetype_extend("javascript", { "javascriptreact" })
  --   end,
  -- },
  -- {
  --   "windwp/nvim-autopairs",
  --   config = function(plugin, opts)
  --     require "plugins.configs.nvim-autopairs"(plugin, opts) -- setup 호출을 하는 기본 astronvim 구성 포함
  --     -- 사용자 정의 자동 쌍 설정 등 추가적인 autopairs 구성
  --     local npairs = require "nvim-autopairs"
  --     local Rule = require "nvim-autopairs.rule"
  --     local cond = require "nvim-autopairs.conds"
  --     npairs.add_rules(
  --       {
  --         Rule("$", "$", { "tex", "latex" })
  --           -- 다음 문자가 %일 경우 쌍을 추가하지 않음
  --           :with_pair(cond.not_after_regex "%%")
  --           -- 이전 문자가 xxx일 경우 쌍을 추가하지 않음
  --           :with_pair(
  --             cond.not_before_regex("xxx", 3)
  --           )
  --           -- 반복 문자일 경우 오른쪽으로 이동하지 않음
  --           :with_move(cond.none())
  --           -- 다음 문자가 xx일 경우 삭제하지 않음
  --           :with_del(cond.not_after_regex "xx")
  --           -- <cr>를 눌렀을 때 새 줄 추가 안 함
  --           :with_cr(cond.none()),
  --       },
  --       -- .vim 파일에는 비활성화하지만, 다른 파일 타입에는 작동
  --       Rule("a", "a", "-vim")
  --     )
  --   end,
  -- },
  -- which-key 설정에 추가하여 더 많은 which-key 등록 바인딩을 추가
  -- {
  --   "folke/which-key.nvim",
  --   config = function(plugin, opts)
  --     require "plugins.configs.which-key"(plugin, opts) -- setup 호출을 하는 기본 astronvim 구성 포함
  --     -- 그룹 이름으로 보여지는 바인딩 추가
  --     local wk = require "which-key"
  --     wk.register({
  --       b = { name = "Buffer" },
  --     }, { mode = "n", prefix = "<leader>" })
  --   end,
  -- },
}
