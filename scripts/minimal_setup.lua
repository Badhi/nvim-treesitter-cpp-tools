--vim.cmd [[set runtimepath+=.]]
vim.cmd [[runtime! plugin/plenary.vim]]
vim.cmd [[runtime! plugin/nvim-treesitter.vim]]
vim.cmd [[runtime! plugin/nt-cpp-tools.vim]]

vim.o.swapfile = false
vim.bo.swapfile = false
vim.o.filetype = 'cpp'

require("nvim-treesitter.configs").setup {
}
