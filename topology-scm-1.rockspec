package = 'topology'
version = 'scm-1'
source = {
    url    = 'https://github.com/tarantool/topology',
    branch = 'master',
}
description = {
    summary    = 'Tarantool topology client',
    homepage   = 'https://github.com/tarantool/topology',
    maintainer = 'Sergey Bronnikov <sergeyb@tarantool.org>',
    license    = 'BSD2',
}
dependencies = {
    'tarantool >= 1.10',
    'checks',
    'conf',
    'errors',
}

build = {
    type = 'make',
    -- Nothing to build.
    build_pass = false,
    variables = {
        -- https://github.com/tarantool/modulekit/issues/2
        TARANTOOL_INSTALL_LUADIR='$(LUADIR)',
    },
    -- Don't copy doc/ folder.
    copy_directories = {},
}
