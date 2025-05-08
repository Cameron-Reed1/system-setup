require'nvim-treesitter.configs'.setup {
  ensure_installed = { "c", "rust", "lua", "vim", "vimdoc", "query", "sql", "zig" },

  sync_install = false,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  ignore_install = {  },

  highlight = {
    enable = true,

    additional_vim_regex_highlighting = false,
  },
}
