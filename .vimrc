let $CVA6_REPO_DIR = expand('<sfile>:p:h')
let g:ale_verilog_verilator_options = "--rule " . $CVA6_REPO_DIR . "/verilator_config.vlt"
