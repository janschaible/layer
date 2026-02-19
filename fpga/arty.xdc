# https://github.com/Digilent/digilent-xdc/blob/master/Arty-A7-100-Master.xdc

# Clock pin
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# SPI
#set_property -dict { PACKAGE_PIN G1    IOSTANDARD LVCMOS33 } [get_ports { miso }]; #IO_L17N_T2_35 Sch=ck_miso
#set_property -dict { PACKAGE_PIN H1    IOSTANDARD LVCMOS33 } [get_ports { mosi }]; #IO_L17P_T2_35 Sch=ck_mosi
#set_property -dict { PACKAGE_PIN F1    IOSTANDARD LVCMOS33 } [get_ports { sclk }]; #IO_L18P_T2_35 Sch=ck_sck
#set_property -dict { PACKAGE_PIN C1    IOSTANDARD LVCMOS33 } [get_ports { ss }]; #IO_L16N_T2_35 Sch=ck_ss

### SPI
# pin 0 -ok
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports cs_0]
# pin 1
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports cs_1]
# pin 2
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports spi_sclk]
# pin 3
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports spi_mosi]
# pin 4
set_property -dict {PACKAGE_PIN R12 IOSTANDARD LVCMOS33} [get_ports spi_miso]

#### Other pins
# pin 5 - led ext 0
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports status_fault]
# #IO_L14P_T2_SRCC_14 Sch=ck_io[5]
# pin 6 - led ext 1
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports status_unlock]
# pin 7 - led ext 2
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports status_busy]
# pin 8  - trigger door open?
#set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { ck_io8  }]; #IO_L11P_T1_SRCC_14 Sch=ck_io[8]

## ChipKit Inner Digital Header
# set_property -dict {PACKAGE_PIN U11 IOSTANDARD LVCMOS33} [get_ports {last_read[0]}]
# set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {last_read[1]}]
# set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports {last_read[2]}]
# set_property -dict {PACKAGE_PIN R10 IOSTANDARD LVCMOS33} [get_ports {last_read[3]}]
# set_property -dict {PACKAGE_PIN R11 IOSTANDARD LVCMOS33} [get_ports {last_read[4]}]
# set_property -dict {PACKAGE_PIN R13 IOSTANDARD LVCMOS33} [get_ports {last_read[5]}]
# set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS33} [get_ports {last_read[6]}]
# set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {last_read[7]}]
#set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { ck_io35 }]; #IO_L11N_T1_SRCC_14 Sch=ck_io[35]
#set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { ck_io36 }]; #IO_L8P_T1_D11_14 Sch=ck_io[36]
#set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { ck_io37 }]; #IO_L17P_T2_A14_D30_14 Sch=ck_io[37]
#set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports { ck_io38 }]; #IO_L7N_T1_D10_14 Sch=ck_io[38]
#set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { ck_io39 }]; #IO_L7P_T1_D09_14 Sch=ck_io[39]
#set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { ck_io40 }]; #IO_L9N_T1_DQS_D13_14 Sch=ck_io[40]
#set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { ck_io41 }]; #IO_L9P_T1_DQS_14 Sch=ck_io[41]

## Switches
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS33} [get_ports rst]
#set_property -dict { PACKAGE_PIN C11   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]; #IO_L13P_T2_MRCC_16 Sch=sw[1]
#set_property -dict { PACKAGE_PIN C10   IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]; #IO_L13N_T2_MRCC_16 Sch=sw[2]
#set_property -dict { PACKAGE_PIN A10   IOSTANDARD LVCMOS33 } [get_ports { sw[3] }]; #IO_L14P_T2_SRCC_16 Sch=sw[3]

# leds
# set_property PACKAGE_PIN H5 [get_ports {led[0]}]
# set_property PACKAGE_PIN J5 [get_ports {led[1]}]
# set_property PACKAGE_PIN T9 [get_ports {led[2]}]
# set_property PACKAGE_PIN T10 [get_ports {led[3]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

# Clock constraints
create_clock -period 10.000 [get_ports clk]

# connect_debug_port u_ila_0/probe1 [get_nets [list {u_spi/p_1_in[0]} {u_spi/p_1_in[1]} {u_spi/p_1_in[2]} {u_spi/p_1_in[3]} {u_spi/p_1_in[4]} {u_spi/p_1_in[5]} {u_spi/p_1_in[6]} {u_spi/p_1_in[7]}]]


connect_debug_port u_ila_0/probe0 [get_nets [list {spi_dut/u_mfrc_top/state[0]} {spi_dut/u_mfrc_top/state[1]} {spi_dut/u_mfrc_top/state[2]} {spi_dut/u_mfrc_top/state[3]} {spi_dut/u_mfrc_top/state[4]} {spi_dut/u_mfrc_top/state[5]} {spi_dut/u_mfrc_top/state[6]}]]
connect_debug_port u_ila_0/probe1 [get_nets [list {spi_dut/u_eeprom_ctrl/u_eeprom_spi/state[0]} {spi_dut/u_eeprom_ctrl/u_eeprom_spi/state[1]} {spi_dut/u_eeprom_ctrl/u_eeprom_spi/state[2]} {spi_dut/u_eeprom_ctrl/u_eeprom_spi/state[3]} {spi_dut/u_eeprom_ctrl/u_eeprom_spi/state[4]} {spi_dut/u_eeprom_ctrl/u_eeprom_spi/state[5]}]]
connect_debug_port u_ila_0/probe2 [get_nets [list {spi_dut/u_mfrc_top/u_mfrc_reg_if/state[0]} {spi_dut/u_mfrc_top/u_mfrc_reg_if/state[1]} {spi_dut/u_mfrc_top/u_mfrc_reg_if/state[2]}]]
connect_debug_port u_ila_0/probe3 [get_nets [list {mfrc_atqa[0]} {mfrc_atqa[1]} {mfrc_atqa[2]} {mfrc_atqa[3]} {mfrc_atqa[4]} {mfrc_atqa[5]} {mfrc_atqa[6]} {mfrc_atqa[7]} {mfrc_atqa[8]} {mfrc_atqa[9]} {mfrc_atqa[10]} {mfrc_atqa[11]} {mfrc_atqa[12]} {mfrc_atqa[13]} {mfrc_atqa[14]} {mfrc_atqa[15]}]]
connect_debug_port u_ila_0/probe4 [get_nets [list {led_OBUF[0]} {led_OBUF[1]} {led_OBUF[2]} {led_OBUF[3]}]]
connect_debug_port u_ila_0/probe5 [get_nets [list {mfrc_tx_last_bits[0]} {mfrc_tx_last_bits[1]} {mfrc_tx_last_bits[2]}]]
connect_debug_port u_ila_0/probe6 [get_nets [list {spi_dut/u_eeprom_ctrl/u_eeprom_spi/lat_addr[0]} {spi_dut/u_eeprom_ctrl/u_eeprom_spi/lat_addr[1]} {spi_dut/u_eeprom_ctrl/u_eeprom_spi/lat_addr[2]} {spi_dut/u_eeprom_ctrl/u_eeprom_spi/lat_addr[3]} {spi_dut/u_eeprom_ctrl/u_eeprom_spi/lat_addr[4]} {spi_dut/u_eeprom_ctrl/u_eeprom_spi/lat_addr[5]} {spi_dut/u_eeprom_ctrl/u_eeprom_spi/lat_addr[6]}]]
connect_debug_port u_ila_0/probe7 [get_nets [list {spi_dut/u_eeprom_ctrl/state[0]} {spi_dut/u_eeprom_ctrl/state[1]} {spi_dut/u_eeprom_ctrl/state[2]} {spi_dut/u_eeprom_ctrl/state[3]} {spi_dut/u_eeprom_ctrl/state[4]} {spi_dut/u_eeprom_ctrl/state[5]}]]
connect_debug_port u_ila_0/probe9 [get_nets [list {mfrc_rx_len[0]} {mfrc_rx_len[1]} {mfrc_rx_len[2]} {mfrc_rx_len[3]} {mfrc_rx_len[4]}]]
connect_debug_port u_ila_0/probe10 [get_nets [list {mfrc_rx_last_bits[0]} {mfrc_rx_last_bits[1]} {mfrc_rx_last_bits[2]}]]
connect_debug_port u_ila_0/probe11 [get_nets [list cs0_OBUF]]
connect_debug_port u_ila_0/probe12 [get_nets [list cs1_OBUF]]
connect_debug_port u_ila_0/probe13 [get_nets [list spi_dut/u_eeprom_ctrl/u_eeprom_spi/eeprom_busy]]
connect_debug_port u_ila_0/probe14 [get_nets [list spi_dut/u_eeprom_ctrl/u_eeprom_spi/eeprom_done]]
connect_debug_port u_ila_0/probe16 [get_nets [list mfrc_init_done]]
connect_debug_port u_ila_0/probe18 [get_nets [list mfrc_tx_ready]]
connect_debug_port u_ila_0/probe20 [get_nets [list miso_IBUF]]
connect_debug_port u_ila_0/probe21 [get_nets [list mosi_OBUF]]
connect_debug_port u_ila_0/probe23 [get_nets [list sclk_OBUF]]
connect_debug_port u_ila_0/probe24 [get_nets [list spi_dut/u_eeprom_ctrl/u_eeprom_spi/spi_busy]]
connect_debug_port u_ila_0/probe25 [get_nets [list spi_dut/u_eeprom_ctrl/u_eeprom_spi/spi_done]]
connect_debug_port u_ila_0/probe26 [get_nets [list spi_dut/u_eeprom_ctrl/u_eeprom_spi/spi_start]]


connect_debug_port u_ila_0/probe9 [get_nets [list {layr/auth_i/auth_i/next_input_key[0]} {layr/auth_i/auth_i/next_input_key[1]} {layr/auth_i/auth_i/next_input_key[2]} {layr/auth_i/auth_i/next_input_key[3]} {layr/auth_i/auth_i/next_input_key[4]} {layr/auth_i/auth_i/next_input_key[5]} {layr/auth_i/auth_i/next_input_key[6]} {layr/auth_i/auth_i/next_input_key[7]} {layr/auth_i/auth_i/next_input_key[8]} {layr/auth_i/auth_i/next_input_key[9]} {layr/auth_i/auth_i/next_input_key[10]} {layr/auth_i/auth_i/next_input_key[11]} {layr/auth_i/auth_i/next_input_key[12]} {layr/auth_i/auth_i/next_input_key[13]} {layr/auth_i/auth_i/next_input_key[14]} {layr/auth_i/auth_i/next_input_key[15]} {layr/auth_i/auth_i/next_input_key[16]} {layr/auth_i/auth_i/next_input_key[17]} {layr/auth_i/auth_i/next_input_key[18]} {layr/auth_i/auth_i/next_input_key[19]} {layr/auth_i/auth_i/next_input_key[20]} {layr/auth_i/auth_i/next_input_key[21]} {layr/auth_i/auth_i/next_input_key[22]} {layr/auth_i/auth_i/next_input_key[23]} {layr/auth_i/auth_i/next_input_key[24]} {layr/auth_i/auth_i/next_input_key[25]} {layr/auth_i/auth_i/next_input_key[26]} {layr/auth_i/auth_i/next_input_key[27]} {layr/auth_i/auth_i/next_input_key[28]} {layr/auth_i/auth_i/next_input_key[29]} {layr/auth_i/auth_i/next_input_key[30]} {layr/auth_i/auth_i/next_input_key[31]} {layr/auth_i/auth_i/next_input_key[32]} {layr/auth_i/auth_i/next_input_key[33]} {layr/auth_i/auth_i/next_input_key[34]} {layr/auth_i/auth_i/next_input_key[35]} {layr/auth_i/auth_i/next_input_key[36]} {layr/auth_i/auth_i/next_input_key[37]} {layr/auth_i/auth_i/next_input_key[38]} {layr/auth_i/auth_i/next_input_key[39]} {layr/auth_i/auth_i/next_input_key[40]} {layr/auth_i/auth_i/next_input_key[41]} {layr/auth_i/auth_i/next_input_key[42]} {layr/auth_i/auth_i/next_input_key[43]} {layr/auth_i/auth_i/next_input_key[44]} {layr/auth_i/auth_i/next_input_key[45]} {layr/auth_i/auth_i/next_input_key[46]} {layr/auth_i/auth_i/next_input_key[47]} {layr/auth_i/auth_i/next_input_key[48]} {layr/auth_i/auth_i/next_input_key[49]} {layr/auth_i/auth_i/next_input_key[50]} {layr/auth_i/auth_i/next_input_key[51]} {layr/auth_i/auth_i/next_input_key[52]} {layr/auth_i/auth_i/next_input_key[53]} {layr/auth_i/auth_i/next_input_key[54]} {layr/auth_i/auth_i/next_input_key[55]} {layr/auth_i/auth_i/next_input_key[56]} {layr/auth_i/auth_i/next_input_key[57]} {layr/auth_i/auth_i/next_input_key[58]} {layr/auth_i/auth_i/next_input_key[59]} {layr/auth_i/auth_i/next_input_key[60]} {layr/auth_i/auth_i/next_input_key[61]} {layr/auth_i/auth_i/next_input_key[62]} {layr/auth_i/auth_i/next_input_key[63]} {layr/auth_i/auth_i/next_input_key[64]} {layr/auth_i/auth_i/next_input_key[65]} {layr/auth_i/auth_i/next_input_key[66]} {layr/auth_i/auth_i/next_input_key[67]} {layr/auth_i/auth_i/next_input_key[68]} {layr/auth_i/auth_i/next_input_key[69]} {layr/auth_i/auth_i/next_input_key[70]} {layr/auth_i/auth_i/next_input_key[71]} {layr/auth_i/auth_i/next_input_key[72]} {layr/auth_i/auth_i/next_input_key[73]} {layr/auth_i/auth_i/next_input_key[74]} {layr/auth_i/auth_i/next_input_key[75]} {layr/auth_i/auth_i/next_input_key[76]} {layr/auth_i/auth_i/next_input_key[77]} {layr/auth_i/auth_i/next_input_key[78]} {layr/auth_i/auth_i/next_input_key[79]} {layr/auth_i/auth_i/next_input_key[80]} {layr/auth_i/auth_i/next_input_key[81]} {layr/auth_i/auth_i/next_input_key[82]} {layr/auth_i/auth_i/next_input_key[83]} {layr/auth_i/auth_i/next_input_key[84]} {layr/auth_i/auth_i/next_input_key[85]} {layr/auth_i/auth_i/next_input_key[86]} {layr/auth_i/auth_i/next_input_key[87]} {layr/auth_i/auth_i/next_input_key[88]} {layr/auth_i/auth_i/next_input_key[89]} {layr/auth_i/auth_i/next_input_key[90]} {layr/auth_i/auth_i/next_input_key[91]} {layr/auth_i/auth_i/next_input_key[92]} {layr/auth_i/auth_i/next_input_key[93]} {layr/auth_i/auth_i/next_input_key[94]} {layr/auth_i/auth_i/next_input_key[95]} {layr/auth_i/auth_i/next_input_key[96]} {layr/auth_i/auth_i/next_input_key[97]} {layr/auth_i/auth_i/next_input_key[98]} {layr/auth_i/auth_i/next_input_key[99]} {layr/auth_i/auth_i/next_input_key[100]} {layr/auth_i/auth_i/next_input_key[101]} {layr/auth_i/auth_i/next_input_key[102]} {layr/auth_i/auth_i/next_input_key[103]} {layr/auth_i/auth_i/next_input_key[104]} {layr/auth_i/auth_i/next_input_key[105]} {layr/auth_i/auth_i/next_input_key[106]} {layr/auth_i/auth_i/next_input_key[107]} {layr/auth_i/auth_i/next_input_key[108]} {layr/auth_i/auth_i/next_input_key[109]} {layr/auth_i/auth_i/next_input_key[110]} {layr/auth_i/auth_i/next_input_key[111]} {layr/auth_i/auth_i/next_input_key[112]} {layr/auth_i/auth_i/next_input_key[113]} {layr/auth_i/auth_i/next_input_key[114]} {layr/auth_i/auth_i/next_input_key[115]} {layr/auth_i/auth_i/next_input_key[116]} {layr/auth_i/auth_i/next_input_key[117]} {layr/auth_i/auth_i/next_input_key[118]} {layr/auth_i/auth_i/next_input_key[119]} {layr/auth_i/auth_i/next_input_key[120]} {layr/auth_i/auth_i/next_input_key[121]} {layr/auth_i/auth_i/next_input_key[122]} {layr/auth_i/auth_i/next_input_key[123]} {layr/auth_i/auth_i/next_input_key[124]} {layr/auth_i/auth_i/next_input_key[125]} {layr/auth_i/auth_i/next_input_key[126]} {layr/auth_i/auth_i/next_input_key[127]}]]
connect_debug_port u_ila_0/probe11 [get_nets [list {layr/auth_i/auth_i/next_session_key[0]} {layr/auth_i/auth_i/next_session_key[1]} {layr/auth_i/auth_i/next_session_key[2]} {layr/auth_i/auth_i/next_session_key[3]} {layr/auth_i/auth_i/next_session_key[4]} {layr/auth_i/auth_i/next_session_key[5]} {layr/auth_i/auth_i/next_session_key[6]} {layr/auth_i/auth_i/next_session_key[7]} {layr/auth_i/auth_i/next_session_key[8]} {layr/auth_i/auth_i/next_session_key[9]} {layr/auth_i/auth_i/next_session_key[10]} {layr/auth_i/auth_i/next_session_key[11]} {layr/auth_i/auth_i/next_session_key[12]} {layr/auth_i/auth_i/next_session_key[13]} {layr/auth_i/auth_i/next_session_key[14]} {layr/auth_i/auth_i/next_session_key[15]} {layr/auth_i/auth_i/next_session_key[16]} {layr/auth_i/auth_i/next_session_key[17]} {layr/auth_i/auth_i/next_session_key[18]} {layr/auth_i/auth_i/next_session_key[19]} {layr/auth_i/auth_i/next_session_key[20]} {layr/auth_i/auth_i/next_session_key[21]} {layr/auth_i/auth_i/next_session_key[22]} {layr/auth_i/auth_i/next_session_key[23]} {layr/auth_i/auth_i/next_session_key[24]} {layr/auth_i/auth_i/next_session_key[25]} {layr/auth_i/auth_i/next_session_key[26]} {layr/auth_i/auth_i/next_session_key[27]} {layr/auth_i/auth_i/next_session_key[28]} {layr/auth_i/auth_i/next_session_key[29]} {layr/auth_i/auth_i/next_session_key[30]} {layr/auth_i/auth_i/next_session_key[31]} {layr/auth_i/auth_i/next_session_key[32]} {layr/auth_i/auth_i/next_session_key[33]} {layr/auth_i/auth_i/next_session_key[34]} {layr/auth_i/auth_i/next_session_key[35]} {layr/auth_i/auth_i/next_session_key[36]} {layr/auth_i/auth_i/next_session_key[37]} {layr/auth_i/auth_i/next_session_key[38]} {layr/auth_i/auth_i/next_session_key[39]} {layr/auth_i/auth_i/next_session_key[40]} {layr/auth_i/auth_i/next_session_key[41]} {layr/auth_i/auth_i/next_session_key[42]} {layr/auth_i/auth_i/next_session_key[43]} {layr/auth_i/auth_i/next_session_key[44]} {layr/auth_i/auth_i/next_session_key[45]} {layr/auth_i/auth_i/next_session_key[46]} {layr/auth_i/auth_i/next_session_key[47]} {layr/auth_i/auth_i/next_session_key[48]} {layr/auth_i/auth_i/next_session_key[49]} {layr/auth_i/auth_i/next_session_key[50]} {layr/auth_i/auth_i/next_session_key[51]} {layr/auth_i/auth_i/next_session_key[52]} {layr/auth_i/auth_i/next_session_key[53]} {layr/auth_i/auth_i/next_session_key[54]} {layr/auth_i/auth_i/next_session_key[55]} {layr/auth_i/auth_i/next_session_key[56]} {layr/auth_i/auth_i/next_session_key[57]} {layr/auth_i/auth_i/next_session_key[58]} {layr/auth_i/auth_i/next_session_key[59]} {layr/auth_i/auth_i/next_session_key[60]} {layr/auth_i/auth_i/next_session_key[61]} {layr/auth_i/auth_i/next_session_key[62]} {layr/auth_i/auth_i/next_session_key[63]} {layr/auth_i/auth_i/next_session_key[64]} {layr/auth_i/auth_i/next_session_key[65]} {layr/auth_i/auth_i/next_session_key[66]} {layr/auth_i/auth_i/next_session_key[67]} {layr/auth_i/auth_i/next_session_key[68]} {layr/auth_i/auth_i/next_session_key[69]} {layr/auth_i/auth_i/next_session_key[70]} {layr/auth_i/auth_i/next_session_key[71]} {layr/auth_i/auth_i/next_session_key[72]} {layr/auth_i/auth_i/next_session_key[73]} {layr/auth_i/auth_i/next_session_key[74]} {layr/auth_i/auth_i/next_session_key[75]} {layr/auth_i/auth_i/next_session_key[76]} {layr/auth_i/auth_i/next_session_key[77]} {layr/auth_i/auth_i/next_session_key[78]} {layr/auth_i/auth_i/next_session_key[79]} {layr/auth_i/auth_i/next_session_key[80]} {layr/auth_i/auth_i/next_session_key[81]} {layr/auth_i/auth_i/next_session_key[82]} {layr/auth_i/auth_i/next_session_key[83]} {layr/auth_i/auth_i/next_session_key[84]} {layr/auth_i/auth_i/next_session_key[85]} {layr/auth_i/auth_i/next_session_key[86]} {layr/auth_i/auth_i/next_session_key[87]} {layr/auth_i/auth_i/next_session_key[88]} {layr/auth_i/auth_i/next_session_key[89]} {layr/auth_i/auth_i/next_session_key[90]} {layr/auth_i/auth_i/next_session_key[91]} {layr/auth_i/auth_i/next_session_key[92]} {layr/auth_i/auth_i/next_session_key[93]} {layr/auth_i/auth_i/next_session_key[94]} {layr/auth_i/auth_i/next_session_key[95]} {layr/auth_i/auth_i/next_session_key[96]} {layr/auth_i/auth_i/next_session_key[97]} {layr/auth_i/auth_i/next_session_key[98]} {layr/auth_i/auth_i/next_session_key[99]} {layr/auth_i/auth_i/next_session_key[100]} {layr/auth_i/auth_i/next_session_key[101]} {layr/auth_i/auth_i/next_session_key[102]} {layr/auth_i/auth_i/next_session_key[103]} {layr/auth_i/auth_i/next_session_key[104]} {layr/auth_i/auth_i/next_session_key[105]} {layr/auth_i/auth_i/next_session_key[106]} {layr/auth_i/auth_i/next_session_key[107]} {layr/auth_i/auth_i/next_session_key[108]} {layr/auth_i/auth_i/next_session_key[109]} {layr/auth_i/auth_i/next_session_key[110]} {layr/auth_i/auth_i/next_session_key[111]} {layr/auth_i/auth_i/next_session_key[112]} {layr/auth_i/auth_i/next_session_key[113]} {layr/auth_i/auth_i/next_session_key[114]} {layr/auth_i/auth_i/next_session_key[115]} {layr/auth_i/auth_i/next_session_key[116]} {layr/auth_i/auth_i/next_session_key[117]} {layr/auth_i/auth_i/next_session_key[118]} {layr/auth_i/auth_i/next_session_key[119]} {layr/auth_i/auth_i/next_session_key[120]} {layr/auth_i/auth_i/next_session_key[121]} {layr/auth_i/auth_i/next_session_key[122]} {layr/auth_i/auth_i/next_session_key[123]} {layr/auth_i/auth_i/next_session_key[124]} {layr/auth_i/auth_i/next_session_key[125]} {layr/auth_i/auth_i/next_session_key[126]} {layr/auth_i/auth_i/next_session_key[127]}]]

connect_debug_port u_ila_0/probe3 [get_nets [list {u_spi/u_mfrc_top/state[0]} {u_spi/u_mfrc_top/state[1]} {u_spi/u_mfrc_top/state[2]} {u_spi/u_mfrc_top/state[3]} {u_spi/u_mfrc_top/state[4]} {u_spi/u_mfrc_top/state[5]} {u_spi/u_mfrc_top/state[6]}]]
connect_debug_port u_ila_0/probe4 [get_nets [list {layr/auth_i/auth_i/next_state_3[0]} {layr/auth_i/auth_i/next_state_3[1]} {layr/auth_i/auth_i/next_state_3[2]} {layr/auth_i/auth_i/next_state_3[3]} {layr/auth_i/auth_i/next_state_3[4]} {layr/auth_i/auth_i/next_state_3[5]} {layr/auth_i/auth_i/next_state_3[6]} {layr/auth_i/auth_i/next_state_3[7]} {layr/auth_i/auth_i/next_state_3[8]} {layr/auth_i/auth_i/next_state_3[9]} {layr/auth_i/auth_i/next_state_3[10]} {layr/auth_i/auth_i/next_state_3[11]} {layr/auth_i/auth_i/next_state_3[12]} {layr/auth_i/auth_i/next_state_3[13]} {layr/auth_i/auth_i/next_state_3[14]} {layr/auth_i/auth_i/next_state_3[15]} {layr/auth_i/auth_i/next_state_3[16]} {layr/auth_i/auth_i/next_state_3[17]} {layr/auth_i/auth_i/next_state_3[18]} {layr/auth_i/auth_i/next_state_3[19]} {layr/auth_i/auth_i/next_state_3[20]} {layr/auth_i/auth_i/next_state_3[21]} {layr/auth_i/auth_i/next_state_3[22]} {layr/auth_i/auth_i/next_state_3[23]} {layr/auth_i/auth_i/next_state_3[24]} {layr/auth_i/auth_i/next_state_3[25]} {layr/auth_i/auth_i/next_state_3[26]} {layr/auth_i/auth_i/next_state_3[27]} {layr/auth_i/auth_i/next_state_3[28]} {layr/auth_i/auth_i/next_state_3[29]} {layr/auth_i/auth_i/next_state_3[30]} {layr/auth_i/auth_i/next_state_3[31]}]]
connect_debug_port u_ila_0/probe8 [get_nets [list {u_spi/u_eeprom_ctrl/state[0]} {u_spi/u_eeprom_ctrl/state[1]} {u_spi/u_eeprom_ctrl/state[2]} {u_spi/u_eeprom_ctrl/state[3]} {u_spi/u_eeprom_ctrl/state[4]} {u_spi/u_eeprom_ctrl/state[5]}]]
connect_debug_port u_ila_0/probe10 [get_nets [list {layr/auth_i/auth_i/state_1[0]} {layr/auth_i/auth_i/state_1[1]} {layr/auth_i/auth_i/state_1[2]} {layr/auth_i/auth_i/state_1[3]} {layr/auth_i/auth_i/state_1[4]} {layr/auth_i/auth_i/state_1[5]} {layr/auth_i/auth_i/state_1[6]} {layr/auth_i/auth_i/state_1[7]} {layr/auth_i/auth_i/state_1[8]} {layr/auth_i/auth_i/state_1[9]} {layr/auth_i/auth_i/state_1[10]} {layr/auth_i/auth_i/state_1[11]} {layr/auth_i/auth_i/state_1[12]} {layr/auth_i/auth_i/state_1[13]} {layr/auth_i/auth_i/state_1[14]} {layr/auth_i/auth_i/state_1[15]} {layr/auth_i/auth_i/state_1[16]} {layr/auth_i/auth_i/state_1[17]} {layr/auth_i/auth_i/state_1[18]} {layr/auth_i/auth_i/state_1[19]} {layr/auth_i/auth_i/state_1[20]} {layr/auth_i/auth_i/state_1[21]} {layr/auth_i/auth_i/state_1[22]} {layr/auth_i/auth_i/state_1[23]} {layr/auth_i/auth_i/state_1[24]} {layr/auth_i/auth_i/state_1[25]} {layr/auth_i/auth_i/state_1[26]} {layr/auth_i/auth_i/state_1[27]} {layr/auth_i/auth_i/state_1[28]} {layr/auth_i/auth_i/state_1[29]} {layr/auth_i/auth_i/state_1[30]} {layr/auth_i/auth_i/state_1[31]}]]
connect_debug_port u_ila_0/probe13 [get_nets [list u_spi/u_eeprom_ctrl/u_eeprom_spi/eeprom_busy]]
connect_debug_port u_ila_0/probe15 [get_nets [list u_spi/u_eeprom_ctrl/u_eeprom_spi/spi_busy]]
connect_debug_port u_ila_0/probe16 [get_nets [list u_spi/u_eeprom_ctrl/u_eeprom_spi/spi_done]]
connect_debug_port u_ila_0/probe17 [get_nets [list u_spi/u_eeprom_ctrl/u_eeprom_spi/spi_start]]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 16384 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {layr/mux/state[0]} {layr/mux/state[1]} {layr/mux/state[2]} {layr/mux/state[3]} {layr/mux/state[4]} {layr/mux/state[5]} {layr/mux/state[6]} {layr/mux/state[7]} {layr/mux/state[8]} {layr/mux/state[9]} {layr/mux/state[10]} {layr/mux/state[11]} {layr/mux/state[12]} {layr/mux/state[13]} {layr/mux/state[14]} {layr/mux/state[15]} {layr/mux/state[16]} {layr/mux/state[17]} {layr/mux/state[18]} {layr/mux/state[19]} {layr/mux/state[20]} {layr/mux/state[21]} {layr/mux/state[22]} {layr/mux/state[23]} {layr/mux/state[24]} {layr/mux/state[25]} {layr/mux/state[26]} {layr/mux/state[27]} {layr/mux/state[28]} {layr/mux/state[29]} {layr/mux/state[30]} {layr/mux/state[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 7 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {u_spi/u_eeprom_ctrl/u_eeprom_spi/lat_addr[0]} {u_spi/u_eeprom_ctrl/u_eeprom_spi/lat_addr[1]} {u_spi/u_eeprom_ctrl/u_eeprom_spi/lat_addr[2]} {u_spi/u_eeprom_ctrl/u_eeprom_spi/lat_addr[3]} {u_spi/u_eeprom_ctrl/u_eeprom_spi/lat_addr[4]} {u_spi/u_eeprom_ctrl/u_eeprom_spi/lat_addr[5]} {u_spi/u_eeprom_ctrl/u_eeprom_spi/lat_addr[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 32 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {layr/auth_i/auth_i/next_state_4[0]} {layr/auth_i/auth_i/next_state_4[1]} {layr/auth_i/auth_i/next_state_4[2]} {layr/auth_i/auth_i/next_state_4[3]} {layr/auth_i/auth_i/next_state_4[4]} {layr/auth_i/auth_i/next_state_4[5]} {layr/auth_i/auth_i/next_state_4[6]} {layr/auth_i/auth_i/next_state_4[7]} {layr/auth_i/auth_i/next_state_4[8]} {layr/auth_i/auth_i/next_state_4[9]} {layr/auth_i/auth_i/next_state_4[10]} {layr/auth_i/auth_i/next_state_4[11]} {layr/auth_i/auth_i/next_state_4[12]} {layr/auth_i/auth_i/next_state_4[13]} {layr/auth_i/auth_i/next_state_4[14]} {layr/auth_i/auth_i/next_state_4[15]} {layr/auth_i/auth_i/next_state_4[16]} {layr/auth_i/auth_i/next_state_4[17]} {layr/auth_i/auth_i/next_state_4[18]} {layr/auth_i/auth_i/next_state_4[19]} {layr/auth_i/auth_i/next_state_4[20]} {layr/auth_i/auth_i/next_state_4[21]} {layr/auth_i/auth_i/next_state_4[22]} {layr/auth_i/auth_i/next_state_4[23]} {layr/auth_i/auth_i/next_state_4[24]} {layr/auth_i/auth_i/next_state_4[25]} {layr/auth_i/auth_i/next_state_4[26]} {layr/auth_i/auth_i/next_state_4[27]} {layr/auth_i/auth_i/next_state_4[28]} {layr/auth_i/auth_i/next_state_4[29]} {layr/auth_i/auth_i/next_state_4[30]} {layr/auth_i/auth_i/next_state_4[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 6 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {u_spi/u_eeprom_ctrl/u_eeprom_spi/state[0]} {u_spi/u_eeprom_ctrl/u_eeprom_spi/state[1]} {u_spi/u_eeprom_ctrl/u_eeprom_spi/state[2]} {u_spi/u_eeprom_ctrl/u_eeprom_spi/state[3]} {u_spi/u_eeprom_ctrl/u_eeprom_spi/state[4]} {u_spi/u_eeprom_ctrl/u_eeprom_spi/state[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {layr/mux/next_state[0]} {layr/mux/next_state[1]} {layr/mux/next_state[2]} {layr/mux/next_state[3]} {layr/mux/next_state[4]} {layr/mux/next_state[5]} {layr/mux/next_state[6]} {layr/mux/next_state[7]} {layr/mux/next_state[8]} {layr/mux/next_state[9]} {layr/mux/next_state[10]} {layr/mux/next_state[11]} {layr/mux/next_state[12]} {layr/mux/next_state[13]} {layr/mux/next_state[14]} {layr/mux/next_state[15]} {layr/mux/next_state[16]} {layr/mux/next_state[17]} {layr/mux/next_state[18]} {layr/mux/next_state[19]} {layr/mux/next_state[20]} {layr/mux/next_state[21]} {layr/mux/next_state[22]} {layr/mux/next_state[23]} {layr/mux/next_state[24]} {layr/mux/next_state[25]} {layr/mux/next_state[26]} {layr/mux/next_state[27]} {layr/mux/next_state[28]} {layr/mux/next_state[29]} {layr/mux/next_state[30]} {layr/mux/next_state[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 3 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {u_spi/u_mfrc_top/u_mfrc_reg_if/state[0]} {u_spi/u_mfrc_top/u_mfrc_reg_if/state[1]} {u_spi/u_mfrc_top/u_mfrc_reg_if/state[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {layr/controller/next_state[0]} {layr/controller/next_state[1]} {layr/controller/next_state[2]} {layr/controller/next_state[3]} {layr/controller/next_state[4]} {layr/controller/next_state[5]} {layr/controller/next_state[6]} {layr/controller/next_state[7]} {layr/controller/next_state[8]} {layr/controller/next_state[9]} {layr/controller/next_state[10]} {layr/controller/next_state[11]} {layr/controller/next_state[12]} {layr/controller/next_state[13]} {layr/controller/next_state[14]} {layr/controller/next_state[15]} {layr/controller/next_state[16]} {layr/controller/next_state[17]} {layr/controller/next_state[18]} {layr/controller/next_state[19]} {layr/controller/next_state[20]} {layr/controller/next_state[21]} {layr/controller/next_state[22]} {layr/controller/next_state[23]} {layr/controller/next_state[24]} {layr/controller/next_state[25]} {layr/controller/next_state[26]} {layr/controller/next_state[27]} {layr/controller/next_state[28]} {layr/controller/next_state[29]} {layr/controller/next_state[30]} {layr/controller/next_state[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 32 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {layr/controller/state[0]} {layr/controller/state[1]} {layr/controller/state[2]} {layr/controller/state[3]} {layr/controller/state[4]} {layr/controller/state[5]} {layr/controller/state[6]} {layr/controller/state[7]} {layr/controller/state[8]} {layr/controller/state[9]} {layr/controller/state[10]} {layr/controller/state[11]} {layr/controller/state[12]} {layr/controller/state[13]} {layr/controller/state[14]} {layr/controller/state[15]} {layr/controller/state[16]} {layr/controller/state[17]} {layr/controller/state[18]} {layr/controller/state[19]} {layr/controller/state[20]} {layr/controller/state[21]} {layr/controller/state[22]} {layr/controller/state[23]} {layr/controller/state[24]} {layr/controller/state[25]} {layr/controller/state[26]} {layr/controller/state[27]} {layr/controller/state[28]} {layr/controller/state[29]} {layr/controller/state[30]} {layr/controller/state[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 32 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {layr/auth_i/state_0[0]} {layr/auth_i/state_0[1]} {layr/auth_i/state_0[2]} {layr/auth_i/state_0[3]} {layr/auth_i/state_0[4]} {layr/auth_i/state_0[5]} {layr/auth_i/state_0[6]} {layr/auth_i/state_0[7]} {layr/auth_i/state_0[8]} {layr/auth_i/state_0[9]} {layr/auth_i/state_0[10]} {layr/auth_i/state_0[11]} {layr/auth_i/state_0[12]} {layr/auth_i/state_0[13]} {layr/auth_i/state_0[14]} {layr/auth_i/state_0[15]} {layr/auth_i/state_0[16]} {layr/auth_i/state_0[17]} {layr/auth_i/state_0[18]} {layr/auth_i/state_0[19]} {layr/auth_i/state_0[20]} {layr/auth_i/state_0[21]} {layr/auth_i/state_0[22]} {layr/auth_i/state_0[23]} {layr/auth_i/state_0[24]} {layr/auth_i/state_0[25]} {layr/auth_i/state_0[26]} {layr/auth_i/state_0[27]} {layr/auth_i/state_0[28]} {layr/auth_i/state_0[29]} {layr/auth_i/state_0[30]} {layr/auth_i/state_0[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 32 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {layr/auth_i/next_state[0]} {layr/auth_i/next_state[1]} {layr/auth_i/next_state[2]} {layr/auth_i/next_state[3]} {layr/auth_i/next_state[4]} {layr/auth_i/next_state[5]} {layr/auth_i/next_state[6]} {layr/auth_i/next_state[7]} {layr/auth_i/next_state[8]} {layr/auth_i/next_state[9]} {layr/auth_i/next_state[10]} {layr/auth_i/next_state[11]} {layr/auth_i/next_state[12]} {layr/auth_i/next_state[13]} {layr/auth_i/next_state[14]} {layr/auth_i/next_state[15]} {layr/auth_i/next_state[16]} {layr/auth_i/next_state[17]} {layr/auth_i/next_state[18]} {layr/auth_i/next_state[19]} {layr/auth_i/next_state[20]} {layr/auth_i/next_state[21]} {layr/auth_i/next_state[22]} {layr/auth_i/next_state[23]} {layr/auth_i/next_state[24]} {layr/auth_i/next_state[25]} {layr/auth_i/next_state[26]} {layr/auth_i/next_state[27]} {layr/auth_i/next_state[28]} {layr/auth_i/next_state[29]} {layr/auth_i/next_state[30]} {layr/auth_i/next_state[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 32 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {layr/auth_i/auth_i/state_2[0]} {layr/auth_i/auth_i/state_2[1]} {layr/auth_i/auth_i/state_2[2]} {layr/auth_i/auth_i/state_2[3]} {layr/auth_i/auth_i/state_2[4]} {layr/auth_i/auth_i/state_2[5]} {layr/auth_i/auth_i/state_2[6]} {layr/auth_i/auth_i/state_2[7]} {layr/auth_i/auth_i/state_2[8]} {layr/auth_i/auth_i/state_2[9]} {layr/auth_i/auth_i/state_2[10]} {layr/auth_i/auth_i/state_2[11]} {layr/auth_i/auth_i/state_2[12]} {layr/auth_i/auth_i/state_2[13]} {layr/auth_i/auth_i/state_2[14]} {layr/auth_i/auth_i/state_2[15]} {layr/auth_i/auth_i/state_2[16]} {layr/auth_i/auth_i/state_2[17]} {layr/auth_i/auth_i/state_2[18]} {layr/auth_i/auth_i/state_2[19]} {layr/auth_i/auth_i/state_2[20]} {layr/auth_i/auth_i/state_2[21]} {layr/auth_i/auth_i/state_2[22]} {layr/auth_i/auth_i/state_2[23]} {layr/auth_i/auth_i/state_2[24]} {layr/auth_i/auth_i/state_2[25]} {layr/auth_i/auth_i/state_2[26]} {layr/auth_i/auth_i/state_2[27]} {layr/auth_i/auth_i/state_2[28]} {layr/auth_i/auth_i/state_2[29]} {layr/auth_i/auth_i/state_2[30]} {layr/auth_i/auth_i/state_2[31]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_IBUF_BUFG]
