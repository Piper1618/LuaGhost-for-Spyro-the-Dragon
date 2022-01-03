local file = {}

file.seperator = package.config:sub(1, 1)

function file.combinePath(a, b, c, d, e)
	local seperator = file.seperator
	if type(a) == "string" then
		if type(b) == "string" then
			a = a .. seperator .. b
			if type(c) == "string" then
				a = a .. seperator .. c
				if type(d) == "string" then
					a = a .. seperator .. d
					if type(e) == "string" then
						a = a .. seperator .. e
					end
				end
			end
		end
		return a
	elseif type(a) == "table" then
		local path = ""
		for i, v in ipairs(a) do
			if i > 1 then path = path .. seperator end
			path = path .. v
		end
		return path
	end
	return nil
end

function file.nameFromPath(path)
	local sep = file.seperator
	local t = {}
	for field, s in string.gmatch(path, "([^"..sep.."]*)("..sep.."?)") do
		table.insert(t,field)
		if s == "" then break end
	end
	return t[#t]
end

function file.copy(old, new)
	local f, err = io.open(old, 'rb')
	if err then
		error(err)
	end
	local content = f:read("*a")
	f:close()
	
	f, err = io.open(new, "wb")
	if err then
		error(err)
	end
	f:write(content)
	f:close()
end

function file.exists(path)
	local f=io.open(path,"r")
	if f~=nil then io.close(f) return true else return false end
end

function file.createFolder(path)
	os.execute("mkdir \"" .. path .. "\"")
end

function file.listFiles(path)
	return io.popen("dir \"" .. (path or "") .. "\" /b /a-d"):lines()
end

function file.listFilesRecursively(path)
	return io.popen("dir \"" .. (path or "") .. "\" /b /a-d /s"):lines()
end

function file.listDirectories(path)
	return io.popen("dir \"" .. (path or "") .. "\" /b /ad"):lines()
end

-- func should be a function. It will be called for each
-- file. It is called with two arguments, the full path to
-- the file (including the file name) and the file name
-- without the path.
function file.forAllFilesRecursively(folder, func)
	local function split(inputstr, sep)
		sep = sep or '%s'
		local t = {}
		for field,s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
			table.insert(t,field)
			if s == "" then return t end
		end
	end
	
	for f in file.listFilesRecursively(folder) do
		local filename = split(f, file.seperator)
		filename = filename[#filename]
		func(f, filename)
	end
end

return file