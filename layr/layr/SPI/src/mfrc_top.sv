// mfrc_top – MFRC522 top-level controller
//
// Replicates the behaviour of the Arduino main.ino reference:
//   1. Auto-init: soft reset, register configuration, antenna enable
//   2. Auto-poll: periodically send REQA (0x26) to detect cards
//   3. Transceive passthrough: external TX/RX interface for PICC commands
//      (ANTICOLL, SELECT, RATS, I-Blocks are driven by the layer above)
//
// Instantiates mfrc_reg_if internally for register-level SPI access.
// Connects to spi_arb as Client B (cs_sel=0 → MFRC522 / cs0).
//
// Status outputs:
//   ready        – 1 when idle and accepting TX commands
//   init_done    – latched high after auto-init completes
//   card_present – 1 after successful REQA (ATQA received)
//   atqa         – last received ATQA (16-bit)
//
// TX interface (from higher layer to card):
//   tx_valid, tx_ready, tx_len, tx_data, tx_last_bits
//
// RX interface (from card to higher layer):
//   rx_valid, rx_len, rx_data, rx_last_bits

module mfrc_top (
    input wire clk,
    input wire rst,

    // -- status outputs --
    output reg         ready,
    output reg         init_done,
    output reg         card_present,
    output reg  [15:0] atqa,

    // -- TX interface (to card) --
    input  wire         tx_valid,
    output reg          tx_ready,
    input  wire [  4:0] tx_len,        // byte count - 1
    input  wire [255:0] tx_data,       // payload (byte 0 = [255:248])
    input  wire [  2:0] tx_last_bits,  // valid bits in last byte (0=all 8)

    // -- RX interface (from card) --
    output reg          rx_valid,
    output reg  [  4:0] rx_len,        // byte count - 1
    output reg  [255:0] rx_data,       // payload (byte 0 = [255:248])
    output reg  [  2:0] rx_last_bits,

    // -- SPI arbiter interface (directly wired to spi_arb Client B) --
    output wire         spi_go,
    input  wire         spi_done,
    input  wire         spi_busy,
    output wire [255:0] spi_tx_data,
    input  wire [255:0] spi_rx_data,
    output wire [  5:0] spi_w_len,
    output wire [  5:0] spi_r_len
);

  // ===================================================================
  // Register interface instance
  // ===================================================================
  reg          reg_req_valid;
  wire         reg_req_ready;
  reg          reg_req_write;
  reg  [  5:0] reg_req_addr;
  reg  [  4:0] reg_req_len;
  reg  [255:0] reg_req_wdata;
  wire         reg_resp_valid;
  wire [255:0] reg_resp_rdata;
  wire         reg_resp_ok;

  mfrc_reg_if u_mfrc_reg_if (
      .clk       (clk),
      .rst       (rst),
      .req_valid (reg_req_valid),
      .req_ready (reg_req_ready),
      .req_write (reg_req_write),
      .req_addr  (reg_req_addr),
      .req_len   (reg_req_len),
      .req_wdata (reg_req_wdata),
      .resp_valid(reg_resp_valid),
      .resp_rdata(reg_resp_rdata),
      .resp_ok   (reg_resp_ok),
      .spi_go    (spi_go),
      .spi_done  (spi_done),
      .spi_busy  (spi_busy),
      .spi_w_len (spi_w_len),
      .spi_r_len (spi_r_len),
      .spi_tx_data(spi_tx_data),
      .spi_rx_data(spi_rx_data)
  );

  // ===================================================================
  // MFRC522 register addresses (matching Arduino defines)
  // ===================================================================
  localparam [5:0] R_COMMAND      = 6'h01,
                   R_COM_IRQ      = 6'h04,
                   R_DIV_IRQ      = 6'h05,
                   R_ERROR        = 6'h06,
                   R_FIFO_DATA    = 6'h09,
                   R_FIFO_LEVEL   = 6'h0A,
                   R_CONTROL      = 6'h0C,
                   R_BIT_FRAMING  = 6'h0D,
                   R_COLL         = 6'h0E,
                   R_MODE         = 6'h11,
                   R_TX_MODE      = 6'h12,
                   R_RX_MODE      = 6'h13,
                   R_TX_CONTROL   = 6'h14,
                   R_TX_ASK       = 6'h15,
                   R_CRC_RESULT_H = 6'h21,
                   R_CRC_RESULT_L = 6'h22,
                   R_MOD_WIDTH    = 6'h24,
                   R_T_MODE       = 6'h2A,
                   R_T_PRESCALER  = 6'h2B,
                   R_T_RELOAD_H   = 6'h2C,
                   R_T_RELOAD_L   = 6'h2D,
                   R_VERSION      = 6'h37;

  // MFRC522 commands
  localparam [7:0] CMD_IDLE       = 8'h00,
                   CMD_CALCCRC    = 8'h03,
                   CMD_TRANSCEIVE = 8'h0C,
                   CMD_SOFTRESET  = 8'h0F;

  // ComIrqReg bit masks
  localparam [7:0] IRQ_TIMER = 8'h01,
                   IRQ_ERR   = 8'h02,
                   IRQ_IDLE  = 8'h10,
                   IRQ_RX    = 8'h20,
                   IRQ_TX    = 8'h40;

  // ===================================================================
  // Main state machine
  // ===================================================================
  //
  // States are grouped by phase:
  //   INIT_*   – auto-initialization after reset
  //   POLL_*   – auto-poll for card presence (REQA)
  //   TRX_*    – transceive passthrough for external commands

  // Transceive source tracking (replaces trx_is_poll)
  localparam [2:0] TRX_SRC_POLL     = 3'd0,
                   TRX_SRC_EXT      = 3'd1,
                   TRX_SRC_ANTICOLL = 3'd2,
                   TRX_SRC_SELECT   = 3'd3,
                   TRX_SRC_RATS     = 3'd4;

  localparam [6:0]
    // Initialization sequence (matches Arduino setup())
    S_IDLE           = 7'd0,
    S_INIT_RESET     = 7'd1,   // Write CMD_SOFTRESET to CommandReg
    S_INIT_RESET_W   = 7'd2,   // Wait for resp
    S_INIT_RESET_RD  = 7'd3,   // Read CommandReg to check reset done
    S_INIT_RESET_CHK = 7'd4,   // Check if PowerDown bit cleared
    S_INIT_REG       = 7'd5,   // Write init registers (table-driven)
    S_INIT_REG_W     = 7'd6,   // Wait for resp
    S_INIT_ANT_RD    = 7'd7,   // Read TxControlReg
    S_INIT_ANT_CHK   = 7'd8,   // Check antenna bits
    S_INIT_ANT_WR    = 7'd9,   // Write TxControlReg with antenna on
    S_INIT_ANT_W     = 7'd10,  // Wait for resp
    S_INIT_DONE      = 7'd11,  // Done

    // Polling (matches PICC_IsNewCardPresent)
    S_POLL_SETUP     = 7'd12,  // Write TxModeReg etc.
    S_POLL_SETUP_W   = 7'd13,
    S_POLL_TRX_PREP  = 7'd14,  // Prepare transceive for REQA
    S_POLL_TRX_PREP_W= 7'd15,
    S_POLL_WAIT      = 7'd16,  // Waiting for result from transceive engine

    // Transceive engine (shared by poll and external TX)
    S_TRX_IDLE_CMD   = 7'd17,  // wrReg(CommandReg, CMD_IDLE)
    S_TRX_IDLE_W     = 7'd18,
    S_TRX_CLR_IRQ    = 7'd19,  // wrReg(ComIrqReg, 0x7F)
    S_TRX_CLR_W      = 7'd20,
    S_TRX_FLUSH      = 7'd21,  // wrReg(FIFOLevelReg, 0x80)
    S_TRX_FLUSH_W    = 7'd22,
    S_TRX_FIFO_LOAD  = 7'd23,  // wrReg(FIFODataReg, byte[i])
    S_TRX_FIFO_W     = 7'd24,
    S_TRX_BITFRAME   = 7'd25,  // wrReg(BitFramingReg, validBits)
    S_TRX_BITFRAME_W = 7'd26,
    S_TRX_START_CMD  = 7'd27,  // wrReg(CommandReg, CMD_TRANSCEIVE)
    S_TRX_START_W    = 7'd28,
    S_TRX_RD_BF      = 7'd29,  // rdReg(BitFramingReg)
    S_TRX_RD_BF_W    = 7'd30,
    S_TRX_SET_START  = 7'd31,  // wrReg(BitFramingReg, bf | 0x80)
    S_TRX_SET_START_W = 7'd32,
    S_TRX_POLL_IRQ   = 7'd33,  // rdReg(ComIrqReg)
    S_TRX_POLL_IRQ_W = 7'd34,
    S_TRX_CHK_ERR    = 7'd35,  // rdReg(ErrorReg)
    S_TRX_CHK_ERR_W  = 7'd36,
    S_TRX_RD_FIFO_LEN = 7'd37, // rdReg(FIFOLevelReg)
    S_TRX_RD_FIFO_LEN_W = 7'd38,
    S_TRX_RD_FIFO    = 7'd39,  // rdReg(FIFODataReg) × N
    S_TRX_RD_FIFO_W  = 7'd40,
    S_TRX_RD_CTRL    = 7'd41,  // rdReg(ControlReg) for RxLastBits
    S_TRX_RD_CTRL_W  = 7'd42,
    S_TRX_DONE       = 7'd43,  // Signal result

    // External transceive (passthrough)
    S_EXT_ACCEPT     = 7'd44,  // Accept external TX request
    S_EXT_DONE       = 7'd45,  // Signal RX result

    // Delay between polls
    S_POLL_DELAY     = 7'd46,

    // Card activation: Anticollision (PICC_ReadCardSerial step 1)
    S_ANTICOLL_PREP  = 7'd47,  // Prepare anticoll frame (93 20)
    S_ANTICOLL_DONE  = 7'd48,  // Process anticoll result, store UID

    // Card activation: Select (PICC_ReadCardSerial step 2 – needs CRC)
    S_SELECT_CRC_PREP = 7'd49, // Build 7-byte header, start CRC

    // CRC calculation sub-FSM (mirrors Arduino calculateCRC)
    S_CRC_IDLE_CMD   = 7'd50,  // wrReg(CommandReg, CMD_IDLE)
    S_CRC_IDLE_W     = 7'd51,
    S_CRC_CLR_DIV    = 7'd52,  // wrReg(DivIrqReg, 0x04)
    S_CRC_CLR_W      = 7'd53,
    S_CRC_FLUSH      = 7'd54,  // wrReg(FIFOLevelReg, 0x80)
    S_CRC_FLUSH_W    = 7'd55,
    S_CRC_FIFO_LOAD  = 7'd56,  // wrReg(FIFODataReg, byte[i])
    S_CRC_FIFO_W     = 7'd57,
    S_CRC_START      = 7'd58,  // wrReg(CommandReg, CMD_CALCCRC)
    S_CRC_START_W    = 7'd59,
    S_CRC_POLL       = 7'd60,  // rdReg(DivIrqReg)
    S_CRC_POLL_W     = 7'd61,
    S_CRC_STOP       = 7'd62,  // wrReg(CommandReg, CMD_IDLE)
    S_CRC_STOP_W     = 7'd63,
    S_CRC_RD_L       = 7'd64,  // rdReg(CRCResultRegL)
    S_CRC_RD_L_W     = 7'd65,
    S_CRC_RD_H       = 7'd66,  // rdReg(CRCResultRegH)
    S_CRC_RD_H_W     = 7'd67,

    // Card activation: Select send
    S_SELECT_SEND    = 7'd68,  // Append CRC, start transceive
    S_SELECT_DONE    = 7'd69,  // Check SAK

    // Card activation: RATS pre-config
    S_RATS_PRE_CFG   = 7'd70,  // Table-driven register writes
    S_RATS_PRE_CFG_W = 7'd71,

    // Card activation: RATS command
    S_RATS_PREP      = 7'd72,  // Prepare RATS frame (E0 50)
    S_RATS_DONE      = 7'd73,  // Check ATS result

    // Card activation: RATS post-config
    S_RATS_POST_CFG  = 7'd74,  // Table-driven register writes
    S_RATS_POST_CFG_W= 7'd75,

    // Card fully activated
    S_CARD_READY     = 7'd76;

  (* MARK_DEBUG = "TRUE" *) reg [6:0] state;

  // ===================================================================
  // Transceive working registers
  // ===================================================================
  reg [255:0] trx_tx_data;     // data to send to card
  reg [  4:0] trx_tx_len;      // bytes - 1
  reg [  2:0] trx_tx_last_bits;// valid bits in last byte
  reg [255:0] trx_rx_data;     // data received from card
  reg [  4:0] trx_rx_len;      // bytes received - 1
  reg [  2:0] trx_rx_last_bits;
  reg         trx_ok;          // 1 = success
  reg [  2:0] trx_source;      // who invoked the transceive engine

  reg [  4:0] fifo_idx;        // FIFO byte index for load/read
  reg [  4:0] fifo_cnt;        // FIFO byte count from MFRC522

  // Card activation working registers
  reg [39:0]  uid_bcc;         // UID[0:3] + BCC from anticollision
  reg [ 7:0]  crc_result_l;    // CRC result low byte
  reg [ 7:0]  crc_result_h;    // CRC result high byte
  reg [ 7:0]  pcb_byte;        // I-Block PCB (starts 0x02, toggles bit 0)
  reg         rats_complete;   // 1 after RATS succeeds
  reg [ 4:0]  crc_byte_cnt;    // CRC: number of bytes to hash
  reg [ 4:0]  crc_byte_idx;    // CRC: current byte index
  reg [ 2:0]  rats_cfg_idx;    // RATS config table index
  reg [19:0]  crc_timeout_ctr; // CRC IRQ poll timeout

  // ===================================================================
  // Init register table
  // ===================================================================
  // Matches Arduino setup() register writes exactly:
  //   TxModeReg=0x00, RxModeReg=0x00, ModWidthReg=0x26,
  //   TModeReg=0x80, TPrescalerReg=0xA9,
  //   TReloadRegH=0x03, TReloadRegL=0xE8,
  //   TxASKReg=0x40, ModeReg=0x3D
  localparam INIT_REG_COUNT = 9;

  // Pack as {addr[5:0], data[7:0]} = 14 bits
  wire [13:0] init_table [0:INIT_REG_COUNT-1];
  assign init_table[0] = {R_TX_MODE,     8'h00};
  assign init_table[1] = {R_RX_MODE,     8'h00};
  assign init_table[2] = {R_MOD_WIDTH,   8'h26};
  assign init_table[3] = {R_T_MODE,      8'h80};
  assign init_table[4] = {R_T_PRESCALER, 8'hA9};
  assign init_table[5] = {R_T_RELOAD_H,  8'h03};
  assign init_table[6] = {R_T_RELOAD_L,  8'hE8};
  assign init_table[7] = {R_TX_ASK,      8'h40};
  assign init_table[8] = {R_MODE,        8'h3D};

  reg [3:0] init_idx;

  // ===================================================================
  // Poll setup register table
  // ===================================================================
  // Before REQA: TxModeReg=0x00, RxModeReg=0x00, ModWidthReg=0x26
  // (Matches PICC_IsNewCardPresent)
  localparam POLL_SETUP_COUNT = 4;

  wire [13:0] poll_setup_table [0:POLL_SETUP_COUNT-1];
  assign poll_setup_table[0] = {R_TX_MODE,   8'h00};
  assign poll_setup_table[1] = {R_RX_MODE,   8'h00};
  assign poll_setup_table[2] = {R_MOD_WIDTH, 8'h26};
  assign poll_setup_table[3] = {R_COLL,      8'h80};  // CollReg = 0x80

  reg [2:0] poll_setup_idx;

  // ===================================================================
  // RATS pre-config register table
  // ===================================================================
  // Before RATS: TxModeReg=0x80 (CRC on TX), RxModeReg=0x00
  localparam RATS_PRE_COUNT = 2;

  wire [13:0] rats_pre_table [0:RATS_PRE_COUNT-1];
  assign rats_pre_table[0] = {R_TX_MODE,  8'h80};  // Enable TX CRC
  assign rats_pre_table[1] = {R_RX_MODE,  8'h00};  // Disable RX CRC

  // ===================================================================
  // RATS post-config register table
  // ===================================================================
  // After RATS success: RxModeReg=0x80, BitFramingReg=0x00,
  //                     TModeReg=0x8D, TPrescalerReg=0x3E
  localparam RATS_POST_COUNT = 4;

  wire [13:0] rats_post_table [0:RATS_POST_COUNT-1];
  assign rats_post_table[0] = {R_RX_MODE,      8'h80};  // Enable RX CRC
  assign rats_post_table[1] = {R_BIT_FRAMING,  8'h00};  // Clear BitFraming
  assign rats_post_table[2] = {R_T_MODE,       8'h8D};  // Timer settings
  assign rats_post_table[3] = {R_T_PRESCALER,  8'h3E};  // Prescaler

  // ===================================================================
  // Poll delay counter
  // ===================================================================
  localparam [19:0] POLL_DELAY = 20'd50_000;  // ~500us at 100MHz
  reg [19:0] delay_ctr;

  // ===================================================================
  // IRQ polling timeout counter
  // ===================================================================
  localparam [19:0] IRQ_TIMEOUT = 20'd500_000;  // 5ms at 100MHz
  reg [19:0] irq_timeout_ctr;

  // ===================================================================
  // Soft reset wait counter
  // ===================================================================
  reg [15:0] reset_wait_ctr;

  // ===================================================================
  // Helper: write a single register byte via reg_if
  // ===================================================================
  task automatic issue_write(input [5:0] addr, input [7:0] data);
    begin
      reg_req_valid <= 1'b1;
      reg_req_write <= 1'b1;
      reg_req_addr  <= addr;
      reg_req_len   <= 5'd0;
      reg_req_wdata <= {data, 248'd0};
    end
  endtask

  // Helper: read a single register byte via reg_if
  task automatic issue_read(input [5:0] addr);
    begin
      reg_req_valid <= 1'b1;
      reg_req_write <= 1'b0;
      reg_req_addr  <= addr;
      reg_req_len   <= 5'd0;
      reg_req_wdata <= 256'd0;
    end
  endtask

  // Extracted response byte
  wire [7:0] resp_byte = reg_resp_rdata[255:248];

  // ===================================================================
  // Main FSM
  // ===================================================================
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state            <= S_IDLE;
      ready            <= 1'b0;
      init_done        <= 1'b0;
      card_present     <= 1'b0;
      atqa             <= 16'd0;
      tx_ready         <= 1'b0;
      rx_valid         <= 1'b0;
      rx_len           <= 5'd0;
      rx_data          <= 256'd0;
      rx_last_bits     <= 3'd0;

      reg_req_valid    <= 1'b0;
      reg_req_write    <= 1'b0;
      reg_req_addr     <= 6'd0;
      reg_req_len      <= 5'd0;
      reg_req_wdata    <= 256'd0;

      trx_tx_data      <= 256'd0;
      trx_tx_len       <= 5'd0;
      trx_tx_last_bits <= 3'd0;
      trx_rx_data      <= 256'd0;
      trx_rx_len       <= 5'd0;
      trx_rx_last_bits <= 3'd0;
      trx_ok           <= 1'b0;
      trx_source       <= TRX_SRC_POLL;

      fifo_idx         <= 5'd0;
      fifo_cnt         <= 5'd0;
      init_idx         <= 4'd0;
      poll_setup_idx   <= 3'd0;
      delay_ctr        <= 20'd0;
      irq_timeout_ctr  <= 20'd0;
      reset_wait_ctr   <= 16'd0;

      uid_bcc          <= 40'd0;
      crc_result_l     <= 8'd0;
      crc_result_h     <= 8'd0;
      pcb_byte         <= 8'h02;
      rats_complete    <= 1'b0;
      crc_byte_cnt     <= 5'd0;
      crc_byte_idx     <= 5'd0;
      rats_cfg_idx     <= 3'd0;
      crc_timeout_ctr  <= 20'd0;
    end else begin
      // Auto-clear pulses
      reg_req_valid <= 1'b0;
      rx_valid      <= 1'b0;

      case (state)

        // ============================================================
        // IDLE – start init on boot
        // ============================================================
        S_IDLE: begin
          state <= S_INIT_RESET;
        end

        // ============================================================
        // INIT phase: Soft Reset
        // ============================================================
        // Arduino: wrReg(CommandReg, 0x0F)
        S_INIT_RESET: begin
          if (reg_req_ready) begin
            issue_write(R_COMMAND, CMD_SOFTRESET);
            state <= S_INIT_RESET_W;
          end
        end

        S_INIT_RESET_W: begin
          if (reg_resp_valid) begin
            reset_wait_ctr <= 16'd5000;  // wait ~50us for reset
            state <= S_INIT_RESET_RD;
          end
        end

        // Arduino: while((rdReg(CommandReg) & (1<<4)) != 0)
        S_INIT_RESET_RD: begin
          if (reset_wait_ctr != 0) begin
            reset_wait_ctr <= reset_wait_ctr - 16'd1;
          end else if (reg_req_ready) begin
            issue_read(R_COMMAND);
            state <= S_INIT_RESET_CHK;
          end
        end

        S_INIT_RESET_CHK: begin
          if (reg_resp_valid) begin
            if (resp_byte[4] == 1'b0) begin
              // Reset complete, proceed to register init
              init_idx <= 4'd0;
              state    <= S_INIT_REG;
            end else begin
              // Still resetting, try again
              reset_wait_ctr <= 16'd5000;
              state <= S_INIT_RESET_RD;
            end
          end
        end

        // ============================================================
        // INIT phase: Register configuration (table-driven)
        // ============================================================
        S_INIT_REG: begin
          if (reg_req_ready) begin
            if (init_idx < INIT_REG_COUNT) begin
              issue_write(init_table[init_idx][13:8],
                         init_table[init_idx][7:0]);
              state <= S_INIT_REG_W;
            end else begin
              // All init registers written, check antenna
              state <= S_INIT_ANT_RD;
            end
          end
        end

        S_INIT_REG_W: begin
          if (reg_resp_valid) begin
            init_idx <= init_idx + 4'd1;
            state    <= S_INIT_REG;
          end
        end

        // ============================================================
        // INIT phase: Antenna enable
        // ============================================================
        // Arduino: tc = rdReg(TxControlReg); if ((tc & 0x03) != 0x03) wrReg(...)
        S_INIT_ANT_RD: begin
          if (reg_req_ready) begin
            issue_read(R_TX_CONTROL);
            state <= S_INIT_ANT_CHK;
          end
        end

        S_INIT_ANT_CHK: begin
          if (reg_resp_valid) begin
            if ((resp_byte & 8'h03) != 8'h03) begin
              // Need to enable antenna
              state <= S_INIT_ANT_WR;
            end else begin
              // Antenna already on
              state <= S_INIT_DONE;
            end
          end
        end

        S_INIT_ANT_WR: begin
          if (reg_req_ready) begin
            issue_write(R_TX_CONTROL, resp_byte | 8'h03);
            state <= S_INIT_ANT_W;
          end
        end

        S_INIT_ANT_W: begin
          if (reg_resp_valid) begin
            state <= S_INIT_DONE;
          end
        end

        // ============================================================
        // INIT complete → start polling
        // ============================================================
        S_INIT_DONE: begin
          init_done <= 1'b1;
          ready     <= 1'b1;
          tx_ready  <= 1'b1;
          poll_setup_idx <= 3'd0;
          state     <= S_POLL_SETUP;
        end

        // ============================================================
        // POLL phase: Setup registers before REQA
        // ============================================================
        // Arduino: wrReg(TxModeReg, 0x00); wrReg(RxModeReg, 0x00);
        //          wrReg(ModWidthReg, 0x26);
        S_POLL_SETUP: begin
          // Check for external TX request (higher priority)
          if (tx_valid && tx_ready) begin
            state <= S_EXT_ACCEPT;
          end else if (reg_req_ready) begin
            if (poll_setup_idx < POLL_SETUP_COUNT) begin
              issue_write(poll_setup_table[poll_setup_idx][13:8],
                         poll_setup_table[poll_setup_idx][7:0]);
              state <= S_POLL_SETUP_W;
            end else begin
              // Setup done, prepare REQA transceive
              state <= S_POLL_TRX_PREP;
            end
          end
        end

        S_POLL_SETUP_W: begin
          if (reg_resp_valid) begin
            poll_setup_idx <= poll_setup_idx + 3'd1;
            state          <= S_POLL_SETUP;
          end
        end

        // ============================================================
        // POLL: Prepare REQA transceive
        // ============================================================
        S_POLL_TRX_PREP: begin
          trx_tx_data      <= {8'h26, 248'd0};  // REQA command
          trx_tx_len       <= 5'd0;              // 1 byte
          trx_tx_last_bits <= 3'd7;              // 7-bit frame
          trx_source       <= TRX_SRC_POLL;
          trx_ok           <= 1'b0;
          fifo_idx         <= 5'd0;
          trx_rx_data      <= 256'd0;
          trx_rx_len       <= 5'd0;
          trx_rx_last_bits <= 3'd0;
          rats_complete    <= 1'b0;
          pcb_byte         <= 8'h02;
          ready            <= 1'b0;
          tx_ready         <= 1'b0;
          state            <= S_TRX_IDLE_CMD;
        end

        S_POLL_WAIT: begin
          // Return from transceive engine with REQA result
          if (trx_ok) begin
            // ATQA received (2 bytes: trx_rx_data[255:240])
            atqa <= trx_rx_data[255:240];
            // Continue to anticollision (don't signal card_present yet)
            state <= S_ANTICOLL_PREP;
          end else begin
            card_present <= 1'b0;
            ready    <= 1'b1;
            tx_ready <= 1'b1;
            delay_ctr <= POLL_DELAY;
            state     <= S_POLL_DELAY;
          end
        end

        // ============================================================
        // POLL delay between attempts
        // ============================================================
        S_POLL_DELAY: begin
          // Check for external TX request (higher priority)
          if (tx_valid && tx_ready) begin
            state <= S_EXT_ACCEPT;
          end else if (delay_ctr == 0) begin
            poll_setup_idx <= 3'd0;
            state          <= S_POLL_SETUP;
          end else begin
            delay_ctr <= delay_ctr - 20'd1;
          end
        end

        // ============================================================
        // External transceive: accept TX request
        // ============================================================
        S_EXT_ACCEPT: begin
          // I-Block framing: prepend PCB byte when RATS complete
          if (rats_complete) begin
            trx_tx_data      <= {pcb_byte, tx_data[255:8]};
            trx_tx_len       <= tx_len + 5'd1;
          end else begin
            trx_tx_data      <= tx_data;
            trx_tx_len       <= tx_len;
          end
          trx_tx_last_bits <= tx_last_bits;
          trx_source       <= TRX_SRC_EXT;
          trx_ok           <= 1'b0;
          fifo_idx         <= 5'd0;
          trx_rx_data      <= 256'd0;
          trx_rx_len       <= 5'd0;
          trx_rx_last_bits <= 3'd0;
          ready            <= 1'b0;
          tx_ready         <= 1'b0;
          state            <= S_TRX_IDLE_CMD;
        end

        S_EXT_DONE: begin
          // Signal RX result to external layer
          rx_valid <= 1'b1;
          if (rats_complete) begin
            // I-Block framing: strip PCB byte from response, toggle PCB
            rx_data      <= {trx_rx_data[247:0], 8'd0};
            rx_len       <= trx_rx_len - 5'd1;
            pcb_byte     <= pcb_byte ^ 8'h01;
          end else begin
            rx_data      <= trx_rx_data;
            rx_len       <= trx_rx_len;
          end
          rx_last_bits <= trx_rx_last_bits;
          ready        <= 1'b1;
          tx_ready     <= 1'b1;
          delay_ctr    <= POLL_DELAY;
          state        <= S_POLL_DELAY;
        end

        // ============================================================
        // TRANSCEIVE ENGINE
        // ============================================================
        // Mirrors PCD_TransceiveData() from Arduino:
        //   1. wrReg(CommandReg, CMD_IDLE)
        //   2. wrReg(ComIrqReg, 0x7F)    – clear all IRQ flags
        //   3. wrReg(FIFOLevelReg, 0x80)  – flush FIFO
        //   4. wrReg(FIFODataReg, byte_i) – load TX bytes
        //   5. wrReg(BitFramingReg, valid_bits)
        //   6. wrReg(CommandReg, CMD_TRANSCEIVE)
        //   7. rdReg(BitFramingReg) → bf
        //   8. wrReg(BitFramingReg, bf | 0x80)  – start send
        //   9. Poll rdReg(ComIrqReg) until RxIRq|IdleIRq or TimerIRq
        //  10. rdReg(ErrorReg) – check errors
        //  11. rdReg(FIFOLevelReg) – get RX byte count
        //  12. rdReg(FIFODataReg) × N – read RX bytes
        //  13. rdReg(ControlReg) – get RxLastBits

        // Step 1: wrReg(CommandReg, CMD_IDLE)
        S_TRX_IDLE_CMD: begin
          if (reg_req_ready) begin
            issue_write(R_COMMAND, CMD_IDLE);
            state <= S_TRX_IDLE_W;
          end
        end
        S_TRX_IDLE_W: begin
          if (reg_resp_valid) state <= S_TRX_CLR_IRQ;
        end

        // Step 2: wrReg(ComIrqReg, 0x7F) – clear IRQ flags
        S_TRX_CLR_IRQ: begin
          if (reg_req_ready) begin
            issue_write(R_COM_IRQ, 8'h7F);
            state <= S_TRX_CLR_W;
          end
        end
        S_TRX_CLR_W: begin
          if (reg_resp_valid) state <= S_TRX_FLUSH;
        end

        // Step 3: wrReg(FIFOLevelReg, 0x80) – flush
        S_TRX_FLUSH: begin
          if (reg_req_ready) begin
            issue_write(R_FIFO_LEVEL, 8'h80);
            state <= S_TRX_FLUSH_W;
          end
        end
        S_TRX_FLUSH_W: begin
          if (reg_resp_valid) begin
            fifo_idx <= 5'd0;
            state    <= S_TRX_FIFO_LOAD;
          end
        end

        // Step 4: wrReg(FIFODataReg, byte[i]) for each TX byte
        S_TRX_FIFO_LOAD: begin
          if (reg_req_ready) begin
            if (fifo_idx <= trx_tx_len) begin
              issue_write(R_FIFO_DATA, trx_tx_data[255 - fifo_idx*8 -: 8]);
              state <= S_TRX_FIFO_W;
            end else begin
              // All bytes loaded
              state <= S_TRX_BITFRAME;
            end
          end
        end
        S_TRX_FIFO_W: begin
          if (reg_resp_valid) begin
            fifo_idx <= fifo_idx + 5'd1;
            state    <= S_TRX_FIFO_LOAD;
          end
        end

        // Step 5: wrReg(BitFramingReg, validBits)
        // Arduino: bf = (rxAlign << 4) + validBits
        // For our usage rxAlign is always 0
        S_TRX_BITFRAME: begin
          if (reg_req_ready) begin
            issue_write(R_BIT_FRAMING, {5'b0, trx_tx_last_bits});
            state <= S_TRX_BITFRAME_W;
          end
        end
        S_TRX_BITFRAME_W: begin
          if (reg_resp_valid) state <= S_TRX_START_CMD;
        end

        // Step 6: wrReg(CommandReg, CMD_TRANSCEIVE)
        S_TRX_START_CMD: begin
          if (reg_req_ready) begin
            issue_write(R_COMMAND, CMD_TRANSCEIVE);
            state <= S_TRX_START_W;
          end
        end
        S_TRX_START_W: begin
          if (reg_resp_valid) state <= S_TRX_RD_BF;
        end

        // Step 7: rdReg(BitFramingReg)
        S_TRX_RD_BF: begin
          if (reg_req_ready) begin
            issue_read(R_BIT_FRAMING);
            state <= S_TRX_RD_BF_W;
          end
        end
        S_TRX_RD_BF_W: begin
          if (reg_resp_valid) state <= S_TRX_SET_START;
        end

        // Step 8: wrReg(BitFramingReg, bf | 0x80) – StartSend
        S_TRX_SET_START: begin
          if (reg_req_ready) begin
            issue_write(R_BIT_FRAMING, resp_byte | 8'h80);
            irq_timeout_ctr <= IRQ_TIMEOUT;
            state <= S_TRX_SET_START_W;
          end
        end
        S_TRX_SET_START_W: begin
          if (reg_resp_valid) state <= S_TRX_POLL_IRQ;
        end

        // Step 9: Poll ComIrqReg
        S_TRX_POLL_IRQ: begin
          if (reg_req_ready) begin
            if (irq_timeout_ctr == 0) begin
              // Software timeout
              trx_ok <= 1'b0;
              state  <= S_TRX_DONE;
            end else begin
              issue_read(R_COM_IRQ);
              irq_timeout_ctr <= irq_timeout_ctr - 20'd1;
              state <= S_TRX_POLL_IRQ_W;
            end
          end
        end

        S_TRX_POLL_IRQ_W: begin
          if (reg_resp_valid) begin
            // Check IRQ bits (Arduino: if (n & 0x30) break)
            if (resp_byte & (IRQ_RX | IRQ_IDLE)) begin
              // RxIRq or IdleIRq set → transceive complete
              state <= S_TRX_CHK_ERR;
            end else if (resp_byte & IRQ_TIMER) begin
              // TimerIRq → timeout, no card response
              trx_ok <= 1'b0;
              state  <= S_TRX_DONE;
            end else begin
              // Keep polling
              state <= S_TRX_POLL_IRQ;
            end
          end
        end

        // Step 10: rdReg(ErrorReg) – check for errors
        S_TRX_CHK_ERR: begin
          if (reg_req_ready) begin
            issue_read(R_ERROR);
            state <= S_TRX_CHK_ERR_W;
          end
        end
        S_TRX_CHK_ERR_W: begin
          if (reg_resp_valid) begin
            // Arduino: if (rdReg(ErrorReg) & 0x13) return 0
            if (resp_byte & 8'h13) begin
              trx_ok <= 1'b0;
              state  <= S_TRX_DONE;
            end else begin
              state <= S_TRX_RD_FIFO_LEN;
            end
          end
        end

        // Step 11: rdReg(FIFOLevelReg) – get byte count
        S_TRX_RD_FIFO_LEN: begin
          if (reg_req_ready) begin
            issue_read(R_FIFO_LEVEL);
            state <= S_TRX_RD_FIFO_LEN_W;
          end
        end
        S_TRX_RD_FIFO_LEN_W: begin
          if (reg_resp_valid) begin
            fifo_cnt <= resp_byte[4:0];
            fifo_idx <= 5'd0;
            trx_rx_data <= 256'd0;
            if (resp_byte[4:0] == 5'd0) begin
              // No data received
              trx_ok     <= 1'b0;
              trx_rx_len <= 5'd0;
              state      <= S_TRX_DONE;
            end else begin
              trx_rx_len <= resp_byte[4:0] - 5'd1;
              state      <= S_TRX_RD_FIFO;
            end
          end
        end

        // Step 12: rdReg(FIFODataReg) × N
        S_TRX_RD_FIFO: begin
          if (reg_req_ready) begin
            if (fifo_idx < fifo_cnt) begin
              issue_read(R_FIFO_DATA);
              state <= S_TRX_RD_FIFO_W;
            end else begin
              // All bytes read
              state <= S_TRX_RD_CTRL;
            end
          end
        end
        S_TRX_RD_FIFO_W: begin
          if (reg_resp_valid) begin
            trx_rx_data[255 - fifo_idx*8 -: 8] <= resp_byte;
            fifo_idx <= fifo_idx + 5'd1;
            state    <= S_TRX_RD_FIFO;
          end
        end

        // Step 13: rdReg(ControlReg) for RxLastBits
        S_TRX_RD_CTRL: begin
          if (reg_req_ready) begin
            issue_read(R_CONTROL);
            state <= S_TRX_RD_CTRL_W;
          end
        end
        S_TRX_RD_CTRL_W: begin
          if (reg_resp_valid) begin
            trx_rx_last_bits <= resp_byte[2:0];
            trx_ok           <= 1'b1;
            state            <= S_TRX_DONE;
          end
        end

        // ============================================================
        // TRANSCEIVE DONE: route result based on trx_source
        // ============================================================
        S_TRX_DONE: begin
          case (trx_source)
            TRX_SRC_POLL:     state <= S_POLL_WAIT;
            TRX_SRC_EXT:      state <= S_EXT_DONE;
            TRX_SRC_ANTICOLL: state <= S_ANTICOLL_DONE;
            TRX_SRC_SELECT:   state <= S_SELECT_DONE;
            TRX_SRC_RATS:     state <= S_RATS_DONE;
            default:          state <= S_POLL_WAIT;
          endcase
        end

        // ============================================================
        // ANTICOLLISION: send 93 20, receive UID[0:3]+BCC
        // (Arduino PICC_ReadCardSerial step 1)
        // ============================================================
        S_ANTICOLL_PREP: begin
          trx_tx_data      <= {8'h93, 8'h20, 240'd0};
          trx_tx_len       <= 5'd1;   // 2 bytes
          trx_tx_last_bits <= 3'd0;   // full bytes
          trx_source       <= TRX_SRC_ANTICOLL;
          trx_ok           <= 1'b0;
          fifo_idx         <= 5'd0;
          trx_rx_data      <= 256'd0;
          trx_rx_len       <= 5'd0;
          trx_rx_last_bits <= 3'd0;
          state            <= S_TRX_IDLE_CMD;
        end

        S_ANTICOLL_DONE: begin
          if (trx_ok && trx_rx_len >= 5'd4) begin
            // Store UID[0:3] + BCC from response
            uid_bcc <= trx_rx_data[255:216];
            state   <= S_SELECT_CRC_PREP;
          end else begin
            // Anticoll failed, back to polling
            card_present <= 1'b0;
            delay_ctr    <= POLL_DELAY;
            ready        <= 1'b1;
            tx_ready     <= 1'b1;
            state        <= S_POLL_DELAY;
          end
        end

        // ============================================================
        // SELECT: build 93 70 UID BCC CRC frame
        // (Arduino PICC_ReadCardSerial step 2)
        // ============================================================
        // First compute CRC over the 7-byte header
        S_SELECT_CRC_PREP: begin
          // Build header in trx_tx_data: [93][70][UID0][UID1][UID2][UID3][BCC][--][--]
          trx_tx_data <= {8'h93, 8'h70, uid_bcc, 200'd0};
          crc_byte_cnt <= 5'd7;
          crc_byte_idx <= 5'd0;
          state        <= S_CRC_IDLE_CMD;
        end

        // ============================================================
        // CRC CALCULATION SUB-FSM
        // (mirrors Arduino calculateCRC using MFRC522 hardware CRC)
        // Input: trx_tx_data[255:..], crc_byte_cnt bytes
        // Output: crc_result_l, crc_result_h
        // Returns to: S_SELECT_SEND
        // ============================================================

        // CRC step 1: wrReg(CommandReg, CMD_IDLE)
        S_CRC_IDLE_CMD: begin
          if (reg_req_ready) begin
            issue_write(R_COMMAND, CMD_IDLE);
            state <= S_CRC_IDLE_W;
          end
        end
        S_CRC_IDLE_W: begin
          if (reg_resp_valid) state <= S_CRC_CLR_DIV;
        end

        // CRC step 2: wrReg(DivIrqReg, 0x04) – clear CRC IRQ
        S_CRC_CLR_DIV: begin
          if (reg_req_ready) begin
            issue_write(R_DIV_IRQ, 8'h04);
            state <= S_CRC_CLR_W;
          end
        end
        S_CRC_CLR_W: begin
          if (reg_resp_valid) state <= S_CRC_FLUSH;
        end

        // CRC step 3: wrReg(FIFOLevelReg, 0x80) – flush
        S_CRC_FLUSH: begin
          if (reg_req_ready) begin
            issue_write(R_FIFO_LEVEL, 8'h80);
            state <= S_CRC_FLUSH_W;
          end
        end
        S_CRC_FLUSH_W: begin
          if (reg_resp_valid) begin
            crc_byte_idx <= 5'd0;
            state <= S_CRC_FIFO_LOAD;
          end
        end

        // CRC step 4: wrReg(FIFODataReg, byte[i]) for each byte
        S_CRC_FIFO_LOAD: begin
          if (reg_req_ready) begin
            if (crc_byte_idx < crc_byte_cnt) begin
              issue_write(R_FIFO_DATA, trx_tx_data[255 - crc_byte_idx*8 -: 8]);
              state <= S_CRC_FIFO_W;
            end else begin
              state <= S_CRC_START;
            end
          end
        end
        S_CRC_FIFO_W: begin
          if (reg_resp_valid) begin
            crc_byte_idx <= crc_byte_idx + 5'd1;
            state <= S_CRC_FIFO_LOAD;
          end
        end

        // CRC step 5: wrReg(CommandReg, CMD_CALCCRC)
        S_CRC_START: begin
          if (reg_req_ready) begin
            issue_write(R_COMMAND, CMD_CALCCRC);
            state <= S_CRC_START_W;
          end
        end
        S_CRC_START_W: begin
          if (reg_resp_valid) begin
            crc_timeout_ctr <= IRQ_TIMEOUT;
            state <= S_CRC_POLL;
          end
        end

        // CRC step 6: Poll DivIrqReg until CRCIRq (bit 2)
        S_CRC_POLL: begin
          if (reg_req_ready) begin
            if (crc_timeout_ctr == 0) begin
              // CRC timeout – fail, back to polling
              trx_ok   <= 1'b0;
              card_present <= 1'b0;
              delay_ctr <= POLL_DELAY;
              ready     <= 1'b1;
              tx_ready  <= 1'b1;
              state     <= S_POLL_DELAY;
            end else begin
              issue_read(R_DIV_IRQ);
              crc_timeout_ctr <= crc_timeout_ctr - 20'd1;
              state <= S_CRC_POLL_W;
            end
          end
        end
        S_CRC_POLL_W: begin
          if (reg_resp_valid) begin
            if (resp_byte[2]) begin
              // CRCIRq set – CRC done
              state <= S_CRC_STOP;
            end else begin
              state <= S_CRC_POLL;
            end
          end
        end

        // CRC step 7: wrReg(CommandReg, CMD_IDLE) – stop CRC
        S_CRC_STOP: begin
          if (reg_req_ready) begin
            issue_write(R_COMMAND, CMD_IDLE);
            state <= S_CRC_STOP_W;
          end
        end
        S_CRC_STOP_W: begin
          if (reg_resp_valid) state <= S_CRC_RD_L;
        end

        // CRC step 8: rdReg(CRCResultRegL)
        S_CRC_RD_L: begin
          if (reg_req_ready) begin
            issue_read(R_CRC_RESULT_L);
            state <= S_CRC_RD_L_W;
          end
        end
        S_CRC_RD_L_W: begin
          if (reg_resp_valid) begin
            crc_result_l <= resp_byte;
            state <= S_CRC_RD_H;
          end
        end

        // CRC step 9: rdReg(CRCResultRegH)
        S_CRC_RD_H: begin
          if (reg_req_ready) begin
            issue_read(R_CRC_RESULT_H);
            state <= S_CRC_RD_H_W;
          end
        end
        S_CRC_RD_H_W: begin
          if (reg_resp_valid) begin
            crc_result_h <= resp_byte;
            state <= S_SELECT_SEND;
          end
        end

        // ============================================================
        // SELECT SEND: append CRC to frame and transceive
        // ============================================================
        S_SELECT_SEND: begin
          // trx_tx_data already has [93][70][UID0-3][BCC] in bytes 0-6
          // Append CRC_L at byte 7, CRC_H at byte 8
          trx_tx_data[255 - 7*8 -: 8] <= crc_result_l;
          trx_tx_data[255 - 8*8 -: 8] <= crc_result_h;
          trx_tx_len       <= 5'd8;   // 9 bytes total
          trx_tx_last_bits <= 3'd0;
          trx_source       <= TRX_SRC_SELECT;
          trx_ok           <= 1'b0;
          fifo_idx         <= 5'd0;
          trx_rx_data      <= 256'd0;
          trx_rx_len       <= 5'd0;
          trx_rx_last_bits <= 3'd0;
          state            <= S_TRX_IDLE_CMD;
        end

        S_SELECT_DONE: begin
          if (trx_ok) begin
            // SAK received – card is selected, proceed to RATS
            rats_cfg_idx <= 3'd0;
            state        <= S_RATS_PRE_CFG;
          end else begin
            // Select failed, back to polling
            card_present <= 1'b0;
            delay_ctr    <= POLL_DELAY;
            ready        <= 1'b1;
            tx_ready     <= 1'b1;
            state        <= S_POLL_DELAY;
          end
        end

        // ============================================================
        // RATS PRE-CONFIG: TxModeReg=0x80, RxModeReg=0x00
        // (Arduino: wrReg(TxModeReg, 0x80) + doRATS pre-config)
        // ============================================================
        S_RATS_PRE_CFG: begin
          if (reg_req_ready) begin
            if (rats_cfg_idx < RATS_PRE_COUNT) begin
              issue_write(rats_pre_table[rats_cfg_idx][13:8],
                         rats_pre_table[rats_cfg_idx][7:0]);
              state <= S_RATS_PRE_CFG_W;
            end else begin
              state <= S_RATS_PREP;
            end
          end
        end
        S_RATS_PRE_CFG_W: begin
          if (reg_resp_valid) begin
            rats_cfg_idx <= rats_cfg_idx + 3'd1;
            state        <= S_RATS_PRE_CFG;
          end
        end

        // ============================================================
        // RATS: send E0 50 (RATS command)
        // MFRC522 auto-appends CRC because TxModeReg bit 7 is set
        // ============================================================
        S_RATS_PREP: begin
          trx_tx_data      <= {8'hE0, 8'h50, 240'd0};
          trx_tx_len       <= 5'd1;   // 2 bytes
          trx_tx_last_bits <= 3'd0;
          trx_source       <= TRX_SRC_RATS;
          trx_ok           <= 1'b0;
          fifo_idx         <= 5'd0;
          trx_rx_data      <= 256'd0;
          trx_rx_len       <= 5'd0;
          trx_rx_last_bits <= 3'd0;
          state            <= S_TRX_IDLE_CMD;
        end

        S_RATS_DONE: begin
          if (trx_ok) begin
            // ATS received – proceed to post-config
            rats_cfg_idx <= 3'd0;
            state        <= S_RATS_POST_CFG;
          end else begin
            // RATS failed, back to polling
            card_present <= 1'b0;
            delay_ctr    <= POLL_DELAY;
            ready        <= 1'b1;
            tx_ready     <= 1'b1;
            state        <= S_POLL_DELAY;
          end
        end

        // ============================================================
        // RATS POST-CONFIG: RxModeReg=0x80, BitFramingReg=0x00,
        //                   TModeReg=0x8D, TPrescalerReg=0x3E
        // ============================================================
        S_RATS_POST_CFG: begin
          if (reg_req_ready) begin
            if (rats_cfg_idx < RATS_POST_COUNT) begin
              issue_write(rats_post_table[rats_cfg_idx][13:8],
                         rats_post_table[rats_cfg_idx][7:0]);
              state <= S_RATS_POST_CFG_W;
            end else begin
              state <= S_CARD_READY;
            end
          end
        end
        S_RATS_POST_CFG_W: begin
          if (reg_resp_valid) begin
            rats_cfg_idx <= rats_cfg_idx + 3'd1;
            state        <= S_RATS_POST_CFG;
          end
        end

        // ============================================================
        // CARD READY: full activation complete (REQA→anticoll→select→RATS)
        // ============================================================
        S_CARD_READY: begin
          card_present  <= 1'b1;
          rats_complete <= 1'b1;
          ready         <= 1'b1;
          tx_ready      <= 1'b1;
          delay_ctr     <= POLL_DELAY;
          state         <= S_POLL_DELAY;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
