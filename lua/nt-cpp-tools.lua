local queries = require "nvim-treesitter.query"

local M = {}

--TODO reuse the function provided by the treesitter utils
local function setup_commands(commands)
    for command_name, def in pairs(commands) do
        local f_args = def.f_args or "<f-args>"
        local call_fn = string.format(
        "lua require'nvim-treesitter.nt-cpp-tools.internal'.commands.%s['run<bang>'](%s)",
        command_name,
        f_args
        )
        local parts = vim.tbl_flatten {
            "command!",
            def.args,
            command_name,
            call_fn,
        }
        vim.api.nvim_command(table.concat(parts, " "))
    end
end

function M.init()
    vim.cmd([[ hi def TSCppHighlight guifg=#808080 ctermfg=244 ]])
    require "nvim-treesitter".define_modules {
        nt_cpp_tools = {
          module_path = "nvim-treesitter.nt-cpp-tools.internal",
          enable = false,
          preview = {
              quit = 'q',
              accept = '<tab>'
          },
          is_supported = function(lang)
            -- TODO: you don't want your queries to be named `awesome-query`, do you ?
            return queries.get_query(lang, 'query') ~= nil
          end
        }
    }
end

setup_commands(require"nvim-treesitter.nt-cpp-tools.internal".commands)

return M
