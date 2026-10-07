let $CVA6_REPO_DIR = expand('<sfile>:p:h')
let g:ale_verilog_verilator_options = " --no-timing " . $CVA6_REPO_DIR . "/verilator_config.vlt -f Flist.ariane +incdir+corev_apu/axi_node --unroll-count 256 -Wall -Werror-PINMISSING -Werror-IMPLICIT -Wno-fatal -Wno-PINCONNECTEMPTY -Wno-ASSIGNDLY -Wno-DECLFILENAME -Wno-UNUSED -Wno-UNOPTFLAT -Wno-BLKANDNBLK -Wno-style "
