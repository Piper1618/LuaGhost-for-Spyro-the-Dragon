-- Some of these depend on functionality added by the BizHawk emulator (such as the bizstring library)

function string.starts(String, Start)
   return string.sub(String, 1, string.len(Start)) == Start
end

function string.ends(String, End)
	return string.sub(String, string.len(String) - string.len(End) + 1) == End
end

function string.split(inputstr, sep)
	sep = sep or '%s'
	local t = {}
	for field,s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
		table.insert(t,field)
		if s == "" then return t end
	end
end

function string.trim(String)
	return bizstring.trim(String) or ""
end

function table.globalize(t)
	for k, v in pairs(t) do
		_G[k] = v
	end
end

function table.insertSorted(t, v, sortFunction)
	-- If t is an array (a table of size n with numeric
	-- keys for 1 through n) that is already sorted
	-- according to sortFunction, the new value v will be
	-- inserted into the array at while keeping the
	-- array sorted.
	
	if type(sortFunction) ~= "function" then
		sortFunction = function(a, b) return a < b end
	end
	
	for i = 1, #t do
		if not sortFunction(t[i], v) then
			table.insert(t, i, v)
			return
		end
	end
	
	table.insert(t, v)

end

function table.set(t) -- set of list
  local u = { }
  for _, v in ipairs(t) do u[v] = true end
  return u
end

function table.keys(t)
	local u = {}
	for k in pairs(t) do
		table.insert(u, k)
	end
	return u
end

function table.duplicate(t)
	if type(t) ~= "table" then return t end
	
	local newTable = {}
	setmetatable(newTable, getmetatable(t))
	
	for k, v in pairs(t) do
		newTable[k] = v
	end
	
	return newTable
end

function table.deepDuplicate(t)
	
	local seen = {}
	
	local function _dupe(_t)
		if type(_t) ~= "table" then return _t end
		
		if seen[_t] ~= nil then return seen[_t] end
		
		local newTable = {}
		setmetatable(newTable, getmetatable(_t))
		
		for k, v in pairs(_t) do
			newTable[k] = _dupe(v)
		end
		
		seen[_t] = newTable
	
		return newTable
	end
	
	return _dupe(t)
end

function table.isSimilar(t, u, exclude)
	-- Checks if the two tables have the same content, even
	-- if they are not the same reference.
	-- If exclude is a table, its keys will be ignored in t
	-- and u. Note that to skip "a" and "b" in the
	-- check, exclude should be formated as {a = true, b = true},
	-- not {"a", "b"}. if t and u contain tables as values,
	-- these will be checked recursively, but exclude will
	-- not propogate beyond the top level.
	
	if type(t) ~= "table" or type(u) ~= "table" then return t == u end
	
	-- Check that every (key, value) pair in t has a matching (key, value) in u
	for k, v in pairs(t) do
		if exclude == nil or exclude[k] == nil then
			if type(v) == "table" then
				if not table.isSimilar(v, u[k]) then return false end
			else
				if v ~= u[k] then return false end 
			end
		end
	end
	
	-- Check that every key in o also exists in t
	for k in pairs(u) do
		if exclude == nil or exclude[k] == nil then
			if t[k] == nil then return false end
		end
	end
	
	return true
end

function math.round(n)
	return math.floor(n + 0.5)
end

function dump(o)
	function _dump(o, a, b)
		if type(o) == 'table' then
			local s = ''
			for k,v in pairs(o) do
				if type(k) ~= 'number' then k = '"'..k..'"' end
				s = s..a..'['..k..'] = '.._dump(v, '', '')..','..b
			end
			return '{'..b..s..'}'..b
		elseif type(o) == 'string' then
			return '"' .. o .. '"'
		else
			return tostring(o)
		end
	end

	return _dump(o, "\t", "\n")
end

function conditional(b, t, f)
	if b then return t end
	return f
end

function getGlobalVariable(target)
	--[[
		Get a value in the global table.
		target is the name of the variable (as a string) to be got OR it is an array of strings describing the path to the variable (for if you need to get a property of a table). If the full path to the requested variable does not exist, nil will be returned.
		
		examples:
		getGlobalVariable("a") is the same as _G["a"]
		getGlobalVariable({"a", "b"}) is the same as _G["a"]["b"]
	--]]
	
	if (target or "") == "" then return nil end
	
	if type(target) == "string" then
		--Condition: We're accessing a global variable directly
		return _G[target]
	elseif type(target) == "table" then
		--Condition: We're accessing a property of a global table
		local var = _G[target[1]] or {}
		for i = 2, (#target - 1) do
			var = var[target[i]] or {}
		end
		return var[target[#target]]
	end
end

function setGlobalVariable(target, value)
	--[[
		Set a value in the global table.
		target is the name of the variable (as a string) to be set OR it is an array of strings describing the path to the variable (for if you need to set a property of a table).
		value will be writen to the variable described by target. If target is an array and the full path does not exist, it will be created.
		
		examples:
		setGlobalVariable("a", 1) is the same as _G["a"] = 1
		setGlobalVariable({"a", "b"}, 1) is the same as _G["a"]["b"] = 1
	--]]

	if (target or "") == "" then return end
	
	if type(target) == "string" then
		--Condition: We're accessing a global variable directly
		_G[target] = value
	elseif type(target) == "table" then
		--Condition: We're accessing a property of a global table
		if _G[target[1]] == nil then _G[target[1]] = {} end
		local var = _G[target[1]]
		for i = 2, (#target - 1) do
			if var[target[i]] == nil then var[target[i]] = {} end
			var = var[target[i]]
		end
		var[target[#target]] = value
	end
end

function tryGetGlobalFunction(target)
	if type(target) == "function" then
		return target, true
	end
	
	local f = getGlobalVariable(target)
	if type(f) == "function" then
		return f, true
	end
	
	return nil, false
end

function tryRunGlobalFunction(target, a, b, c, d, e)
	local f = tryGetGlobalFunction(target)
	
	if type(f) == "function" then
		return f(a, b, c, d, e)
	end
end
