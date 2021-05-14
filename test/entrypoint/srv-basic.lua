#!/usr/bin/env tarantool

local workdir = os.getenv('TARANTOOL_WORKDIR')
local listen = os.getenv('TARANTOOL_LISTEN')
box.cfg({
    work_dir = workdir,
    listen = listen,
})

box.once('schema', function()
   box.schema.user.create('storage', {password = 'storage'})
   box.schema.user.grant('storage', 'replication') -- grant replication role
   box.schema.user.grant('storage', 'execute', 'universe')
   box.schema.space.create('test')
   box.space.test:create_index('primary')
end)
