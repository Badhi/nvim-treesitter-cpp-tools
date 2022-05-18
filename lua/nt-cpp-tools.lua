local queries = require "nvim-treesitter.query"
local configs = require "nvim-treesitter.configs"

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

local function get_copy(table)
    local ret = {}
    for k, v in pairs(table) do
        if type(v) == 'table' then
           ret[k] = get_copy(v)
        else
            ret[k] = v
        end
    end
    return ret
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
          header_file_extension = 'h',
          source_file_extension = 'cpp',
          is_supported = function(lang)
            -- TODO: you don't want your queries to be named `awesome-query`, do you ?
            return queries.get_query(lang, 'query') ~= nil
          end
        }
    }

    local config = configs.get_module "nt_cpp_tools"
    if config.custom_impl_commands then
        local internal = require"nvim-treesitter.nt-cpp-tools.internal"
        local default_command = internal.commands.TSCppDefineClassFunc
        for command_name, command in pairs(config.custom_impl_commands) do
            local value = get_copy(default_command)
            value['run'] = function (s, e) internal.imp_func(s, e, command.output_cb) end
            internal.commands[command_name] = value
        end
    end
    setup_commands(require"nvim-treesitter.nt-cpp-tools.internal".commands)
end


return M
