vim.cmd [[set runtimepath+=.]]
vim.cmd [[set runtimepath+=/home/bhashith/lazy/nvim-treesitter/]]
vim.cmd [[set runtimepath+=/home/bhashith/lazy/plenary.nvim/]]
vim.cmd [[runtime! plugin/plenary.vim]]
vim.cmd [[runtime! plugin/nvim-treesitter.lua]]
vim.cmd [[runtime! plugin/nt-cpp-tools.vim]]

vim.o.swapfile = false
vim.bo.swapfile = false
vim.o.filetype = 'cpp'

require("nvim-treesitter.configs").setup {
}
