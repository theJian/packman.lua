function try(f, catch_f)
	local status, exception = pcall(f)
	if not status then
		catch_f(exception)
	end
end

try(function()
	local uv = vim.loop
	local cwd = vim.api.nvim_call_function('getcwd', {})
	local testdir = cwd .. '/test'
	vim.api.nvim_set_option('runtimepath', cwd)
	vim.api.nvim_set_option('packpath', testdir)

	packman.init()

	local test_get = loadfile('test/test-get.lua')
	local test_dump = loadfile('test/test-dump.lua')
	local test_remove = loadfile('test/test-remove.lua')
	local test_install = loadfile('test/test-install.lua')

	local test_modules = {test_get, test_dump, test_remove, test_install}
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

	local helper = {}

	function helper.is_installed(target_name)
		local dir = packman.path .. '/start'
		for name, t in fs_iter(dir) do
			if t == 'directory' and name == target_name then
				return true
			end
		end
		return false
	end

	function helper.is_installed_as_optional(target_name)
		local dir = packman.path .. '/opt'
		for name, t in fs_iter(dir) do
			if t == 'directory' and name == target_name then
				return true
			end
		end
		return false
	end

	coroutine.wrap(function()

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

		test_helper = helper

		for _, test_module in ipairs(test_modules) do
			test_module()
		end

		print_summary()

		if test_result.failed > 0 then
			vim.api.nvim_command('cq')
		else
			vim.api.nvim_command('q')
		end
	end)()
end, function(err)
	print(vim.inspect(err))
	vim.api.nvim_command('cq')
end)

