local uv = vim.loop

test('remove plugin', function()
	assert(test_helper.is_installed('nvim-hello'))

	packman.remove 'theJian/nvim-hello'

	assert(test_helper.is_installed('nvim-hello'))
end)
