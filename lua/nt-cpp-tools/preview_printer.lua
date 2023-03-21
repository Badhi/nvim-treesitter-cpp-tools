local configs = require "nt-cpp-tools.config"

local M = {}

local mark_id
local last_buffer
local ns_id
local result
local on_accept_callbck

local function remove_virt_text()
    if mark_id and vim.api.nvim_buf_is_valid(last_buffer) then
        vim.api.nvim_buf_del_extmark(last_buffer, ns_id, mark_id)
    end
end

local function draw_virtual_text(txt, row)
    remove_virt_text()

    if txt then
        result = {}
        for line in txt:gmatch('[^\n]+') do
            result[#result+1] = {{line, 'TSCppHighlight'}}
        end
    end

    last_buffer = vim.fn.bufnr('%')
    ns_id = vim.api.nvim_create_namespace('TSCppTools')

    local line_num = row - 1
    local col_num = 0

    local opts = {
      id = 1,
      virt_lines = result
    }

    mark_id = vim.api.nvim_buf_set_extmark(last_buffer, ns_id, line_num, col_num, opts)
end


local function end_preview()
    local config = configs.get_cfg()
    vim.api.nvim_del_keymap('n', config.preview.quit)
    vim.api.nvim_del_keymap('n', config.preview.accept)
    remove_virt_text()
    vim.cmd( [[autocmd! TSCppTools *]])
end

function M.flush_and_end_preview()
    end_preview()
    on_accept_callbck = nil
end

function M.accept_and_end_preview()
    end_preview()
    on_accept_callbck(vim.api.nvim_win_get_cursor(0)[1])
    on_accept_callbck = nil
end

function M.on_cursor_moved()
    draw_virtual_text(nil, vim.api.nvim_win_get_cursor(0)[1])
end

function M.start_preview(txt, insert_row, on_accept_cb)
    on_accept_callbck = on_accept_cb
    local keymap_config = { silent = true, noremap = true }

    local config = configs.get_cfg()

    vim.api.nvim_set_keymap('n', config.preview.quit,
        ":lua require'nt-cpp-tools.preview_printer'.flush_and_end_preview()<CR>",
        keymap_config)
    vim.api.nvim_set_keymap('n', config.preview.accept,
        ":lua require'nt-cpp-tools.preview_printer'.accept_and_end_preview()<CR>",
        keymap_config)

    draw_virtual_text(txt, vim.api.nvim_win_get_cursor(0)[1])

    vim.cmd(
    [[
    augroup TSCppTools
    autocmd! CursorMoved * lua require'nt-cpp-tools.preview_printer'.on_cursor_moved()
    augroup END
    ]]
    )

    vim.api.nvim_win_set_cursor(0, {insert_row, 0})
    M.on_cursor_moved()
end

return M
