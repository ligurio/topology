# Topology

[![Build Status][ghactions-badge]][ghactions-page]

[ghactions-badge]: https://github.com/tarantool/topology/actions/workflows/test.yml/badge.svg
[ghactions-page]: https://github.com/tarantool/topology/actions/workflows/test.yml

## Features

- Centralized topology storage using [conf module][conf-module-src]
- Automatic sharding configuration (both storage and router)

## Requirements

* For use:
  * `tarantool`,
  * [conf][conf-module-src] ([documentation][conf-module-doc]),

* For test (additionally to 'for use'):
  * `luacheck`,
  * `luacov`,

* For building apidoc (additionally to 'for use'):
  * `ldoc`.

[conf-module-doc]: https://tarantool.github.io/conf/
[conf-module-src]: https://github.com/tarantool/conf/

## Usage

Consider the [API documentation][apidoc] and examples below.

How to bootstrap vshard cluster using topology module:

```sh
$ tarantoolctl rocks make
$ tarantoolctl rocks install vshard
$ rm -rf etcd_data
$ ETCD_URI=http://localhost:2379 \
  ETCD_DATA_DIR=etcd_data \
  ETCD_LISTEN_CLIENT_URLS=${ETCD_URI} \
  ETCD_ADVERTISE_CLIENT_URLS=${ETCD_URI} etcd
$ cd example && tarantool topology_create.lua
$ make
> vshard.router.info()
```

How to use [Cartridge][cartridge] with topology module:

TODO

[apidoc]: https://tarantool.github.io/topology/
[cartridge]: https://www.tarantool.io/en/cartridge/

## License

See LICENSE file.
