local uv = vim.loop

test('remove plugin', function()
	expect(test_helper.is_installed('nvim-hello'))

	packman.remove 'nvim-hello'

	expect(not test_helper.is_installed('nvim-hello'))
	expect(not test_helper.is_installed_as_optional('nvim-hello'))
end)
