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
		vim.api.nvim_call_function('mkdir', {installation_path, 'p'})
	end

	return installation_path
end

local function select_name_from_source(source)
	local idx = string.find(source, "/[^/]*$")
	local name = string.sub(source, idx + 1)
	name = string.gsub(name, "%.git$", '')
	return name
end

local function normalize_source(source)
	if string.match(source, '^https?') or string.match(source, '^git') then
		return source
	end

	if string.match(source, '^.+/.+$') then
		return 'https://github.com/' .. source
	end

	-- FIXME: this will make vim crash
	error(source .. ' is not a valid plugin source')
end

local function get_default_dump_file()
	local info = debug.getinfo(1, 'S')
	return vim.api.nvim_call_function('fnamemodify', {info.short_src, ':h'}) .. '/packman.txt'
end

local function download_work(source, dest)
	local process = io.popen(string.format('git clone %s %s --recurse-submodules --quiet 2>&1; echo $?', source, dest))
	local lastline
	for line in process:lines() do
		lastline = line
	end
	return lastline
end

local function fetch_plugin(source, dir, cb)
	local ok, result = pcall(normalize_source, source)
	if not ok then
		vim.api.nvim_err_writeln('failed to resolve source ' .. source)
		return
	end
	source = result
	local name = select_name_from_source(source)
	local dest = dir .. '/' .. name
	local isdir = vim.api.nvim_call_function('isdirectory', {dest})
	if isdir == 1 then
		vim.api.nvim_err_writeln('plugin is already installed.')
		return
	end

	vim.loop.new_work(download_work, function(code)
		if code == '0' then
			vim.api.nvim_out_write('Install plugin "' .. name .. '" successfully\n')
		else
			vim.api.nvim_err_writeln('Install plugin "' .. name .. '" failed')
		end

		if type(cb) == 'function' then cb(code) end
	end):queue(source, dest)
end

local function get_dir_start()
	return packman.path .. '/start'
end

local function get_dir_opt()
	return packman.path .. '/opt'
end

---- Public Methods ----

function packman.init()
	packman.path = init_installation_path()
end

function packman.install(filename)
	if filename == nil then
		filename = get_default_dump_file()
	end

	local read = io.lines(filename)

	function run()
		local line = read()
		if line then
			local words = {}
			for w in line:gmatch('%S+') do table.insert(words, w) end
			if words[1] == '*' then
				fetch_plugin(words[2], get_dir_opt(), run)
			else
				fetch_plugin(words[1], get_dir_start(), run)
			end
		end
	end

	run()
end

function packman.dump(filename)
	if filename == nil then
		filename = get_default_dump_file()
	end

	local outputfile = io.open(filename, 'w+')
	local files = io.popen('ls -d ' .. packman.path .. '/start/*/')
	for fname in files:lines() do
		local url = io.popen('cd ' .. fname .. ' && git config --get remote.origin.url')
		local urlstring = url:read()
		outputfile:write(urlstring .. '\n')
		url:close()
	end
	files = io.popen('ls -d ' .. packman.path .. '/opt/*/')
	for fname in files:lines() do
		local url = io.popen('cd ' .. fname .. ' && git config --get remote.origin.url')
		local urlstring = url:read()
		outputfile:write('* ' .. urlstring .. '\n')
		url:close()
	end

	outputfile:flush()
	outputfile:close()
end

function packman.get(source)
	if type(source) == 'table' then
		-- Source is on the first slot if it is a table, install it as a optional plugin.
		return packman.opt(source[1])
	end
	local dir = get_dir_start()
	fetch_plugin(source, dir)
end

function packman.opt(source)
	local dir = get_dir_opt()
	fetch_plugin(source, dir)
end

function packman.remove(name)
	local plugins_matching_name = {}
	local subdir = {'start', 'opt'}

	for _, dir in ipairs(subdir) do
		local files = io.popen('ls ' .. packman.path .. '/' .. dir)
		for filename in files:lines() do
			if filename == name then
				table.insert(plugins_matching_name, dir .. '/' .. filename)
			end
		end
		files:close()
	end

	local count = #plugins_matching_name
	if count == 0 then
		-- TODO: better log
		print('Unable to locate plugin ' .. name)
	end

	if count > 1 then
		print(count .. ' results found')
	end

	for _, plugin in ipairs(plugins_matching_name) do
		local code = os.execute('rm -rf "' .. packman.path .. '/' .. plugin .. '" 2> /dev/null')
		if code ~= 0 then
			print('Failed to remove plugin ' .. plugin)
		end
	end
end

function packman.clear()
	local code = os.execute('rm -rf "' .. packman.path .. '"')
	if code ~= 0 then
		print('Failed to clear plugins')
	end
end

packman.init()

return packman
