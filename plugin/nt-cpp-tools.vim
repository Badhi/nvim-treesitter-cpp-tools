lua require("nt-cpp-tools").init()

command! -range TSCppDefineClassFunc  lua require'nt-cpp-tools.internal'.impFunc()
