local skynet = require "skynet"
local snax = require "skynet.snax"
local gateserver = require "snax.wsgateserver"

local watchdog
local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }
local forwarding = {}	-- agent -> connection

local login

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local handler = {}

function handler.open(source)
	-- default code
	-- watchdog = conf.watchdog or source

  -- from ken
	watchdog = snax.bind(source, "watchdog")
	login = skynet.newservice("login")
	skynet.call(login, "lua", "open", source)
end

function handler.message(fd, msg, sz)
	-- recv a package, forward it
	local c = connection[fd]
	local agent = c.agent
	if agent then
		skynet.redirect(agent, c.client, "client", 0, msg, sz)
	else
		-- default code
		-- skynet.send(watchdog, "lua", "socket", "data", fd, netpack.tostring(msg, sz))

		-- from ken
		skynet.redirect(login, fd, "client", 0, msg, sz)
	end
end

function handler.connect(fd, addr)
	print("connect:", addr)
	local c = {
		fd = fd,
		ip = addr,
	}
	connection[fd] = c
	-- default code
	-- skynet.send(watchdog, "lua", "socket", "open", fd, addr)

  -- from ken
	gateserver.openclient(fd)
end

local function unforward(c)
	if c.agent then
		forwarding[c.agent] = nil
		c.agent = nil
		c.client = nil
	end
end

local function close_fd(fd)
	local c = connection[fd]
	if c then
		unforward(c)
		connection[fd] = nil
	end
end

function handler.disconnect(fd)
	close_fd(fd)
	-- default code
	-- skynet.send(watchdog, "lua", "socket", "close", fd)

	-- from ken
	watchdog.post.close(fd)
end

function handler.error(fd, msg)
	close_fd(fd)
	-- default code
	-- skynet.send(watchdog, "lua", "socket", "error", fd, msg)

	-- from ken
	watchdog.post.error(fd, msg)
end

function handler.warning(fd, size)
	-- default code
	-- skynet.send(watchdog, "lua", "socket", "warning", fd, size)

	-- from ken
	watchdog.post.warning(fd, size)
end

local CMD = {}

function CMD.forward(source, fd, client, address)
	local c = assert(connection[fd])
	unforward(c)
	c.client = client or 0
	c.agent = address or source
	forwarding[c.agent] = c
	-- default code
	-- gateserver.openclient(fd)
end

-- function CMD.accept(source, fd)
-- 	local c = assert(connection[fd])
-- 	unforward(c)
-- 	gateserver.openclient(fd)
-- end

function CMD.kick(source, fd)
	gateserver.closeclient(fd)
end

function handler.command(cmd, source, ...)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

gateserver.start(handler)
