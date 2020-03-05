packman = {}

local function NOOP()end

local function alert(str)
	-- TODO
	-- vim.api.nvim_err_writeln(str)
end

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
	return vim.api.nvim_call_function('fnamemodify', {info.short_src, ':h'}) .. '/packfile'
end

local function read_packfile(filename)
	if filename == nil then
		filename = get_default_dump_file()
	end

	local plugins = {}

	-- save the content and restore them after finishing reading packfile
	local opt_saved = opt
	local Pack_saved = Pack

	function opt() end
	function Pack(p)
		local source, optional

		source = p[1]
		if not source then
			error('Error reading packfile. pack.source is required.')
		end

		optional = vim.tbl_contains(p, opt)

		table.insert(plugins, {
			source = source,
			optional = optional,
		})
	end
	dofile(filename)

	opt = opt_saved
	Pack = Pack_saved

	return plugins
end

local task_return_code_ok = 0
local task_return_code_failed = 1
local task_return_code_skipped = 2

local function get_git_clone_command(source, dest)
	return string.format('git clone %s %s --recurse-submodules --quiet', source, dest)
end

local function download(source, dest, cb)
	local loop = vim.loop
	local command = get_git_clone_command(source, dest)

	local handle
	handle = loop.spawn('bash', {
		args = { '-c', command },
	}, function(code)
		handle:close()
		cb(code)
	end)
end

local function install_plugin(source, dir, cb)
	cb = cb or NOOP
	local ok, result = pcall(normalize_source, source)
	if not ok then
		local reason = 'failed to resolve source ' .. source
		alert(reason)
		cb(task_return_code_failed, reason)
		return
	end

	source = result
	local name = select_name_from_source(source)
	local dest = dir .. '/' .. name
	local isdir = vim.api.nvim_call_function('isdirectory', {dest})
	if isdir == 1 then
		local reason = 'plugin is already installed'
		alert(reason)
		cb(task_return_code_skipped, reason)
		return
	end

	download(source, dest, function(code)
		if code == 0 then
			cb(task_return_code_ok)
		else
			cb(task_return_code_failed, 'failed to install')
		end
	end)
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
	local plugins = read_packfile(filename)

	local function run(plugins, n, cb)
		local plugin = plugins[n]
		if plugin then
			install_plugin(
				plugin.source,
				plugin.optional and get_dir_opt() or get_dir_start(),
				vim.schedule_wrap(function(code, reason)
					local next_n = n + 1
					cb({
						i = n,
						status = {code, reason},
						next = next_n
					});
					run(plugins, next_n, cb)
				end)
			)
		end
	end

	run(plugins, 1, function(result)
		alert(result.i, vim.inspect(result.status))
	end)
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
	install_plugin(source, dir)
end

function packman.opt(source)
	local dir = get_dir_opt()
	install_plugin(source, dir)
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
		alert('Unable to locate plugin ' .. name)
	end

	if count > 1 then
		alert(count .. ' results found')
	end

	for _, plugin in ipairs(plugins_matching_name) do
		local code = os.execute('rm -rf "' .. packman.path .. '/' .. plugin .. '" 2> /dev/null')
		if code ~= 0 then
			alert('Failed to remove plugin ' .. plugin)
		end
	end
end

function packman.clear()
	local code = os.execute('rm -rf "' .. packman.path .. '"')
	if code ~= 0 then
		alert('Failed to clear plugins')
	end
end

packman.init()

return packman
