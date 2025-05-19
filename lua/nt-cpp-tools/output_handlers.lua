local util = require("nt-cpp-tools.util")
local configs = require("nt-cpp-tools.config")
local previewer = require("nt-cpp-tools.preview_printer")

local M = {}


local function get_filter(filter_name)
    local query = vim.treesitter.query.get('cpp', filter_name)
    if not query then
        vim.notify('Internal error : Failed to get the filter (' .. filter_name .. ')',
            vim.log.levels.ERROR)
    end
    return query
end

local function get_namespaces(root, row)
    local namespaces = {}

    local query = get_filter('namespace_filter')
    if not query then
        return namespaces
    end

    for _, node, metadata, _ in query:iter_captures(root, 0) do
        local row1, _, row2, _ = node:range()
        if row1 < row and row2 > row then
            local n = vim.treesitter.get_node_text(node:field('name')[1], 0, metadata)
            table.insert(namespaces, n)
        end
    end
    return namespaces
end

local function move_modifier(txt, row)
    local buf_root = vim.treesitter.get_parser(nil, 'cpp'):parse()[1]:root()
    local namespaces = get_namespaces(buf_root, row)
    if not namespaces then
        return txt
    end

    local str_root = vim.treesitter.get_string_parser(txt, 'cpp'):parse()[1]:root()
    local query = get_filter('function_namespaces')
    if not query then
        return txt
    end

    local k = {}
    for _, node, _, _ in query:iter_captures(str_root, txt) do
        table.insert(k, node)
    end


    return txt
end

local function preview_and_apply(output, context)
    local on_preview_succces = function (row)
        util.add_text_edit(output, row, 0)
    end

    previewer.start_preview(output, context.class_end_row + 1,
        on_preview_succces, move_modifier)
end

function M.get_preview_and_apply(_)
    return preview_and_apply
end

local function add_to_cpp(output, _)
    local config = configs.get_cfg()
    local file_name = vim.fn.expand('%:r')
    vim.api.nvim_command('vsp ' .. file_name ..
        '.' .. config.source_extension)
    util.add_text_edit(output, 1, 0)
end

function M.get_add_to_cpp(_)
    return add_to_cpp
end

return M
