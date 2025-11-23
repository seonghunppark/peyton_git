## TopGun Lock-on System - Basys3 Constraints File
## For Xilinx Artix-7 (XC7A35T-1CPG236C)

## Clock signal (100MHz)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset button (active high)
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports reset]

## VGA Connector
set_property -dict { PACKAGE_PIN G19  IOSTANDARD LVCMOS33 } [get_ports {vga_r[0]}]
set_property -dict { PACKAGE_PIN H19  IOSTANDARD LVCMOS33 } [get_ports {vga_r[1]}]
set_property -dict { PACKAGE_PIN J19  IOSTANDARD LVCMOS33 } [get_ports {vga_r[2]}]
set_property -dict { PACKAGE_PIN N19  IOSTANDARD LVCMOS33 } [get_ports {vga_r[3]}]
set_property -dict { PACKAGE_PIN N18  IOSTANDARD LVCMOS33 } [get_ports {vga_b[0]}]
set_property -dict { PACKAGE_PIN L18  IOSTANDARD LVCMOS33 } [get_ports {vga_b[1]}]
set_property -dict { PACKAGE_PIN K18  IOSTANDARD LVCMOS33 } [get_ports {vga_b[2]}]
set_property -dict { PACKAGE_PIN J18  IOSTANDARD LVCMOS33 } [get_ports {vga_b[3]}]
set_property -dict { PACKAGE_PIN J17  IOSTANDARD LVCMOS33 } [get_ports {vga_g[0]}]
set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS33 } [get_ports {vga_g[1]}]
set_property -dict { PACKAGE_PIN G17  IOSTANDARD LVCMOS33 } [get_ports {vga_g[2]}]
set_property -dict { PACKAGE_PIN D17  IOSTANDARD LVCMOS33 } [get_ports {vga_g[3]}]
set_property -dict { PACKAGE_PIN P19  IOSTANDARD LVCMOS33 } [get_ports vga_hsync]
set_property -dict { PACKAGE_PIN R19  IOSTANDARD LVCMOS33 } [get_ports vga_vsync]

## OV7670 Camera Interface (PMOD Header JA)
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports {cam_data[0]}]
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports {cam_data[1]}]
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 } [get_ports {cam_data[2]}]
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports {cam_data[3]}]
set_property -dict { PACKAGE_PIN H1   IOSTANDARD LVCMOS33 } [get_ports {cam_data[4]}]
set_property -dict { PACKAGE_PIN K2   IOSTANDARD LVCMOS33 } [get_ports {cam_data[5]}]
set_property -dict { PACKAGE_PIN H2   IOSTANDARD LVCMOS33 } [get_ports {cam_data[6]}]
set_property -dict { PACKAGE_PIN G3   IOSTANDARD LVCMOS33 } [get_ports {cam_data[7]}]

## Camera control signals (PMOD Header JB)
set_property -dict { PACKAGE_PIN A14  IOSTANDARD LVCMOS33 } [get_ports cam_xclk]
set_property -dict { PACKAGE_PIN A16  IOSTANDARD LVCMOS33 } [get_ports cam_pclk]
set_property -dict { PACKAGE_PIN B15  IOSTANDARD LVCMOS33 } [get_ports cam_href]
set_property -dict { PACKAGE_PIN B16  IOSTANDARD LVCMOS33 } [get_ports cam_vsync]

## Mode Selection Switches
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {sw_mode[0]}]
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {sw_mode[1]}]
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports {sw_mode[2]}]
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports {sw_mode[3]}]

## Security Key Switches
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS33 } [get_ports {sw_security[0]}]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {sw_security[1]}]
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports {sw_security[2]}]
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports {sw_security[3]}]

## Threshold Adjustment (remaining switches)
set_property -dict { PACKAGE_PIN V2   IOSTANDARD LVCMOS33 } [get_ports {threshold_adj[0]}]
set_property -dict { PACKAGE_PIN T3   IOSTANDARD LVCMOS33 } [get_ports {threshold_adj[1]}]
set_property -dict { PACKAGE_PIN T2   IOSTANDARD LVCMOS33 } [get_ports {threshold_adj[2]}]
set_property -dict { PACKAGE_PIN R3   IOSTANDARD LVCMOS33 } [get_ports {threshold_adj[3]}]
set_property -dict { PACKAGE_PIN W2   IOSTANDARD LVCMOS33 } [get_ports {threshold_adj[4]}]
set_property -dict { PACKAGE_PIN U1   IOSTANDARD LVCMOS33 } [get_ports {threshold_adj[5]}]
set_property -dict { PACKAGE_PIN T1   IOSTANDARD LVCMOS33 } [get_ports {threshold_adj[6]}]
set_property -dict { PACKAGE_PIN R2   IOSTANDARD LVCMOS33 } [get_ports {threshold_adj[7]}]

## Scramble Enable Button
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports btn_scramble]

## Status LEDs
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports led_lock_on]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports led_motion]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports led_scramble]

## Target Coordinate Output (directly output for debugging via LEDs)
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {target_x_out[0]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {target_x_out[1]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {target_x_out[2]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {target_x_out[3]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {target_x_out[4]}]
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports {target_x_out[5]}]
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports {target_x_out[6]}]
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports {target_x_out[7]}]

set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports {target_y_out[0]}]
set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports {target_y_out[1]}]
set_property -dict { PACKAGE_PIN N3   IOSTANDARD LVCMOS33 } [get_ports {target_y_out[2]}]
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports {target_y_out[3]}]
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports {target_y_out[4]}]
set_property -dict { PACKAGE_PIN K3   IOSTANDARD LVCMOS33 } [get_ports {target_y_out[5]}]
set_property -dict { PACKAGE_PIN K1   IOSTANDARD LVCMOS33 } [get_ports {target_y_out[6]}]

## Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]

## Timing Constraints
set_false_path -from [get_ports reset]
set_false_path -from [get_ports sw_*]
set_false_path -from [get_ports btn_*]
set_false_path -to [get_ports led_*]
set_false_path -to [get_ports target_*]

## Camera clock domain crossing
set_max_delay -datapath_only -from [get_clocks -of_objects [get_ports cam_pclk]] -to [get_clocks sys_clk_pin] 8.0
set_max_delay -datapath_only -from [get_clocks sys_clk_pin] -to [get_clocks -of_objects [get_ports cam_pclk]] 8.0
