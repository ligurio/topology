# This way everything works as expected ever for
# `make -C /path/to/project` or
# `make -f /path/to/project/Makefile`.
MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_DIR := $(patsubst %/,%,$(dir $(MAKEFILE_PATH)))
LUACOV_REPORT := $(PROJECT_DIR)/luacov.report.out

default:
	false

luacheck:
	cd $(PROJECT_DIR) && luacheck --codes .

check: luacheck

# The template (ldoc.tpl) is written using tarantool specific
# functions like string.split(), string.endswith(), so we run
# ldoc using tarantool.
apidoc:
	ldoc -c $(PROJECT_DIR)/doc/ldoc/config.ld -d $(PROJECT_DIR)/doc/apidoc/ -p topology topology

test:
	rm -f $(LUACOV_REPORT)
	cd $(PROJECT_DIR) && luatest --coverage --verbose

$(LUACOV_REPORT): test

coverage: $(LUACOV_REPORT)
	cd $(PROJECT_DIR) && luacov .
	grep -A999 '^Summary' $^

.PHONY: check luacheck test apidoc
