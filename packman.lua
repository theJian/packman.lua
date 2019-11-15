packman = {}

local function init_installation_path()
	local packpath = vim.api.nvim_get_option('packpath')
	local idx = packpath:find(',')
	local installation_path
	if idx then
		installation_path = packpath:sub(1, idx - 1)
	else
		installation_path = packpath
	end
	installation_path = installation_path .. '/pack/packman'

	local isdir = vim.api.nvim_call_function('isdirectory', {installation_path})
	if isdir == 0 then
		vim.api.nvim_call_function('mkdir', {installation_path})
	end

	return installation_path
end

local function fetch_plugin(source, dest)
	local isdir = vim.api.nvim_call_function('isdirectory', {dest})
	if isdir == 1 then
		-- TODO: better log message
		print('plugin is already installed.')
		return
	end

	os.execute(string.format('git clone %s %s --recurse-submodules --quiet', source, dest))
end

local function select_name_from_source(source)
	local idx = string.find(source, "/[^/]*$")
	local name = string.sub(source, idx + 1)
	return name
end

local function normalize_source(source)
	if string.match(source, '^https?') or string.match(source, '^git@') then
		return source
	end

	if string.match(source, '^.+/.+$') then
		return 'https://github.com/' .. source
	end

	error(source .. ' is not a valid plugin source')
end

---- Public Methods ----

function packman.init()
	packman.path = init_installation_path()
end

function packman.install()
	
end

function packman.get(source)
	if type(source) == 'table' then
		-- Source is on the first slot if it is a table, install it as a optional plugin.
		return packman.opt(source[1])
	end
	local ok, result = pcall(function() return normalize_source(source) end)
	if not ok then
		-- TODO: log error
		return
	end
	source = result
	local name = select_name_from_source(source)
	local dest = packman.path .. '/start/' .. name
	fetch_plugin(source, dest)
end

function packman.opt(source)
	local ok, result = pcall(function() return normalize_source(source) end)
	if not ok then
		-- TODO: log error
		return
	end
	source = result
	local name = select_name_from_source(source)
	local dest = packman.path .. '/opt/' .. name
	fetch_plugin(source, dest)
end

function packman.remove()
	-- TODO
end

packman.init()

return packman
