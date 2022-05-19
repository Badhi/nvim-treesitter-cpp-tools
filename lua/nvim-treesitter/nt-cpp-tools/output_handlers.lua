local util = require("nvim-treesitter.nt-cpp-tools.util")
local configs = require("nvim-treesitter.configs")
local previewer = require("nvim-treesitter.nt-cpp-tools.preview_printer")

local M = {}


local function preview_and_apply(output, context)
    local on_preview_succces = function (row)
        util.add_text_edit(output, row, 0)
    end

    previewer.start_preview(output, context.class_end_row + 1, on_preview_succces)
end

function M.get_preview_and_apply(_)
    return preview_and_apply
end

local source_extension = 'cpp'

local function add_to_cpp(output, _)
    local file_name = vim.fn.expand('%:r')
    vim.api.nvim_command('vsp ' .. file_name ..
        '.' .. source_extension)
    util.add_text_edit(output, 1, 0)
end

function M.get_add_to_cpp(config)
    if config then
        if config.source_extension then
            source_extension = config.source_extension
        end
    end
    return add_to_cpp
end

return M
