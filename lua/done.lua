local M = {}

-- local config_defaults = {
--   dir
-- }

local EMPTY_TASK = '[ ] '

M.setup = function()
  -- TODO
end

-- Global State
local state = {
  floating = {
    buf = -1,
    win = -1,
  },
  lines = {},
}

local function urlEncode(str)
  str = string.gsub(str, '([^%w%.%- ])', function(c)
    return string.format('%%%02X', string.byte(c))
  end)
  str = string.gsub(str, ' ', '+')
  return str
end

local function get_dir()
  return vim.fn.stdpath 'data' .. '/done'
end

local function get_path()
  local raw_cwd = vim.uv.cwd()
  if raw_cwd == nil then
    return ''
  end

  local safe_cwd = urlEncode(raw_cwd:sub(2))

  return get_dir() .. '/' .. safe_cwd .. '.txt'
end

local function read_file()
  -- Try to read file, if fails the file does not exist
  local ok, lines = pcall(vim.fn.readfile, get_path())
  state.lines = ok and lines or { EMPTY_TASK }
end

local function save_file()
  local lines = vim.api.nvim_buf_get_lines(state.floating.buf, 0, -1, false)

  local dir = get_dir()

  -- Only make directory if doesn't exist
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end

  vim.fn.writefile(lines, get_path())
end

local function bound_keymap(mode, lhs, rhs)
  vim.keymap.set(mode, lhs, rhs, { buffer = state.floating.buf })
end

local function create_floating_window(opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)

  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local buf
  if vim.api.nvim_buf_is_valid(opts.buf) then
    buf = opts.buf
  else
    buf = vim.api.nvim_create_buf(false, false) -- No file, scratch buffer
  end

  read_file()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, state.lines)

  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'rounded',
    title = vim.uv.cwd(),
    title_pos = 'center',
  }

  vim.api.nvim_create_autocmd('BufWinLeave', {
    buffer = buf,
    callback = function()
      save_file()
    end,
  })

  local win = vim.api.nvim_open_win(buf, true, win_config)

  return { buf = buf, win = win }
end

local function close_window()
  vim.api.nvim_win_hide(state.floating.win)
end

local function open_window()
  state.floating = create_floating_window { buf = state.floating.buf }
  bound_keymap('n', '<ESC>', function()
    close_window()
  end)
  bound_keymap('i', '<CR>', '<CR>' .. EMPTY_TASK)
  bound_keymap('n', 'o', 'o' .. EMPTY_TASK)
  bound_keymap('n', 'O', 'O' .. EMPTY_TASK)
  -- Task keymaps
  bound_keymap('n', 'ga', 'i' .. EMPTY_TASK)
  bound_keymap('n', 'gd', '<CMD>DoneTaskDone<CR>')
  bound_keymap('n', 'gf', '<CMD>DoneTaskForward<CR>')
  bound_keymap('n', 'gi', '<CMD>DoneTaskInProgress<CR>')
end

local function toggle_window()
  if not vim.api.nvim_win_is_valid(state.floating.win) then
    open_window()
  else
    close_window()
  end
end

local function change_task_state(newState)
  local divider = newState == '/' and '$' or '/'
  local cursor = vim.api.nvim_win_get_cursor(0)

  vim.cmd('s' .. divider .. '^\\[.\\]' .. divider .. '[\\' .. newState .. ']')
  vim.cmd 'nohlsearch'

  vim.api.nvim_win_set_cursor(0, cursor)
end

local function send_to_bottom()
  local lines = vim.api.nvim_buf_get_lines(state.floating.buf, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(state.floating.win)
  local row = cursor[1]
  local line = lines[row]

  table.remove(lines, row)
  table.insert(lines, line)

  vim.api.nvim_buf_set_lines(state.floating.buf, 0, -1, false, lines)
end

vim.api.nvim_create_user_command('DoneToggle', toggle_window, {})
vim.api.nvim_create_user_command('DoneTaskDone', function()
  if vim.api.nvim_get_current_win() == state.floating.win then
    change_task_state 'x'
    send_to_bottom()
  end
end, {})
vim.api.nvim_create_user_command('DoneTaskForward', function()
  if vim.api.nvim_get_current_win() == state.floating.win then
    change_task_state '>'
  end
end, {})
vim.api.nvim_create_user_command('DoneTaskInProgress', function()
  if vim.api.nvim_get_current_win() == state.floating.win then
    change_task_state '/'
  end
end, {})

return M
