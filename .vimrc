let g:ale_verilog_slang_options = "-I/home/derumigny/FPGA/cva6/core/include,/home/derumigny/FPGA/cva6/core/cache_subsystem/hpdcache/rtl/include"
let $HPDCACHE_DIR = "/home/derumigny/FPGA/cva6/core/cache_subsystem/hpdcache"
let $TARGET_CFG = "cv64a6_imafdc_sv39"
let g:ale_verilog_verilator_options = "-I/home/derumigny/FPGA/cva6/core/include -I/home/derumigny/FPGA/cva6/core/cache_subsystem/hpdcache/rtl/include -I/home/derumigny/FPGA/cva6/corev_apu/fpga/src/verilog_wrappers/block_design_wrappers -I/home/derumigny/FPGA/cva6/corev_apu/register_interface/include -f /home/derumigny/FPGA/cva6/core/Flist.cva6 -Wno-MODDUP"
