# Topology

[![Build Status][ghactions-badge]][ghactions-page]

[ghactions-badge]: https://github.com/ligurio/topology/actions/workflows/test.yml/badge.svg
[ghactions-page]: https://github.com/ligurio/topology/actions/workflows/test.yml

[API documentation][apidoc].

[apidoc]: https://ligurio.github.io/topology/

## Features

- Centralized topology storage using [conf module][conf-module-src]
- Automatic sharding configuration (both storage and router)

## Requirements

* For use:
  * tarantool,
  * [conf][conf-module-src] ([documentation][conf-module-doc]),

* For test (additionally to 'for use'):
  * luacheck,
  * luacov,

* For building apidoc (additionally to 'for use'):
  * ldoc.

[conf-module-doc]: https://totktonada.github.io/conf/
[conf-module-src]: https://github.com/Totktonada/conf/

## Usage

How to bootstrap vshard cluster using topology module:

```
$ cd example
$ rm -rf etcd_data ETCD_URI=http://localhost:2379 \
                   ETCD_DATA_DIR=etcd_data \
                   ETCD_LISTEN_CLIENT_URLS=${ETCD_URI} \
                   ETCD_ADVERTISE_CLIENT_URLS=${ETCD_URI} etcd
$ tarantool topology_create.lua
$ make
> vshard.router.info()
```

## License

See LICENSE file.
