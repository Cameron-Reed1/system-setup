local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
local uv = vim.uv or vim.loop

-- Auto-install lazy.nvim if not present
if not uv.fs_stat(lazypath) then
  print('Installing lazy.nvim....')
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  })
  print('Done.')
end

vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  {'folke/tokyonight.nvim'},

  {'ThePrimeagen/vim-be-good'},

  {
    'kristijanhusak/vim-dadbod-ui',
    dependencies = {
      {'tpope/vim-dadbod'},
      {'kristijanhusak/vim-dadbod-completion'},
    }
  },

  {'tpope/vim-fugitive'},

  {
    'VonHeikemen/lsp-zero.nvim',
    branch = 'v2.x',
    dependencies = {
      {'neovim/nvim-lspconfig'},
      {'williamboman/mason.nvim'},
      {'williamboman/mason-lspconfig.nvim'},

      {'hrsh7th/nvim-cmp'},
      {'hrsh7th/cmp-nvim-lsp'},
      {'L3MON4D3/LuaSnip'},
    }
  },

  {
    'nvim-treesitter/nvim-treesitter',
    build = ":TSUpdate"
  },

  {
    'nvim-telescope/telescope.nvim', branch = '0.1.x',
    dependencies = {
      {'nvim-lua/plenary.nvim'},
    }
  },

  {'mbbill/undotree'},

  {
    'ThePrimeagen/harpoon',
    dependencies = {
      {'nvim-lua/plenary.nvim'},
    }
  },

  {'andweeb/presence.nvim'},

  {'EmmaEwert/vim-rgbds'},
})

