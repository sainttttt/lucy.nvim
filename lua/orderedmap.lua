
local M = {}

M.add = function(map, k, v)
	if map['orderlist'] == nil then
		map['orderlist'] = {}
	end

	-- this doesn't allow overwrites atm
	if map[k] == nil then
		table.insert(map['orderlist'], k)
		map[k] = v
	end
end

M.delValFromList = function(map, val)
	local newList = {}

	for k,v in pairs(map) do
		if v ~= val then
			table.insert(newOrderList, v)
		end
	end
	return newList

end

M.del = function(map, k)
	if map[k] == nil then
		return
	end

	local newOrderList = {}
	for i in map['orderlist'] do
		if i ~= map[k] then
			table.insert(newOrderList, i)
		end
	end

	map['orderlist'] = newOrderList

	map[k] = nil
end

M.first = function(map)
	return map['orderlist'][1]
end

M.last = function(map)
	return map['orderlist'][#map['orderlist']]
end

M.find = function(map, v)
	-- find index of element
	local index = nil
	for k, val in pairs(map['orderlist']) do
		if val == v then index = k end
	end

	-- returns nil if cannot find element
	return index
end

M.next = function(map, v)
	local index = M.find(map, v)
	if index == #map['orderlist'] then
		index = 0
	end
	return map['orderlist'][index + 1]
end

M.prev = function(map, v)
	local index = M.find(map, v)
	if index == 1 then
		index = #map['orderlist'] + 1
	end
	return map['orderlist'][index - 1]
end


return M

