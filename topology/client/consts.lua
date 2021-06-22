return {
    MASTER_MODE = {
        SINGLE = 'single',
        MULTI = 'multi',
        AUTO = 'auto',
    },

    -- vshard default values
    DEFAULT_BUCKET_COUNT = 3000,
    DEFAULT_COLLECT_BUCKET_GARBAGE_INTERVAL = 0.5,
    DEFAULT_COLLECT_LUA_GARBAGE = false,
    DEFAULT_DISCOVERY_MODE = 'on',
    DEFAULT_FAILOVER_PING_TIMEOUT = 5,
    DEFAULT_REBALANCER_DISBALANCE_THRESHOLD = 1,
    DEFAULT_REBALANCER_MAX_RECEIVING = 100,
    DEFAULT_REBALANCER_MAX_SENDING = 1,
    DEFAULT_SHARD_INDEX = 'bucket_id',
    DEFAULT_SHARDING = false,
    DEFAULT_SYNC_TIMEOUT = 1,

    -- topology default values
    DEFAULT_WAIT_INTERVAL = 0.1,

    -- tarantool max values
    REPLICA_MAX = 32, -- box.schema.REPLICA_MAX
}
