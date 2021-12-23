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
                results[#results].fun_dec = value:gsub('override$', '')
            elseif cap_str == 'ref_fun_dec' then
                results[#results].ret_type = results[#results].ret_type .. '&'
                results[#results].fun_dec = value:gsub('^& *', ''):gsub('override$', '')
            end
        end
    end

    if not run_on_nodes(query, runner) then
        return
    end

    local output = ''
    for _, fun in ipairs(results) do
        output = output .. (fun.ret_type ~= '' and fun.ret_type .. ' ' or '' ) .. class .. '::' .. fun.fun_dec .. '\n{\n}\n'
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

function M.concreteClassImp()
    local query = ts_query.get_query('cpp', 'concrete_implement')
    local base_class = ''
    local results = {}
    local eRow;
    local runner =  function(captures, matches)
        for p, node in pairs(matches) do
            local cap_str = captures[p]
            local value = ts_utils.get_node_text(node)[1]
            if cap_str == 'base_class_name' then
                base_class = value
                results[#results + 1] = ''
            elseif cap_str == 'class' then
                _, _, eRow, _ = node:range()
            elseif cap_str == 'virtual' then
                results[#results] = value:gsub('^virtual', ''):gsub([[= *0]], 'override')
            end
        end
    end

    if not run_on_nodes(query, runner) then
        return
    end

    local class_name = vim.fn.input("New Name: ", base_class .. "Impl")
    local class = string.format('class %s : public %s\n{\npublic:\n', class_name, base_class)
    for _, imp in ipairs(results) do
        class = class .. imp .. '\n'
    end
    class = class .. '};'

    local edit = {}
    table.insert(edit, {
        range = {
            start = { line = eRow + 1, character = 0},
            ["end"] = { line = eRow + 1, character = 0}
        },
        newText = class
    })
    vim.lsp.util.apply_text_edits(edit, 0)
end

function M.attach(bufnr, lang)
    print("attach")
end

function M.detach(bufnr)
    print("dattach")
end

M.commands = {
    TSCppDefineClassFunc = {
        run = M.impFunc,
        args = {
            "-range"
        }
    },
    TSCppMakeConcreteClass = {
        run = M.concreteClassImp,
        args = {
            "-range"
        }
    }
}

return M
