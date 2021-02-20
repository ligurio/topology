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
   "argparse",
}
build = {
   type = "builtin",
   modules = {
      topology = "topology/topology.lua",
   },
}
