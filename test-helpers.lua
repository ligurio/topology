--- Helpers for integration testing.
-- This module extends `luatest.helpers` with additional helpers.
--
-- @module topology.test-helpers
-- @alias helpers

local luatest = require('luatest')

local helpers = table.copy(luatest.helpers)

--- Class to run and manage etcd node.
-- @see test.test-helpers.etcd
helpers.Etcd = require('test.test-helpers.etcd')

return helpers
