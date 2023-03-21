local mock = require('luassert.mock')
local match = require 'luassert.match'
local buf_writer = require 'nt-cpp-tools.buffer_writer'

local function lsp_txt(_, arguments, _)
    local expected = arguments[1]
    local test_name = arguments[2]
    return function (value)
        local received = value[1].newText
        received = received:gsub('\n*$', '')
        expected = expected:gsub('\n*$', '')
        if expected ~= received then
            vim.api.nvim_command('w! ' .. test_name)
            print('expected ' .. expected:gsub('\n', 'L'))
            print('received ' .. received:gsub('\n', 'L'))
            return false
        else
            return true
        end
    end
end

assert:register("matcher", "lsp_txt", lsp_txt)


local function read_test_file(filename, scenario_list)
    local file  = io.open(filename, 'r')

    while true do
        local line = file:read()

        if not line then
            break
        end

        if line:find('^=+$') then
            local test_case = {name = nil, input = nil, expected = nil, range = nil}
            line = file:read()
            test_case.name = line

            line = file:read()
            assert(line:find('^=+$') ~= nil, 'expected ===== line')

            line = file:read()
            while line:find('^-+$') == nil do
                if test_case.input then
                    test_case.input = test_case.input .. '\n' .. line
                else
                    test_case.input = line
                end
                line = file:read()
            end

            line = file:read()
            while line:find('^-+$') == nil do
                if test_case.expected then
                    test_case.expected = test_case.expected .. '\n' .. line
                else
                    test_case.expected = line
                end
                line = file:read()
            end

            line = file:read()
            local r_start, r_end = line:gmatch('(%d+), *(%d+)')()
            test_case.range = {tonumber(r_start), tonumber(r_end)}

            table.insert(scenario_list, test_case)
        end
    end
end

describe("implement_functions", function()
    local text_edit

    local scenrio_list = {}
    read_test_file("test/implement_functions.txt", scenrio_list)

    local write = function(txt)
        local tbl = {}
        for v in txt:gmatch("[^\r\n]+") do
            table.insert(tbl, v)
        end
        vim.api.nvim_put(tbl, 'c', true, true)
    end

    local run_test = function (input, location, expected, test_name)
        text_edit = mock(buf_writer, true)
        vim.api.nvim_command('normal ggdG')
        write(input)
        require'nt-cpp-tools.internal'.imp_func(location[1], location[2])
        require'nt-cpp-tools.preview_printer'.accept_and_end_preview()
        assert.stub(text_edit.apply_text_edits).was_called_with(match.lsp_txt(expected, test_name), 0)
        mock.revert(text_edit)
    end

    before_each(function()
    end)

    for k, s in pairs(scenrio_list) do
        local test_name =  s.name or ("test_" .. k)
        it(test_name, function()
            run_test(s.input,  s.range, s.expected, test_name)
        end)
    end

    after_each(function ()
    end)

end)
