local uv = vim.loop

test('get plugin', function(done)

	local installed_count = 0

	packman.get('theJian/nvim-hello', function()
		expect(test_helper.is_installed('nvim-hello'))
		installed_count = installed_count + 1
		if installed_count == 2 then
			done()
		end
	end)

	packman.get('github/copilot.vim', function()
		expect(test_helper.is_installed('copilot.vim'))
		installed_count = installed_count + 1
		if installed_count == 2 then
			done()
		end
	end)
end)

test('get plugin with https', function(done)
	packman.get('https://github.com/theJian/nvim-hello.git', function()
		expect(test_helper.is_installed('nvim-hello'))
		done()
	end)
end)

test('get plugin with ssh', function(done)
	packman.get('git@github.com:theJian/nvim-hello.git', function()
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
