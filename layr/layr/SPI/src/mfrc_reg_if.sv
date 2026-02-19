// mfrc_reg_if – MFRC522 register-access layer on top of spi_ctrl
//
// Translates simple register read/write requests into SPI transactions
// that follow the MFRC522 SPI framing rules:
//
//   Address byte: { R/W, addr[5:0], 0 }
//     bit7 = 1 for READ, 0 for WRITE
//     bits[6:1] = 6-bit register address
//     bit0 = 0
//
//   MFRC522 SPI requires a separate CS transaction for EACH byte:
//     Write 1 byte: CS low → addr_byte + data_byte → CS high
//     Read  1 byte: CS low → addr_byte + dummy     → CS high
//
//   For multi-byte access (e.g. FIFODataReg), each byte is a separate
//   CS transaction with the address byte repeated each time.
//   This matches the Arduino library behavior.
//
// Supports burst access (req_len = 0..31 → 1..32 bytes) for registers
// like FIFODataReg, issuing one SPI transaction per byte internally.

module mfrc_reg_if (
    input wire clk,
    input wire rst,

    // ── request side ──
    input  wire         req_valid,  // pulse to submit request
    output wire         req_ready,  // high when idle, can accept
    input  wire         req_write,  // 1 = write, 0 = read
    input  wire [  5:0] req_addr,   // MFRC522 register address
    input  wire [  4:0] req_len,    // number of data bytes: 0 → 1 byte, 31 → 32 bytes
    input  wire [255:0] req_wdata,  // write payload (byte0 at [255:248])

    // ── response side ──
    output reg         resp_valid,  // 1-cycle pulse when done
    output reg [255:0] resp_rdata,  // read payload (byte0 at [255:248])
    output reg         resp_ok,     // always 1 for now

    // ── connection to spi_ctrl ──
    output reg          spi_go,
    input  wire         spi_done,
    input  wire         spi_busy,
    output reg  [  5:0] spi_w_len,
    output reg  [  5:0] spi_r_len,
    output reg  [255:0] spi_tx_data,
    input  wire [255:0] spi_rx_data
);
  // ── FSM ──
  localparam S_IDLE  = 3'd0;
  localparam S_ISSUE = 3'd1;
  localparam S_WAIT  = 3'd2;
  localparam S_NEXT  = 3'd3;  // advance to next byte in burst
  localparam S_RESP  = 3'd4;

  (* MARK_DEBUG = "TRUE" *) reg [  2:0] state;

  // Latched request fields
  reg         lat_write;
  reg [  5:0] lat_addr;
  reg [  4:0] lat_len;      // total bytes - 1 (0 = 1 byte)
  reg [255:0] lat_wdata;

  // Burst progress
  reg [  4:0] byte_idx;     // current byte index (0-based)
  reg [255:0] rd_accum;     // accumulated read data

  assign req_ready = (state == S_IDLE);

  // Build MFRC522 address byte
  // Read:  { 1, addr[5:0], 0 }
  // Write: { 0, addr[5:0], 0 }
  function [7:0] addr_byte(input wr, input [5:0] addr);
    addr_byte = {wr ? 1'b0 : 1'b1, addr, 1'b0};
  endfunction

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state       <= S_IDLE;
      lat_write   <= 1'b0;
      lat_addr    <= 6'd0;
      lat_len     <= 5'd0;
      lat_wdata   <= 256'd0;
      byte_idx    <= 5'd0;
      rd_accum    <= 256'd0;
      spi_go      <= 1'b0;
      spi_w_len   <= 6'd0;
      spi_r_len   <= 6'd0;
      spi_tx_data <= 256'd0;
      resp_valid  <= 1'b0;
      resp_rdata  <= 256'd0;
      resp_ok     <= 1'b0;
    end else begin
      // Defaults
      spi_go     <= 1'b0;
      resp_valid <= 1'b0;

      case (state)
        // ─────────────────────────────────────
        S_IDLE: begin
          if (req_valid) begin
            lat_write <= req_write;
            lat_addr  <= req_addr;
            lat_len   <= req_len;
            lat_wdata <= req_wdata;
            byte_idx  <= 5'd0;
            rd_accum  <= 256'd0;
            state     <= S_ISSUE;
          end
        end

        // Issue one 2-byte SPI transaction (addr + data/dummy) per byte
        S_ISSUE: begin
          if (lat_write) begin
            // Write: addr_byte + 1 data byte → w_len=2, r_len=0
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_tx_data[255:248] <= addr_byte(1'b1, lat_addr);
            // Extract byte[byte_idx] from lat_wdata
            spi_tx_data[247:240] <= lat_wdata[255 - byte_idx*8 -: 8];
            spi_tx_data[239:0]   <= 240'd0;
          end else begin
            // Read: addr_byte + 1 dummy → w_len=1, r_len=1
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_tx_data[255:248] <= addr_byte(1'b0, lat_addr);
            spi_tx_data[247:0]   <= 248'd0;
          end

          spi_go <= 1'b1;
          state  <= S_WAIT;
        end

        // Wait for spi_ctrl to finish this single-byte transaction
        S_WAIT: begin
          if (spi_done) begin
            state <= S_NEXT;
          end
        end

        // Capture read data and decide if more bytes needed
        S_NEXT: begin
          if (!lat_write) begin
            // Store received byte into accumulated read data
            // spi_rx_data[255:248] contains the read byte (byte0 position)
            rd_accum[255 - byte_idx*8 -: 8] <= spi_rx_data[255:248];
          end

          if (byte_idx == lat_len) begin
            // All bytes done
            state <= S_RESP;
          end else begin
            // More bytes to go
            byte_idx <= byte_idx + 5'd1;
            state    <= S_ISSUE;
          end
        end

        // Pulse resp_valid for one cycle
        S_RESP: begin
          resp_valid <= 1'b1;
          resp_ok    <= 1'b1;
          if (lat_write) begin
            resp_rdata <= 256'd0;
          end else begin
            resp_rdata <= rd_accum;
          end
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
