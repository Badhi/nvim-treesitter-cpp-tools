local queries = require "nvim-treesitter.query"

local default_config = {
    enable = false,
    preview = {
        quit = 'q',
        accept = '<tab>'
    },
    header_extension = 'h',
    source_extension = 'cpp',
    is_supported = function(lang)
        return queries.get_query(lang, 'query') ~= nil
    end
}

local M = {}

function M.init(user_cfg)
    user_cfg = user_cfg or {}
    default_config = vim.tbl_deep_extend('force', default_config, user_cfg)
    return default_config
end

function M.get_cfg()
  return default_config
end

return M
