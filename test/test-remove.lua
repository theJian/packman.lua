local uv = vim.loop

test('remove plugin', function()
	assert(test_helper.is_installed('nvim-hello'))

	packman.remove 'nvim-hello'

	assert(not test_helper.is_installed('nvim-hello'))
	assert(not test_helper.is_installed_as_optional('nvim-hello'))
end)
