set partNumber $::env(XILINX_PART)
set boardName  $::env(XILINX_BOARD)

set ipName axi_protocol_converter

create_project $ipName . -force -part $partNumber
set_property board_part $boardName [current_project]

create_ip -name axi_protocol_converter -vendor xilinx.com -library ip -module_name $ipName

set_property -dict [list \
  CONFIG.DATA_WIDTH {32} \
  CONFIG.ID_WIDTH {16} \
  CONFIG.MI_PROTOCOL {AXI4LITE} \
  CONFIG.READ_WRITE_MODE {READ_WRITE} \
  CONFIG.SI_PROTOCOL {AXI4} \
  CONFIG.TRANSLATION_MODE {2} \
] [get_ips $ipName]

generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files  ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
