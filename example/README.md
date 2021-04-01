
### How-To Run:

```
$ ETCD_URI=http://localhost:2379
$ rm -rf data
$ ETCD_DATA_DIR=data
$ ETCD_LISTEN_CLIENT_URLS=${ETCD_URI}
$ ETCD_ADVERTISE_CLIENT_URLS=${ETCD_URI}
$ etcd

$ tarantool topology_create.lua
$ make
> vshard.router.info()
```
