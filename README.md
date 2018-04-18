# lua-resty-mysql-connector
Connection utilities for lua-resty-mysql,support for read and write separation，support for instantiating different databases
# Methods

## new

```
syntax: yourdb = db:new(database)
```
if there is not a database name, database = "default"

```
local libmysql = require("libmysql")
local db_member = libmysql:new("member")
local db_test = libmysql:new()
```

## query

```
syntax: res, err = yourdb:query("select des from test1 where test_id=? ", {3})
```
Some read database operations
## main
```
syntax: res, err = yourdb:main("UPDATE test1 SET des='my lua' WHERE test_id=?", {3})
```
Some write database operations

# Synopsis

```
local libmysql = require("libmysql")
local db_member = libmysql:new("member")
local db_test = libmysql:new()

local res, err =  db_member:query("select des from test1 where (test_id=? )", {3})
if err or not res or type(res)~="table" or #res<1 then
   ngx.say("test database member query :nothing") 
else
    ngx.say("test database member query :res") 
end

local res, err =  db_test:query("select des from test1 where test_id=? ;", {3})
if err or not res or type(res)~="table" or #res<1 then
   ngx.say("test database test query :nothing") 
else
    ngx.say("test database test query :res") 
end
local res, err =  db_test:main("UPDATE test1 SET des='my lua' WHERE test_id=?", {3})
```
