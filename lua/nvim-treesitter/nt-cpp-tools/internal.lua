local ts_utils = require("nvim-treesitter.ts_utils")
local ts_query = require("nvim-treesitter.query")
local parsers = require("nvim-treesitter.parsers")
local previewer = require("nvim-treesitter.nt-cpp-tools.preview_printer")
local buffer_writer = require("nvim-treesitter.nt-cpp-tools.buffer_writer")

local M = {}

local function run_on_nodes(query, runner, sel_start_row, sel_end_row)
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
    buffer_writer.apply_text_edits(edit, 0)
end

local function t2s(txt, add_empty_lines)
    local value
    for id, line in pairs(txt) do
        if add_empty_lines or line ~= '' then
        --if line ~= '' then
            value = (id == 1 and line or value .. '\n' .. line)
        end
    end
    return value
end

local function get_default_values_locations(t)
    local positions = {}
    local child_count = t:child_count()
    -- inorder to remove strings easier,
    -- doing reverse order
    for j = child_count-1, 0, -1 do
        local child = t:child(j)
        if child:type() == 'optional_parameter_declaration' then
            local _, _, start_row, start_col = child:field('declarator')[1]:range()
            local _, _, end_row, end_col = child:field('default_value')[1]:range()
            table.insert(positions,
            {   start_row = start_row,
                start_col = start_col,
                end_row = end_row,
                end_col = end_col
            }
            )
        end
    end
    return positions
end

local function remove_entries_and_get_node_string(node, entries)
    -- we expect entries to be sorted from end to begining when
    -- considering a row so that changing the statement will not
    -- mess up the indexes of the entries
    local base_row_offset, base_col_offset, _, _ = node:range()
    local txt = ts_utils.get_node_text(node)
    for _, entry in pairs(entries) do
        entry.start_row = entry.start_row - base_row_offset + 1
        entry.end_row = entry.end_row - base_row_offset + 1
        -- start row is trimmed to the tagged other rows are not
        local column_offset = entry.start_row > 1 and 0 or base_col_offset
        if entry.start_row == entry.end_row then
            local line = txt[entry.start_row]
            local s = line:sub(1, entry.start_col - column_offset)
            local e = line:sub(entry.end_col - column_offset + 1)
            txt[entry.start_row] = s .. e
        else
            txt[entry.start_row] = txt[entry.start_row]:sub(1, entry.start_col - column_offset)
            -- we will just mark the rows in between as empty since deleting will
            -- mess up locations of following entries
            for l = entry.start_row + 1, entry.end_row - 1, 1 do
                txt[l] = ''
            end

            local tail_txt = txt[entry.end_row]
            local indent_start, indent_end = tail_txt:find('^ *')
            local indent_str = string.format('%' .. (indent_end - indent_start) .. 's', ' ')

            -- no need to add column offset since we know end_row is not trimmed
            txt[entry.end_row] = indent_str .. tail_txt:sub(entry.end_col + 1)
        end
    end
    return txt
end

local function check_get_template_info(node)
    if node:parent():type() ~= 'template_declaration' then
        return nil, nil
    end

    local typename_names = {}
    local remove_entries = {}

    local template_param_list = node:parent():field('parameters')[1]
    local parameters_count = template_param_list:named_child_count()
    for param_id = parameters_count - 1, 0, -1 do
        local param_node = template_param_list:named_child(param_id)
        if param_node:type() == 'type_parameter_declaration' then
            table.insert(typename_names,
                    t2s(ts_utils.get_node_text(param_node:named_child(0))))
        elseif param_node:type() == 'optional_type_parameter_declaration' then
            local type_identifier = param_node:field('name')[1]
            table.insert(typename_names,
                    t2s(ts_utils.get_node_text(type_identifier)))
            local _, _, start_row, start_col = type_identifier:range()
            local _, _, end_row, end_col = param_node:field('default_type')[1]:range()
            table.insert(remove_entries,
            {   start_row = start_row,
                start_col = start_col,
                end_row = end_row,
                end_col = end_col
            }
            )
        end
    end
    return t2s(remove_entries_and_get_node_string(template_param_list, remove_entries)),
                typename_names
end


-- supports both reference return type and non reference return type
-- and no return type member functions
local function get_member_function_data(node)
    local result = {template = '', ret_type = '', fun_dec = '', class_details = nil}

    result.template, _ = check_get_template_info(node)
    result.template = result.template and 'template ' .. result.template

    local return_node = node:field('type')[1]
    local function_dec_node = node:field('declarator')[1]

    if next(node:field('default_value')) ~= nil then -- pure virtual
        return nil
    end

    result.ret_type = t2s(ts_utils.get_node_text(return_node)) -- return tye
    local node_child_count = node:named_child_count()
    for c = 0, node_child_count - 1, 1 do
        local child = node:named_child(c)
        if child:type() == 'type_qualifier' then -- return constness
            result.ret_type = t2s(ts_utils.get_node_text(child)) .. ' ' .. result.ret_type
            break
        end
    end

    if function_dec_node:type() == 'reference_declarator' or
        function_dec_node:type() == 'pointer_declarator' then
        result.ret_type = result.ret_type ..
            (function_dec_node:type() == 'reference_declarator' and '&' or '*')
        function_dec_node = function_dec_node:named_child(0)
    end

    result.fun_dec = t2s(ts_utils.get_node_text(function_dec_node:field('declarator')[1]))

    local fun_params = function_dec_node:field('parameters')[1]
    result.fun_dec = result.fun_dec .. t2s(remove_entries_and_get_node_string(fun_params,
                                                get_default_values_locations(fun_params)))

    local fun_dec_child_count = function_dec_node:named_child_count()
    for c = 0, fun_dec_child_count - 1, 1 do
        local child = function_dec_node:named_child(c)
        if child:type() == 'type_qualifier' then -- function constness
            result.fun_dec = result.fun_dec .. ' ' .. t2s(ts_utils.get_node_text(child))
            break
        end
    end
    return result
end

local function get_nth_parent(node, n)
    local parent = node
    for _ = 0 , n , 1 do
        parent = parent:parent()
        if not parent then return nil end
    end
    return parent
end

local function find_class_details(member_node, member_data)
    member_data.class_details = {}
    local end_row
    local class_node = member_node:parent():type() == 'template_declaration' and
                        member_node:parent():parent():parent() or member_node:parent():parent()
    while class_node and
        (class_node:type() == 'class_specifier' or
        class_node:type() == 'struct_specifier' or
        class_node:type() == 'union_specifier' ) do
        local class_data = {}
        class_data.name = t2s(ts_utils.get_node_text(class_node:field('name')[1]))

        local template_statement, params = check_get_template_info(class_node)
        if template_statement then
            class_data.class_template_statement = 'template ' .. template_statement
            for i = #params, 1, -1 do
                local val = params[i]
                class_data.class_template_params = (i == #params and '<' or
                                class_data.class_template_params .. ',') .. val
            end
            class_data.class_template_params = class_data.class_template_params .. '>'
        end

        _, _, end_row, _ = class_node:range()
        table.insert(member_data.class_details, class_data)

        class_node = get_nth_parent(class_node, 2)
    end
    return end_row
end

function M.imp_func(range_start, range_end)
    range_start = range_start - 1
    range_end = range_end - 1

    local query = ts_query.get_query('cpp', 'outside_class_def')

    local e_row
    local results = {}
    local runner =  function(captures, match)
        for cid, node in pairs(match) do
            local cap_str = captures[cid]
            if cap_str == 'member_function' then
                local fun_start, _, fun_end, _ = node:range()
                if fun_end >= range_start and fun_start <= range_end then
                    local member_data = get_member_function_data(node)
                    if member_data then
                        e_row = find_class_details(node, member_data)
                        table.insert(results, member_data)
                    end
                end
            end
        end
    end

    if not run_on_nodes(query, runner, range_start, range_end) then
        return
    end

    local output = ''
    for _, fun in ipairs(results) do
        if fun.fun_dec ~= '' then

            local classes_name
            local classes_template_statemets

            for h = #fun.class_details, 1, -1 do
                local templ_class_name = fun.class_details[h].name ..
                            (fun.class_details[h].class_template_params or '') .. '::'
                classes_name = (h == #fun.class_details) and templ_class_name or classes_name .. templ_class_name
                if not classes_template_statemets then
                    classes_template_statemets = fun.class_details[h].class_template_statement
                else
                    classes_template_statemets = classes_template_statemets .. ' '
                                            .. fun.class_details[h].class_template_statement
                end
            end


            local template_statements
            if classes_template_statemets and fun.template then
                template_statements = classes_template_statemets .. ' ' .. fun.template
            elseif classes_template_statemets  then
                template_statements = classes_template_statemets
            elseif fun.template then
                template_statements = fun.template
            end

            output = output .. (template_statements and template_statements .. '\n' or '') ..
                                (fun.ret_type and fun.ret_type .. ' ' or '' ) ..
                                classes_name
                                .. fun.fun_dec .. '\n{\n}\n'
        end
    end

    if output ~= '' then
        local on_preview_succces = function (row)
            add_text_edit(output, row, 0)
        end

        previewer.start_preview(output, e_row + 1, on_preview_succces)
    end

end

function M.concrete_class_imp(range_start, range_end)
    range_start = range_start - 1
    range_end = range_end - 1

    local query = ts_query.get_query('cpp', 'concrete_implement')
    local base_class = ''
    local results = {}
    local e_row
    local runner =  function(captures, matches)
        for p, node in pairs(matches) do
            local cap_str = captures[p]
            local value = ''
            for id, line in pairs(ts_utils.get_node_text(node)) do
                value = (id == 1 and line or value .. '\n' .. line)
            end

            if cap_str == 'base_class_name' then
                base_class = value
            elseif cap_str == 'class' then
                _, _, e_row, _ = node:range()
            elseif cap_str == 'virtual' then
                results[#results+1] = value:gsub('^virtual', ''):gsub([[= *0]], 'override')
            end
        end
    end

    if not run_on_nodes(query, runner, range_start, range_end) then
        return
    end

    if #results == 0 then
        vim.notify('No virtual functions detected to implement')
        return
    end

    local class_name = vim.fn.input("New Name: ", base_class .. "Impl")
    local class = string.format('class %s : public %s\n{\npublic:\n', class_name, base_class)
    for _, imp in ipairs(results) do
        class = class .. imp .. '\n'
    end
    class = class .. '};'

    local on_preview_succces = function (row)
        add_text_edit(class, row, 0)
    end

    previewer.start_preview(class, e_row + 1, on_preview_succces)
end


local function get_parameter_list(dependencies, is_reference)
    if not is_reference then is_reference = false end

    local parameter_list
    for d, _ in pairs(dependencies) do
        local parameter = t2s(ts_utils.get_node_text(d))
        if is_reference then parameter = '&' .. parameter end -- int* k -> int* & k
        local n = d:parent()
        while n do
            if n:type() == 'init_declarator' then
                -- initialization statement
                -- taking the sibling of init_declarator -> type
                parameter = t2s(ts_utils.get_node_text(n:parent():field('type')[1])) .. ' ' .. parameter
                break
            end
            if n:type() == 'parameter_declaration' or n:type() == 'declaration' then
                -- function argument
                parameter = t2s(ts_utils.get_node_text(n:field('type')[1])) .. ' ' .. parameter
                break
            end

            if n:type() == 'pointer_declarator' then
                parameter = '*' .. parameter
            elseif n:type() == 'reference_declarator' then
                parameter = '&' .. parameter
            end

            n = n:parent()
        end
        parameter_list = parameter_list and (parameter_list .. ', ' .. parameter) or parameter
    end
    return parameter_list
end

local function get_output_declarations(nodes)
    local declarations = {}
    for d, _ in pairs(nodes) do
        local n = d:parent()

        local is_init_declaration = false
        local ref_pointers
        while n do
            if n:type() == 'declaration' then -- a declaration, not an assignment use as it is
                if is_init_declaration then
                    local type = t2s(ts_utils.get_node_text(n:field('type')[1]))
                    local dec = ref_pointers and type .. ref_pointers or type -- type
                    dec = dec .. ' ' .. t2s(ts_utils.get_node_text(d)) .. ';' -- variable name
                    table.insert(declarations, dec)
                else
                    table.insert(declarations, t2s(ts_utils.get_node_text(n)))
                end
                break
            elseif n:type() == 'pointer_declarator' then
                ref_pointers = ref_pointers and '*' .. ref_pointers or '*'
            elseif n:type() == 'reference_declarator' then
                ref_pointers = ref_pointers and '&' .. ref_pointers or '&'
            elseif n:type() == 'init_declarator' then
                is_init_declaration = true
            end
            n = n:parent()
        end
    end
    return declarations
end

function M.refactor_to_function(range_start, range_end)
    range_start = range_start - 1
    range_end = range_end - 1

    local scope_identifiers = {}
    local scope_init_identifiers = {}

    local query = ts_query.get_query('cpp', 'refactor')

    local function_start_row, function_end_row 

    local scope_runner =  function(captures, matches)
        for p, node in pairs(matches) do
            local cap_str = captures[p]
            -- local value = ''
            -- for id, line in pairs(ts_utils.get_node_text(node)) do
            --     value = (id == 1 and line or value .. '\n' .. line)
            -- end

            if not function_start_row then
                local n = node
                while n do
                    n = n:parent()
                    if n:type() == 'function_definition' then
                        function_start_row, _, function_end_row, _ = n:range()
                        break
                    end
                end
            end

            if cap_str == 'identifier' then
                scope_identifiers[node] = true
            elseif  cap_str == 'init_declare_identifier' then
                scope_init_identifiers[node] = true
            end
        end
    end

    if not run_on_nodes(query, scope_runner, range_start, range_end) then
        return
    end

    if not function_start_row then
        print('Cannot find the function scope range')
        return
    end

    local all_init_identifiers = {}
    local dependent_identifiers = {}

    local function_runner = function(captures, matches)
        for p, node in pairs(matches) do
            local cap_str = captures[p]
            if cap_str == 'init_declare_identifier' then
                all_init_identifiers[node] = true
            elseif cap_str == 'identifier' then
                local s_row, _, _, _ = node:range()
                if s_row > range_end then
                    dependent_identifiers[node] = true
                end
            end
        end
    end

    if not run_on_nodes(query, function_runner, function_start_row, function_end_row) then
        return
    end

    -- print('scope init identifiers : ')
    -- for v, _ in pairs(scope_init_identifiers) do
    --     print(t2s(ts_utils.get_node_text(v)))
    -- end
    -- print('scope identifiers : ')
    -- for v, _ in pairs( scope_identifiers) do
    --     print(t2s(ts_utils.get_node_text(v)))
    -- end
    -- print('all init : ')
    -- for v, _ in pairs(all_init_identifiers) do
    --     print(t2s(ts_utils.get_node_text(v)))
    -- end

    for s, _ in pairs(scope_init_identifiers) do
        for v, _ in pairs(all_init_identifiers) do
            if s == v then
                all_init_identifiers[v] = nil
            end
        end
    end

    local required_external_dependencies = {}

    for init, _ in pairs(all_init_identifiers) do
        for id, _ in pairs(scope_identifiers) do
            if t2s(ts_utils.get_node_text(id)) == t2s(ts_utils.get_node_text(init)) then
                required_external_dependencies[init] = true
                break
            end
        end
    end

    local required_output_dependencies = {}
    for s, _ in pairs(scope_init_identifiers) do
        for o, _ in pairs(dependent_identifiers) do
            if t2s(ts_utils.get_node_text(s)) == t2s(ts_utils.get_node_text(o)) then
                required_output_dependencies[s] = true
            end
        end
    end
    -- print('Output Depends:')
    -- for v, _ in pairs(required_output_dependencies) do
    --     print(t2s(ts_utils.get_node_text(v)))
    -- end

    local function_name = vim.fn.input('Function Name: ', 'tempFunction')
    local parameter_list = get_parameter_list(required_external_dependencies)
    local dependent_list = get_parameter_list(required_output_dependencies, true)

    if dependent_list then
        parameter_list = parameter_list .. ', ' .. dependent_list
    end

    local param_call_list
    for p,_ in pairs(required_external_dependencies) do
        local txt = t2s(ts_utils.get_node_text(p))
        param_call_list = param_call_list and param_call_list .. ', ' .. txt or txt
    end
    for p,_ in pairs(required_output_dependencies) do
        local txt = t2s(ts_utils.get_node_text(p))
        param_call_list = param_call_list and param_call_list .. ', ' .. txt or txt
    end

    local output_declarations = get_output_declarations(required_output_dependencies)

    local fun_dec = 'void ' .. function_name .. '(' .. parameter_list .. ') {\n' ..
                    t2s(vim.api.nvim_buf_get_lines(0, range_start, range_end, false), true) ..
                    '\n}'

    table.insert(output_declarations, function_name .. '(' .. param_call_list .. ');')
    vim.api.nvim_buf_set_lines(0, range_start, range_end, false, output_declarations)

    add_text_edit(fun_dec, function_start_row - 1, 0)
end


function M.rule_of_5(limit_at_3, range_start, range_end)
    range_start = range_start - 1
    range_end = range_end - 1

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
            local value = ''
            for id, line in pairs(ts_utils.get_node_text(node)) do
                value = (id == 1 and line or value .. '\n' .. line)
            end
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

    if not run_on_nodes(query, runner, range_start, range_end) then
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
            local txt = class_name .. '& operator=(' .. class_name .. '&&);'
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
        f_args = "<line1>, <line2>",
        args = {
            "-range"
        }
    },
    TSCppMakeConcreteClass = {
        run = M.concrete_class_imp,
        f_args = "<line1>, <line2>",
        args = {
            "-range"
        }
    },
    TSCppRuleOf3 = {
        run = function (s, e) M.rule_of_5(true, s, e) end,
        f_args = "<line1>, <line2>",
        args = {
            "-range"
        }
    },
    TSCppRuleOf5 = {
        run = function (s, e) M.rule_of_5(false, s, e) end,
        f_args = "<line1>, <line2>",
        args = {
            "-range"
        }
    },
    TSCppRefactorFun = {
        run = M.refactor_to_function,
        f_args = "<line1>, <line2>",
        args = {
            "-range"
        }
    },
}

return M
