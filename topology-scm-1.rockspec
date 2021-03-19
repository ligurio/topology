package = "topology"
version = "scm-1"
source = {
   url = "https://github.com/ligurio/topology"
}
description = {
   homepage = "https://github.com/ligurio/topology",
   license = "BSD",
}
dependencies = {
   "conf",
}
build = {
   type = "builtin",
   modules = {
      constants = "topology/constants.lua",
      topology = "topology/topology.lua",
      utils = "topology/utils.lua",
   },
}
