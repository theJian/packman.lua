local uv = vim.loop
local dumpfile = packman.path .. '/packfile'

test('install', function(done)
	expect(not test_helper.is_installed('nvim-hello'))
	expect(not test_helper.is_installed_as_optional('nvim-hello'))

	packman.install(dumpfile, function()
		expect(test_helper.is_installed('nvim-hello'))
		expect(test_helper.is_installed_as_optional('nvim-hello'))
		done()
	end)
end)
