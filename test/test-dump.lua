local uv = vim.loop
local dumpfile = packman.path .. '/packfile'

test('dump', function()
	packman.dump(dumpfile)
	local f = io.open(dumpfile, "r")
	local file_exists = f~=nil
	io.close(f)
	assert(file_exists)
end)
