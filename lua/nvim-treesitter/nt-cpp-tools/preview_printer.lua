M = {}

local mark_id
local last_buffer
local ns_id
local last_txt
local on_accept

local function remove_virt_text()
    if mark_id then
        vim.api.nvim_buf_del_extmark(last_buffer, ns_id, mark_id)
    end
end

local function draw_virtual_text(txt, row)
    remove_virt_text()

    if txt then
        last_txt = txt
    else
        txt = last_txt
    end

    local result = {}
    for line in txt:gmatch('[^\n]+') do
        result[#result+1] = {{line, ''}}
    end

    last_buffer = vim.fn.bufnr('%')
    ns_id = vim.api.nvim_create_namespace('TSCppTools')

    local line_num = row - 1
    local col_num = 0

    local opts = {
      end_line = 10,
      id = 1,
      virt_lines = result
    }

    mark_id = vim.api.nvim_buf_set_extmark(last_buffer, ns_id, line_num, col_num, opts)
end


local function end_preview()
    vim.api.nvim_buf_del_keymap(0, 'n', 'q')
    vim.api.nvim_buf_del_keymap(0, 'n', '<tab>')
    remove_virt_text()
    vim.cmd( [[autocmd! TSCppTools *]])
end

function M.flush_and_end_preview()
    end_preview()
    on_accept = nil
end

function M.accept_and_end_preview()
    end_preview()
    on_accept(vim.api.nvim_win_get_cursor(0)[1])
    on_accept = nil
end

function M.start_preview(result, insert_row, on_accept_cb)
    on_accept = on_accept_cb
    insert_row = insert_row or vim.api.nvim_win_get_cursor(0)[1]

    local config = { silent = true, noremap = true }

    local scope = "require'nvim-treesitter.nt-cpp-tools.preview_printer'."
    vim.api.nvim_buf_set_keymap(0, 'n', 'q', ":lua " .. scope .. "end_preview()<CR>", config)
    vim.api.nvim_buf_set_keymap(0, 'n', '<tab>', ":lua " .. scope .. "accept_and_end_preview()<CR>", config)

    draw_virtual_text(result, insert_row)

    vim.cmd(
    [[
    augroup TSCppTools
    autocmd! CursorMoved * lua require'nvim-treesitter.nt-cpp-tools.preview_printer'.start_preview()
    augroup END
    ]]
    )
end

return M
