local util = require("nvim-treesitter.nt-cpp-tools.util")
local configs = require("nvim-treesitter.configs")
local previewer = require("nvim-treesitter.nt-cpp-tools.preview_printer")

local M = {}


function M.preview_and_apply(output, context)
    local on_preview_succces = function (row)
        util.add_text_edit(output, row, 0)
    end

    previewer.start_preview(output, context.class_end_row + 1, on_preview_succces)
end

function M.add_to_cpp(output, _)
    local nt_configs = configs.get_module "nt_cpp_tools"
    local file_name = vim.fn.expand('%:p:h:t')
    vim.api.nvim_command('vsp ' .. file_name ..
        nt_configs.source_file_extension)
    util.add_text_edit(output, 1, 0)
end

return M
