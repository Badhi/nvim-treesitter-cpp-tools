local queries = require "nvim-treesitter.query"

local M = {}

-- TODO: In this function replace `module-template` with the actual name of your module.
function M.init()
  require "nvim-treesitter".define_modules {
    nt_cpp_tools = {
      module_path = "nt-cpp-tools.internal",
      enable = false,
      is_supported = function(lang)
        -- TODO: you don't want your queries to be named `awesome-query`, do you ?
        return queries.get_query(lang, 'query') ~= nil
      end
    }
  }
end

return M
