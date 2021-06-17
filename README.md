# Topology

[![Build Status][ghactions-badge]][ghactions-page]

[ghactions-badge]: https://github.com/tarantool/topology/actions/workflows/test.yml/badge.svg
[ghactions-page]: https://github.com/tarantool/topology/actions/workflows/test.yml

## Features

- Centralized topology storage with [etcd](etcd-www) using [conf module][conf-module-src]
- Automatic sharding configuration (both storage and router)
- Integration with [Cartridge](cartridge-www) and [vshard](vshard-www)
- Support offline and online modes

## Requirements

* For use:
  * `tarantool`,
  * [conf][conf-module-src] ([documentation][conf-module-doc]),

* For test (additionally to 'for use'):
  * `luacheck`,
  * `luacov`,
  * `vshard`,

* For building apidoc (additionally to 'for use'):
  * `ldoc`.

[conf-module-doc]: https://tarantool.github.io/conf/
[conf-module-src]: https://github.com/tarantool/conf/
[etcd-www]: https://etcd.io/
[vshard-www]: https://github.com/tarantool/vshard
[cartridge-www]: https://github.com/tarantool/cartridge

## Usage

Consider the [API documentation][apidoc] and integration tests.

[apidoc]: https://tarantool.github.io/topology/
[cartridge]: https://www.tarantool.io/en/cartridge/

## License

See LICENSE file.
