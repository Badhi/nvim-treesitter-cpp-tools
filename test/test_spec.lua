local mock = require('luassert.mock')
local match = require 'luassert.match'

local function lsp_txt(a, arguments, b)
    local expected = arguments[1]
    local test_name = arguments[2]
    return function (value)
        local received = value[1].newText
        if expected ~= received then
            -- vim.api.nvim_command('w! ' .. test_name)
            -- print('expected ' .. expected)
            -- print('received ' .. received)
            return false
        else
            return true
        end
    end
end

assert:register("matcher", "lsp_txt", lsp_txt)

describe("implement_functions", function()
    local text_edit

    local write = function(txt)
        local tbl = {}
        for v in txt:gmatch("[^\r\n]+") do
            table.insert(tbl, v)
        end
        vim.api.nvim_put(tbl, 'c', true, true)
    end

    local run_test = function (input, location, expected, test_name)
        vim.api.nvim_command('normal ggdG')
        write(input)
        require'nvim-treesitter.nt-cpp-tools.internal'.imp_func(location[1], location[2])
        require'nvim-treesitter.nt-cpp-tools.preview_printer'.accept_and_end_preview()
        assert.stub(text_edit.apply_text_edits).was_called_with(match.lsp_txt(expected, test_name), 0)
    end

    before_each(function()
        text_edit = mock(vim.lsp.util, true)
    end)

    local scenrio_list = {
        {
            name = 'def_constructor',
            input =
[[
class C 
{
    public:
    C();
};
]]
            ,
            expected =
[[
C::C()
{
}
]]
            ,
            range = {4, 4}
        },
        {
            name = 'with_return_type',
            input =
[[
class C 
{
public:
    void test();
};
]]
            ,
            expected =
[[
void C::test()
{
}
]]
            ,
            range = {4, 4}
        },
        {
            name = 'with_return_type_and_args',
            input =
[[
class C 
{
public:
    void test(int i);
};
]]
            ,
            expected =
[[
void C::test(int i)
{
}
]]
            ,
            range = {4, 4}
        },
        {
            name = 'with_ref_return_type_and_args',
            input =
[[
#include <vector>
class C 
{
public:
    std::vector<int>& test(int i);
};
]]
            ,
            expected =
[[
std::vector<int>& C::test(int i)
{
}
]]
            ,
            range = {5, 5}
        },
        {
            name = 'default_value',
            input =
[[
#include <vector>
class C 
{
public:
    std::vector<int>& test(int i = 1);
};
]]
            ,
            expected =
[[
std::vector<int>& C::test(int i)
{
}
]]
            ,
            range = {5, 5}
        }
    }

    for k, s in pairs(scenrio_list) do
        local test_name =  s.name or ("test " .. k)
        it(test_name, function()
            run_test(s.input,  s.range, s.expected, test_name)
        end)
    end

    after_each(function ()
        mock.revert(text_edit)
    end)

end)
