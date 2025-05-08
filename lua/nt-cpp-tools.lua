local M = {}

local init_done = false

--TODO reuse the function provided by the treesitter utils
local function setup_commands(commands)
    for command_name, def in pairs(commands) do
        local f_args = def.f_args or "<f-args>"
        local call_fn = string.format(
        "lua require'nt-cpp-tools.internal'.commands.%s['run<bang>'](%s)",
        command_name,
        f_args
        )
        local parts = vim.iter({
            "command!",
            def.args,
            command_name,
            call_fn,
        }):flatten():totable()
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

function M.setup(user_config)
    if init_done then
        return
    end
    init_done = true


    vim.cmd([[ hi def TSCppHighlight guifg=#808080 ctermfg=244 ]])

    local config = require 'nt-cpp-tools.config'.init(user_config)
    if config.custom_define_class_function_commands then
        local internal = require"nt-cpp-tools.internal"
        local default_command = internal.commands.TSCppDefineClassFunc
        for command_name, command in pairs(config.custom_define_class_function_commands) do
            local value = get_copy(default_command)
            value['run'] = function (s, e) internal.imp_func(s, e, command.output_handle) end
            internal.commands[command_name] = value
        end
    end
    setup_commands(require"nt-cpp-tools.internal".commands)
end


return M
