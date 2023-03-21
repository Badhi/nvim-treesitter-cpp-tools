local buffer_writer = require("nt-cpp-tools.buffer_writer")

local M = {}
function M.add_text_edit(text, start_row, start_col)
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

return M
