local M = {}
local config = require("lucy.config")
local serpent = require("serpent")
local marks = {}
local api = vim.api
local augroup = vim.api.nvim_create_augroup -- Create/get autocommand group
local autocmd = vim.api.nvim_create_autocmd -- Create autocommand
local om = require('orderedmap')

local saved_hi_group = nil
local ns_id = vim.api.nvim_create_namespace('HighlightLineNamespace')

-- local filename = ""

local cwd = nil

-- Cache to use for speed up (at cost of possibly outdated results)
local root_cache = {}

-- Array of file names indicating root directory. Modify to your liking.
local root_names = { '.git',
  'project.toml',
  ".clang-format",
  "pyproject.toml",
  "setup.py",
  "LICENSE",
  "README.md",
  'Makefile' }

function string.starts(String, Start)
  return string.sub(String, 1, string.len(Start)) == Start
end

local set_root = function()
  -- Get directory path to start search from
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' then
    path = vim.loop.cwd()
  else
    path = vim.fs.dirname(path)
  end

  -- Try cache and resort to searching upward for root directory
  local root = root_cache[path]

  local obsidian_root = vim.fn.expand "~/Library/Mobile Documents/iCloud~md~obsidian/"
  if root == nil then
    if string.starts(path, obsidian_root) then
      root = obsidian_root
    else
      local root_file = vim.fs.find(root_names, { path = path, upward = true })[1]
      if root_file == nil then
        root = vim.loop.cwd()
      else
        root = vim.fs.dirname(root_file)
        root_cache[path] = root
      end
    end
  end

  -- Set current directory
  cwd = root
end


local getMarksFile = function()
  -- return vim.fn.stdpath("data") .. "/lucy/" .. vim.fn.getcwd():gsub('/', '_') .. ".lua"
  if cwd == nil then return end
  return vim.fn.stdpath("data") .. "/lucy/" .. cwd:gsub('/', '_') .. ".lua"
end


function swallow_output(callback, ...)
  local old_print = print
  print = function(...)
  end
  pcall(callback, arg)
  print = old_print
end

function firstNonWhitespace(str)
  for i = 1, #str do
    if not string.find(str:sub(i, i), "%s") then
      return i
    end
  end
  return -1 -- Return -1 if no non-whitespace character is found
end

local addMark = function(lineNr, filename, marks_section)
  local lineText = vim.api.nvim_buf_get_lines(0, lineNr - 1, lineNr, false)[1]
  local startCol = firstNonWhitespace(lineText)


  local endCol = string.len(lineText)

  if startCol == -1 then
    marks_section[lineNr] = nil
    return
  end

  -- print("start end", startCol, endCol )


  local extmark_id = vim.api.nvim_buf_set_extmark(0, ns_id, lineNr - 1, startCol - 1,
    { end_row = lineNr - 1, end_col = endCol, hl_group = 'LucyLine' })

  marks_section[lineNr] = extmark_id
  -- M.drawMarks()
end


local getMarkSection = function(filename)
  if marks[getMarksFile()][filename] == nil then
    return nil
  end

  local marks_section = marks[getMarksFile()][filename]['extmarks']
  if marks[getMarksFile()][filename]['mod_extmarks'] ~= nil then
    marks_section = marks[getMarksFile()][filename]['mod_extmarks']
  end
  return marks_section
end

local clearModMarks = function(marks)
  for k, v in pairs(marks[getMarksFile()]) do
    marks[getMarksFile()][k]['mod_extmarks'] = nil
  end
end

local copyModMarks = function(marks)
  for k, v in pairs(marks[getMarksFile()]) do
    if marks[getMarksFile()][k]['mod_extmarks'] ~= nil then
      marks[getMarksFile()][k]['extmarks'] = vim.deepcopy(marks[getMarksFile()][k]['mod_extmarks'])
    end
    marks[getMarksFile()][k]['mod_extmarks'] = nil
  end
end


M.toggleMark = function(line_nr)
  local filename = vim.fn.expand('%')

  -- M.readFile()

  local text = vim.api.nvim_buf_get_lines(0, line_nr - 1, line_nr, false)[1]

  local file_entry = { extmarks = {} }

  if marks[getMarksFile()] == nil then
    marks[getMarksFile()] = {}
  end

  om.add(marks[getMarksFile()], filename, file_entry)
  print("added file", dump(marks[getMarksFile()][filename]))

  local marks_section = getMarkSection(filename)

  if marks_section[line_nr] ~= nil then
    print('deleting')

    vim.api.nvim_buf_del_extmark(0, ns_id, marks_section[line_nr])
    marks_section[line_nr] = nil

    -- if next(marks_section) == nil then
    --   om.del(marks[getMarksFile()], filename)
    -- end
  else
    print('adding')
    addMark(line_nr, filename, marks_section)
  end

  if not api.nvim_buf_get_option(0, 'modified') then
    M.writeFile()
  end
end

M.drawMarks = function()
  local filename = vim.fn.expand('%')

  -- print('draw marks for: ' .. filename)
  -- print('dump marks')

  -- dump(marks)
  -- dump(getMarksFile())

  if marks[getMarksFile()] == nil or next(marks[getMarksFile()]) == nil then
    M.readFile()
    -- dump(marks[getMarksFile()])
  end

  if marks[getMarksFile()][filename] == nil then
    -- print('returning')
    return
  end

  -- print('draw marks[getMarksFile()]')
  local marks_section = getMarkSection(filename)

  for k, v in pairs(marks_section) do
    addMark(k, filename, marks_section)
  end
end

M.clearAllMarks = function(filename)
  local all = api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})
  -- marks[getMarksFile()][filename]['mod_extmarks'] = {}
  for k, v in pairs(all) do
    vim.api.nvim_buf_del_extmark(0, ns_id, v[1])
  end
end

-- on buf change
M.updateMarksFromExt = function()
  local filename = vim.fn.expand('%')

  if marks[getMarksFile()] == nil
      or marks[getMarksFile()][filename] == nil then
    return
  end

  if filename == {}
      or filename == nil
      or filename == ""
      or vim.bo.filetype == "term"
      or vim.bo.filetype == ""
      or vim.bo.filetype == "fzf"
      or vim.bo.filetype == "Nvimtree"
  then
    return
  end

  if api.nvim_buf_get_option(0, 'modified') then
    if marks[getMarksFile()][filename]['mod_extmarks'] == nil then
      marks[getMarksFile()][filename]['mod_extmarks'] = vim.deepcopy(marks[getMarksFile()][filename]['ext_marks'])
    end

    -- get all actual marks[getMarksFile()] to mod buffer
    local all = api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})
    marks[getMarksFile()][filename]['mod_extmarks'] = {}
    for k, v in pairs(all) do
      marks[getMarksFile()][filename]['mod_extmarks'][v[2] + 1] = v[1]
    end
  else
    -- remove file from mod lists if it is not modded anymore
    marks[getMarksFile()][filename]['mod_extmarks'] = nil
  end

  M.clearAllMarks(filename)
  M.drawMarks(filename)
end



M.writeFile = function()
  print('writing attempt')
  print(dump(marks[getMarksFile()]))
  print("copy mod marks")
  copyModMarks(marks)

  local serialized = serpent.dump(marks[getMarksFile()])
  print(serialized)
  local file = io.open(getMarksFile(), "w")
  if file then
    file:write(serialized)
    file:close()
    print("Table serialized ")
  else
    print("Error: Unable to open output.json for writing")
  end
end

-- Function to read a JSON file
local function readJsonFromFile(filename)
  local file = io.open(filename, "r") -- Open the file in read mode
  if file then
    local str = file:read("*a")       -- Read the entire content of the file
    file:close()                      -- Close the file

    local ok, copy = serpent.load(str)
    if ok then
      return copy
    else
      return nil, "Error: File not found or unable to open."
    end
  else
    return nil, "Error: File not found or unable to open."
  end
end


M.readFile = function()
  local filename = vim.fn.expand('%')
  -- if filename == nil or filename == '' then
  --   return
  -- end

  -- Example usage: read the JSON file "data.json"
  -- local data, error_message = readJsonFromFile(vim.fn.expand("~/code/lucy.nvim/test.json"))
  local data, error_message = readJsonFromFile(getMarksFile())
  if data then
    marks[getMarksFile()] = data
    clearModMarks(marks)
    -- print("JSON data loaded successfully:")
  else
    return
    -- todo: check if file exists, silent return
    -- print(error_message)
  end
end

function getPrevIndex(tbl, key)
  local prevKey = nil
  for k, v in pairs(tbl) do
    if k == key then
      return prevKey
    end
    prevKey = k
  end
  return nil -- Key not found or first key in the table
end

function getLastItem(tbl)
  local last = nil
  for k, v in pairs(tbl) do
    last = k
  end
  return last
end

local getNextFile = function(backwards, filename)

  local next_file = nil
  if filename == nil or filename == "" then
    next_file = (backwards and { om.last(marks[getMarksFile()]) }
      or { om.first(marks[getMarksFile()]) })[1]
  else
    next_file = (backwards and { om.prev(marks[getMarksFile()], filename) }
      or { om.next(marks[getMarksFile()], filename) })[1]
  end
  return next_file
end

local getNextMarkPos = function(current_line, marks_section, backwards)
  local jump = -1

  -- find line to jump to
  for k, v in pairs(marks_section) do
    if backwards then
      if k < current_line and (jump == -1 or k > jump) then
        jump = k
      end
    else
      if k > current_line and (jump == -1 or k < jump) then
        jump = k
      end
    end
  end
  return jump
end


M.fileJump = function(opts)
  local filename = vim.fn.expand('%')
  local backwards = opts["backwards"]

  if getMarksFile() == nil then
    return
  end

  if marks[getMarksFile()] == nil or next(marks[getMarksFile()]) == nil then return end

  local next_file = nil
  if filename == '' or filename == nil then
    local next_file = next(marks[getMarksFile()]["orderlist"], nil)
  else
    next_file = getNextFile(backwards, filename)
  end
  vim.cmd('e ' .. next_file)
end


M.jump = function(opts)
  local backwards = opts["backwards"]
  local fileJump = opts["fileJump"]
  local filename = vim.fn.expand('%')

  if getMarksFile() == nil then
    return
  end

  -- M.readFile()

  if marks[getMarksFile()] == nil or next(marks[getMarksFile()]) == nil then return end

  -- jump to first file from splash
  if filename == '' or filename == nil then
    local next_file = next(marks[getMarksFile()], nil)
    if next_file == "orderlist" then
      next_file = next(marks[getMarksFile()], "orderlist")
    end
    if next_file == nil then return end
    vim.cmd('e ' .. next_file)
    if backwards then
      vim.cmd('normal! G')
    else
      vim.cmd('normal! gg')
    end
    M.jump({ backwards = backwards })
    return
  end

  local marks_section = getMarkSection(filename)
  if marks_section == nil then return end

  local pos = vim.fn.getpos('.')
  local jump = getNextMarkPos(pos[2], marks_section, backwards)

  -- todo: has the bug if you're one line above a block
  if jump ~= -1 then
    local total_lines = vim.fn.line('$')
    local last_jump = pos[2]
    while math.abs(jump - last_jump) == 1 do
      last_jump = jump
      jump = getNextMarkPos(jump, marks_section, backwards)

      -- todo: this condition seems to not be necessary or
      -- only valid for forward, should look
      if jump > total_lines then break end
    end
    if last_jump ~= pos[2] then
      jump = last_jump
    end

    vim.cmd('normal! ' .. jump .. 'G')
    return
  else
    -- line not found
    -- stay at last position if we reach the end
    jump = pos[2]


    -- print('here ' .. fileJump)

    if not fileJump then
      return
    end


    -- or jump to next file
    local next_file = nil
    while next_file ~= filename do
      if next_file == nil then
        next_file = filename
      end
      next_file = getNextFile(backwards, next_file)

      if next_file == nil then
        return
      end

      local new_marks_section = getMarkSection(next_file)

      if next(new_marks_section) ~= nil then
        break
      end
    end

    -- prevent infinite loop
    if next_file == filename then
      return
    end

    -- print('next file', next_file)

    vim.cmd('e ' .. next_file)
    if backwards then
      vim.cmd('normal! G')
    else
      vim.cmd('normal! gg')
    end

    local new_marks_section = getMarkSection(next_file)
    local pos = vim.fn.getpos('.')

    if new_marks_section and new_marks_section[pos[2]] == nil then
      M.jump(opts)
    end
  end
end


-- M.jump = function(opts)
--   local filename = vim.fn.expand('%')
--   M.jumpToNextMark(opts)
-- end


-- Function to toggle a highlighting group
local toggleHighlightingGroup = function(group)
  local get_hi_group = api.nvim_get_hl(0, { name = group })
  print('hi_group ', dump(get_hi_group))
  if next(get_hi_group) ~= nil then
    saved_hi_group = get_hi_group
    api.nvim_set_hl(0, group, {})
  else
    api.nvim_set_hl(0, group, saved_hi_group)
  end
end

M.toggleMarkPress = function()
  local vstart = vim.fn.getpos('v')[2]
  local vend = vim.fn.getpos('.')[2]
  if vend < vstart then
    vend, vstart = vstart, vend -- swap
  end

  -- print(vstart, vend)
  for i = vstart, vend do
    M.toggleMark(i)
  end

  -- leave visual mode
  api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', false, true, true), 'nx', false)
end



M.setup = function()
  -- auto group stuff for detecting the cwd
  local cwd_augroup = vim.api.nvim_create_augroup('CwdAutoRoot', {})
  vim.api.nvim_create_autocmd({ 'BufReadPost', "BufEnter", "VimEnter" }, { group = cwd_augroup, callback = set_root })
  config.setup()

  augroup('LucyAutoCmds', { clear = true })
  autocmd('BufEnter', {
    group = 'LucyAutoCmds',
    callback = function()
      swallow_output(M.drawMarks)
      swallow_output(M.updateMarksFromExt())
    end
  })

  autocmd({ "TextChanged", "TextChangedI" }, {
    group = 'LucyAutoCmds',
    callback = function()
      swallow_output(M.updateMarksFromExt)
    end
  })

  autocmd({ "BufWritePost" }, {
    group = 'LucyAutoCmds',
    callback = function()
      swallow_output(M.writeFile)
    end
  })
end

return M
