packman = {}

local function NOOP()end

local function set_interval(interval, cb)
	local timer = vim.loop.new_timer()
	timer:start(interval, interval, vim.schedule_wrap(function()
		cb()
	end))
	return timer
end

local function set_timeout(timeout, cb)
	local timer = vim.loop.new_timer()
	timer:start(timeout, 0, vim.schedule_wrap(function()
		timer:stop()
		timer:close()
		cb()
	end))
	return timer
end

local function clear_timer(timer)
	if timer and timer:is_active() then
		timer:stop()
		timer:close()
	end
end

local function make_package(name, pathname, optional)
	return {
		name = name,
		pathname = pathname,
		optional = optional,
	}
end

local notify = {
	buf = nil,
	win = nil,
	timer = nil,
}

function notify:show(text)
	if not self.win then
		-- create a win
		local ew = vim.api.nvim_get_option('columns')
		local eh = vim.api.nvim_get_option('lines')
		self.buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(self.buf, 0, -1, true, {text})
		local opts = {
			relative = 'editor',
			width = vim.api.nvim_strwidth(text),
			height = 1,
			focusable = false,
			style = 'minimal',
			anchor = 'SE',
			row = eh - 2,
			col = ew,
		}
		self.win = vim.api.nvim_open_win(self.buf, false, opts)
	else
		-- update win buffer
		vim.api.nvim_buf_set_lines(self.buf, 0, -1, true, {text})
		vim.api.nvim_win_set_width(self.win, vim.api.nvim_strwidth(text))
	end
end

function notify:hide()
	if self.win then
		vim.api.nvim_win_close(self.win, true)
		self.win = nil
		self.buf = nil
	end
end

function notify:alert(str)
	clear_timer(self.timer)
	self:show(str)
	self.timer = set_timeout(3000, function()
		self:hide()
	end)
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

local function get_packfile(filename)
	if filename == nil then
		local info = debug.getinfo(1, 'S')
		return vim.api.nvim_call_function('fnamemodify', {info.short_src, ':h'}) .. '/packfile'
	end
	return filename
end

local function read_packfile(filename)
	filename = get_packfile(filename)

	local plugins = {}

	local opt = 'opt'
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
	local chunk = assert(loadfile(filename))
	setfenv(chunk, { Pack = Pack, opt = opt })
	chunk()

	return plugins
end

local task_return_code_ok = 0
local task_return_code_failed = 1
local task_return_code_skipped = 2

local function git_clone_command(source, dest)
	return string.format('git clone %s %s --recurse-submodules --quiet', source, dest)
end

local function git_pull_command(dir)
	return string.format('git -C %s pull --quiet --ff-only --rebase=false', dir)
end

local function download(source, dest, cb)
	local loop = vim.loop
	local command = git_clone_command(source, dest)

	local handle
	handle = loop.spawn('bash', {
		args = { '-c', command },
	}, function(code)
		handle:close()
		cb(code)
	end)
end

local function update(dir, cb)
	local loop = vim.loop
	local command = git_pull_command(dir)

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
		notify:alert(reason)
		cb(task_return_code_failed, reason)
		return
	end

	source = result
	local name = select_name_from_source(source)
	local dest = dir .. '/' .. name
	local isdir = vim.api.nvim_call_function('isdirectory', {dest})
	if isdir == 1 then
		local reason = 'plugin is already installed'
		notify:alert(reason)
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

local function update_plugin(dir, cb)
	cb = cb or NOOP
	local isdir = vim.api.nvim_call_function('isdirectory', {dir})
	if isdir ~= 1 then
		cb(task_return_code_failed, 'Plugin is not installed')
		return
	end

	update(dir, function(code)
		if code == 0 then
			cb(task_return_code_ok)
		else
			cb(task_return_code_failed, 'failed to update')
		end
	end)
end

local function get_dir_start()
	return packman.path .. '/start'
end

local function get_dir_opt()
	return packman.path .. '/opt'
end

local function get_files_in_dir(dir)
	return io.popen('/bin/ls -d ' .. dir .. '/* 2>/dev/null')
end

local function get_git_url(dir)
	local file = io.popen('git -C '.. dir .. ' config --get remote.origin.url')
	local output = file:read()
	file:close()
	return output
end

local function packfile_serialize(o)
	local s = {}
	if type(o) == 'table' then
		table.insert(s, 'Pack {')
		for k,v in pairs(o) do
			if k == 'optional' then
				if v then
					table.insert(s, '  opt,')
				end
			elseif k == 'source' then
				table.insert(s, 2, string.format('  %q,', v))
			else
				table.insert(s, string.format('  %s = %s,', k, packfile_serialize(v)))
			end
		end
		table.insert(s, '}')
	elseif type(o) == 'number' then
		table.insert(s, o)
	elseif type(o) == 'string' then
		table.insert(s, string.format('%q', o))
	else
		error('cannot serialize a ' .. type(o))
	end

	return table.concat(s, '\n')
end

local function run_install_plugins(plugins, n, cb)
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
				run_install_plugins(plugins, next_n, cb)
			end)
		)
	end
end

local function run_update_plugins(files, n, cb)
	local dir = files[n]
	if dir then
		update_plugin(
			dir,
			vim.schedule_wrap(function(code, reason)
				local next_n = n + 1
				cb({
					i = n,
					status = {code, reason},
					next = next_n
				});
				run_update_plugins(files, next_n, cb)
			end)
		)
	end
end

local spinner_generator = coroutine.create(function()
	local frames = {'🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'}
	local l = #frames
	local i = 1
	while true do
		coroutine.yield(frames[i])
		i = i % l + 1
	end
end)

local function spinner_sign()
	local _, sign = coroutine.resume(spinner_generator)
	return sign
end

local function show_install_progress(i, total)
	notify:show(spinner_sign() .. string.format(' Installing plugins [%u/%u]', i, total))
end

local function show_install_result(succeeded, failed, skipped)
	notify:alert(string.format('%u succeeded, %u failed, %u skipped', succeeded, failed, skipped))
end

local function show_update_result(succeeded, failed, total)
	if succeeded == total then
		notify:alert('Done!')
		return
	end

	notify:alert(string.format('%u updated, %u failed', succeeded, failed))
end

local function find_installed_files(pattern)
	local files = {}
	local files_start = get_files_in_dir(get_dir_start())
	local files_opt = get_files_in_dir(get_dir_opt())
	for _, files_found in ipairs({files_start, files_opt}) do
		for fname in files_found:lines() do
			local name = vim.api.nvim_call_function('fnamemodify', {fname, ':t'})
			if pattern == name or pattern == nil then
				table.insert(files, fname)
			end
		end
	end
	return files
end

local function get_installed_packages()
	local packages = {}
	local files_start = get_files_in_dir(get_dir_start())
	local files_opt = get_files_in_dir(get_dir_opt())
	for pathname in files_start:lines() do
		local name = vim.api.nvim_call_function('fnamemodify', {pathname, ':t'})
		table.insert(packages, make_package(name, pathname, false))
	end

	for pathname in files_opt:lines() do
		local name = vim.api.nvim_call_function('fnamemodify', {pathname, ':t'})
		table.insert(packages, make_package(name, pathname, true))
	end

	return packages
end

---- Public Methods ----

function packman.init()
	packman.path = init_installation_path()
end

function packman.install(filename, cb)
	local plugins = read_packfile(filename)

	local succeeded = 0
	local skipped = 0
	local failed = 0
	local total = #plugins
	local i = 1

	show_install_progress(i, total)
	local timer = set_interval(500, function()
		show_install_progress(i, total)
	end)

	run_install_plugins(plugins, 1, function(result)
		local return_code = result.status[1]
		if return_code == task_return_code_ok then
			succeeded = succeeded + 1
		elseif return_code == task_return_code_failed then
			failed = failed + 1
		elseif return_code == task_return_code_skipped then
			skipped = skipped + 1
		end

		if result.i == total then
			-- tasks finished
			clear_timer(timer)
			show_install_result(succeeded, failed, skipped)

			if cb then
				cb(result)
			end

			return
		end

		i = result.next
	end)
end

function packman.dump(filename)
	filename = get_packfile(filename)

	local plugins = {}
	local files = get_files_in_dir(get_dir_start())
	for fname in files:lines() do
		local git_url = get_git_url(fname)
		table.insert(plugins, {
			source = git_url,
		})
	end

	files = get_files_in_dir(get_dir_opt())
	for fname in files:lines() do
		local git_url = get_git_url(fname)
		table.insert(plugins, {
			source = git_url,
			optional = true
		})
	end

	local outputfile = io.open(filename, 'w+')

	for _, plugin in ipairs(plugins) do
		outputfile:write(packfile_serialize(plugin) .. '\n\n')
	end

	outputfile:flush()
	outputfile:close()

	notify:alert('packfile has been created as ' .. filename)
end

function packman.get(source, cb)
	local dir, src
	if type(source) == 'table' then
		-- Source is on the first slot if it is a table, install it as a optional plugin.
		dir = get_dir_opt()
		src = source[1]
	else
		dir = get_dir_start()
		src = source
	end

	local msg = string.format(' Installing from %s', src)
	notify:show(spinner_sign() .. msg)
	local timer = set_interval(500, function()
		notify:show(spinner_sign() .. msg)
	end)

	install_plugin(
		src,
		dir,
		vim.schedule_wrap(function(code, reason)
			clear_timer(timer)

			if code == task_return_code_ok then
				notify:alert('Done!')
			elseif code == task_return_code_failed then
				notify:alert('Failed! ' .. reason)
			elseif code == task_return_code_skipped then
				notify:alert('skipped! ' .. reason)
			end

			if cb then
				cb(code, reason)
			end
		end)
	)
end

function packman.update(pattern)
	local files = find_installed_files(pattern)

	if #files == 0 then
		notify:alert(string.format('Unable to find plugin %q', pattern))
		return
	end

	local succeeded = 0
	local failed = 0
	local total = #files

	local msg = ' Updating'
	notify:show(spinner_sign() .. msg)
	local timer = set_interval(500, function()
		notify:show(spinner_sign() .. msg)
	end)

	run_update_plugins(files, 1, function(result)
		local return_code = result.status[1]
		if return_code == task_return_code_ok then
			succeeded = succeeded + 1
		elseif return_code == task_return_code_failed then
			failed = failed + 1
		end

		if result.i == total then
			clear_timer(timer)
			show_update_result(succeeded, failed, total)
		end
	end)
end

function packman.remove(pattern)
	local files = find_installed_files(pattern)

	if #files == 0 then
		notify:alert(string.format('Unable to find plugin %q', pattern))
		return
	end

	local succeeded = 0
	local failed = 0
	for _, fname in ipairs(files) do
		local code = os.execute(string.format('rm -rf %q 2> /dev/null', fname))
		if code ~= 0 then
			failed = failed + 1
		else
			succeeded = succeeded + 1
		end
	end

	if failed == 0 then
		notify:alert(succeeded .. ' plugins removed')
	else
		notify:alert(succeeded .. ' plugins removed, but ' .. failed .. ' failed to remove.')
	end
end

function packman.clear()
	local code = os.execute(string.format('rm -rf %q', packman.path))
	if code ~= 0 then
		notify:alert('failed to clear plugins')
	end
end

function packman.helptags(pattern)
	local files = find_installed_files(pattern)

	if #files == 0 then
		notify:alert(string.format('Unable to find plugin %q', pattern))
		return
	end

	for _, file in ipairs(files) do
		local doc_dir = file .. '/doc'
		local isdir = vim.api.nvim_call_function('isdirectory', {doc_dir})
		if isdir == 1 then
			print(file)
			vim.cmd("helptags " .. doc_dir)
		end
	end
end

function packman.list()
	local packages = get_installed_packages()
	local write = vim.api.nvim_out_write

	local max_len = 0
	for _, package in ipairs(packages) do
		local name = package.name
		if #name > max_len then max_len = #name end
	end

	for _, package in ipairs(packages) do
		local name = package.name
		write(name .. string.rep(' ', max_len - #name + 1))
		if package.optional then
			write('[optional]\n')
		else
			write('\n')
		end
	end
end

packman.init()

return packman
