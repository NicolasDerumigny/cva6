set partNumber $::env(XILINX_PART)
set boardName  $::env(XILINX_BOARD)

set ipName zynq_ultra_ps_e

create_project $ipName . -force -part $partNumber
set_property board_part $boardName [current_project]

create_ip -name zynq_ultra_ps_e -vendor xilinx.com -library ip -module_name $ipName

# S_AXI_GP2: 64-bit AXI access to RAM
# M_AXI_GP2: 32-bit AXI control for JTAG
# SD1: ZCU104 SD1 access
#    CONFIG.PSU__SD1__PERIPHERAL__ENABLE {1} \
#    CONFIG.PSU__SD1__PERIPHERAL__IO {EMIO} \
# ENET3: ZCU104 Eth access
#    CONFIG.PSU__ENET3__PERIPHERAL__ENABLE {1} \
#    CONFIG.PSU__ENET3__PERIPHERAL__IO {EMIO} \
# Use RPLL to generate a 200 MHz clock to FPGA
set_property -dict [list\
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
    CONFIG.PSU__SAXIGP2__DATA_WIDTH {64} \
    CONFIG.PSU__USE__M_AXI_GP2 {1} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {32} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {200} \
] [get_ips $ipName]

generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files  ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
