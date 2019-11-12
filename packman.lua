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

local function define_commands()
	-- TODO
end

function packman.init()
	local path = init_installation_path()
	define_commands()
end

function packman.get()
	-- TODO
end

function packman.remove()
	-- TODO
end

packman.init()

return packman
