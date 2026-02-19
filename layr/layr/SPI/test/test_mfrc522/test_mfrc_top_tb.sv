module test_mfrc_top_tb (
    input wire clk,
    input wire rst,

    input wire eeprom_start,
    input wire eeprom_get_key,
    output wire eeprom_busy,
    output wire eeprom_done,
    output wire [127:0] eeprom_rbuffer,

    output wire        mfrc_ready,
    output wire        mfrc_init_done,
    output wire        mfrc_card_present,
    output wire [15:0] mfrc_atqa,

    input  wire         mfrc_tx_valid,
    output wire         mfrc_tx_ready,
    input  wire [  4:0] mfrc_tx_len,
    input  wire [255:0] mfrc_tx_data,
    input  wire [  2:0] mfrc_tx_last_bits,

    output wire         mfrc_rx_valid,
    output wire [  4:0] mfrc_rx_len,
    output wire [255:0] mfrc_rx_data,
    output wire [  2:0] mfrc_rx_last_bits,

    output wire spi_sclk,
    output wire spi_mosi,
    input  wire spi_miso,
    output wire cs_0,
    output wire cs_1
);

  spi_top u_dut (
      .clk(clk),
      .rst(rst),
      .eeprom_start(eeprom_start),
      .eeprom_busy(eeprom_busy),
      .eeprom_done(eeprom_done),
      .eeprom_get_key(eeprom_get_key),
      .eeprom_rbuffer(eeprom_rbuffer),
      .mfrc_ready(mfrc_ready),
      .mfrc_init_done(mfrc_init_done),
      .mfrc_card_present(mfrc_card_present),
      .mfrc_atqa(mfrc_atqa),
      .mfrc_tx_valid(mfrc_tx_valid),
      .mfrc_tx_ready(mfrc_tx_ready),
      .mfrc_tx_len(mfrc_tx_len),
      .mfrc_tx_data(mfrc_tx_data),
      .mfrc_tx_last_bits(mfrc_tx_last_bits),
      .mfrc_rx_valid(mfrc_rx_valid),
      .mfrc_rx_len(mfrc_rx_len),
      .mfrc_rx_data(mfrc_rx_data),
      .mfrc_rx_last_bits(mfrc_rx_last_bits),
      .spi_sclk(spi_sclk),
      .spi_mosi(spi_mosi),
      .spi_miso(spi_miso),
      .cs_0(cs_0),
      .cs_1(cs_1)
  );

endmodule
