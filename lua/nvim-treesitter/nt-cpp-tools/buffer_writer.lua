local uv = vim.loop
local validate = vim.validate
local api = vim.api

local M = {}
local function get_lines(bufnr, rows)
  rows = type(rows) == "table" and rows or { rows }

  ---@private
  local function buf_lines()
    local lines = {}
    for _, row in pairs(rows) do
      lines[row] = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false) or { "" })[1]
    end
    return lines
  end

  local uri = vim.uri_from_bufnr(bufnr)

  -- load the buffer if this is not a file uri
  -- Custom language server protocol extensions can result in servers sending URIs with custom schemes. Plugins are able to load these via `BufReadCmd` autocmds.
  if uri:sub(1, 4) ~= "file" then
    vim.fn.bufload(bufnr)
    return buf_lines()
  end

  -- use loaded buffers if available
  if vim.fn.bufloaded(bufnr) == 1 then
    return buf_lines()
  end

  local filename = api.nvim_buf_get_name(bufnr)

  -- get the data from the file
  local fd = uv.fs_open(filename, "r", 438)
  if not fd then return "" end
  local stat = uv.fs_fstat(fd)
  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)

  local lines = {} -- rows we need to retrieve
  local need = 0 -- keep track of how many unique rows we need
  for _, row in pairs(rows) do
    if not lines[row] then
      need = need + 1
    end
    lines[row] = true
  end

  local found = 0
  local lnum = 0

  for line in string.gmatch(data, "([^\n]*)\n?") do
    if lines[lnum] == true then
      lines[lnum] = line
      found = found + 1
      if found == need then break end
    end
    lnum = lnum + 1
  end

  -- change any lines we didn't find to the empty string
  for i, line in pairs(lines) do
    if line == true then
      lines[i] = ""
    end
  end
  return lines
end

local function get_line(bufnr, row)
  return get_lines(bufnr, { row })[row]
end

local function get_line_byte_from_position(bufnr, position, offset_encoding)
  -- LSP's line and characters are 0-indexed
  -- Vim's line and columns are 1-indexed
  local col = position.character
  -- When on the first character, we can ignore the difference between byte and
  -- character
  if col > 0 then
    local line = get_line(bufnr, position.line)
    local ok, result

    if offset_encoding == "utf-16" or not offset_encoding then
      ok, result = pcall(vim.str_byteindex, line, col, true)
    elseif offset_encoding == "utf-32" then
      ok, result = pcall(vim.str_byteindex, line, col, false)
    end

    if ok then
      return result
    end
    return math.min(#line, col)
  end
  return col
end

function M.apply_text_edits(text_edits, bufnr)
  validate {
    text_edits = { text_edits, 't', false };
    bufnr = { bufnr, 'number', false };
  }
  if not next(text_edits) then return end
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  api.nvim_buf_set_option(bufnr, 'buflisted', true)

  -- Fix reversed range and indexing each text_edits
  local index = 0
  text_edits = vim.tbl_map(function(text_edit)
    index = index + 1
    text_edit._index = index

    if text_edit.range.start.line > text_edit.range['end'].line or text_edit.range.start.line == text_edit.range['end'].line and text_edit.range.start.character > text_edit.range['end'].character then
      local start = text_edit.range.start
      text_edit.range.start = text_edit.range['end']
      text_edit.range['end'] = start
    end
    return text_edit
  end, text_edits)

  -- Sort text_edits
  table.sort(text_edits, function(a, b)
    if a.range.start.line ~= b.range.start.line then
      return a.range.start.line > b.range.start.line
    end
    if a.range.start.character ~= b.range.start.character then
      return a.range.start.character > b.range.start.character
    end
    if a._index ~= b._index then
      return a._index > b._index
    end
  end)

  -- Some LSP servers may return +1 range of the buffer content but nvim_buf_set_text can't accept it so we should fix it here.
  local has_eol_text_edit = false
  local max = vim.api.nvim_buf_line_count(bufnr)
  -- TODO handle offset_encoding
  local _, len = vim.str_utfindex(vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1] or '')
  text_edits = vim.tbl_map(function(text_edit)
    if max <= text_edit.range.start.line then
      text_edit.range.start.line = max - 1
      text_edit.range.start.character = len
      text_edit.newText = '\n' .. text_edit.newText
      has_eol_text_edit = true
    end
    if max <= text_edit.range['end'].line then
      text_edit.range['end'].line = max - 1
      text_edit.range['end'].character = len
      has_eol_text_edit = true
    end
    return text_edit
  end, text_edits)

  -- Some LSP servers are depending on the VSCode behavior.
  -- The VSCode will re-locate the cursor position after applying TextEdit so we also do it.
  local is_current_buf = vim.api.nvim_get_current_buf() == bufnr
  local cursor = (function()
    if not is_current_buf then
      return {
        row = -1,
        col = -1,
      }
    end
    local cursor = vim.api.nvim_win_get_cursor(0)
    return {
      row = cursor[1] - 1,
      col = cursor[2],
    }
  end)()

  -- Apply text edits.
  local is_cursor_fixed = false
  for _, text_edit in ipairs(text_edits) do
    local e = {
      start_row = text_edit.range.start.line,
      start_col = get_line_byte_from_position(bufnr, text_edit.range.start),
      end_row = text_edit.range['end'].line,
      end_col  = get_line_byte_from_position(bufnr, text_edit.range['end']),
      text = vim.split(text_edit.newText, '\n', true),
    }
    vim.api.nvim_buf_set_text(bufnr, e.start_row, e.start_col, e.end_row, e.end_col, e.text)

    local row_count = (e.end_row - e.start_row) + 1
    if e.end_row < cursor.row then
      cursor.row = cursor.row + (#e.text - row_count)
      is_cursor_fixed = true
    elseif e.end_row == cursor.row and e.end_col <= cursor.col then
      cursor.row = cursor.row + (#e.text - row_count)
      cursor.col = #e.text[#e.text] + (cursor.col - e.end_col)
      if #e.text == 1 then
        cursor.col = cursor.col + e.start_col
      end
      is_cursor_fixed = true
    end
  end

  if is_cursor_fixed then
    local is_valid_cursor = true
    is_valid_cursor = is_valid_cursor and cursor.row < vim.api.nvim_buf_line_count(bufnr)
    is_valid_cursor = is_valid_cursor and cursor.col <= #(vim.api.nvim_buf_get_lines(bufnr, cursor.row, cursor.row + 1, false)[1] or '')
    if is_valid_cursor then
      vim.api.nvim_win_set_cursor(0, { cursor.row + 1, cursor.col })
    end
  end

  -- Remove final line if needed
  local fix_eol = has_eol_text_edit
  fix_eol = fix_eol and api.nvim_buf_get_option(bufnr, 'fixeol')
  fix_eol = fix_eol and (vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1] or '') == ''
  if fix_eol then
    vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, {})
  end
end

return M
