local ts_utils = require("nvim-treesitter.ts_utils")
local ts_query = require("nvim-treesitter.query")
local parsers = require("nvim-treesitter.parsers")

local M = {}

local function  get_visual_range()
  local _, csrow, cscol, _ = unpack(vim.fn.getpos("'<"))
  local _, cerow, cecol, _ = unpack(vim.fn.getpos("'>"))
  if csrow < cerow or (csrow == cerow and cscol <= cecol) then
    return csrow - 1, cscol - 1, cerow - 1, cecol
  else
    return cerow - 1, cecol - 1, csrow - 1, cscol
  end
end

local function run_on_nodes(query, runner)
    local sel_start_row, sel_end_row
    if vim.fn.mode() == 'v' then
        sel_start_row = vim.fn.getpos("v")
        sel_end_row = vim.fn.getpos(".")
    else
        sel_start_row, _, sel_end_row, _ = get_visual_range()
    end

    local bufnr = 0
    local ft = vim.api.nvim_buf_get_option(bufnr, 'ft')

    local parser = parsers.get_parser(bufnr, ft)
    local root = parser:parse()[1]:root()

    local matches = query:iter_matches(root, bufnr, sel_start_row, sel_end_row)

    while true do
        local pattern, match = matches()
        if pattern == nil then
            break
        end
        runner(query.captures, match)
    end

    return true
end

function M.impFunc()
    local query = ts_query.get_query('cpp', 'outside_class_def')

    local class = ''
    local results = {}
    local eRow = 0;
    local runner =  function(captures, match)
        for cid, node in pairs(match) do
            local cap_str = captures[cid]
            local value = ts_utils.get_node_text(node)[1]

            if  cap_str == 'class' then
                _, _, eRow, _ = node:range()
            elseif cap_str == 'class_name' then
                class = value
                results[#results + 1] = { ret_type = '', fun_dec = '' }
            elseif cap_str == 'return_type_qualifier' then
                results[#results].ret_type = value .. ' ' .. results[#results].ret_type
            elseif cap_str == 'return_type' then
                results[#results].ret_type = results[#results].ret_type .. value
            elseif cap_str == 'fun_dec' then
                results[#results].fun_dec = value
            elseif cap_str == 'ref_fun_dec' then
                results[#results].ret_type = results[#results].ret_type .. '&'
                results[#results].fun_dec = value:gsub('^& *', '')
            end
        end
    end

    if not run_on_nodes(query, runner) then
        return
    end

    local output = ''
    for _, fun in ipairs(results) do
        output = output .. fun.ret_type .. ' ' .. class .. '::' .. fun.fun_dec .. '\n{\n}\n'
    end

    local edit = {}
    table.insert(edit, {
        range = {
            start = { line = eRow + 1, character = 0},
            ["end"] = { line = eRow + 1, character = 0}
        },
        newText = output
    })
    vim.lsp.util.apply_text_edits(edit, 0)
end

function M.attach(bufnr, lang)
    print("attach")
end

function M.detach(bufnr)
    print("dattach")
end

return M
