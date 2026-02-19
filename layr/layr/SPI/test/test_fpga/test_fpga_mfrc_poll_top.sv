module test_fpga_mfrc_poll_top (
    input         clk,
    (* MARK_DEBUG = "TRUE" *) input         rst,

    (* MARK_DEBUG = "TRUE" *) output logic [3:0] led,

    // SPI bus
    (* MARK_DEBUG = "TRUE" *) output wire       sclk,
    (* MARK_DEBUG = "TRUE" *) output wire       mosi,
    (* MARK_DEBUG = "TRUE" *) input  wire       miso,
    (* MARK_DEBUG = "TRUE" *) output wire       cs1,
    (* MARK_DEBUG = "TRUE" *) output wire       cs0,
    (* MARK_DEBUG = "TRUE" *) output wire [7:0] last_read
);

  // eeprom  
  logic        eeprom_start;
  wire         eeprom_done;
  wire         eeprom_busy;
  logic        eeprom_get_key;
  wire [127:0] eeprom_buffer;

  // mfrc status outputs
  wire        mfrc_ready;         // 1 = idle/ready
  (* MARK_DEBUG = "TRUE" *) wire        mfrc_init_done;     // 1 = init complete
  (* MARK_DEBUG = "TRUE" *) wire        mfrc_card_present;  // 1 = card detected
  (* MARK_DEBUG = "TRUE" *) wire [15:0] mfrc_atqa;          // ATQA response

  // mfrc TX interface (to card)
  (* MARK_DEBUG = "TRUE" *) wire         mfrc_tx_valid;
  (* MARK_DEBUG = "TRUE" *) wire         mfrc_tx_ready;
  (* MARK_DEBUG = "TRUE" *) wire [  4:0] mfrc_tx_len;
  wire [255:0] mfrc_tx_data;
  (* MARK_DEBUG = "TRUE" *) wire [  2:0] mfrc_tx_last_bits;

  // mfrc RX interface (from card)
  (* MARK_DEBUG = "TRUE" *) wire         mfrc_rx_valid;
  (* MARK_DEBUG = "TRUE" *) wire [  4:0] mfrc_rx_len;
  wire [255:0] mfrc_rx_data;
  (* MARK_DEBUG = "TRUE" *) wire [  2:0] mfrc_rx_last_bits;


  spi_top spi_dut (
    .clk(clk),
    .rst(rst),

    .status(last_read),

    // eeprom interface
    .eeprom_start(eeprom_start),
    .eeprom_busy(eeprom_busy),
    .eeprom_done(eeprom_done),
    .eeprom_get_key(eeprom_get_key),  // get_key = 1, get_id = 0
    .eeprom_rbuffer(eeprom_buffer),

    // mfrc status outputs
    .mfrc_ready(mfrc_ready),         // 1 = idle/ready
    .mfrc_init_done(mfrc_init_done),     // 1 = init complete
    .mfrc_card_present(mfrc_card_present),  // 1 = card detected
    .mfrc_atqa(mfrc_atqa),          // ATQA response
  
    // mfrc TX interface (to card)
    .mfrc_tx_valid(mfrc_tx_valid),
    .mfrc_tx_ready(mfrc_tx_ready),
    .mfrc_tx_len(mfrc_tx_len),
    .mfrc_tx_data(mfrc_tx_data),
    .mfrc_tx_last_bits(mfrc_tx_last_bits),
  
    // mfrc RX interface (from card)
    .mfrc_rx_valid(mfrc_rx_valid),
    .mfrc_rx_len(mfrc_rx_len),
    .mfrc_rx_data(mfrc_rx_data),
    .mfrc_rx_last_bits(mfrc_rx_last_bits),

    // spi bus output
    .spi_sclk(sclk),
    .spi_mosi(mosi),
    .spi_miso(miso),
    .cs_0(cs0),  // active-low chip select – MFRC522
    .cs_1(cs1)  // active-low chip select – AT25010B
);

  // ── Heartbeat blink ──
  localparam [32:0] DELAY_CYCLES = 32'd200_000_000;
  reg [32:0] blink_ctr;

  // ── Periodic EEPROM read ──
  localparam [127:0] KEY_A = 128'h39558d1f193656ab8b4b65e25ac48474;
  localparam [127:0] ID_A  = 128'hbbe8278a67f960605adafd6f63cf7ba7;
  localparam [23:0]  EEPROM_INTERVAL = 24'd100_000;

  typedef enum logic [1:0] {
    EE_IDLE,
    EE_START,
    EE_WAIT
  } ee_state_t;

  (* MARK_DEBUG = "TRUE" *) ee_state_t ee_state;
  reg [23:0] ee_ctr;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      blink_ctr <= DELAY_CYCLES;
      led       <= 4'b0000;

      // eeprom
      eeprom_start  <= 1'b0;
      eeprom_get_key <= 1'b0;
      ee_state      <= EE_IDLE;
      ee_ctr        <= EEPROM_INTERVAL;
    end else begin
      eeprom_start <= 1'b0;  // default: pulse only one cycle

      // ── LED[1]: card detected ──
      if (mfrc_card_present)
        led[1] <= 1'b1;

      // ── LED[0]: heartbeat blink ──
      if (blink_ctr == 0) begin
        blink_ctr <= DELAY_CYCLES;
      end else begin
        blink_ctr <= blink_ctr - 1;
      end
      if (blink_ctr == DELAY_CYCLES / 2)
        led[0] <= 1'b1;

      // ── Periodic EEPROM reads (every EEPROM_INTERVAL cycles) ──
      case (ee_state)
        EE_IDLE: begin
          if (ee_ctr == 0) begin
            eeprom_get_key <= ~eeprom_get_key;  // alternate key/id
            ee_state       <= EE_START;
          end else begin
            ee_ctr <= ee_ctr - 1;
          end
        end

        EE_START: begin
          eeprom_start <= 1'b1;
          ee_state     <= EE_WAIT;
        end

        EE_WAIT: begin
          if (eeprom_done) begin
            if (eeprom_get_key == 0) begin
              // just read ID
              if (eeprom_buffer[127:0] == ID_A)
                led[2] <= 1'b1;
              else
                led[2] <= 1'b0;
            end else begin
              // just read KEY
              if (eeprom_buffer[127:0] == KEY_A)
                led[3] <= 1'b1;
              else
                led[3] <= 1'b0;
            end
            ee_ctr   <= EEPROM_INTERVAL;
            ee_state <= EE_IDLE;
          end
        end

        default: ee_state <= EE_IDLE;
      endcase
    end
  end
endmodule