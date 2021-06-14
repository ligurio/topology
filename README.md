# Topology

[![Build Status][ghactions-badge]][ghactions-page]

[ghactions-badge]: https://github.com/tarantool/topology/actions/workflows/test.yml/badge.svg
[ghactions-page]: https://github.com/tarantool/topology/actions/workflows/test.yml

## Features

- Centralized topology storage using [conf module][conf-module-src]
- Automatic sharding configuration (both storage and router)
- Support offline and online modes

## Requirements

* For use:
  * `tarantool`,
  * [conf][conf-module-src] ([documentation][conf-module-doc]).

* For test (additionally to 'for use'):
  * `luacheck`,
  * `luacov`,
  * `vshard`,
  * `luatest`,
  * `lua-quickcheck`.

* For building apidoc (additionally to 'for use'):
  * `ldoc`.

[conf-module-doc]: https://tarantool.github.io/conf/
[conf-module-src]: https://github.com/tarantool/conf/

## Usage

Consider the [API documentation][apidoc] and integration tests.

[apidoc]: https://tarantool.github.io/topology/
[cartridge]: https://www.tarantool.io/en/cartridge/

## License

See LICENSE file.
