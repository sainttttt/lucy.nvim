local M = {}
local config = require("lucy.config")
local serpent = require("serpent")
local marks = {}
local api = vim.api
local augroup = vim.api.nvim_create_augroup   -- Create/get autocommand group
local autocmd = vim.api.nvim_create_autocmd   -- Create autocommand


-- local filename = ""

local ns_id = vim.api.nvim_create_namespace('HighlightLineNamespace')


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

  if marks[filename] == nil then
    marks[filename] = {extmarks = {}}
  end

  print(dump(marks[filename]))

  local marks_section = getMarkSection(filename)

  if marks_section[line_nr] ~= nil then
    print('deleting')
    print(dump(marks))

    vim.api.nvim_buf_del_extmark(0, ns_id, marks_section[line_nr])
    marks_section[line_nr] = nil
  else
    print('adding')
    print(dump(marks))
    addMark(pos[2], filename, marks_section)
  end

  if not api.nvim_buf_get_option(0, 'modified') then
    M.writeFile()
  end
end

M.drawMarks = function(filename)
  if marks[filename] == nil then
    return
  end

  local marks_section = getMarkSection(filename)

  for k,v in pairs(marks_section) do
    addMark(k, filename, marks_section)
  end
end

-- on buf change
M.updateMarksFromExt = function()

  print("updating marks")
  local filename = vim.fn.expand('%')

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
    marks[filename]['mod_extmarks'] = vim.deepcopy(marks[filename]['ext_marks'])
  else
    marks[filename]['mod_extmarks'] = nil
    return
  end

  local all = api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})
  print(dump(all))
  marks[filename]['mod_extmarks'] = {}
  for k, v in pairs(all) do
    marks[filename]['mod_extmarks'][v[2] + 1] = v[1]
  end
  print(dump(marks))
  print("done update")
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
  if filename == nil or filename == '' then
    return
  end

  -- Example usage: read the JSON file "data.json"
  -- local data, error_message = readJsonFromFile(vim.fn.expand("~/code/lucy.nvim/test.json"))
  print(getMarksFile())
  local data, error_message = readJsonFromFile(getMarksFile())
  if data then
    marks = data
    clearModMarks(marks)
    print('read marks')
    print(dump(marks))
    -- print("JSON data loaded successfully:")
  else
    return
    -- todo: check if file exists, silent return
    -- print(error_message)
  end

  M.drawMarks(filename)
end

M.jumpToNextMark = function(backwards)
  local filename = vim.fn.expand('%')
  local marks_section = getMarkSection(filename)

  local pos = vim.fn.getpos('.')
  local jump = -1

  print("here")
  print(dump(marks_section))
  for k,v in pairs(marks_section) do
    print('entry')
    print(k,v)
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
    jump = pos[2]
    print('max')
  end
  vim.cmd('normal! ' .. jump .. 'G')
end


M.setup = function()
  vim.keymap.set('n', '<leader><leader>', function() M.toggleMark() end)
  vim.keymap.set('n', '<leader>ba', function() M.listMarks() end)
  vim.keymap.set('n', '<leader>bd', function() M.readFile() end)
  vim.keymap.set('n', '<leader>j', function() M.jumpToNextMark() end)
  vim.keymap.set('n', '<leader>k', function() M.jumpToNextMark(true) end)
  config.setup()

  augroup('LucyAutoCmds', { clear = true })
  autocmd('BufReadPost', {
    group = 'LucyAutoCmds',
    callback = function()
      M.readFile()
    end
  })

  autocmd({"TextChanged", "TextChangedI"}, {
    group = 'LucyAutoCmds',
    callback = function()
      M.updateMarksFromExt()
    end
  })

  autocmd({"BufWritePost"}, {
    group = 'LucyAutoCmds',
    callback = function()
      M.writeFile()
    end
  })
end



return M
