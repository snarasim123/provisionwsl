require ('initcolors')

vim.cmd("set expandtab")
vim.cmd("set tabstop=4")
vim.g.mapleader = " "
vim.wo.number = true

function setup_neotree()
  require("neo-tree").setup({
    filesystem = {
      filtered_items = {
        visible = true,
        show_hidden_count = true,
        hide_dotfiles = false,
        never_show = {},        
      },
    }
  })
  
  vim.keymap.set('n', '<F7>', '<Cmd>Neotree ..<CR>')
  vim.keymap.set('n', '<F8>', '<Cmd>Neotree toggle<CR>')
end

function setup_telescope()
  local builtin = require('telescope.builtin')  
  vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
  vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
  vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
  vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
  vim.keymap.set('n', '<leader>fi', builtin.git_files, {})
  vim.keymap.set('n', '<leader>fs', builtin.grep_string, {})
  -- require'telescope'.extensions.projects.projects{}
end

function setup_lazy()
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({"git","clone","--filter=blob:none","https://github.com/folke/lazy.nvim.git","--branch=stable", lazypath,})
  end
  vim.opt.rtp:prepend(lazypath)
  local plugins = {
    {"catppuccin/nvim", name = "catppuccin", priority = 1000 },
    {"ribru17/bamboo.nvim", name = "bamboo", priority = 1000 },
    {"rebelot/kanagawa.nvim", name = "kanagawa" },
    {"nyoom-engineering/oxocarbon.nvim", name = "oxocarbon"},
    { "bluz71/vim-moonfly-colors", name = "moonfly", lazy = false, priority = 1000 },
    {"nvim-neo-tree/neo-tree.nvim", name = "neo-tree"},
    {"nvim-tree/nvim-web-devicons", name = "nvim-web-devicons"},
    {"nvim-lua/plenary.nvim", name = "plenary.nvim"},
    {"MunifTanjim/nui.nvim", name = "nui.nvim"},
    {'nvim-telescope/telescope.nvim', tag = '0.1.8', dependencies = { 'nvim-lua/plenary.nvim' }},
    
    -- {"nvim-treesitter/nvim-treesitter", build = ":TSUpdate"}
  }

  local opts = {}
  require("lazy").setup(plugins,opts)
end


setup_lazy()
set_colors()
setup_neotree()
setup_telescope()

-- sudo apt-get install ripgrep
-- apt install fd-find (https://github.com/sharkdp/fd)
