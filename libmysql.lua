local sgsub = string.gsub
local gmatch = string.gmatch
local tinsert = table.insert
local quote_sql_str = ngx.quote_sql_str
local type = type
local ipairs = ipairs
local pairs = pairs
local random = math.random
local randomseed = math.randomseed
--local cjson = require("cjson")
local mytime = ngx.time()
local mysql = require("resty.mysql")
local config = require("config")["mysql"]
local _DB = {}

function _DB:new(self,database)
    if not database then
        databaseconfig = config["default"]
    else
        if database and type(database) ~= "string"  then
            ngx.log(ngx.ERR, "database is not string")
            return nil, "database is not string"
        end
        databaseconfig = config[database]
    end

    return setmetatable({databaseconfig=databaseconfig}, { __index = _DB})
    
end

local function exec(self,sql,forType)
    if not sql then
        ngx.log(ngx.ERR, "sql parse error! please check")
        return nil, "sql parse error! please check"
    end

    local db, err = mysql:new()
    if not db then
        return nil, "failed to instantiate mysql: "..err
    end   
    local config = self.databaseconfig
    local conf,random_num
    if forType == "main" then
        conf = config["main"]
    else
        if not config["query"] then
            conf = config["main"]
        elseif #config["query"] == 1 then
            conf = config["query"][1]
        else
            randomseed(mytime)
            random_num = random(1,#config["query"])
            conf = config["query"][random_num]
        end       
    end

    db:set_timeout(conf.timeout) -- 1 sec

    local ok, err, errno, sqlstate = db:connect(conf.connect_config)
    if not ok then
        --再尝试其他读库
        if random_num then
            for i=1,#config["query"],1 do
                if i ~= random_num then
                    conf = config["query"][i]
                    ok, err, errno, sqlstate = db:connect(conf.connect_config)
                end
                if ok then
                    break
                end
            end
        end
    end
    if not ok then
        ngx.log(ngx.ERR,"failed to connect: ", err, ": ", errno, " ", sqlstate)
        return nil
    end
    --ngx.log(ngx.ERR, "connected to mysql, reused_times:", db:get_reused_times(), " sql:", sql)

    db:query("SET NAMES utf8")
    local res, err, errno, sqlstate = db:query(sql)
    if not res then
        ngx.log(ngx.ERR, "bad result: ", err, ": ", errno, ": ", sqlstate, ".")
    end

    local ok, err = db:set_keepalive(conf.pool_config.max_idle_timeout, conf.pool_config.pool_size)
    if not ok then
        ngx.log(ngx.ERR,"failed to set keepalive: ",err)
    end

    return res, err, errno, sqlstate
end

local function table_is_array(t)
    if type(t) ~= "table" then return false end
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end
local function split(str, delimiter)
    if str==nil or str=='' or delimiter==nil then
        return nil
    end
    
    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        tinsert(result, match)
    end
    return result
end


local function compose(t, params)
    if t==nil or params==nil or type(t)~="table" or type(params)~="table" or #t~=#params+1 or #t==0 then
        return nil
    else
        local result = t[1]
        for i=1, #params do
            result = result  .. params[i].. t[i+1]
        end
        return result
    end
end


local function parse_sql(sql, params)
    if not params or not table_is_array(params) or #params == 0 then
        return sql
    end

    local new_params = {}
    for i, v in ipairs(params) do
        if v and type(v) == "string" then
            v = quote_sql_str(v)
        end
        
        tinsert(new_params, v)
    end

    local t = split(sql,"?")
    local sql = compose(t, new_params)

    return sql
end 


function _DB.query(self,sql, params)
    local sql = parse_sql(sql, params)
    return exec(self,sql,"query")
end

function _DB.main(self,sql, params)
    local sql = parse_sql(sql, params)
    return exec(self,sql,"main")
end

return _DB