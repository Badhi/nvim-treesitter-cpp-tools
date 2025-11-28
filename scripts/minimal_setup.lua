vim.cmd [[set runtimepath+=.]]
vim.cmd [[set runtimepath+=./nvim-treesitter]]
vim.cmd [[set runtimepath+=./plenary.nvim]]
vim.cmd [[runtime! plugin/plenary.vim]]
vim.cmd [[runtime! plugin/nvim-treesitter.lua]]
vim.cmd [[runtime! plugin/nt-cpp-tools.vim]]

vim.o.swapfile = false
vim.bo.swapfile = false
vim.o.filetype = 'cpp'

require("nvim-treesitter").setup {
}
