local M = {}
local config = require("lucy.config")
local serpent = require("serpent")
local marks = {['extmarks'] = {}}
local api = vim.api

local ns_id = vim.api.nvim_create_namespace('HighlightLineNamespace')

M.setup = function()
  vim.keymap.set('n', '<leader><leader>', function() M.addMark() end)
  vim.keymap.set('n', '<leader>ba', function() M.listMarks() end)
  vim.keymap.set('n', '<leader>bd', function() M.readFile() end)
  config.setup()
end


function firstNonWhitespace(str)
    for i = 1, #str do
        if not string.find(str:sub(i, i), "%s") then
            return i
        end
    end
    return -1  -- Return -1 if no non-whitespace character is found
end

local highlightLine = function(lineNr)
  local lineText = vim.api.nvim_buf_get_lines(0, lineNr - 1, lineNr, false)[1]


  local startCol = firstNonWhitespace(lineText)
  local endCol = string.len(lineText)

  if type(marks['extmarks']) ~= "table" then
    marks['extmarks'] = {}
  end

  local extmark_id = vim.api.nvim_buf_set_extmark(0, ns_id, lineNr - 1, startCol - 1, {end_row = lineNr - 1, end_col = endCol, hl_group='LucyLine'})

  marks['extmarks'][lineNr] = extmark_id
end


M.addMark = function()
  local filename = vim.fn.expand('%')
  local pos = vim.fn.getpos('.')
  local text = vim.fn.getline('.')

  local line_nr = pos[2]

  if type(marks[filename]) ~= "table" then
    marks[filename] = {}
  end

  if marks[filename][line_nr] == nil then
    marks[filename][line_nr] = text
  else
    marks[filename][line_nr] = nil
  end

  print(dump(marks))
  print("woof")
  print(type(marks['extmarks']))

  if type(marks['extmarks']) ~= "table" then
    marks['extmarks'] = {}
  end

  print(line_nr)
  print(marks['extmarks'][line_nr])
  if marks['extmarks'][line_nr] ~= nil then
    print('deleting')
    print(dump(marks))
    vim.api.nvim_buf_del_extmark(0, ns_id, marks['extmarks'][line_nr])
    marks['extmarks'][line_nr] = nil
  else
    print('adding')
    print(dump(marks))
    highlightLine(pos[2])
  end
  M.writeFile()
end


M.drawMarks = function()
  for k,v in pairs(marks['extmarks']) do
    highlightLine(k)
  end
end

M.updateMarksFromExt = function()
  local all = api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})
  marks['extmarks'] = {}
  for k, v in pairs(all) do
    marks['extmarks'][v[2] + 1] = v[1]
  end
end


local getMarksFile = function()
  return vim.fn.stdpath("data") .. "/lucy/" .. vim.fn.getcwd():gsub('/', '_') .. ".lua"
end

M.writeFile = function()
  print('writing attempt')
  print(dump(marks))
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
  -- Example usage: read the JSON file "data.json"
  -- local data, error_message = readJsonFromFile(vim.fn.expand("~/code/lucy.nvim/test.json"))
  print(getMarksFile())
  local data, error_message = readJsonFromFile(getMarksFile())
  if data then
    marks = data
    print("JSON data loaded successfully:")
  else
    -- Error occurred while reading the JSON file
    print(error_message)
  end
  M.drawMarks()
end

return M

