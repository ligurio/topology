# This way everything works as expected ever for
# `make -C /path/to/project` or
# `make -f /path/to/project/Makefile`.
MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_DIR := $(patsubst %/,%,$(dir $(MAKEFILE_PATH)))

default:
	false

luacheck:
	cd $(PROJECT_DIR) && luacheck --codes .

check: luacheck

# The template (ldoc.tpl) is written using tarantool specific
# functions like string.split(), string.endswith(), so we run
# ldoc using tarantool.
apidoc:
	tarantool -e "                                             \
		arg = {                                            \
			[0] = 'tarantool',                         \
			'-c', '$(PROJECT_DIR)/doc/ldoc/config.ld', \
			'-d', '$(PROJECT_DIR)/doc/apidoc',         \
			'-p', 'topology',                          \
			'$(PROJECT_DIR)'                           \
		}                                                  \
		require('ldoc')                                    \
		os.exit()"

test:
	cd $(PROJECT_DIR) && luatest --verbose

.PHONY: check luacheck test apidoc
