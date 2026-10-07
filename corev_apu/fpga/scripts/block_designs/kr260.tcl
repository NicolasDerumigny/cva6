
################################################################
# This is a generated script based on design: SoC
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2024.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   if { [string compare $scripts_vivado_version $current_vivado_version] > 0 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2042 -severity "ERROR" " This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Sourcing the script failed since it was created with a future version of Vivado."}

   } else {
     catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   }

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source SoC_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# bootrom_wrapper, ariane_peripherals_wrapper_verilog, cva6_wrapper_verilog, clint_wrapper_verilog, debug_module_wrapper_verilog, axi_xbar_interface_verilog, axi_riscv_amos_wrapper_verilog, ram_offset_to_zero

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xck26-sfvc784-2LV-c
   set_property BOARD_PART xilinx.com:kr260_som_som240_2_connector_kr260_carrier_som240_2_connector_som240_1_connector_kr260_carrier_som240_1_connector:part0:1.1 [current_project]
}

set_property board_connections {
        som240_2_connector xilinx.com:kr260_carrier:som240_2_connector:1.1
        som240_1_connector xilinx.com:kr260_carrier:som240_1_connector:1.1
    } [current_project]


# CHANGE DESIGN NAME HERE
variable design_name
set design_name SoC

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:axi_bram_ctrl:4.1\
xilinx.com:ip:axi_quad_spi:3.2\
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:axi_jtag:1.0\
xilinx.com:ip:axi_gpio:2.0\
xilinx.com:ip:axi_uart16550:2.0\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:zynq_ultra_ps_e:3.5\
xilinx.com:ip:axi_protocol_converter:2.1\
xilinx.com:ip:axi_dwidth_converter:2.1\
xilinx.com:ip:axi_ethernet:7.2\
xilinx.com:ip:axi_dma:7.1\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

##################################################################
# CHECK Modules
##################################################################
set bCheckModules 1
if { $bCheckModules == 1 } {
   set list_check_mods "\ 
bootrom_wrapper\
ariane_peripherals_wrapper_verilog\
cva6_wrapper_verilog\
clint_wrapper_verilog\
debug_module_wrapper_verilog\
axi_xbar_interface_verilog\
axi_riscv_amos_wrapper_verilog\
ram_offset_to_zero\
"

   set list_mods_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2020 -severity "INFO" "Checking if the following modules exist in the project's sources: $list_check_mods ."

   foreach mod_vlnv $list_check_mods {
      if { [can_resolve_reference $mod_vlnv] == 0 } {
         lappend list_mods_missing $mod_vlnv
      }
   }

   if { $list_mods_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2021 -severity "ERROR" "The following module(s) are not found in the project: $list_mods_missing" }
      common::send_gid_msg -ssname BD::TCL -id 2022 -severity "INFO" "Please add source files for the missing module(s) above."
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: Ethernet_Subsystem
proc create_hier_cell_Ethernet_Subsystem { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_Ethernet_Subsystem() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 ETH_DMA_M_AXI_SG

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 ETH_DMA_M_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_ETH

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_DMA

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:mdio_rtl:1.0 som240_2_connector_pl_gem3_rgmii_mdio_mdc

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:rgmii_rtl:1.0 som240_2_connector_pl_gem3_rgmii


  # Create pins
  create_bd_pin -dir I -type rst eth_dma_axi_resetn
  create_bd_pin -dir O -type intr mm2s_introut
  create_bd_pin -dir O -type intr s2mm_introut
  create_bd_pin -dir I -type rst eth_axi_resetn
  create_bd_pin -dir I axi_clk
  create_bd_pin -dir I -type clk gtx_clk
  create_bd_pin -dir I -type clk ref_clk
  create_bd_pin -dir O -from 0 -to 0 -type rst som240_2_connector_pl_gem3_reset
  create_bd_pin -dir O -type intr eth_interrupt

  # Create instance: axi_ethernet_0, and set properties
  set axi_ethernet_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_ethernet:7.2 axi_ethernet_0 ]
  set_property -dict [list \
    CONFIG.ENABLE_AVB {false} \
    CONFIG.ETHERNET_BOARD_INTERFACE {som240_2_connector_pl_gem3_rgmii} \
    CONFIG.Frame_Filter {false} \
    CONFIG.MDIO_BOARD_INTERFACE {som240_2_connector_pl_gem3_rgmii_mdio_mdc} \
    CONFIG.PHYRST_BOARD_INTERFACE {som240_2_connector_pl_gem3_reset} \
    CONFIG.RXCSUM {Full} \
    CONFIG.RXMEM {4k} \
    CONFIG.Statistics_Counters {false} \
    CONFIG.SupportLevel {1} \
    CONFIG.TXCSUM {Full} \
    CONFIG.TXMEM {4k} \
    CONFIG.USE_BOARD_FLOW {true} \
    CONFIG.axiliteclkrate {60} \
    CONFIG.axisclkrate {60} \
  ] $axi_ethernet_0


  # Create instance: axi_eth_dma, and set properties
  set axi_eth_dma [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_eth_dma ]
  set_property -dict [list \
    CONFIG.c_addr_width {64} \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_mm2s_dre {1} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_include_s2mm_dre {1} \
    CONFIG.c_m_axi_mm2s_data_width {64} \
    CONFIG.c_m_axi_s2mm_data_width {64} \
    CONFIG.c_m_axis_mm2s_tdata_width {32} \
    CONFIG.c_mm2s_burst_size {16} \
    CONFIG.c_s2mm_burst_size {16} \
    CONFIG.c_s_axis_s2mm_tdata_width {32} \
    CONFIG.c_sg_use_stsapp_length {1} \
    CONFIG.c_single_interface {1} \
  ] $axi_eth_dma


  # Create instance: eth_dma_axi_protocol_convert, and set properties
  set eth_dma_axi_protocol_convert [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 eth_dma_axi_protocol_convert ]

  # Create instance: eth_s_axi_protocol_convert1, and set properties
  set eth_s_axi_protocol_convert1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 eth_s_axi_protocol_convert1 ]

  # Create instance: eth_dma_axi_dwidth_converter, and set properties
  set eth_dma_axi_dwidth_converter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dwidth_converter:2.1 eth_dma_axi_dwidth_converter ]
  set_property -dict [list \
    CONFIG.MI_DATA_WIDTH {64} \
    CONFIG.SI_DATA_WIDTH {32} \
  ] $eth_dma_axi_dwidth_converter


  # Create instance: axi_dwidth_converter_0, and set properties
  set axi_dwidth_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dwidth_converter:2.1 axi_dwidth_converter_0 ]

  # Create instance: axi_dwidth_converter_1, and set properties
  set axi_dwidth_converter_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dwidth_converter:2.1 axi_dwidth_converter_1 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins eth_s_axi_protocol_convert1/S_AXI] [get_bd_intf_pins S_AXI_ETH]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins eth_dma_axi_protocol_convert/S_AXI] [get_bd_intf_pins S_AXI_DMA]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins axi_ethernet_0/mdio] [get_bd_intf_pins som240_2_connector_pl_gem3_rgmii_mdio_mdc]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins axi_ethernet_0/rgmii] [get_bd_intf_pins som240_2_connector_pl_gem3_rgmii]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins axi_eth_dma/M_AXI] [get_bd_intf_pins ETH_DMA_M_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_CNTRL [get_bd_intf_pins axi_eth_dma/M_AXIS_CNTRL] [get_bd_intf_pins axi_ethernet_0/s_axis_txc]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_MM2S [get_bd_intf_pins axi_eth_dma/M_AXIS_MM2S] [get_bd_intf_pins axi_ethernet_0/s_axis_txd]
  connect_bd_intf_net -intf_net axi_dwidth_converter_0_M_AXI [get_bd_intf_pins ETH_DMA_M_AXI_SG] [get_bd_intf_pins eth_dma_axi_dwidth_converter/M_AXI]
  connect_bd_intf_net -intf_net axi_dwidth_converter_0_M_AXI1 [get_bd_intf_pins axi_dwidth_converter_0/M_AXI] [get_bd_intf_pins axi_eth_dma/S_AXI_LITE]
  connect_bd_intf_net -intf_net axi_dwidth_converter_1_M_AXI [get_bd_intf_pins axi_dwidth_converter_1/M_AXI] [get_bd_intf_pins axi_ethernet_0/s_axi]
  connect_bd_intf_net -intf_net axi_eth_dma_M_AXI_SG [get_bd_intf_pins eth_dma_axi_dwidth_converter/S_AXI] [get_bd_intf_pins axi_eth_dma/M_AXI_SG]
  connect_bd_intf_net -intf_net axi_ethernet_0_m_axis_rxd [get_bd_intf_pins axi_ethernet_0/m_axis_rxd] [get_bd_intf_pins axi_eth_dma/S_AXIS_S2MM]
  connect_bd_intf_net -intf_net axi_ethernet_0_m_axis_rxs [get_bd_intf_pins axi_ethernet_0/m_axis_rxs] [get_bd_intf_pins axi_eth_dma/S_AXIS_STS]
  connect_bd_intf_net -intf_net eth_dma_axi_protocol_convert_M_AXI [get_bd_intf_pins eth_dma_axi_protocol_convert/M_AXI] [get_bd_intf_pins axi_dwidth_converter_0/S_AXI]
  connect_bd_intf_net -intf_net eth_s_axi_protocol_convert1_M_AXI [get_bd_intf_pins axi_dwidth_converter_1/S_AXI] [get_bd_intf_pins eth_s_axi_protocol_convert1/M_AXI]

  # Create port connections
  connect_bd_net -net Net [get_bd_pins axi_clk] [get_bd_pins axi_dwidth_converter_0/s_axi_aclk] [get_bd_pins axi_dwidth_converter_1/s_axi_aclk] [get_bd_pins axi_eth_dma/s_axi_lite_aclk] [get_bd_pins axi_eth_dma/m_axi_sg_aclk] [get_bd_pins axi_eth_dma/m_axi_mm2s_aclk] [get_bd_pins axi_eth_dma/m_axi_s2mm_aclk] [get_bd_pins axi_ethernet_0/s_axi_lite_clk] [get_bd_pins axi_ethernet_0/axis_clk] [get_bd_pins eth_dma_axi_dwidth_converter/s_axi_aclk] [get_bd_pins eth_dma_axi_protocol_convert/aclk] [get_bd_pins eth_s_axi_protocol_convert1/aclk]
  connect_bd_net -net axi_dma_0_mm2s_cntrl_reset_out_n [get_bd_pins axi_eth_dma/mm2s_cntrl_reset_out_n] [get_bd_pins axi_ethernet_0/axi_txc_arstn]
  connect_bd_net -net axi_dma_0_mm2s_introut [get_bd_pins axi_eth_dma/mm2s_introut] [get_bd_pins mm2s_introut]
  connect_bd_net -net axi_dma_0_mm2s_prmry_reset_out_n [get_bd_pins axi_eth_dma/mm2s_prmry_reset_out_n] [get_bd_pins axi_ethernet_0/axi_txd_arstn]
  connect_bd_net -net axi_dma_0_s2mm_introut [get_bd_pins axi_eth_dma/s2mm_introut] [get_bd_pins s2mm_introut]
  connect_bd_net -net axi_dma_0_s2mm_prmry_reset_out_n [get_bd_pins axi_eth_dma/s2mm_prmry_reset_out_n] [get_bd_pins axi_ethernet_0/axi_rxd_arstn]
  connect_bd_net -net axi_dma_0_s2mm_sts_reset_out_n [get_bd_pins axi_eth_dma/s2mm_sts_reset_out_n] [get_bd_pins axi_ethernet_0/axi_rxs_arstn]
  connect_bd_net -net axi_ethernet_0_interrupt [get_bd_pins axi_ethernet_0/interrupt] [get_bd_pins eth_interrupt]
  connect_bd_net -net axi_ethernet_0_phy_rst_n [get_bd_pins axi_ethernet_0/phy_rst_n] [get_bd_pins som240_2_connector_pl_gem3_reset]
  connect_bd_net -net axi_resetn_0_1 [get_bd_pins eth_dma_axi_resetn] [get_bd_pins axi_dwidth_converter_0/s_axi_aresetn] [get_bd_pins axi_eth_dma/axi_resetn] [get_bd_pins eth_dma_axi_dwidth_converter/s_axi_aresetn] [get_bd_pins eth_dma_axi_protocol_convert/aresetn]
  connect_bd_net -net gtx_clk_1 [get_bd_pins gtx_clk] [get_bd_pins axi_ethernet_0/gtx_clk]
  connect_bd_net -net ref_clk_1 [get_bd_pins ref_clk] [get_bd_pins axi_ethernet_0/ref_clk]
  connect_bd_net -net s_axi_lite_resetn_0_1 [get_bd_pins eth_axi_resetn] [get_bd_pins axi_dwidth_converter_1/s_axi_aresetn] [get_bd_pins axi_ethernet_0/s_axi_lite_resetn] [get_bd_pins eth_s_axi_protocol_convert1/aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: northbridge
proc create_hier_cell_northbridge { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_northbridge() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 CPU_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 DDR_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 UART_AXILite

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 CLINT_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 TIMER_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 BOOTROM_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 SDCARD_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 DEBUG_MODULE_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 DEBUG_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 PLIC_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 GPIO_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 ETH_LED_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:mdio_rtl:1.0 som240_2_connector_pl_gem3_rgmii_mdio_mdc

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:rgmii_rtl:1.0 som240_2_connector_pl_gem3_rgmii


  # Create pins
  create_bd_pin -dir I -type clk aclk
  create_bd_pin -dir I -from 5 -to 0 cpu_atop_in
  create_bd_pin -dir I -type rst aresetn
  create_bd_pin -dir I -type rst cpu_peripheral_aresetn
  create_bd_pin -dir O -type intr mm2s_introut
  create_bd_pin -dir O -type intr s2mm_introut
  create_bd_pin -dir I -from 5 -to 0 debug_module_atop
  create_bd_pin -dir O -from 5 -to 0 m_axi_debug_awatop
  create_bd_pin -dir O -from 5 -to 0 m_axi_clint_awatop
  create_bd_pin -dir O -from 5 -to 0 m_axi_timer_awatop
  create_bd_pin -dir O -from 5 -to 0 m_axi_plic_awatop
  create_bd_pin -dir I -type clk gtx_clk
  create_bd_pin -dir I -type clk ref_clk
  create_bd_pin -dir O -from 0 -to 0 -type rst som240_2_connector_pl_gem3_reset
  create_bd_pin -dir O -type intr eth_interrupt

  # Create instance: Ethernet_Subsystem
  create_hier_cell_Ethernet_Subsystem $hier_obj Ethernet_Subsystem

  # Create instance: axi_xbar_interface_v_0, and set properties
  set block_name axi_xbar_interface_verilog
  set block_cell_name axi_xbar_interface_v_0
  if { [catch {set axi_xbar_interface_v_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $axi_xbar_interface_v_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [list \
    CONFIG.AXI_MST_ID_WIDTH {6} \
    CONFIG.AXI_SLV_ID_WIDTH {4} \
    CONFIG.AXI_USER_WIDTH {0} \
  ] $axi_xbar_interface_v_0


  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {6} \
  ] $xlconstant_0


  # Create instance: gpio_axi_protocol_convert, and set properties
  set gpio_axi_protocol_convert [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 gpio_axi_protocol_convert ]

  # Create instance: eth_led_axi_protocol_convert, and set properties
  set eth_led_axi_protocol_convert [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 eth_led_axi_protocol_convert ]

  # Create instance: uart_axi_protocol_convert, and set properties
  set uart_axi_protocol_convert [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 uart_axi_protocol_convert ]

  # Create instance: sdcard_axi_dwidth_converter, and set properties
  set sdcard_axi_dwidth_converter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dwidth_converter:2.1 sdcard_axi_dwidth_converter ]

  # Create instance: gpio_axi_dwidth_converter, and set properties
  set gpio_axi_dwidth_converter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dwidth_converter:2.1 gpio_axi_dwidth_converter ]

  # Create instance: uart_axi_dwidth_converter, and set properties
  set uart_axi_dwidth_converter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dwidth_converter:2.1 uart_axi_dwidth_converter ]

  # Create instance: gpio_axi_dwidth_converter1, and set properties
  set gpio_axi_dwidth_converter1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dwidth_converter:2.1 gpio_axi_dwidth_converter1 ]

  # Create instance: axi_riscv_amos_wrapp_0, and set properties
  set block_name axi_riscv_amos_wrapper_verilog
  set block_cell_name axi_riscv_amos_wrapp_0
  if { [catch {set axi_riscv_amos_wrapp_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $axi_riscv_amos_wrapp_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property CONFIG.AXI_ID_WIDTH {6} $axi_riscv_amos_wrapp_0


  # Create instance: axi_interconnect_0, and set properties
  set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]
  set_property CONFIG.NUM_MI {1} $axi_interconnect_0


  # Create instance: ram_offset_to_zero_0, and set properties
  set block_name ram_offset_to_zero
  set block_cell_name ram_offset_to_zero_0
  if { [catch {set ram_offset_to_zero_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ram_offset_to_zero_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [list \
    CONFIG.AXI_ADDR_WIDTH {64} \
    CONFIG.OFFSET {0x70000000} \
  ] $ram_offset_to_zero_0


  # Create interface connections
  connect_bd_intf_net -intf_net CPU_AXI_1 [get_bd_intf_pins CPU_AXI] [get_bd_intf_pins axi_xbar_interface_v_0/s_axi_cpu]
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins gpio_axi_dwidth_converter/M_AXI] [get_bd_intf_pins GPIO_AXI]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins gpio_axi_dwidth_converter1/M_AXI] [get_bd_intf_pins ETH_LED_AXI]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins Ethernet_Subsystem/som240_2_connector_pl_gem3_rgmii_mdio_mdc] [get_bd_intf_pins som240_2_connector_pl_gem3_rgmii_mdio_mdc]
  connect_bd_intf_net -intf_net Conn6 [get_bd_intf_pins Ethernet_Subsystem/som240_2_connector_pl_gem3_rgmii] [get_bd_intf_pins som240_2_connector_pl_gem3_rgmii]
  connect_bd_intf_net -intf_net DEBUG_MODULE_AXI_1 [get_bd_intf_pins DEBUG_MODULE_AXI] [get_bd_intf_pins axi_xbar_interface_v_0/s_axi_debug]
  connect_bd_intf_net -intf_net Ethernet_Subsystem_ETH_DMA_M_AXI [get_bd_intf_pins Ethernet_Subsystem/ETH_DMA_M_AXI] [get_bd_intf_pins axi_xbar_interface_v_0/s_axi_eth_dma]
  connect_bd_intf_net -intf_net Ethernet_Subsystem_ETH_DMA_M_AXI_SG [get_bd_intf_pins Ethernet_Subsystem/ETH_DMA_M_AXI_SG] [get_bd_intf_pins axi_xbar_interface_v_0/s_axi_eth_dma_sg]
  connect_bd_intf_net -intf_net axi_dwidth_converter_0_M_AXI [get_bd_intf_pins SDCARD_AXI] [get_bd_intf_pins sdcard_axi_dwidth_converter/M_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins DDR_AXI] [get_bd_intf_pins axi_interconnect_0/M00_AXI]
  connect_bd_intf_net -intf_net axi_riscv_amos_wrapp_0_m_axi_out [get_bd_intf_pins axi_riscv_amos_wrapp_0/m_axi_out] [get_bd_intf_pins ram_offset_to_zero_0/s_axi_ram]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_bootrom [get_bd_intf_pins BOOTROM_AXI] [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_bootrom]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_clint [get_bd_intf_pins CLINT_AXI] [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_clint]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_debug [get_bd_intf_pins DEBUG_AXI] [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_debug]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_eth [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_eth] [get_bd_intf_pins Ethernet_Subsystem/S_AXI_ETH]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_eth_dma [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_eth_dma] [get_bd_intf_pins Ethernet_Subsystem/S_AXI_DMA]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_eth_leds [get_bd_intf_pins eth_led_axi_protocol_convert/S_AXI] [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_eth_leds]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_gpio [get_bd_intf_pins gpio_axi_protocol_convert/S_AXI] [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_gpio]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_plic [get_bd_intf_pins PLIC_AXI] [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_plic]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_ram [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_ram] [get_bd_intf_pins axi_riscv_amos_wrapp_0/s_axi_in]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_sdcard [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_sdcard] [get_bd_intf_pins sdcard_axi_dwidth_converter/S_AXI]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_timer [get_bd_intf_pins TIMER_AXI] [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_timer]
  connect_bd_intf_net -intf_net axi_xbar_interface_v_0_m_axi_uart [get_bd_intf_pins uart_axi_protocol_convert/S_AXI] [get_bd_intf_pins axi_xbar_interface_v_0/m_axi_uart]
  connect_bd_intf_net -intf_net eth_led_axi_protocol_convert_M_AXI [get_bd_intf_pins eth_led_axi_protocol_convert/M_AXI] [get_bd_intf_pins gpio_axi_dwidth_converter1/S_AXI]
  connect_bd_intf_net -intf_net gpio_axi_protocol_convert_M_AXI [get_bd_intf_pins gpio_axi_protocol_convert/M_AXI] [get_bd_intf_pins gpio_axi_dwidth_converter/S_AXI]
  connect_bd_intf_net -intf_net ram_offset_to_zero_0_m_axi_ram [get_bd_intf_pins ram_offset_to_zero_0/m_axi_ram] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net uart_axi_dwidth_converter_M_AXI [get_bd_intf_pins UART_AXILite] [get_bd_intf_pins uart_axi_dwidth_converter/M_AXI]
  connect_bd_intf_net -intf_net uart_axi_protocol_convert_M_AXI [get_bd_intf_pins uart_axi_dwidth_converter/S_AXI] [get_bd_intf_pins uart_axi_protocol_convert/M_AXI]

  # Create port connections
  connect_bd_net -net Ethernet_Subsystem_interrupt_0 [get_bd_pins Ethernet_Subsystem/eth_interrupt] [get_bd_pins eth_interrupt]
  connect_bd_net -net Ethernet_Subsystem_mm2s_introut [get_bd_pins Ethernet_Subsystem/mm2s_introut] [get_bd_pins mm2s_introut]
  connect_bd_net -net Ethernet_Subsystem_s2mm_introut [get_bd_pins Ethernet_Subsystem/s2mm_introut] [get_bd_pins s2mm_introut]
  connect_bd_net -net Ethernet_Subsystem_som240_2_connector_pl_gem3_reset [get_bd_pins Ethernet_Subsystem/som240_2_connector_pl_gem3_reset] [get_bd_pins som240_2_connector_pl_gem3_reset]
  connect_bd_net -net S02_ARESETN_1 [get_bd_pins cpu_peripheral_aresetn] [get_bd_pins Ethernet_Subsystem/eth_axi_resetn] [get_bd_pins Ethernet_Subsystem/eth_dma_axi_resetn]
  connect_bd_net -net aresetn_1 [get_bd_pins aresetn] [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins eth_led_axi_protocol_convert/aresetn] [get_bd_pins gpio_axi_dwidth_converter1/s_axi_aresetn] [get_bd_pins gpio_axi_dwidth_converter/s_axi_aresetn] [get_bd_pins gpio_axi_protocol_convert/aresetn] [get_bd_pins sdcard_axi_dwidth_converter/s_axi_aresetn] [get_bd_pins uart_axi_dwidth_converter/s_axi_aresetn] [get_bd_pins uart_axi_protocol_convert/aresetn] [get_bd_pins axi_riscv_amos_wrapp_0/aresetn] [get_bd_pins axi_xbar_interface_v_0/aresetn]
  connect_bd_net -net axi_riscv_amos_wrapp_0_m_axi_out_awatop [get_bd_pins axi_riscv_amos_wrapp_0/m_axi_out_awatop] [get_bd_pins ram_offset_to_zero_0/s_axi_ram_awatop]
  connect_bd_net -net axi_xbar_interface_v_0_m_axi_clint_awatop [get_bd_pins axi_xbar_interface_v_0/m_axi_clint_awatop] [get_bd_pins m_axi_clint_awatop]
  connect_bd_net -net axi_xbar_interface_v_0_m_axi_debug_awatop [get_bd_pins axi_xbar_interface_v_0/m_axi_debug_awatop] [get_bd_pins m_axi_debug_awatop]
  connect_bd_net -net axi_xbar_interface_v_0_m_axi_plic_awatop [get_bd_pins axi_xbar_interface_v_0/m_axi_plic_awatop] [get_bd_pins m_axi_plic_awatop]
  connect_bd_net -net axi_xbar_interface_v_0_m_axi_ram_awatop [get_bd_pins axi_xbar_interface_v_0/m_axi_ram_awatop] [get_bd_pins axi_riscv_amos_wrapp_0/s_axi_in_awatop]
  connect_bd_net -net axi_xbar_interface_v_0_m_axi_timer_awatop [get_bd_pins axi_xbar_interface_v_0/m_axi_timer_awatop] [get_bd_pins m_axi_timer_awatop]
  connect_bd_net -net clk_wiz_0_clk_out1 [get_bd_pins aclk] [get_bd_pins Ethernet_Subsystem/axi_clk] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins eth_led_axi_protocol_convert/aclk] [get_bd_pins gpio_axi_dwidth_converter1/s_axi_aclk] [get_bd_pins gpio_axi_dwidth_converter/s_axi_aclk] [get_bd_pins gpio_axi_protocol_convert/aclk] [get_bd_pins sdcard_axi_dwidth_converter/s_axi_aclk] [get_bd_pins uart_axi_dwidth_converter/s_axi_aclk] [get_bd_pins uart_axi_protocol_convert/aclk] [get_bd_pins axi_riscv_amos_wrapp_0/CLK] [get_bd_pins axi_xbar_interface_v_0/aclk] [get_bd_pins ram_offset_to_zero_0/aclk]
  connect_bd_net -net cpu_atop_in_1 [get_bd_pins cpu_atop_in] [get_bd_pins axi_xbar_interface_v_0/s_axi_cpu_awatop]
  connect_bd_net -net debug_module_atop_1 [get_bd_pins debug_module_atop] [get_bd_pins axi_xbar_interface_v_0/s_axi_debug_awatop]
  connect_bd_net -net gtx_clk_1 [get_bd_pins gtx_clk] [get_bd_pins Ethernet_Subsystem/gtx_clk]
  connect_bd_net -net ref_clk_1 [get_bd_pins ref_clk] [get_bd_pins Ethernet_Subsystem/ref_clk]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xlconstant_0/dout] [get_bd_pins axi_xbar_interface_v_0/s_axi_eth_dma_sg_awatop] [get_bd_pins axi_xbar_interface_v_0/s_axi_eth_dma_awatop]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set som240_2_connector_pl_gem3_rgmii_mdio_mdc [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:mdio_rtl:1.0 som240_2_connector_pl_gem3_rgmii_mdio_mdc ]

  set som240_2_connector_pl_gem3_rgmii [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:rgmii_rtl:1.0 som240_2_connector_pl_gem3_rgmii ]

  set som240_2_connector_gem3_led [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 som240_2_connector_gem3_led ]

  set som240_1_connector_User_led [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 som240_1_connector_User_led ]


  # Create ports
  set som240_2_connector_pl_gem3_reset [ create_bd_port -dir O -from 0 -to 0 -type rst som240_2_connector_pl_gem3_reset ]
  set som240_2_connector_hpb_clk0p_clk [ create_bd_port -dir I -type clk -freq_hz 25000000 som240_2_connector_hpb_clk0p_clk ]
  set_property -dict [ list \
   CONFIG.PHASE {0.0} \
 ] $som240_2_connector_hpb_clk0p_clk
  set spi_mosi [ create_bd_port -dir O spi_mosi ]
  set spi_miso [ create_bd_port -dir I spi_miso ]
  set spi_clk_o [ create_bd_port -dir O spi_clk_o ]
  set spi_ss [ create_bd_port -dir O -from 0 -to 0 spi_ss ]
  set uart_sin [ create_bd_port -dir I uart_sin ]
  set uart_sout [ create_bd_port -dir O uart_sout ]

  # Create instance: axi_bootrom_control, and set properties
  set axi_bootrom_control [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bootrom_control ]
  set_property -dict [list \
    CONFIG.DATA_WIDTH {64} \
    CONFIG.SINGLE_PORT_BRAM {1} \
  ] $axi_bootrom_control


  # Create instance: sdcard_quad_spi_axi, and set properties
  set sdcard_quad_spi_axi [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 sdcard_quad_spi_axi ]
  set_property -dict [list \
    CONFIG.C_FAMILY {kintex7} \
    CONFIG.C_FIFO_DEPTH {256} \
    CONFIG.C_NUM_TRANSFER_BITS {8} \
    CONFIG.C_SCK_RATIO {2} \
    CONFIG.C_SPI_MODE {0} \
    CONFIG.C_SUB_FAMILY {kintex7} \
    CONFIG.C_TYPE_OF_AXI4_INTERFACE {1} \
    CONFIG.QSPI_BOARD_INTERFACE {Custom} \
    CONFIG.UC_FAMILY {0} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $sdcard_quad_spi_axi


  # Create instance: bootrom_wrapper_0, and set properties
  set block_name bootrom_wrapper
  set block_cell_name bootrom_wrapper_0
  if { [catch {set bootrom_wrapper_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $bootrom_wrapper_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: ariane_peripherals_0, and set properties
  set block_name ariane_peripherals_wrapper_verilog
  set block_cell_name ariane_peripherals_0
  if { [catch {set ariane_peripherals_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $ariane_peripherals_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [list \
    CONFIG.AXI_DATA_WIDTH {64} \
    CONFIG.AXI_ID_WIDTH {6} \
    CONFIG.AXI_USER_WIDTH {0} \
    CONFIG.NR_CORES {1} \
  ] $ariane_peripherals_0


  # Create instance: irqconcat, and set properties
  set irqconcat [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 irqconcat ]
  set_property -dict [list \
    CONFIG.IN3_WIDTH {20} \
    CONFIG.IN5_WIDTH {18} \
    CONFIG.NUM_PORTS {4} \
  ] $irqconcat


  # Create instance: cpu_0, and set properties
  set block_name cva6_wrapper_verilog
  set block_cell_name cpu_0
  if { [catch {set cpu_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $cpu_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [list \
    CONFIG.AXI_CUT_BYPASS {1} \
    CONFIG.AXI_ID_WIDTH {4} \
    CONFIG.AXI_USER_WIDTH {0} \
    CONFIG.NR_CORES {1} \
  ] $cpu_0


  # Create instance: clint_0, and set properties
  set block_name clint_wrapper_verilog
  set block_cell_name clint_0
  if { [catch {set clint_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $clint_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [list \
    CONFIG.AXI_ID_WIDTH {6} \
    CONFIG.AXI_USER_WIDTH {0} \
    CONFIG.NR_CORES {1} \
  ] $clint_0


  # Create instance: northbridge
  create_hier_cell_northbridge [current_bd_instance .] northbridge

  # Create instance: cpu_reset_gen, and set properties
  set cpu_reset_gen [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 cpu_reset_gen ]

  # Create instance: cpu_debug, and set properties
  set block_name debug_module_wrapper_verilog
  set block_cell_name cpu_debug
  if { [catch {set cpu_debug [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $cpu_debug eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [list \
    CONFIG.AXI_USER_WIDTH {0} \
    CONFIG.NR_CORES {1} \
  ] $cpu_debug


  # Create instance: ps8_0_axi_periph, and set properties
  set ps8_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps8_0_axi_periph ]
  set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
  ] $ps8_0_axi_periph


  # Create instance: xlconstant_1, and set properties
  set xlconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1 ]
  set_property CONFIG.CONST_VAL {1} $xlconstant_1


  # Create instance: axi_jtag_0, and set properties
  set axi_jtag_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_jtag:1.0 axi_jtag_0 ]

  # Create instance: axi_gpio_0, and set properties
  set axi_gpio_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0 ]
  set_property -dict [list \
    CONFIG.GPIO_BOARD_INTERFACE {som240_1_connector_User_led} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $axi_gpio_0


  # Create instance: axi_uart16550_0, and set properties
  set axi_uart16550_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uart16550:2.0 axi_uart16550_0 ]

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_0


  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {16} \
    CONFIG.IN1_WIDTH {48} \
  ] $xlconcat_0


  # Create instance: axi_eth_led_gpio, and set properties
  set axi_eth_led_gpio [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_eth_led_gpio ]
  set_property -dict [list \
    CONFIG.GPIO_BOARD_INTERFACE {som240_2_connector_gem3_led} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $axi_eth_led_gpio


  # Create instance: xlconstant_3, and set properties
  set xlconstant_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_3 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {20} \
  ] $xlconstant_3


  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {103.11999999999999} \
    CONFIG.CLKIN1_UI_JITTER {0.01} \
    CONFIG.CLKIN2_JITTER_PS {1000000.0} \
    CONFIG.CLKIN2_UI_JITTER {0.010} \
    CONFIG.CLKOUT1_DRIVES {Buffer} \
    CONFIG.CLKOUT1_JITTER {220.126} \
    CONFIG.CLKOUT1_PHASE_ERROR {237.727} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000} \
    CONFIG.CLKOUT2_DRIVES {Buffer} \
    CONFIG.CLKOUT2_JITTER {193.101} \
    CONFIG.CLKOUT2_PHASE_ERROR {237.727} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {333.33333} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_DRIVES {Buffer} \
    CONFIG.CLKOUT3_JITTER {356.130} \
    CONFIG.CLKOUT3_PHASE_ERROR {237.727} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {25} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT4_DRIVES {Buffer} \
    CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT5_DRIVES {Buffer} \
    CONFIG.CLKOUT5_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT6_DRIVES {Buffer} \
    CONFIG.CLKOUT6_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT7_DRIVES {Buffer} \
    CONFIG.CLKOUT7_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {som240_2_connector_hpb_clk0p_clk} \
    CONFIG.CLK_OUT1_PORT {clk_gtx_125} \
    CONFIG.CLK_OUT2_PORT {clk_ref_333} \
    CONFIG.CLK_OUT3_PORT {clk_ref_25} \
    CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
    CONFIG.JITTER_OPTIONS {UI} \
    CONFIG.MMCM_BANDWIDTH {OPTIMIZED} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {40.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {40.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {8.000} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {3} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {40} \
    CONFIG.MMCM_COMPENSATION {AUTO} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.MMCM_REF_JITTER1 {0.010} \
    CONFIG.MMCM_REF_JITTER2 {0.010} \
    CONFIG.NUM_OUT_CLKS {3} \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.USE_BOARD_FLOW {true} \
    CONFIG.USE_FREQ_SYNTH {true} \
    CONFIG.USE_LOCKED {false} \
    CONFIG.USE_RESET {false} \
  ] $clk_wiz_0


  # Create instance: clk_wiz_2, and set properties
  set clk_wiz_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_2 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {400.0} \
    CONFIG.CLKIN1_UI_JITTER {0.01} \
    CONFIG.CLKIN2_JITTER_PS {100.0} \
    CONFIG.CLKIN2_UI_JITTER {0.010} \
    CONFIG.CLKOUT1_JITTER {203.173} \
    CONFIG.CLKOUT1_PHASE_ERROR {222.305} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {60} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT2_JITTER {207.962} \
    CONFIG.CLKOUT2_PHASE_ERROR {222.305} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {50} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT5_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT6_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT7_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {Custom} \
    CONFIG.CLK_IN2_BOARD_INTERFACE {Custom} \
    CONFIG.CLK_OUT1_PORT {clk_core_60} \
    CONFIG.CLK_OUT2_PORT {clk_spi_50} \
    CONFIG.JITTER_OPTIONS {UI} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {48.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {40.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {20.000} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {24} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.MMCM_REF_JITTER1 {0.010} \
    CONFIG.MMCM_REF_JITTER2 {0.010} \
    CONFIG.NUM_OUT_CLKS {2} \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
    CONFIG.PRIM_SOURCE {No_buffer} \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.SECONDARY_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.USE_BOARD_FLOW {true} \
    CONFIG.USE_FREQ_SYNTH {true} \
    CONFIG.USE_INCLK_SWITCHOVER {false} \
    CONFIG.USE_LOCKED {false} \
    CONFIG.USE_RESET {false} \
  ] $clk_wiz_2


  # Create instance: xlconstant_2, and set properties
  set xlconstant_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_2 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_2


  # Create instance: zynq_ultra_ps_e_0, and set properties
  set zynq_ultra_ps_e_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0 ]
  set_property -dict [list \
    CONFIG.PSU_BANK_0_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_1_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_2_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_BANK_3_IO_STANDARD {LVCMOS18} \
    CONFIG.PSU_DDR_RAM_HIGHADDR {0xFFFFFFFF} \
    CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET {0x800000000} \
    CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET {0x80000000} \
    CONFIG.PSU_MIO_0_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_0_SLEW {slow} \
    CONFIG.PSU_MIO_10_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_10_SLEW {slow} \
    CONFIG.PSU_MIO_11_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_11_SLEW {slow} \
    CONFIG.PSU_MIO_12_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_12_POLARITY {Default} \
    CONFIG.PSU_MIO_12_SLEW {slow} \
    CONFIG.PSU_MIO_13_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_13_POLARITY {Default} \
    CONFIG.PSU_MIO_13_SLEW {slow} \
    CONFIG.PSU_MIO_14_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_14_POLARITY {Default} \
    CONFIG.PSU_MIO_14_SLEW {slow} \
    CONFIG.PSU_MIO_15_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_15_POLARITY {Default} \
    CONFIG.PSU_MIO_15_SLEW {slow} \
    CONFIG.PSU_MIO_16_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_16_POLARITY {Default} \
    CONFIG.PSU_MIO_16_SLEW {slow} \
    CONFIG.PSU_MIO_17_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_17_POLARITY {Default} \
    CONFIG.PSU_MIO_17_SLEW {slow} \
    CONFIG.PSU_MIO_18_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_18_POLARITY {Default} \
    CONFIG.PSU_MIO_18_SLEW {slow} \
    CONFIG.PSU_MIO_19_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_19_POLARITY {Default} \
    CONFIG.PSU_MIO_19_SLEW {slow} \
    CONFIG.PSU_MIO_1_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_1_SLEW {slow} \
    CONFIG.PSU_MIO_20_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_20_POLARITY {Default} \
    CONFIG.PSU_MIO_20_SLEW {slow} \
    CONFIG.PSU_MIO_21_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_21_POLARITY {Default} \
    CONFIG.PSU_MIO_21_SLEW {slow} \
    CONFIG.PSU_MIO_22_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_22_POLARITY {Default} \
    CONFIG.PSU_MIO_22_SLEW {slow} \
    CONFIG.PSU_MIO_23_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_23_POLARITY {Default} \
    CONFIG.PSU_MIO_23_SLEW {slow} \
    CONFIG.PSU_MIO_24_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_24_SLEW {slow} \
    CONFIG.PSU_MIO_25_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_25_SLEW {slow} \
    CONFIG.PSU_MIO_27_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_27_SLEW {slow} \
    CONFIG.PSU_MIO_29_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_29_SLEW {slow} \
    CONFIG.PSU_MIO_2_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_2_SLEW {slow} \
    CONFIG.PSU_MIO_32_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_32_POLARITY {Default} \
    CONFIG.PSU_MIO_32_SLEW {slow} \
    CONFIG.PSU_MIO_33_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_33_POLARITY {Default} \
    CONFIG.PSU_MIO_33_SLEW {slow} \
    CONFIG.PSU_MIO_34_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_34_POLARITY {Default} \
    CONFIG.PSU_MIO_34_SLEW {slow} \
    CONFIG.PSU_MIO_35_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_35_SLEW {slow} \
    CONFIG.PSU_MIO_36_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_36_SLEW {slow} \
    CONFIG.PSU_MIO_38_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_38_SLEW {slow} \
    CONFIG.PSU_MIO_39_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_39_SLEW {slow} \
    CONFIG.PSU_MIO_3_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_3_SLEW {slow} \
    CONFIG.PSU_MIO_40_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_40_SLEW {slow} \
    CONFIG.PSU_MIO_41_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_41_SLEW {slow} \
    CONFIG.PSU_MIO_42_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_42_SLEW {slow} \
    CONFIG.PSU_MIO_43_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_43_SLEW {slow} \
    CONFIG.PSU_MIO_45_PULLUPDOWN {disable} \
    CONFIG.PSU_MIO_47_PULLUPDOWN {disable} \
    CONFIG.PSU_MIO_49_PULLUPDOWN {disable} \
    CONFIG.PSU_MIO_4_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_4_SLEW {slow} \
    CONFIG.PSU_MIO_50_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_50_SLEW {slow} \
    CONFIG.PSU_MIO_51_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_51_SLEW {slow} \
    CONFIG.PSU_MIO_54_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_54_SLEW {slow} \
    CONFIG.PSU_MIO_56_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_56_SLEW {slow} \
    CONFIG.PSU_MIO_57_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_57_SLEW {slow} \
    CONFIG.PSU_MIO_58_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_58_SLEW {slow} \
    CONFIG.PSU_MIO_59_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_59_SLEW {slow} \
    CONFIG.PSU_MIO_5_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_5_SLEW {slow} \
    CONFIG.PSU_MIO_60_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_60_SLEW {slow} \
    CONFIG.PSU_MIO_61_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_61_SLEW {slow} \
    CONFIG.PSU_MIO_62_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_62_SLEW {slow} \
    CONFIG.PSU_MIO_63_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_63_SLEW {slow} \
    CONFIG.PSU_MIO_66_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_66_SLEW {slow} \
    CONFIG.PSU_MIO_68_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_68_SLEW {slow} \
    CONFIG.PSU_MIO_69_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_69_SLEW {slow} \
    CONFIG.PSU_MIO_6_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_6_SLEW {slow} \
    CONFIG.PSU_MIO_70_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_70_SLEW {slow} \
    CONFIG.PSU_MIO_71_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_71_SLEW {slow} \
    CONFIG.PSU_MIO_72_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_72_SLEW {slow} \
    CONFIG.PSU_MIO_73_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_73_SLEW {slow} \
    CONFIG.PSU_MIO_74_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_74_SLEW {slow} \
    CONFIG.PSU_MIO_75_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_75_SLEW {slow} \
    CONFIG.PSU_MIO_76_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_76_SLEW {slow} \
    CONFIG.PSU_MIO_77_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_77_SLEW {slow} \
    CONFIG.PSU_MIO_7_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_7_POLARITY {Default} \
    CONFIG.PSU_MIO_7_SLEW {slow} \
    CONFIG.PSU_MIO_8_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_8_POLARITY {Default} \
    CONFIG.PSU_MIO_8_SLEW {slow} \
    CONFIG.PSU_MIO_9_DRIVE_STRENGTH {4} \
    CONFIG.PSU_MIO_9_SLEW {slow} \
    CONFIG.PSU_MIO_TREE_PERIPHERALS {Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#SPI 1#GPIO0 MIO#GPIO0 MIO#SPI 1#SPI 1#SPI 1#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0\
MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#GPIO0 MIO#I2C 1#I2C 1#PMU GPI 0#DPAUX#DPAUX#DPAUX#DPAUX#PMU GPI 5#GPIO1 MIO#GPIO1 MIO#GPIO1 MIO#PMU GPO 3#UART 1#UART 1#Gem 1#Gem\
1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#Gem 1#MDIO 1#MDIO 1#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB 1#USB\
1#USB 1#USB 1#USB0 Reset#USB1 Reset} \
    CONFIG.PSU_MIO_TREE_SIGNALS {sclk_out#miso_mo1#mo2#mo3#mosi_mi0#n_ss_out#sclk_out#gpio0[7]#gpio0[8]#n_ss_out[0]#miso#mosi#gpio0[12]#gpio0[13]#gpio0[14]#gpio0[15]#gpio0[16]#gpio0[17]#gpio0[18]#gpio0[19]#gpio0[20]#gpio0[21]#gpio0[22]#gpio0[23]#scl_out#sda_out#gpi[0]#dp_aux_data_out#dp_hot_plug_detect#dp_aux_data_oe#dp_aux_data_in#gpi[5]#gpio1[32]#gpio1[33]#gpio1[34]#gpo[3]#txd#rxd#rgmii_tx_clk#rgmii_txd[0]#rgmii_txd[1]#rgmii_txd[2]#rgmii_txd[3]#rgmii_tx_ctl#rgmii_rx_clk#rgmii_rxd[0]#rgmii_rxd[1]#rgmii_rxd[2]#rgmii_rxd[3]#rgmii_rx_ctl#gem1_mdc#gem1_mdio_out#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#ulpi_clk_in#ulpi_dir#ulpi_tx_data[2]#ulpi_nxt#ulpi_tx_data[0]#ulpi_tx_data[1]#ulpi_stp#ulpi_tx_data[3]#ulpi_tx_data[4]#ulpi_tx_data[5]#ulpi_tx_data[6]#ulpi_tx_data[7]#reset#reset}\
\
    CONFIG.PSU_USB3__DUAL_CLOCK_ENABLE {1} \
    CONFIG.PSU__ACT_DDR_FREQ_MHZ {1066.656006} \
    CONFIG.PSU__CRF_APB__ACPU_CTRL__ACT_FREQMHZ {1333.333008} \
    CONFIG.PSU__CRF_APB__ACPU_CTRL__FREQMHZ {1333.333} \
    CONFIG.PSU__CRF_APB__ACPU_CTRL__SRCSEL {APLL} \
    CONFIG.PSU__CRF_APB__ACPU__FRAC_ENABLED {1} \
    CONFIG.PSU__CRF_APB__APLL_CTRL__FRACFREQ {1333.333} \
    CONFIG.PSU__CRF_APB__APLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__APLL_FRAC_CFG__ENABLED {1} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__ACT_FREQMHZ {249.997498} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_FPD_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TRACE_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__ACT_FREQMHZ {249.997498} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRF_APB__DBG_TSTMP_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__ACT_FREQMHZ {533.328003} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ {1200} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__ACT_FREQMHZ {444.444336} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__DPDMA_REF_CTRL__SRCSEL {APLL} \
    CONFIG.PSU__CRF_APB__DPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__ACT_FREQMHZ {24.242182} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__FREQMHZ {25} \
    CONFIG.PSU__CRF_APB__DP_AUDIO_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_AUDIO__FRAC_ENABLED {0} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__ACT_FREQMHZ {26.666401} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__FREQMHZ {27} \
    CONFIG.PSU__CRF_APB__DP_STC_REF_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__ACT_FREQMHZ {299.997009} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__FREQMHZ {300} \
    CONFIG.PSU__CRF_APB__DP_VIDEO_REF_CTRL__SRCSEL {VPLL} \
    CONFIG.PSU__CRF_APB__DP_VIDEO__FRAC_ENABLED {0} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__ACT_FREQMHZ {533.328003} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__GDMA_REF_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__ACT_FREQMHZ {499.994995} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__FREQMHZ {600} \
    CONFIG.PSU__CRF_APB__GPU_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__ACT_FREQMHZ {99.999001} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRF_APB__TOPSW_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__ACT_FREQMHZ {533.328003} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__FREQMHZ {533.33} \
    CONFIG.PSU__CRF_APB__TOPSW_MAIN_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__CRF_APB__VPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__ACT_FREQMHZ {499.994995} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__ADMA_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__AMS_REF_CTRL__ACT_FREQMHZ {49.999500} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__ACT_FREQMHZ {533.328003} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__FREQMHZ {533.333} \
    CONFIG.PSU__CRL_APB__CPU_R5_CTRL__SRCSEL {RPLL} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__ACT_FREQMHZ {249.997498} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__DBG_LPD_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__DLL_REF_CTRL__ACT_FREQMHZ {999.989990} \
    CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__ACT_FREQMHZ {124.998749} \
    CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM0_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__ACT_FREQMHZ {124.998749} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__GEM1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__ACT_FREQMHZ {249.997498} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__GEM_TSU_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__ACT_FREQMHZ {99.999001} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__I2C1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__IOPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__ACT_FREQMHZ {249.997498} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__IOU_SWITCH_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__ACT_FREQMHZ {99.999001} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__LPD_LSBUS_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__ACT_FREQMHZ {499.994995} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__FREQMHZ {500} \
    CONFIG.PSU__CRL_APB__LPD_SWITCH_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__ACT_FREQMHZ {199.998001} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__PCAP_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__ACT_FREQMHZ {96.968727} \
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__ACT_FREQMHZ {99.999001} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__ACT_FREQMHZ {124.998749} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__FREQMHZ {125} \
    CONFIG.PSU__CRL_APB__QSPI_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__RPLL_CTRL__SRCSEL {PSS_REF_CLK} \
    CONFIG.PSU__CRL_APB__SDIO1_REF_CTRL__ACT_FREQMHZ {199.998001} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__ACT_FREQMHZ {199.998001} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__FREQMHZ {200} \
    CONFIG.PSU__CRL_APB__SPI1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__ACT_FREQMHZ {99.999001} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__TIMESTAMP_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__ACT_FREQMHZ {99.999001} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__UART1_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__ACT_FREQMHZ {249.997498} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__USB0_BUS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__ACT_FREQMHZ {249.997498} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__CRL_APB__USB1_BUS_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__ACT_FREQMHZ {19.999800} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__FREQMHZ {20} \
    CONFIG.PSU__CRL_APB__USB3_DUAL_REF_CTRL__SRCSEL {IOPLL} \
    CONFIG.PSU__CRL_APB__USB3__ENABLE {1} \
    CONFIG.PSU__CSUPMU__PERIPHERAL__VALID {1} \
    CONFIG.PSU__DDRC__BG_ADDR_COUNT {1} \
    CONFIG.PSU__DDRC__BRC_MAPPING {ROW_BANK_COL} \
    CONFIG.PSU__DDRC__BUS_WIDTH {64 Bit} \
    CONFIG.PSU__DDRC__CL {16} \
    CONFIG.PSU__DDRC__CLOCK_STOP_EN {0} \
    CONFIG.PSU__DDRC__COMPONENTS {Components} \
    CONFIG.PSU__DDRC__CWL {14} \
    CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {0} \
    CONFIG.PSU__DDRC__DDR4_CAL_MODE_ENABLE {0} \
    CONFIG.PSU__DDRC__DDR4_CRC_CONTROL {0} \
    CONFIG.PSU__DDRC__DDR4_T_REF_MODE {0} \
    CONFIG.PSU__DDRC__DDR4_T_REF_RANGE {Normal (0-85)} \
    CONFIG.PSU__DDRC__DEVICE_CAPACITY {8192 MBits} \
    CONFIG.PSU__DDRC__DM_DBI {DM_NO_DBI} \
    CONFIG.PSU__DDRC__DRAM_WIDTH {16 Bits} \
    CONFIG.PSU__DDRC__ECC {Disabled} \
    CONFIG.PSU__DDRC__FGRM {1X} \
    CONFIG.PSU__DDRC__LP_ASR {manual normal} \
    CONFIG.PSU__DDRC__MEMORY_TYPE {DDR 4} \
    CONFIG.PSU__DDRC__PARITY_ENABLE {0} \
    CONFIG.PSU__DDRC__PER_BANK_REFRESH {0} \
    CONFIG.PSU__DDRC__PHY_DBI_MODE {0} \
    CONFIG.PSU__DDRC__RANK_ADDR_COUNT {0} \
    CONFIG.PSU__DDRC__ROW_ADDR_COUNT {16} \
    CONFIG.PSU__DDRC__SELF_REF_ABORT {0} \
    CONFIG.PSU__DDRC__SPEED_BIN {DDR4_2400R} \
    CONFIG.PSU__DDRC__STATIC_RD_MODE {0} \
    CONFIG.PSU__DDRC__TRAIN_DATA_EYE {1} \
    CONFIG.PSU__DDRC__TRAIN_READ_GATE {1} \
    CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL {1} \
    CONFIG.PSU__DDRC__T_FAW {30.0} \
    CONFIG.PSU__DDRC__T_RAS_MIN {33} \
    CONFIG.PSU__DDRC__T_RC {47.06} \
    CONFIG.PSU__DDRC__T_RCD {16} \
    CONFIG.PSU__DDRC__T_RP {16} \
    CONFIG.PSU__DDRC__VREF {1} \
    CONFIG.PSU__DDR_HIGH_ADDRESS_GUI_ENABLE {1} \
    CONFIG.PSU__DDR__INTERFACE__FREQMHZ {600.000} \
    CONFIG.PSU__DISPLAYPORT__LANE0__ENABLE {1} \
    CONFIG.PSU__DISPLAYPORT__LANE0__IO {GT Lane1} \
    CONFIG.PSU__DISPLAYPORT__LANE1__ENABLE {0} \
    CONFIG.PSU__DISPLAYPORT__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__DPAUX__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__DPAUX__PERIPHERAL__IO {MIO 27 .. 30} \
    CONFIG.PSU__DP__LANE_SEL {Single Lower} \
    CONFIG.PSU__DP__REF_CLK_FREQ {27} \
    CONFIG.PSU__DP__REF_CLK_SEL {Ref Clk1} \
    CONFIG.PSU__ENET0__FIFO__ENABLE {0} \
    CONFIG.PSU__ENET0__GRP_MDIO__ENABLE {0} \
    CONFIG.PSU__ENET0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__ENET0__PERIPHERAL__IO {GT Lane0} \
    CONFIG.PSU__ENET0__PTP__ENABLE {0} \
    CONFIG.PSU__ENET0__TSU__ENABLE {0} \
    CONFIG.PSU__ENET1__FIFO__ENABLE {0} \
    CONFIG.PSU__ENET1__GRP_MDIO__ENABLE {1} \
    CONFIG.PSU__ENET1__GRP_MDIO__IO {MIO 50 .. 51} \
    CONFIG.PSU__ENET1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__ENET1__PERIPHERAL__IO {MIO 38 .. 49} \
    CONFIG.PSU__ENET1__PTP__ENABLE {0} \
    CONFIG.PSU__ENET1__TSU__ENABLE {0} \
    CONFIG.PSU__FPD_SLCR__WDT1__ACT_FREQMHZ {99.999001} \
    CONFIG.PSU__FPGA_PL0_ENABLE {0} \
    CONFIG.PSU__FPGA_PL1_ENABLE {0} \
    CONFIG.PSU__FPGA_PL2_ENABLE {0} \
    CONFIG.PSU__GEM0_COHERENCY {0} \
    CONFIG.PSU__GEM0_ROUTE_THROUGH_FPD {0} \
    CONFIG.PSU__GEM0__REF_CLK_FREQ {125} \
    CONFIG.PSU__GEM0__REF_CLK_SEL {Ref Clk0} \
    CONFIG.PSU__GEM1_COHERENCY {0} \
    CONFIG.PSU__GEM1_ROUTE_THROUGH_FPD {0} \
    CONFIG.PSU__GEM__TSU__ENABLE {0} \
    CONFIG.PSU__GPIO0_MIO__IO {MIO 0 .. 25} \
    CONFIG.PSU__GPIO0_MIO__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__GPIO1_MIO__IO {MIO 26 .. 51} \
    CONFIG.PSU__GPIO1_MIO__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__GT__LINK_SPEED {HBR} \
    CONFIG.PSU__GT__PRE_EMPH_LVL_4 {0} \
    CONFIG.PSU__GT__VLT_SWNG_LVL_4 {0} \
    CONFIG.PSU__I2C1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__I2C1__PERIPHERAL__IO {MIO 24 .. 25} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC0_SEL {APB} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC1_SEL {APB} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC2_SEL {APB} \
    CONFIG.PSU__IOU_SLCR__IOU_TTC_APB_CLK__TTC3_SEL {APB} \
    CONFIG.PSU__IOU_SLCR__TTC0__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__IOU_SLCR__TTC1__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__IOU_SLCR__TTC2__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__IOU_SLCR__TTC3__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__IOU_SLCR__WDT0__ACT_FREQMHZ {99.999001} \
    CONFIG.PSU__LPD_SLCR__CSUPMU__ACT_FREQMHZ {100.000000} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} \
    CONFIG.PSU__OVERRIDE__BASIC_CLOCK {0} \
    CONFIG.PSU__PMU_COHERENCY {0} \
    CONFIG.PSU__PMU__AIBACK__ENABLE {0} \
    CONFIG.PSU__PMU__EMIO_GPI__ENABLE {0} \
    CONFIG.PSU__PMU__EMIO_GPO__ENABLE {0} \
    CONFIG.PSU__PMU__GPI0__ENABLE {1} \
    CONFIG.PSU__PMU__GPI0__IO {MIO 26} \
    CONFIG.PSU__PMU__GPI1__ENABLE {0} \
    CONFIG.PSU__PMU__GPI2__ENABLE {0} \
    CONFIG.PSU__PMU__GPI3__ENABLE {0} \
    CONFIG.PSU__PMU__GPI4__ENABLE {0} \
    CONFIG.PSU__PMU__GPI5__ENABLE {1} \
    CONFIG.PSU__PMU__GPI5__IO {MIO 31} \
    CONFIG.PSU__PMU__GPO0__ENABLE {0} \
    CONFIG.PSU__PMU__GPO1__ENABLE {0} \
    CONFIG.PSU__PMU__GPO2__ENABLE {0} \
    CONFIG.PSU__PMU__GPO3__ENABLE {1} \
    CONFIG.PSU__PMU__GPO3__IO {MIO 35} \
    CONFIG.PSU__PMU__GPO3__POLARITY {low} \
    CONFIG.PSU__PMU__GPO4__ENABLE {0} \
    CONFIG.PSU__PMU__GPO5__ENABLE {0} \
    CONFIG.PSU__PMU__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__PMU__PLERROR__ENABLE {0} \
    CONFIG.PSU__PRESET_APPLIED {1} \
    CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;1|USB0:NonSecure;1|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;0|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;1|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;0|SD0:NonSecure;0|SATA1:NonSecure;0|SATA0:NonSecure;0|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;1|PMU:NA;1|PCIe:NonSecure;0|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;0|GEM2:NonSecure;0|GEM1:NonSecure;1|GEM0:NonSecure;1|FDMA:NonSecure;1|DP:NonSecure;1|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1}\
\
    CONFIG.PSU__PROTECTION__SLAVES {LPD;USB3_1_XHCI;FE300000;FE3FFFFF;1|LPD;USB3_1;FF9E0000;FF9EFFFF;1|LPD;USB3_0_XHCI;FE200000;FE2FFFFF;1|LPD;USB3_0;FF9D0000;FF9DFFFF;1|LPD;UART1;FF010000;FF01FFFF;1|LPD;UART0;FF000000;FF00FFFF;0|LPD;TTC3;FF140000;FF14FFFF;1|LPD;TTC2;FF130000;FF13FFFF;1|LPD;TTC1;FF120000;FF12FFFF;1|LPD;TTC0;FF110000;FF11FFFF;1|FPD;SWDT1;FD4D0000;FD4DFFFF;1|LPD;SWDT0;FF150000;FF15FFFF;1|LPD;SPI1;FF050000;FF05FFFF;1|LPD;SPI0;FF040000;FF04FFFF;0|FPD;SMMU_REG;FD5F0000;FD5FFFFF;1|FPD;SMMU;FD800000;FDFFFFFF;1|FPD;SIOU;FD3D0000;FD3DFFFF;1|FPD;SERDES;FD400000;FD47FFFF;1|LPD;SD1;FF170000;FF17FFFF;0|LPD;SD0;FF160000;FF16FFFF;0|FPD;SATA;FD0C0000;FD0CFFFF;0|LPD;RTC;FFA60000;FFA6FFFF;1|LPD;RSA_CORE;FFCE0000;FFCEFFFF;1|LPD;RPU;FF9A0000;FF9AFFFF;1|LPD;R5_TCM_RAM_GLOBAL;FFE00000;FFE3FFFF;1|LPD;R5_1_Instruction_Cache;FFEC0000;FFECFFFF;1|LPD;R5_1_Data_Cache;FFED0000;FFEDFFFF;1|LPD;R5_1_BTCM_GLOBAL;FFEB0000;FFEBFFFF;1|LPD;R5_1_ATCM_GLOBAL;FFE90000;FFE9FFFF;1|LPD;R5_0_Instruction_Cache;FFE40000;FFE4FFFF;1|LPD;R5_0_Data_Cache;FFE50000;FFE5FFFF;1|LPD;R5_0_BTCM_GLOBAL;FFE20000;FFE2FFFF;1|LPD;R5_0_ATCM_GLOBAL;FFE00000;FFE0FFFF;1|LPD;QSPI_Linear_Address;C0000000;DFFFFFFF;1|LPD;QSPI;FF0F0000;FF0FFFFF;1|LPD;PMU_RAM;FFDC0000;FFDDFFFF;1|LPD;PMU_GLOBAL;FFD80000;FFDBFFFF;1|FPD;PCIE_MAIN;FD0E0000;FD0EFFFF;0|FPD;PCIE_LOW;E0000000;EFFFFFFF;0|FPD;PCIE_HIGH2;8000000000;BFFFFFFFFF;0|FPD;PCIE_HIGH1;600000000;7FFFFFFFF;0|FPD;PCIE_DMA;FD0F0000;FD0FFFFF;0|FPD;PCIE_ATTRIB;FD480000;FD48FFFF;0|LPD;OCM_XMPU_CFG;FFA70000;FFA7FFFF;1|LPD;OCM_SLCR;FF960000;FF96FFFF;1|OCM;OCM;FFFC0000;FFFFFFFF;1|LPD;NAND;FF100000;FF10FFFF;0|LPD;MBISTJTAG;FFCF0000;FFCFFFFF;1|LPD;LPD_XPPU_SINK;FF9C0000;FF9CFFFF;1|LPD;LPD_XPPU;FF980000;FF98FFFF;1|LPD;LPD_SLCR_SECURE;FF4B0000;FF4DFFFF;1|LPD;LPD_SLCR;FF410000;FF4AFFFF;1|LPD;LPD_GPV;FE100000;FE1FFFFF;1|LPD;LPD_DMA_7;FFAF0000;FFAFFFFF;1|LPD;LPD_DMA_6;FFAE0000;FFAEFFFF;1|LPD;LPD_DMA_5;FFAD0000;FFADFFFF;1|LPD;LPD_DMA_4;FFAC0000;FFACFFFF;1|LPD;LPD_DMA_3;FFAB0000;FFABFFFF;1|LPD;LPD_DMA_2;FFAA0000;FFAAFFFF;1|LPD;LPD_DMA_1;FFA90000;FFA9FFFF;1|LPD;LPD_DMA_0;FFA80000;FFA8FFFF;1|LPD;IPI_CTRL;FF380000;FF3FFFFF;1|LPD;IOU_SLCR;FF180000;FF23FFFF;1|LPD;IOU_SECURE_SLCR;FF240000;FF24FFFF;1|LPD;IOU_SCNTRS;FF260000;FF26FFFF;1|LPD;IOU_SCNTR;FF250000;FF25FFFF;1|LPD;IOU_GPV;FE000000;FE0FFFFF;1|LPD;I2C1;FF030000;FF03FFFF;1|LPD;I2C0;FF020000;FF02FFFF;0|FPD;GPU;FD4B0000;FD4BFFFF;1|LPD;GPIO;FF0A0000;FF0AFFFF;1|LPD;GEM3;FF0E0000;FF0EFFFF;0|LPD;GEM2;FF0D0000;FF0DFFFF;0|LPD;GEM1;FF0C0000;FF0CFFFF;1|LPD;GEM0;FF0B0000;FF0BFFFF;1|FPD;FPD_XMPU_SINK;FD4F0000;FD4FFFFF;1|FPD;FPD_XMPU_CFG;FD5D0000;FD5DFFFF;1|FPD;FPD_SLCR_SECURE;FD690000;FD6CFFFF;1|FPD;FPD_SLCR;FD610000;FD68FFFF;1|FPD;FPD_DMA_CH7;FD570000;FD57FFFF;1|FPD;FPD_DMA_CH6;FD560000;FD56FFFF;1|FPD;FPD_DMA_CH5;FD550000;FD55FFFF;1|FPD;FPD_DMA_CH4;FD540000;FD54FFFF;1|FPD;FPD_DMA_CH3;FD530000;FD53FFFF;1|FPD;FPD_DMA_CH2;FD520000;FD52FFFF;1|FPD;FPD_DMA_CH1;FD510000;FD51FFFF;1|FPD;FPD_DMA_CH0;FD500000;FD50FFFF;1|LPD;EFUSE;FFCC0000;FFCCFFFF;1|FPD;Display\
Port;FD4A0000;FD4AFFFF;1|FPD;DPDMA;FD4C0000;FD4CFFFF;1|FPD;DDR_XMPU5_CFG;FD050000;FD05FFFF;1|FPD;DDR_XMPU4_CFG;FD040000;FD04FFFF;1|FPD;DDR_XMPU3_CFG;FD030000;FD03FFFF;1|FPD;DDR_XMPU2_CFG;FD020000;FD02FFFF;1|FPD;DDR_XMPU1_CFG;FD010000;FD01FFFF;1|FPD;DDR_XMPU0_CFG;FD000000;FD00FFFF;1|FPD;DDR_QOS_CTRL;FD090000;FD09FFFF;1|FPD;DDR_PHY;FD080000;FD08FFFF;1|DDR;DDR_LOW;0;7FFFFFFF;1|DDR;DDR_HIGH;800000000;87FFFFFFF;1|FPD;DDDR_CTRL;FD070000;FD070FFF;1|LPD;Coresight;FE800000;FEFFFFFF;1|LPD;CSU_DMA;FFC80000;FFC9FFFF;1|LPD;CSU;FFCA0000;FFCAFFFF;1|LPD;CRL_APB;FF5E0000;FF85FFFF;1|FPD;CRF_APB;FD1A0000;FD2DFFFF;1|FPD;CCI_REG;FD5E0000;FD5EFFFF;1|LPD;CAN1;FF070000;FF07FFFF;0|LPD;CAN0;FF060000;FF06FFFF;0|FPD;APU;FD5C0000;FD5CFFFF;1|LPD;APM_INTC_IOU;FFA20000;FFA2FFFF;1|LPD;APM_FPD_LPD;FFA30000;FFA3FFFF;1|FPD;APM_5;FD490000;FD49FFFF;1|FPD;APM_0;FD0B0000;FD0BFFFF;1|LPD;APM2;FFA10000;FFA1FFFF;1|LPD;APM1;FFA00000;FFA0FFFF;1|LPD;AMS;FFA50000;FFA5FFFF;1|FPD;AFI_5;FD3B0000;FD3BFFFF;1|FPD;AFI_4;FD3A0000;FD3AFFFF;1|FPD;AFI_3;FD390000;FD39FFFF;1|FPD;AFI_2;FD380000;FD38FFFF;1|FPD;AFI_1;FD370000;FD37FFFF;1|FPD;AFI_0;FD360000;FD36FFFF;1|LPD;AFIFM6;FF9B0000;FF9BFFFF;1|FPD;ACPU_GIC;F9010000;F907FFFF;1}\
\
    CONFIG.PSU__PSS_REF_CLK__FREQMHZ {33.333} \
    CONFIG.PSU__QSPI_COHERENCY {0} \
    CONFIG.PSU__QSPI_ROUTE_THROUGH_FPD {0} \
    CONFIG.PSU__QSPI__GRP_FBCLK__ENABLE {0} \
    CONFIG.PSU__QSPI__PERIPHERAL__DATA_MODE {x4} \
    CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__QSPI__PERIPHERAL__IO {MIO 0 .. 5} \
    CONFIG.PSU__QSPI__PERIPHERAL__MODE {Single} \
    CONFIG.PSU__SAXIGP2__DATA_WIDTH {128} \
    CONFIG.PSU__SD1__CLK_100_SDR_OTAP_DLY {0x3} \
    CONFIG.PSU__SD1__CLK_200_SDR_OTAP_DLY {0x3} \
    CONFIG.PSU__SD1__CLK_50_DDR_ITAP_DLY {0x3D} \
    CONFIG.PSU__SD1__CLK_50_DDR_OTAP_DLY {0x4} \
    CONFIG.PSU__SD1__CLK_50_SDR_ITAP_DLY {0x15} \
    CONFIG.PSU__SD1__CLK_50_SDR_OTAP_DLY {0x5} \
    CONFIG.PSU__SD1__PERIPHERAL__ENABLE {0} \
    CONFIG.PSU__SD1__RESET__ENABLE {0} \
    CONFIG.PSU__SPI1__GRP_SS0__IO {MIO 9} \
    CONFIG.PSU__SPI1__GRP_SS1__ENABLE {0} \
    CONFIG.PSU__SPI1__GRP_SS2__ENABLE {0} \
    CONFIG.PSU__SPI1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SPI1__PERIPHERAL__IO {MIO 6 .. 11} \
    CONFIG.PSU__SWDT0__CLOCK__ENABLE {0} \
    CONFIG.PSU__SWDT0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SWDT0__RESET__ENABLE {0} \
    CONFIG.PSU__SWDT1__CLOCK__ENABLE {0} \
    CONFIG.PSU__SWDT1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__SWDT1__RESET__ENABLE {0} \
    CONFIG.PSU__TSU__BUFG_PORT_PAIR {0} \
    CONFIG.PSU__TTC0__CLOCK__ENABLE {0} \
    CONFIG.PSU__TTC0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__TTC0__WAVEOUT__ENABLE {0} \
    CONFIG.PSU__TTC1__CLOCK__ENABLE {0} \
    CONFIG.PSU__TTC1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__TTC1__WAVEOUT__ENABLE {0} \
    CONFIG.PSU__TTC2__CLOCK__ENABLE {0} \
    CONFIG.PSU__TTC2__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__TTC2__WAVEOUT__ENABLE {0} \
    CONFIG.PSU__TTC3__CLOCK__ENABLE {0} \
    CONFIG.PSU__TTC3__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__TTC3__WAVEOUT__ENABLE {0} \
    CONFIG.PSU__UART1__BAUD_RATE {115200} \
    CONFIG.PSU__UART1__MODEM__ENABLE {0} \
    CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__UART1__PERIPHERAL__IO {MIO 36 .. 37} \
    CONFIG.PSU__USB0_COHERENCY {0} \
    CONFIG.PSU__USB0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB0__PERIPHERAL__IO {MIO 52 .. 63} \
    CONFIG.PSU__USB0__REF_CLK_FREQ {26} \
    CONFIG.PSU__USB0__REF_CLK_SEL {Ref Clk2} \
    CONFIG.PSU__USB0__RESET__ENABLE {1} \
    CONFIG.PSU__USB0__RESET__IO {MIO 76} \
    CONFIG.PSU__USB1_COHERENCY {0} \
    CONFIG.PSU__USB1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB1__PERIPHERAL__IO {MIO 64 .. 75} \
    CONFIG.PSU__USB1__REF_CLK_FREQ {26} \
    CONFIG.PSU__USB1__REF_CLK_SEL {Ref Clk3} \
    CONFIG.PSU__USB1__RESET__ENABLE {1} \
    CONFIG.PSU__USB1__RESET__IO {MIO 77} \
    CONFIG.PSU__USB2_0__EMIO__ENABLE {0} \
    CONFIG.PSU__USB2_1__EMIO__ENABLE {0} \
    CONFIG.PSU__USB3_0__EMIO__ENABLE {0} \
    CONFIG.PSU__USB3_0__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB3_0__PERIPHERAL__IO {GT Lane2} \
    CONFIG.PSU__USB3_1__EMIO__ENABLE {0} \
    CONFIG.PSU__USB3_1__PERIPHERAL__ENABLE {1} \
    CONFIG.PSU__USB3_1__PERIPHERAL__IO {GT Lane3} \
    CONFIG.PSU__USB__RESET__MODE {Separate MIO Pin} \
    CONFIG.PSU__USB__RESET__POLARITY {Active Low} \
    CONFIG.PSU__USE__IRQ0 {1} \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
  ] $zynq_ultra_ps_e_0


  # Create interface connections
  connect_bd_intf_net -intf_net axi_eth_led_gpio_GPIO [get_bd_intf_ports som240_2_connector_gem3_led] [get_bd_intf_pins axi_eth_led_gpio/GPIO]
  connect_bd_intf_net -intf_net axi_gpio_0_GPIO [get_bd_intf_ports som240_1_connector_User_led] [get_bd_intf_pins axi_gpio_0/GPIO]
  connect_bd_intf_net -intf_net axi_interconnect_0_M04_AXI [get_bd_intf_pins axi_bootrom_control/S_AXI] [get_bd_intf_pins northbridge/BOOTROM_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M05_AXI [get_bd_intf_pins northbridge/CLINT_AXI] [get_bd_intf_pins clint_0/s_axi_clint]
  connect_bd_intf_net -intf_net axi_interconnect_0_M09_AXI [get_bd_intf_pins northbridge/PLIC_AXI] [get_bd_intf_pins ariane_peripherals_0/s_axi_plic]
  connect_bd_intf_net -intf_net axi_interconnect_0_M10_AXI [get_bd_intf_pins northbridge/TIMER_AXI] [get_bd_intf_pins ariane_peripherals_0/s_axi_timer]
  connect_bd_intf_net -intf_net cpu_0_m_axi_cpu [get_bd_intf_pins cpu_0/m_axi_cpu] [get_bd_intf_pins northbridge/CPU_AXI]
  connect_bd_intf_net -intf_net cpu_debug_m_axi_dmi_jtag [get_bd_intf_pins cpu_debug/m_axi_dmi_jtag] [get_bd_intf_pins northbridge/DEBUG_MODULE_AXI]
  connect_bd_intf_net -intf_net northbridge_DDR_AXI [get_bd_intf_pins northbridge/DDR_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
  connect_bd_intf_net -intf_net northbridge_M06_AXI [get_bd_intf_pins sdcard_quad_spi_axi/AXI_FULL] [get_bd_intf_pins northbridge/SDCARD_AXI]
  connect_bd_intf_net -intf_net northbridge_M12_AXI [get_bd_intf_pins cpu_debug/s_axi_dmi_jtag] [get_bd_intf_pins northbridge/DEBUG_AXI]
  connect_bd_intf_net -intf_net northbridge_M_AXI [get_bd_intf_pins axi_gpio_0/S_AXI] [get_bd_intf_pins northbridge/GPIO_AXI]
  connect_bd_intf_net -intf_net northbridge_M_AXI1 [get_bd_intf_pins axi_eth_led_gpio/S_AXI] [get_bd_intf_pins northbridge/ETH_LED_AXI]
  connect_bd_intf_net -intf_net northbridge_UART_AXI [get_bd_intf_pins axi_uart16550_0/S_AXI] [get_bd_intf_pins northbridge/UART_AXILite]
  connect_bd_intf_net -intf_net northbridge_som240_2_connector_pl_gem3_rgmii [get_bd_intf_ports som240_2_connector_pl_gem3_rgmii] [get_bd_intf_pins northbridge/som240_2_connector_pl_gem3_rgmii]
  connect_bd_intf_net -intf_net northbridge_som240_2_connector_pl_gem3_rgmii_mdio_mdc [get_bd_intf_ports som240_2_connector_pl_gem3_rgmii_mdio_mdc] [get_bd_intf_pins northbridge/som240_2_connector_pl_gem3_rgmii_mdio_mdc]
  connect_bd_intf_net -intf_net ps8_0_axi_periph_M00_AXI [get_bd_intf_pins ps8_0_axi_periph/M00_AXI] [get_bd_intf_pins axi_jtag_0/s_axi]
  connect_bd_intf_net -intf_net zynq_ultra_ps_e_0_M_AXI_HPM0_FPD [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] [get_bd_intf_pins ps8_0_axi_periph/S00_AXI]

  # Create port connections
  connect_bd_net -net ariane_peripherals_0_irq_out [get_bd_pins ariane_peripherals_0/irq_out] [get_bd_pins cpu_0/irqs_in]
  connect_bd_net -net axi_bootrom_control_bram_addr_a [get_bd_pins axi_bootrom_control/bram_addr_a] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net axi_bram_ctrl_0_bram_clk_a [get_bd_pins axi_bootrom_control/bram_clk_a] [get_bd_pins bootrom_wrapper_0/clk_i]
  connect_bd_net -net axi_bram_ctrl_0_bram_en_a [get_bd_pins axi_bootrom_control/bram_en_a] [get_bd_pins bootrom_wrapper_0/req_i]
  connect_bd_net -net axi_jtag_0_tck [get_bd_pins axi_jtag_0/tck] [get_bd_pins cpu_debug/jtag_tck]
  connect_bd_net -net axi_jtag_0_tdi [get_bd_pins axi_jtag_0/tdi] [get_bd_pins cpu_debug/jtag_tdi]
  connect_bd_net -net axi_jtag_0_tms [get_bd_pins axi_jtag_0/tms] [get_bd_pins cpu_debug/jtag_tms]
  connect_bd_net -net axi_uart16550_0_ip2intc_irpt [get_bd_pins axi_uart16550_0/ip2intc_irpt] [get_bd_pins ariane_peripherals_0/uart_irq_i]
  connect_bd_net -net axi_uart16550_0_sout [get_bd_pins axi_uart16550_0/sout] [get_bd_ports uart_sout]
  connect_bd_net -net bootrom_wrapper_0_rdata_o [get_bd_pins bootrom_wrapper_0/rdata_o] [get_bd_pins axi_bootrom_control/bram_rddata_a]
  connect_bd_net -net clint_0_ipi_o [get_bd_pins clint_0/ipi_o] [get_bd_pins cpu_0/ipi_in]
  connect_bd_net -net clint_0_timer_irq_o [get_bd_pins clint_0/timer_irq_o] [get_bd_pins cpu_0/timer_irq_i]
  connect_bd_net -net clk_wiz_0_clk_gtx_125 [get_bd_pins clk_wiz_0/clk_gtx_125] [get_bd_pins northbridge/gtx_clk]
  connect_bd_net -net clk_wiz_0_clk_ref_25 [get_bd_pins clk_wiz_0/clk_ref_25] [get_bd_pins clk_wiz_2/clk_in1]
  connect_bd_net -net clk_wiz_0_clk_ref_333 [get_bd_pins clk_wiz_0/clk_ref_333] [get_bd_pins northbridge/ref_clk]
  connect_bd_net -net clk_wiz_2_clk_spi_50 [get_bd_pins clk_wiz_2/clk_spi_50] [get_bd_pins sdcard_quad_spi_axi/ext_spi_clk]
  connect_bd_net -net cpu_0_m_axi_cpu_awatop [get_bd_pins cpu_0/m_axi_cpu_awatop] [get_bd_pins northbridge/cpu_atop_in]
  connect_bd_net -net cpu_debug_debug_req_irq [get_bd_pins cpu_debug/debug_req_irq] [get_bd_pins cpu_0/debug_req_irq]
  connect_bd_net -net cpu_debug_jtag_tdo [get_bd_pins cpu_debug/jtag_tdo] [get_bd_pins axi_jtag_0/tdo]
  connect_bd_net -net cpu_debug_m_axi_dmi_jtag_awatop [get_bd_pins cpu_debug/m_axi_dmi_jtag_awatop] [get_bd_pins northbridge/debug_module_atop]
  connect_bd_net -net cpu_debug_ndmreset [get_bd_pins cpu_debug/ndmreset] [get_bd_pins cpu_reset_gen/ext_reset_in]
  connect_bd_net -net cpu_interconnect_aresetn_1 [get_bd_pins cpu_reset_gen/interconnect_aresetn] [get_bd_pins northbridge/aresetn] [get_bd_pins axi_jtag_0/s_axi_aresetn] [get_bd_pins ps8_0_axi_periph/ARESETN] [get_bd_pins ps8_0_axi_periph/S00_ARESETN] [get_bd_pins ps8_0_axi_periph/M00_ARESETN] [get_bd_pins cpu_debug/aresetn]
  connect_bd_net -net cpu_reset_gen_peripheral_aresetn [get_bd_pins cpu_reset_gen/peripheral_aresetn] [get_bd_pins northbridge/cpu_peripheral_aresetn] [get_bd_pins axi_bootrom_control/s_axi_aresetn] [get_bd_pins axi_eth_led_gpio/s_axi_aresetn] [get_bd_pins axi_gpio_0/s_axi_aresetn] [get_bd_pins axi_uart16550_0/s_axi_aresetn] [get_bd_pins sdcard_quad_spi_axi/s_axi4_aresetn] [get_bd_pins ariane_peripherals_0/aresetn] [get_bd_pins clint_0/aresetn] [get_bd_pins cpu_0/aresetn]
  connect_bd_net -net io1_i_0_1 [get_bd_ports spi_miso] [get_bd_pins sdcard_quad_spi_axi/io1_i]
  connect_bd_net -net irqconcat_dout [get_bd_pins irqconcat/dout] [get_bd_pins ariane_peripherals_0/irq_i]
  connect_bd_net -net mig_aclk_1 [get_bd_pins clk_wiz_2/clk_core_60] [get_bd_pins northbridge/aclk] [get_bd_pins axi_bootrom_control/s_axi_aclk] [get_bd_pins axi_eth_led_gpio/s_axi_aclk] [get_bd_pins axi_gpio_0/s_axi_aclk] [get_bd_pins axi_jtag_0/s_axi_aclk] [get_bd_pins axi_uart16550_0/s_axi_aclk] [get_bd_pins cpu_reset_gen/slowest_sync_clk] [get_bd_pins ps8_0_axi_periph/ACLK] [get_bd_pins ps8_0_axi_periph/S00_ACLK] [get_bd_pins ps8_0_axi_periph/M00_ACLK] [get_bd_pins sdcard_quad_spi_axi/s_axi4_aclk] [get_bd_pins ariane_peripherals_0/aclk] [get_bd_pins clint_0/aclk] [get_bd_pins cpu_0/aclk] [get_bd_pins cpu_debug/aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk]
  connect_bd_net -net northbridge_eth_interrupt [get_bd_pins northbridge/eth_interrupt] [get_bd_pins ariane_peripherals_0/eth_irq_i]
  connect_bd_net -net northbridge_m_axi_clint_awatop [get_bd_pins northbridge/m_axi_clint_awatop] [get_bd_pins clint_0/s_axi_clint_awatop]
  connect_bd_net -net northbridge_m_axi_debug_awatop [get_bd_pins northbridge/m_axi_debug_awatop] [get_bd_pins cpu_debug/s_axi_dmi_jtag_awatop]
  connect_bd_net -net northbridge_m_axi_plic_awatop [get_bd_pins northbridge/m_axi_plic_awatop] [get_bd_pins ariane_peripherals_0/s_axi_plic_awatop]
  connect_bd_net -net northbridge_m_axi_timer_awatop [get_bd_pins northbridge/m_axi_timer_awatop] [get_bd_pins ariane_peripherals_0/s_axi_timer_awatop]
  connect_bd_net -net northbridge_mm2s_introut [get_bd_pins northbridge/mm2s_introut] [get_bd_pins irqconcat/In0]
  connect_bd_net -net northbridge_s2mm_introut [get_bd_pins northbridge/s2mm_introut] [get_bd_pins irqconcat/In1]
  connect_bd_net -net northbridge_som240_2_connector_pl_gem3_reset [get_bd_pins northbridge/som240_2_connector_pl_gem3_reset] [get_bd_ports som240_2_connector_pl_gem3_reset]
  connect_bd_net -net sdcard_quad_spi_axi_io0_o [get_bd_pins sdcard_quad_spi_axi/io0_o] [get_bd_ports spi_mosi]
  connect_bd_net -net sdcard_quad_spi_axi_ip2intc_irpt [get_bd_pins sdcard_quad_spi_axi/ip2intc_irpt] [get_bd_pins ariane_peripherals_0/spi_irq_i]
  connect_bd_net -net sdcard_quad_spi_axi_sck_o [get_bd_pins sdcard_quad_spi_axi/sck_o] [get_bd_ports spi_clk_o]
  connect_bd_net -net sdcard_quad_spi_axi_ss_o [get_bd_pins sdcard_quad_spi_axi/ss_o] [get_bd_ports spi_ss]
  connect_bd_net -net sin_0_1 [get_bd_ports uart_sin] [get_bd_pins axi_uart16550_0/sin]
  connect_bd_net -net som240_2_connector_hpb_clk0p_clk_1 [get_bd_ports som240_2_connector_hpb_clk0p_clk] [get_bd_pins clk_wiz_0/clk_in1]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins xlconcat_0/dout] [get_bd_pins bootrom_wrapper_0/addr_i]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xlconstant_0/dout] [get_bd_pins axi_uart16550_0/freeze]
  connect_bd_net -net xlconstant_1_dout [get_bd_pins xlconstant_1/dout] [get_bd_pins cpu_debug/jtag_trst_n]
  connect_bd_net -net xlconstant_2_dout [get_bd_pins xlconstant_2/dout] [get_bd_pins irqconcat/In2]
  connect_bd_net -net xlconstant_3_dout [get_bd_pins xlconstant_3/dout] [get_bd_pins irqconcat/In3]
  connect_bd_net -net zynq_ultra_ps_e_0_pl_resetn0 [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins cpu_reset_gen/aux_reset_in]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x00010000000000000000 -target_address_space [get_bd_addr_spaces cpu_0/m_axi_cpu] [get_bd_addr_segs northbridge/axi_xbar_interface_v_0/s_axi_cpu/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000000000000000 -target_address_space [get_bd_addr_spaces cpu_debug/m_axi_dmi_jtag] [get_bd_addr_segs northbridge/axi_xbar_interface_v_0/s_axi_debug/reg0] -force
  assign_bd_address -offset 0xA0000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_jtag_0/s_axi/reg0] -force
  assign_bd_address -offset 0x00010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_bootrom] [get_bd_addr_segs axi_bootrom_control/S_AXI/Mem0] -force
  assign_bd_address -offset 0x02000000 -range 0x00040000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_clint] [get_bd_addr_segs clint_0/s_axi_clint/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_debug] [get_bd_addr_segs cpu_debug/s_axi_dmi_jtag/reg0] -force
  assign_bd_address -offset 0x40C00000 -range 0x00040000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_eth] [get_bd_addr_segs northbridge/Ethernet_Subsystem/axi_ethernet_0/s_axi/Reg0] -force
  assign_bd_address -offset 0x41E00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_eth_dma] [get_bd_addr_segs northbridge/Ethernet_Subsystem/axi_eth_dma/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x40010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_eth_leds] [get_bd_addr_segs axi_eth_led_gpio/S_AXI/Reg] -force
  assign_bd_address -offset 0x40000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_gpio] [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x0C000000 -range 0x04000000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_plic] [get_bd_addr_segs ariane_peripherals_0/s_axi_plic/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x00010000000000000000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_ram] [get_bd_addr_segs northbridge/axi_riscv_amos_wrapp_0/s_axi_in/reg0] -force
  assign_bd_address -offset 0x20000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_sdcard] [get_bd_addr_segs sdcard_quad_spi_axi/aximm/MEM0] -force
  assign_bd_address -offset 0x18000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_timer] [get_bd_addr_segs ariane_peripherals_0/s_axi_timer/reg0] -force
  assign_bd_address -offset 0x10000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces northbridge/axi_xbar_interface_v_0/m_axi_uart] [get_bd_addr_segs axi_uart16550_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x80000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces northbridge/axi_riscv_amos_wrapp_0/m_axi_out] [get_bd_addr_segs northbridge/ram_offset_to_zero_0/s_axi_ram/reg0] -force
  assign_bd_address -offset 0x000800000000 -range 0x000800000000 -target_address_space [get_bd_addr_spaces northbridge/ram_offset_to_zero_0/m_axi_ram] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_HIGH] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces northbridge/ram_offset_to_zero_0/m_axi_ram] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] -force
  assign_bd_address -offset 0xFF000000 -range 0x01000000 -target_address_space [get_bd_addr_spaces northbridge/ram_offset_to_zero_0/m_axi_ram] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_LPS_OCM] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces northbridge/ram_offset_to_zero_0/m_axi_ram] [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_QSPI] -force
  assign_bd_address -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces northbridge/Ethernet_Subsystem/axi_eth_dma/Data] [get_bd_addr_segs northbridge/axi_xbar_interface_v_0/s_axi_eth_dma/reg0] -force
  assign_bd_address -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces northbridge/Ethernet_Subsystem/axi_eth_dma/Data_SG] [get_bd_addr_segs northbridge/axi_xbar_interface_v_0/s_axi_eth_dma_sg/reg0] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


