local uv = vim.loop
local cwd = vim.fn.getcwd()
local testdir = cwd .. '/test'
vim.api.nvim_set_option('runtimepath', cwd)
vim.api.nvim_set_option('packpath', testdir)

packman.init()

local test_get = loadfile('test/test-get.lua')
local test_remove = loadfile('test/test-remove.lua')

local test_result = { total = 0, failed = 0 }

local function print_test_result(desc, is_failed)
	test_result.total = test_result.total + 1
	if is_failed then
		print(string.format('[%s]%s \n', '✗', desc))
		test_result.failed = test_result.failed + 1
	else
		print(string.format('[%s]%s \n', '✓', desc))
	end
end

local function print_summary()
	print(string.format('Tests: %d failed, %d passed, %d total', test_result.failed, test_result.total - test_result.failed, test_result.total))
end

local function fs_iter(path)
	local fs = uv.fs_scandir(path)
	return function()
		return uv.fs_scandir_next(fs)
	end
end

coroutine.wrap(function()
	test_helper = {}

	function test_helper.is_installed(target_name)
		local dir = packman.path .. '/start'
		for name, t in fs_iter(dir) do
			if t == 'directory' and name == target_name then
				return true
			end
		end
		return false
	end

	function test_helper.is_installed_as_optional(target_name)
		local dir = packman.path .. '/opt'
		for name, t in fs_iter(dir) do
			if t == 'directory' and name == target_name then
				return true
			end
		end
		return false
	end

	test = function(desc, f)
		local self = coroutine.running()
		local nparams = debug.getinfo(f).nparams
		local is_async = nparams == 1
		local is_failed = false

		assert = function(condition)
			if not condition then
				is_failed = true
			end
		end

		f(function()
			assert = nil
			print_test_result(desc, is_failed)

			coroutine.resume(self)
		end)

		if is_async then
			coroutine.yield()
		else
			assert = nil
			print_test_result(desc, is_failed)
		end
	end

	test_get()
	test_remove()

	print_summary()

	if test_result.failed > 0 then
		vim.cmd('cq')
	else
		vim.cmd('q')
	end
end)()
