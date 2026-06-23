let g:ale_verilog_verilator_options = "-f " . expand('<sfile>:p:h')  . "/Flist.ariane"
let g:ale_fixers = { 'c': ['remove_trailing_lines', 'trim_whitespace'], 'cpp': ['remove_trailing_lines', 'trim_whitespace'], 'verilog_systemverilog': ['verible_format', 'remove_trailing_lines', 'trim_whitespace'] }
let $HPDCACHE_DIR = expand('<sfile>:p:h') . "/core/cache_subsystem/hpdcache"
let $CVA6_REPO_DIR = expand('<sfile>:p:h')
let $TARGET_CFG = "cv64a6_imafdch_sv39"
