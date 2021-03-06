local setmetatable = setmetatable
local crc32Short = ngx.crc32_short
local redis = require("resty.redis")

local connector = {}
local mt = {__index = connector}
local cjson = require "cjson.safe"
function connector:new(config)
      local instance = {
        timeout = config.timeout or 1000,
        pool = config.pool or {maxIdleTime = 120000, size = 200},
        clusters = config.clusters or {},
        database = config.database or 0,
        password = config.password or "",
    }
    setmetatable(instance, mt)
    return instance
end

function connector:connectByKey(key)
    local hostInfo = self:getHost(key)

    local host = hostInfo[1]
    local port = hostInfo[2]
    local red = redis:new()
    red:set_timeout(self.timeout)
    local ok, err = red:connect(host, port)
    if not ok then
        return nil, err
    end

    local count, err = red:get_reused_times()
    if 0 == count and self.password ~= nil then
        ok, err = red:auth(self.password)
    elseif err then
        return nil, err

    end
    if err then
    	ngx.log(ngx.ERR,err)
    end
    red:select(self.database)
    return red
end

function connector:getHost(key)
    local idx = crc32Short(key) % (#self.clusters) + 1
    return self.clusters[idx]
end

function connector:keepAlive(red)
    local ok, err = red:set_keepalive(self.pool.maxIdleTime, self.pool.size)
    if not ok then
        red:close()
    end
    return true
end

return connector
