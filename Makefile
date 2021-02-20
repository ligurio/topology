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

test:
	cd $(PROJECT_DIR) && luatest -v

.PHONY: check luacheck test
