vim.cmd("set expandtab")
vim.cmd("set tabstop=4")
vim.g.mapleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({"git","clone","--filter=blob:none","https://github.com/folke/lazy.nvim.git","--branch=stable", lazypath,})
end
vim.opt.rtp:prepend(lazypath)
local plugins = {
{ "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  {"nvim-neo-tree/neo-tree.nvim", name = "neo-tree"},
  {"nvim-tree/nvim-web-devicons", name = "web-devicons"},
  {"nvim-lua/plenary.nvim", name = "plenary.nvim"},
  {"MunifTanjim/nui.nvim", name = "nui.nvim"},
-- {'nvim-telescope/telescope.nvim', tag = '0.1.8', dependencies = { 'nvim-lua/plenary.nvim' }},
-- {"nvim-treesitter/nvim-treesitter", build = ":TSUpdate"}
}

local opts = {}
require("lazy").setup(plugins,opts)

-- local builtin = require('telescope.builtin')
-- vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
-- vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
-- vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
-- vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

require("catppuccin").setup {
  color_overrides = {
      all = { text = "#ffffff", },
      latte = { base = "#ff0000", mantle = "#242424", crust = "#474747", },
      frappe = {},
      macchiato = {},
      mocha = {},
  }
}
vim.cmd.colorscheme "catppuccin"

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




-- sudo apt-get install ripgrep
-- apt install fd-find (https://github.com/sharkdp/fd)