local uv = vim.loop
local dumpfile = packman.path .. '/packfile'

test('install', function(done)
	assert(not test_helper.is_installed('nvim-hello'))
	assert(not test_helper.is_installed_as_optional('nvim-hello'))

	packman.install(dumpfile, function()
		assert(test_helper.is_installed('nvim-hello'))
		assert(test_helper.is_installed_as_optional('nvim-hello'))
		done()
	end)
end)
