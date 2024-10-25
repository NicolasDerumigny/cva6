set partNumber $::env(XILINX_PART)
set boardName  $::env(XILINX_BOARD)
set boardNameShort $::env(BOARD)

set ipName xlnx_mig_ddr4

create_project $ipName . -force -part $partNumber
get_board_parts $boardName
set_property board_part $boardName [current_project]

create_ip -name ddr4 -vendor xilinx.com -library ip -module_name $ipName

exec cp mig_$boardNameShort.prj ./$ipName.srcs/sources_1/ip/$ipName/mig_a.prj

set_property -dict [list \
  CONFIG.C0.DDR4_MemoryPart {MTA8ATF51264HZ-2G1} \
  CONFIG.C0.DDR4_MemoryType {SODIMMs} \
  CONFIG.C0.DDR4_Slot {Single} \
  CONFIG.C0.DDR4_Specify_MandD {false} \
  CONFIG.C0.DDR4_TimePeriod {938} \
  CONFIG.C0_CLOCK_BOARD_INTERFACE {Custom} \
  CONFIG.C0_DDR4_BOARD_INTERFACE {Custom} \
  CONFIG.RESET_BOARD_INTERFACE {reset} \
] [get_ips $ipName]

generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files  ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
