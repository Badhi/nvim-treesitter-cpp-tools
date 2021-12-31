local ts_utils = require("nvim-treesitter.ts_utils")
local ts_query = require("nvim-treesitter.query")
local parsers = require("nvim-treesitter.parsers")
local previewer = require("nvim-treesitter.nt-cpp-tools.preview_printer")

local M = {}

local function show_preview(txt)

end

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

local function add_text_edit(text, start_row, start_col)
    local edit = {}
    table.insert(edit, {
        range = {
            start = { line = start_row, character = start_col},
            ["end"] = { line = start_row, character = start_col}
        },
        newText = text
    })
    vim.lsp.util.apply_text_edits(edit, 0)
end

function M.imp_func()
    local query = ts_query.get_query('cpp', 'outside_class_def')

    local class = ''
    local results = {}
    local e_row = 0;
    local runner =  function(captures, match)
        for cid, node in pairs(match) do
            local cap_str = captures[cid]
            local value = ts_utils.get_node_text(node)[1]

            if  cap_str == 'class' then
                _, _, e_row, _ = node:range()
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

    local on_preview_succces = function (position)
        add_text_edit(output, position + 1, 0)
    end

    previewer.start_preview(output, e_row + 1, on_preview_succces)

end

function M.concrete_class_imp()
    local query = ts_query.get_query('cpp', 'concrete_implement')
    local base_class = ''
    local results = {}
    local e_row;
    local runner =  function(captures, matches)
        for p, node in pairs(matches) do
            local cap_str = captures[p]
            local value = ts_utils.get_node_text(node)[1]
            if cap_str == 'base_class_name' then
                base_class = value
                results[#results + 1] = ''
            elseif cap_str == 'class' then
                _, _, e_row, _ = node:range()
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

    add_text_edit(class, e_row + 1, 0)
end

function M.rule_of_5(limit_at_3)
    local query = ts_query.get_query('cpp', 'special_function_detectors')

    local checkers = {
        destructor = false,
        copy_constructor = false,
        copy_assignment = false,
        move_constructor = false,
        move_assignment = false
    }

    local entry_location
    local class_name

    local entry_location_update = function (start_row, start_col)
        if entry_location == nil or entry_location.start_row < start_row then
            entry_location = { start_row = start_row + 1 , start_col = start_col }
        end
    end

    local runner = function(captures, matches)
        for p, node in pairs(matches) do
            local cap_str = captures[p]
            local value = ts_utils.get_node_text(node)[1]
            local start_row, start_col, _, _ = node:range()

            if cap_str == "class_name" then
                class_name = value
            elseif cap_str ==  "destructor" then
                checkers.destructor = true
                entry_location_update(start_row, start_col)
            elseif cap_str ==  "assignment_operator_reference_declarator" then
                checkers.copy_assignment = true
                entry_location_update(start_row, start_col)
            elseif cap_str ==  "copy_construct_function_declarator" then
                checkers.copy_constructor = true
                entry_location_update(start_row, start_col)
            elseif not limit_at_3 then
                if cap_str == "move_assignment_operator_reference_declarator" then
                    checkers.move_assignment = true
                    entry_location_update(start_row, start_col)
                elseif cap_str == "move_construct_function_declarator" then
                    checkers.move_constructor = true
                    entry_location_update(start_row, start_col)
                end
            end
        end
    end

    if not run_on_nodes(query, runner) then
        return
    end

    local skip_rule_of_3 = (checkers.copy_assignment and checkers.copy_constructor and checkers.destructor) or
                            (not checkers.copy_assignment and not checkers.copy_constructor and not checkers.destructor)

    local skip_rule_of_5 =  ( ( checkers.copy_assignment and checkers.copy_constructor and checkers.destructor and
                                    checkers.move_assignment and checkers.move_constructor ) or
                                (not checkers.copy_assignment and not checkers.copy_constructor and not checkers.destructor and
                                    not checkers.move_assignment and not checkers.move_constructor) )

    if limit_at_3 and skip_rule_of_3 then
        local notifyMsg = [[ No change needed since either non or all of the following is implemented
            - destructor
            - copy constructor
            - assignment constructor
            ]]
        vim.notify(notifyMsg)
        return
    end

    if not limit_at_3 and skip_rule_of_5 then
        local notifyMsg = [[ No change needed since either non or all of the following is implemented
            - destructor
            - copy constructor
            - assignment constructor
            - move costructor
            - move assignment
            ]]
        vim.notify(notifyMsg)
        return
    end

    local add_txt_below_existing_def = function (txt)
        add_text_edit(txt, entry_location.start_row, entry_location.start_col)
        entry_location.start_row = entry_location.start_row + 1
    end

    -- We are first adding a empty string on the required line which is of length start_col since
    -- lsp text edit cannot add strings beyond already edited region
    -- TODO need a stable method of handling this entry

    local newLine = string.format('%' .. (entry_location.start_col + 1) .. 's', '\n')

    if not checkers.copy_assignment then
        add_text_edit(newLine, entry_location.start_row, 0)
        local txt = class_name .. '& operator=(const ' .. class_name .. '&);'
        add_txt_below_existing_def(txt)
    end

    if not checkers.copy_constructor then
        add_text_edit(newLine, entry_location.start_row, 0)
        local txt = class_name .. '(const ' .. class_name .. '&);'
        add_txt_below_existing_def(txt)
    end

    if not checkers.destructor then
        add_text_edit(newLine, entry_location.start_row, 0)
        local txt = '~' .. class_name .. '();'
        add_txt_below_existing_def(txt)
    end

    if not limit_at_3 then
        if not checkers.move_assignment then
            add_text_edit(newLine, entry_location.start_row, 0)
        local txt = class_name .. '& operator=(const ' .. class_name .. '&&);'
            add_txt_below_existing_def(txt)
        end

        if not checkers.move_constructor then
            add_text_edit(newLine, entry_location.start_row, 0)
            local txt = class_name .. '(const ' .. class_name .. '&&);'
            add_txt_below_existing_def(txt)
        end
    end
end

function M.attach(bufnr, lang)
    print("attach")
end

function M.detach(bufnr)
    print("dattach")
end

M.commands = {
    TSCppDefineClassFunc = {
        run = M.imp_func,
        args = {
            "-range"
        }
    },
    TSCppMakeConcreteClass = {
        run = M.concrete_class_imp,
        args = {
            "-range"
        }
    },
    TSCppRuleOf3 = {
        run = function () M.rule_of_5(true) end,
        args = {
            "-range"
        }
    },
    TSCppRuleOf5 = {
        run = function () M.rule_of_5(false) end,
        args = {
            "-range"
        }
    },
}

return M
