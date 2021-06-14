local uv = vim.loop

test('get plugin', function(done)
	packman.get('theJian/nvim-hello', function()
		expect(test_helper.is_installed('nvim-hello'))
		done()
	end)
end)

test('get optional plugin', function(done)
	packman.get({'theJian/nvim-hello'}, function()
		expect(test_helper.is_installed_as_optional('nvim-hello'))
		done()
	end)
end)
