## HPDCache
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets SoC_i/cpu_0/inst/i_cva6_wrapper/i_ariane/i_cva6/gen_cache_hpd.i_cva6_hpdcache_subsystem/i_dcache/i_hpdcache/hpdcache_mem_req_write_arbiter_i/hpdcache_fxarb_mem_req_write_i/*]


## UART
# wired on PMOD 1
set_property -dict {PACKAGE_PIN E12 IOSTANDARD LVCMOS33} [get_ports uart_sout]
set_property -dict {PACKAGE_PIN D11 IOSTANDARD LVCMOS33} [get_ports uart_sin]


## SD-card
# SPI mode
# wired on PMOD2
set_property -dict {PACKAGE_PIN K12 IOSTANDARD LVCMOS33} [get_ports spi_clk_o]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS33} [get_ports spi_miso]
set_property -dict {PACKAGE_PIN J10 IOSTANDARD LVCMOS33} [get_ports spi_mosi]
set_property -dict {PACKAGE_PIN J11 IOSTANDARD LVCMOS33} [get_ports spi_ss]


set_output_delay -clock clk_spi_50_SoC_clk_wiz_2_0 -max 5.000 [get_ports spi_mosi]
set_output_delay -clock clk_spi_50_SoC_clk_wiz_2_0 -min -1.000 [get_ports spi_mosi]
set_output_delay -clock clk_spi_50_SoC_clk_wiz_2_0 -max 5.000 [get_ports spi_clk_o]
set_output_delay -clock clk_spi_50_SoC_clk_wiz_2_0 -min -1.000 [get_ports spi_clk_o]
set_input_delay -clock clk_spi_50_SoC_clk_wiz_2_0 -max 7.000 [get_ports spi_miso]
set_input_delay -clock clk_spi_50_SoC_clk_wiz_2_0 -min 3.000 [get_ports spi_miso]
set_false_path -to [get_ports spi_ss]
