local M = {}
local config = require("lucy.config")
local serpent = require("serpent")
local marks = {}
local api = vim.api
local augroup = vim.api.nvim_create_augroup   -- Create/get autocommand group
local autocmd = vim.api.nvim_create_autocmd   -- Create autocommand
local om = require('orderedmap')

-- local filename = ""

local ns_id = vim.api.nvim_create_namespace('HighlightLineNamespace')

function swallow_output(callback, ...)
  local old_print = print
  print = function(...) end
  pcall(callback, arg)
  print = old_print
end


function firstNonWhitespace(str)
    for i = 1, #str do
        if not string.find(str:sub(i, i), "%s") then
            return i
        end
    end
    return -1  -- Return -1 if no non-whitespace character is found
end

local addMark = function(lineNr, filename, marks_section)
  local lineText = vim.api.nvim_buf_get_lines(0, lineNr - 1, lineNr, false)[1]
  local startCol = firstNonWhitespace(lineText)


  local endCol = string.len(lineText)

  if startCol == -1 then
    marks_section[lineNr] = nil
    return
  end

  print("start end", startCol, endCol )


  local extmark_id = vim.api.nvim_buf_set_extmark(0, ns_id, lineNr - 1, startCol - 1, {end_row = lineNr - 1, end_col = endCol, hl_group='LucyLine'})

  marks_section[lineNr] = extmark_id
end

local delHighlight = function(lineNr, filename)
end

local getMarkSection = function(filename)
  local marks_section = marks[filename]['extmarks']
  if marks[filename]['mod_extmarks'] ~= nil then
    marks_section = marks[filename]['mod_extmarks']
  end
  return marks_section
end

local clearModMarks = function(marks)
  for k,v in pairs(marks) do
    marks[k]['mod_extmarks'] = nil
  end
end

local copyModMarks = function(marks)
  for k,v in pairs(marks) do
    if marks[k]['mod_extmarks'] ~= nil then
      marks[k]['extmarks'] = vim.deepcopy(marks[k]['mod_extmarks'])
    end
    marks[k]['mod_extmarks'] = nil
  end
end


M.toggleMark = function()
  local filename = vim.fn.expand('%')
  local pos = vim.fn.getpos('.')
  local text = vim.fn.getline('.')

  local line_nr = pos[2]


  local file_entry = {extmarks = {}}

  om.add(marks, filename, file_entry)
  print("added file", dump(marks[filename]))

  local marks_section = getMarkSection(filename)

  if marks_section[line_nr] ~= nil then
    print('deleting')
    print(dump(marks))

    vim.api.nvim_buf_del_extmark(0, ns_id, marks_section[line_nr])
    marks_section[line_nr] = nil

    -- if next(marks_section) == nil then
    --   om.del(marks, filename)
    -- end

  else
    print('adding')
    print(dump(marks))
    addMark(pos[2], filename, marks_section)
  end

  if not api.nvim_buf_get_option(0, 'modified') then
    M.writeFile()
  end
end

M.drawMarks = function()
  local filename = vim.fn.expand('%')
  if next(marks) == nil then
    M.readFile()
  end

  if marks[filename] == nil then
    return
  end

  print('draw marks')
  print(dump(marks))
  local marks_section = getMarkSection(filename)

  for k,v in pairs(marks_section) do
    addMark(k, filename, marks_section)
  end
end

M.clearAllMarks = function(filename)
  local all = api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})
  -- marks[filename]['mod_extmarks'] = {}
  for k, v in pairs(all) do
    vim.api.nvim_buf_del_extmark(0, ns_id, v[1])
  end
end

-- on buf change
M.updateMarksFromExt = function()

  local filename = vim.fn.expand('%')
  if marks[filename] == nil then return end

  print('wwoooofa2')
  print(filename)
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

  print('wwoooofa')

  if api.nvim_buf_get_option(0, 'modified') then
    if marks[filename]['mod_extmarks'] == nil then
      marks[filename]['mod_extmarks'] = vim.deepcopy(marks[filename]['ext_marks'])
      -- marks['mod_orderlist'] = vim.deepcopy(marks['orderlist'])
      -- marks['mod_files'] = {}
    end
    -- marks['mod_files'][filename] = true

    -- get all actual marks to mod buffer
    local all = api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})
    marks[filename]['mod_extmarks'] = {}
    for k, v in pairs(all) do
      marks[filename]['mod_extmarks'][v[2] + 1] = v[1]
    end
    print(dump(marks))
  else
    -- remove file from mod lists if it is not modded anymore
    marks[filename]['mod_extmarks'] = nil

    -- if marks['mod_files'] ~= nil then
    --   marks['mod_files'][filename] = nil
    -- end
    -- if next(marks['mod_files']) == nil then
    --   marks['mod_files'] = nil
    --   marks['mod_orderlist'] = nil
    -- end

    print(' 22 updated marks state:')
    print(dump(marks))
  end

  print('updated marks state:')
  print(dump(marks))


  M.clearAllMarks(filename)
  M.drawMarks(filename)
end


local getMarksFile = function()
  return vim.fn.stdpath("data") .. "/lucy/" .. vim.fn.getcwd():gsub('/', '_') .. ".lua"
end

M.writeFile = function()
  print('writing attempt')
  print(dump(marks))
  copyModMarks(marks)

  local serialized = serpent.dump(marks)
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
  local file = io.open(filename, "r")  -- Open the file in read mode
  if file then
    local str = file:read("*a")  -- Read the entire content of the file
    file:close()  -- Close the file

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
    marks = data
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
    return nil  -- Key not found or first key in the table
end

function getLastItem(tbl)
  local last = nil
  for k, v in pairs(tbl) do
    last = k
  end
  return last
end

M.jumpToNextMark = function(backwards, calling_filename, loop_count)
  local filename = vim.fn.expand('%')

  if calling_filename == filename then
    if loop_count < 2 then
      loop_count = loop_count + 1
    else
      return
    end
  end


  print('reading marks')
  if next(marks) == nil then
    M.readFile()
  end

  print(dump(marks))

  -- jump to first file
  if filename == '' or filename == nil then
    local next_file = next(marks, nil)
    vim.cmd('e ' .. next_file)
    if backwards then
      vim.cmd('normal! G')
    else
      vim.cmd('normal! gg')
    end
    M.jumpToNextMark(backwards, calling_filename)
    return
  end

  local marks_section = getMarkSection(filename)
  print("here", filename)
  print(dump(marks_section))

  local pos = vim.fn.getpos('.')
  local jump = -1

  for k,v in pairs(marks_section) do
    if backwards then
      if k < pos[2] and (jump == -1 or k > jump) then
        jump = k
      end
    else
      if k > pos[2] and (jump == -1 or k < jump) then
        jump = k
      end
    end
  end

  if jump == -1 then

    -- stay at last position if we reach the end
    jump = pos[2]

    -- or jump to next file
    local next_file  = nil
    if filename == nil or filename == "" then
      next_file = (backwards and {om.last(marks)}
                             or {om.first(marks)})[1]
    else
      next_file = (backwards and {om.prev(marks, filename)}
                             or {om.next(marks, filename)})[1]
    end

    print('next file', next_file)

    vim.cmd('e ' .. next_file)

    if backwards then
      vim.cmd('normal! G')
    else
      vim.cmd('normal! gg')
    end

    M.jumpToNextMark(backwards, calling_filename, loop_count)
    return
  end
  vim.cmd('normal! ' .. jump .. 'G')
end

M.jump = function(backwards)
  local filename = vim.fn.expand('%')
  M.jumpToNextMark(backwards, filename, 0)
end



M.setup = function()
  vim.keymap.set('n', '<leader><leader>', function() M.toggleMark() end)
  vim.keymap.set('n', '<leader>ba', function() M.listMarks() end)
  vim.keymap.set('n', '<leader>bd', function() M.readFile() end)
  vim.keymap.set('n', '<leader>j', function() M.jump() end)
  vim.keymap.set('n', '<leader>k', function() M.jump(true) end)
  config.setup()

  augroup('LucyAutoCmds', { clear = true })
  autocmd('BufReadPost', {
    group = 'LucyAutoCmds',
    callback = function()
      swallow_output(M.drawMarks)
    end
  })

  autocmd({"TextChanged", "TextChangedI"}, {
    group = 'LucyAutoCmds',
    callback = function()
      -- swallow_output(M.updateMarksFromExt)
      M.updateMarksFromExt()
    end
  })

  autocmd({"BufWritePost"}, {
    group = 'LucyAutoCmds',
    callback = function()
      swallow_output(M.writeFile)
    end
  })
end

return M
