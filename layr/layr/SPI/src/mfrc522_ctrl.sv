module mfrc522_ctrl (
    input wire clk,
    input wire rst,

    output reg        ready,
    output reg        init_done,
    output reg        card_present,
    output reg [15:0] atqa,

    input  wire         tx_valid,
    output reg          tx_ready,
    input  wire [  4:0] tx_len,
    input  wire [255:0] tx_data,
    input  wire [  2:0] tx_last_bits,

    output reg          rx_valid,
    output reg  [  4:0] rx_len,
    output reg  [255:0] rx_data,
    output reg  [  2:0] rx_last_bits,

    output reg         spi_start,
    input  wire        spi_done,
    input  wire        spi_busy,
    output reg [255:0] spi_tx_data,
    input  wire [255:0] spi_rx_data,
    output reg [5:0] spi_w_len,
    output reg [5:0] spi_r_len
);

  localparam [5:0] REG_COMMAND = 6'h01;
  localparam [5:0] REG_COM_IRQ = 6'h04;
  localparam [5:0] REG_DIV_IRQ = 6'h05;
  localparam [5:0] REG_ERROR = 6'h06;
  localparam [5:0] REG_FIFO_DATA = 6'h09;
  localparam [5:0] REG_FIFO_LEVEL = 6'h0A;
  localparam [5:0] REG_CONTROL = 6'h0C;
  localparam [5:0] REG_BIT_FRAMING = 6'h0D;
  localparam [5:0] REG_COLL = 6'h0E;
  localparam [5:0] REG_MODE = 6'h11;
  localparam [5:0] REG_TX_MODE = 6'h12;
  localparam [5:0] REG_RX_MODE = 6'h13;
  localparam [5:0] REG_TX_CONTROL = 6'h14;
  localparam [5:0] REG_TX_ASK = 6'h15;
  localparam [5:0] REG_CRC_RES_H = 6'h21;
  localparam [5:0] REG_CRC_RES_L = 6'h22;
  localparam [5:0] REG_MOD_WIDTH = 6'h24;
  localparam [5:0] REG_T_MODE = 6'h2A;
  localparam [5:0] REG_T_PRESCALER = 6'h2B;
  localparam [5:0] REG_T_RELOAD_H = 6'h2C;
  localparam [5:0] REG_T_RELOAD_L = 6'h2D;
  localparam [5:0] REG_VERSION = 6'h37;

  localparam [7:0] CMD_IDLE = 8'h00;
  localparam [7:0] CMD_CALC_CRC = 8'h03;
  localparam [7:0] CMD_TRANSCEIVE = 8'h0C;
  localparam [7:0] CMD_SOFT_RESET = 8'h0F;

  localparam [5:0] INIT_WR_COUNT = 9;
  reg [3:0] init_wr_idx;

  reg [2:0] reqa_cfg_idx;
  reg [2:0] post_rats_idx;

  reg [255:0] trx_tx_buf;
  reg [5:0] trx_tx_len;
  reg [2:0] trx_tx_last_bits;
  reg [5:0] trx_tx_idx;
  reg [5:0] trx_rx_len_reg;
  reg [5:0] trx_rx_idx;
  reg [255:0] trx_rx_buf;
  reg [2:0] trx_rx_last_bits_reg;
  reg [7:0] trx_poll_count;

  reg [255:0] crc_buf;
  reg [5:0] crc_len;
  reg [5:0] crc_idx;
  reg [7:0] crc_l;
  reg [7:0] crc_h;

  reg [255:0] host_tx_buf;
  reg [5:0] host_tx_len;
  reg [2:0] host_tx_last_bits;

  reg [7:0] rd_value;
  reg [7:0] tx_control_cache;
  reg [7:0] anti_bcc;
  reg [31:0] wait_counter;

  reg [1:0] trx_begin_step;
  reg [1:0] crc_begin_step;

  localparam [7:0] WAIT_REQA_RETRY = 8'd50;
  localparam [7:0] MAX_POLL_COUNT = 8'd100;

  typedef enum logic [7:0] {
    S_BOOT_RESET_WR,
    S_BOOT_RESET_WR_WAIT,
    S_BOOT_RESET_RD,
    S_BOOT_RESET_RD_WAIT,
    S_BOOT_INIT_WR,
    S_BOOT_INIT_WR_WAIT,
    S_BOOT_TXCTRL_RD,
    S_BOOT_TXCTRL_RD_WAIT,
    S_BOOT_TXCTRL_WR,
    S_BOOT_TXCTRL_WR_WAIT,
    S_BOOT_VERSION_RD,
    S_BOOT_VERSION_RD_WAIT,

    S_REQA_CFG,
    S_REQA_CFG_WAIT,
    S_REQA_PREP,

    S_TRX_BEGIN,
    S_TRX_BEGIN_WAIT,
    S_TRX_FIFO_WR,
    S_TRX_FIFO_WR_WAIT,
    S_TRX_BF_WR,
    S_TRX_BF_WR_WAIT,
    S_TRX_CMD_WR,
    S_TRX_CMD_WR_WAIT,
    S_TRX_BF_RD,
    S_TRX_BF_RD_WAIT,
    S_TRX_BF_START_WR,
    S_TRX_BF_START_WR_WAIT,
    S_TRX_IRQ_RD,
    S_TRX_IRQ_RD_WAIT,
    S_TRX_ERR_RD,
    S_TRX_ERR_RD_WAIT,
    S_TRX_FLEVEL_RD,
    S_TRX_FLEVEL_RD_WAIT,
    S_TRX_FIFO_RD,
    S_TRX_FIFO_RD_WAIT,
    S_TRX_CTRL_RD,
    S_TRX_CTRL_RD_WAIT,
    S_TRX_OK,
    S_TRX_FAIL,

    S_ANTI_COLL_WR,
    S_ANTI_COLL_WR_WAIT,

    S_CRC_BEGIN,
    S_CRC_BEGIN_WAIT,
    S_CRC_FIFO_WR,
    S_CRC_FIFO_WR_WAIT,
    S_CRC_CMD_WR,
    S_CRC_CMD_WR_WAIT,
    S_CRC_IRQ_RD,
    S_CRC_IRQ_RD_WAIT,
    S_CRC_IDLE_WR,
    S_CRC_IDLE_WR_WAIT,
    S_CRC_RES_L_RD,
    S_CRC_RES_L_RD_WAIT,
    S_CRC_RES_H_RD,
    S_CRC_RES_H_RD_WAIT,

    S_SELECT_PREP,
    S_PRE_RATS_TXMODE_WR,
    S_PRE_RATS_TXMODE_WR_WAIT,
    S_RATS_PREP,
    S_RATS_PREP_WAIT,
    S_RATS_RXMODE_WR,
    S_RATS_RXMODE_WR_WAIT,
    S_POST_RATS_WR,
    S_POST_RATS_WR_WAIT,
    S_ACTIVE,
    S_FAIL_RETRY
  } state_t;

  state_t state;

  typedef enum logic [2:0] {
    TRX_REQA,
    TRX_ANTI,
    TRX_SELECT,
    TRX_RATS,
    TRX_HOST
  } trx_kind_t;

  trx_kind_t trx_kind;

  function automatic [255:0] set_byte (
      input [255:0] data,
      input [5:0] idx,
      input [7:0] value
  );
    reg [255:0] tmp;
    begin
      tmp = data;
      tmp[255-(idx*8)-:8] = value;
      set_byte = tmp;
    end
  endfunction

  function automatic [7:0] get_byte (
      input [255:0] data,
      input [5:0] idx
  );
    begin
      get_byte = data[255-(idx*8)-:8];
    end
  endfunction

  function automatic [255:0] pack_wr (
      input [5:0] reg_addr,
      input [7:0] reg_val
  );
    reg [255:0] tmp;
    begin
      tmp = 256'd0;
      tmp = set_byte(tmp, 6'd0, {reg_addr, 1'b0});
      tmp = set_byte(tmp, 6'd1, reg_val);
      pack_wr = tmp;
    end
  endfunction

  function automatic [255:0] pack_rd (
      input [5:0] reg_addr
  );
    reg [255:0] tmp;
    begin
      tmp = 256'd0;
      tmp = set_byte(tmp, 6'd0, (8'h80 | {reg_addr, 1'b0}));
      pack_rd = tmp;
    end
  endfunction

  function automatic [5:0] init_reg_by_idx (
      input [3:0] idx
  );
    begin
      case (idx)
        4'd0: init_reg_by_idx = REG_TX_MODE;
        4'd1: init_reg_by_idx = REG_RX_MODE;
        4'd2: init_reg_by_idx = REG_MOD_WIDTH;
        4'd3: init_reg_by_idx = REG_T_MODE;
        4'd4: init_reg_by_idx = REG_T_PRESCALER;
        4'd5: init_reg_by_idx = REG_T_RELOAD_H;
        4'd6: init_reg_by_idx = REG_T_RELOAD_L;
        4'd7: init_reg_by_idx = REG_TX_ASK;
        default: init_reg_by_idx = REG_MODE;
      endcase
    end
  endfunction

  function automatic [7:0] init_val_by_idx (
      input [3:0] idx
  );
    begin
      case (idx)
        4'd0: init_val_by_idx = 8'h00;
        4'd1: init_val_by_idx = 8'h00;
        4'd2: init_val_by_idx = 8'h26;
        4'd3: init_val_by_idx = 8'h80;
        4'd4: init_val_by_idx = 8'hA9;
        4'd5: init_val_by_idx = 8'h03;
        4'd6: init_val_by_idx = 8'hE8;
        4'd7: init_val_by_idx = 8'h40;
        default: init_val_by_idx = 8'h3D;
      endcase
    end
  endfunction

  function automatic [5:0] reqa_cfg_reg_by_idx (
      input [1:0] idx
  );
    begin
      case (idx)
        2'd0: reqa_cfg_reg_by_idx = REG_TX_MODE;
        2'd1: reqa_cfg_reg_by_idx = REG_RX_MODE;
        default: reqa_cfg_reg_by_idx = REG_MOD_WIDTH;
      endcase
    end
  endfunction

  function automatic [7:0] reqa_cfg_val_by_idx (
      input [1:0] idx
  );
    begin
      case (idx)
        2'd0: reqa_cfg_val_by_idx = 8'h00;
        2'd1: reqa_cfg_val_by_idx = 8'h00;
        default: reqa_cfg_val_by_idx = 8'h26;
      endcase
    end
  endfunction

  function automatic [5:0] post_rats_reg_by_idx (
      input [1:0] idx
  );
    begin
      case (idx)
        2'd0: post_rats_reg_by_idx = REG_RX_MODE;
        2'd1: post_rats_reg_by_idx = REG_BIT_FRAMING;
        2'd2: post_rats_reg_by_idx = REG_T_MODE;
        default: post_rats_reg_by_idx = REG_T_PRESCALER;
      endcase
    end
  endfunction

  function automatic [7:0] post_rats_val_by_idx (
      input [1:0] idx
  );
    begin
      case (idx)
        2'd0: post_rats_val_by_idx = 8'h80;
        2'd1: post_rats_val_by_idx = 8'h00;
        2'd2: post_rats_val_by_idx = 8'h8D;
        default: post_rats_val_by_idx = 8'h3E;
      endcase
    end
  endfunction

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= S_BOOT_RESET_WR;

      ready <= 1'b0;
      init_done <= 1'b0;
      card_present <= 1'b0;
      atqa <= 16'h0000;

      tx_ready <= 1'b0;
      rx_valid <= 1'b0;
      rx_len <= 5'd0;
      rx_data <= 256'd0;
      rx_last_bits <= 3'd0;

      spi_start <= 1'b0;
      spi_tx_data <= 256'd0;
      spi_w_len <= 6'd0;
      spi_r_len <= 6'd0;

      init_wr_idx <= 4'd0;
      reqa_cfg_idx <= 3'd0;
      post_rats_idx <= 3'd0;

      trx_tx_buf <= 256'd0;
      trx_tx_len <= 6'd0;
      trx_tx_last_bits <= 3'd0;
      trx_tx_idx <= 6'd0;
      trx_rx_len_reg <= 6'd0;
      trx_rx_idx <= 6'd0;
      trx_rx_buf <= 256'd0;
      trx_rx_last_bits_reg <= 3'd0;
      trx_poll_count <= 8'd0;

      crc_buf <= 256'd0;
      crc_len <= 6'd0;
      crc_idx <= 6'd0;
      crc_l <= 8'd0;
      crc_h <= 8'd0;

      host_tx_buf <= 256'd0;
      host_tx_len <= 6'd0;
      host_tx_last_bits <= 3'd0;

      rd_value <= 8'd0;
      tx_control_cache <= 8'd0;
      anti_bcc <= 8'd0;
      wait_counter <= 32'd0;

      trx_begin_step <= 2'd0;
      crc_begin_step <= 2'd0;
      trx_kind <= TRX_REQA;
    end else begin
      spi_start <= 1'b0;
      rx_valid <= 1'b0;
      tx_ready <= 1'b0;

      case (state)
        S_BOOT_RESET_WR: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(REG_COMMAND, CMD_SOFT_RESET);
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_BOOT_RESET_WR_WAIT;
          end
        end

        S_BOOT_RESET_WR_WAIT: begin
          if (spi_done) begin
            state <= S_BOOT_RESET_RD;
          end
        end

        S_BOOT_RESET_RD: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_rd(REG_COMMAND);
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_start <= 1'b1;
            state <= S_BOOT_RESET_RD_WAIT;
          end
        end

        S_BOOT_RESET_RD_WAIT: begin
          if (spi_done) begin
            rd_value <= get_byte(spi_rx_data, 6'd0);
            if ((get_byte(spi_rx_data, 6'd0) & 8'h10) == 8'h00) begin
              init_wr_idx <= 4'd0;
              state <= S_BOOT_INIT_WR;
            end else begin
              state <= S_BOOT_RESET_RD;
            end
          end
        end

        S_BOOT_INIT_WR: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(init_reg_by_idx(init_wr_idx), init_val_by_idx(init_wr_idx));
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_BOOT_INIT_WR_WAIT;
          end
        end

        S_BOOT_INIT_WR_WAIT: begin
          if (spi_done) begin
            if (init_wr_idx == (INIT_WR_COUNT - 1)) begin
              state <= S_BOOT_TXCTRL_RD;
            end else begin
              init_wr_idx <= init_wr_idx + 1'b1;
              state <= S_BOOT_INIT_WR;
            end
          end
        end

        S_BOOT_TXCTRL_RD: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_rd(REG_TX_CONTROL);
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_start <= 1'b1;
            state <= S_BOOT_TXCTRL_RD_WAIT;
          end
        end

        S_BOOT_TXCTRL_RD_WAIT: begin
          if (spi_done) begin
            tx_control_cache <= get_byte(spi_rx_data, 6'd0);
            if ((get_byte(spi_rx_data, 6'd0) & 8'h03) == 8'h03) begin
              state <= S_BOOT_VERSION_RD;
            end else begin
              state <= S_BOOT_TXCTRL_WR;
            end
          end
        end

        S_BOOT_TXCTRL_WR: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(REG_TX_CONTROL, (tx_control_cache | 8'h03));
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_BOOT_TXCTRL_WR_WAIT;
          end
        end

        S_BOOT_TXCTRL_WR_WAIT: begin
          if (spi_done) begin
            state <= S_BOOT_VERSION_RD;
          end
        end

        S_BOOT_VERSION_RD: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_rd(REG_VERSION);
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_start <= 1'b1;
            state <= S_BOOT_VERSION_RD_WAIT;
          end
        end

        S_BOOT_VERSION_RD_WAIT: begin
          if (spi_done) begin
            init_done <= 1'b1;
            card_present <= 1'b0;
            ready <= 1'b0;
            reqa_cfg_idx <= 3'd0;
            state <= S_REQA_CFG;
          end
        end

        S_REQA_CFG: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(reqa_cfg_reg_by_idx(reqa_cfg_idx[1:0]), reqa_cfg_val_by_idx(reqa_cfg_idx[1:0]));
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_REQA_CFG_WAIT;
          end
        end

        S_REQA_CFG_WAIT: begin
          if (spi_done) begin
            if (reqa_cfg_idx == 3'd2) begin
              state <= S_REQA_PREP;
            end else begin
              reqa_cfg_idx <= reqa_cfg_idx + 1'b1;
              state <= S_REQA_CFG;
            end
          end
        end

        S_REQA_PREP: begin
          trx_kind <= TRX_REQA;
          trx_tx_buf <= set_byte(256'd0, 6'd0, 8'h26);
          trx_tx_len <= 6'd1;
          trx_tx_last_bits <= 3'd7;
          state <= S_TRX_BEGIN;
        end

        S_TRX_BEGIN: begin
          if (!spi_busy) begin
            if (trx_begin_step == 2'd0) begin
              spi_tx_data <= pack_wr(REG_COMMAND, CMD_IDLE);
            end else if (trx_begin_step == 2'd1) begin
              spi_tx_data <= pack_wr(REG_COM_IRQ, 8'h7F);
            end else begin
              spi_tx_data <= pack_wr(REG_FIFO_LEVEL, 8'h80);
            end
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_TRX_BEGIN_WAIT;
          end
        end

        S_TRX_BEGIN_WAIT: begin
          if (spi_done) begin
            if (trx_begin_step == 2'd2) begin
              trx_begin_step <= 2'd0;
              trx_tx_idx <= 6'd0;
              state <= S_TRX_FIFO_WR;
            end else begin
              trx_begin_step <= trx_begin_step + 1'b1;
              state <= S_TRX_BEGIN;
            end
          end
        end

        S_TRX_FIFO_WR: begin
          if (trx_tx_idx < trx_tx_len) begin
            if (!spi_busy) begin
              spi_tx_data <= pack_wr(REG_FIFO_DATA, get_byte(trx_tx_buf, trx_tx_idx));
              spi_w_len <= 6'd2;
              spi_r_len <= 6'd0;
              spi_start <= 1'b1;
              state <= S_TRX_FIFO_WR_WAIT;
            end
          end else begin
            state <= S_TRX_BF_WR;
          end
        end

        S_TRX_FIFO_WR_WAIT: begin
          if (spi_done) begin
            trx_tx_idx <= trx_tx_idx + 1'b1;
            state <= S_TRX_FIFO_WR;
          end
        end

        S_TRX_BF_WR: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(REG_BIT_FRAMING, {5'd0, trx_tx_last_bits});
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_TRX_BF_WR_WAIT;
          end
        end

        S_TRX_BF_WR_WAIT: begin
          if (spi_done) begin
            state <= S_TRX_CMD_WR;
          end
        end

        S_TRX_CMD_WR: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(REG_COMMAND, CMD_TRANSCEIVE);
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_TRX_CMD_WR_WAIT;
          end
        end

        S_TRX_CMD_WR_WAIT: begin
          if (spi_done) begin
            state <= S_TRX_BF_RD;
          end
        end

        S_TRX_BF_RD: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_rd(REG_BIT_FRAMING);
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_start <= 1'b1;
            state <= S_TRX_BF_RD_WAIT;
          end
        end

        S_TRX_BF_RD_WAIT: begin
          if (spi_done) begin
            rd_value <= get_byte(spi_rx_data, 6'd0);
            state <= S_TRX_BF_START_WR;
          end
        end

        S_TRX_BF_START_WR: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(REG_BIT_FRAMING, (rd_value | 8'h80));
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_TRX_BF_START_WR_WAIT;
          end
        end

        S_TRX_BF_START_WR_WAIT: begin
          if (spi_done) begin
            trx_poll_count <= 8'd0;
            state <= S_TRX_IRQ_RD;
          end
        end

        S_TRX_IRQ_RD: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_rd(REG_COM_IRQ);
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_start <= 1'b1;
            state <= S_TRX_IRQ_RD_WAIT;
          end
        end

        S_TRX_IRQ_RD_WAIT: begin
          if (spi_done) begin
            rd_value <= get_byte(spi_rx_data, 6'd0);
            if (get_byte(spi_rx_data, 6'd0) & 8'h30) begin
              state <= S_TRX_ERR_RD;
            end else if (get_byte(spi_rx_data, 6'd0) & 8'h01) begin
              state <= S_TRX_FAIL;
            end else if (trx_poll_count >= MAX_POLL_COUNT) begin
              state <= S_TRX_FAIL;
            end else begin
              trx_poll_count <= trx_poll_count + 1'b1;
              state <= S_TRX_IRQ_RD;
            end
          end
        end

        S_TRX_ERR_RD: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_rd(REG_ERROR);
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_start <= 1'b1;
            state <= S_TRX_ERR_RD_WAIT;
          end
        end

        S_TRX_ERR_RD_WAIT: begin
          if (spi_done) begin
            if (get_byte(spi_rx_data, 6'd0) & 8'h13) begin
              state <= S_TRX_FAIL;
            end else begin
              state <= S_TRX_FLEVEL_RD;
            end
          end
        end

        S_TRX_FLEVEL_RD: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_rd(REG_FIFO_LEVEL);
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_start <= 1'b1;
            state <= S_TRX_FLEVEL_RD_WAIT;
          end
        end

        S_TRX_FLEVEL_RD_WAIT: begin
          if (spi_done) begin
            trx_rx_len_reg <= get_byte(spi_rx_data, 6'd0);
            trx_rx_idx <= 6'd0;
            trx_rx_buf <= 256'd0;
            state <= S_TRX_FIFO_RD;
          end
        end

        S_TRX_FIFO_RD: begin
          if (trx_rx_idx < trx_rx_len_reg && trx_rx_idx < 6'd32) begin
            if (!spi_busy) begin
              spi_tx_data <= pack_rd(REG_FIFO_DATA);
              spi_w_len <= 6'd1;
              spi_r_len <= 6'd1;
              spi_start <= 1'b1;
              state <= S_TRX_FIFO_RD_WAIT;
            end
          end else begin
            state <= S_TRX_CTRL_RD;
          end
        end

        S_TRX_FIFO_RD_WAIT: begin
          if (spi_done) begin
            trx_rx_buf <= set_byte(trx_rx_buf, trx_rx_idx, get_byte(spi_rx_data, 6'd0));
            trx_rx_idx <= trx_rx_idx + 1'b1;
            state <= S_TRX_FIFO_RD;
          end
        end

        S_TRX_CTRL_RD: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_rd(REG_CONTROL);
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_start <= 1'b1;
            state <= S_TRX_CTRL_RD_WAIT;
          end
        end

        S_TRX_CTRL_RD_WAIT: begin
          if (spi_done) begin
            trx_rx_last_bits_reg <= (get_byte(spi_rx_data, 6'd0) & 8'h07);
            state <= S_TRX_OK;
          end
        end

        S_TRX_OK: begin
          case (trx_kind)
            TRX_REQA: begin
              if (trx_rx_len_reg >= 6'd2) begin
                atqa <= {get_byte(trx_rx_buf, 6'd0), get_byte(trx_rx_buf, 6'd1)};
                card_present <= 1'b1;
                state <= S_ANTI_COLL_WR;
              end else begin
                state <= S_TRX_FAIL;
              end
            end
            TRX_ANTI: begin
              if (trx_rx_len_reg == 6'd5) begin
                anti_bcc <= get_byte(trx_rx_buf, 6'd4);
                state <= S_SELECT_PREP;
              end else begin
                state <= S_TRX_FAIL;
              end
            end
            TRX_SELECT: begin
              if (trx_rx_len_reg >= 6'd1) begin
                state <= S_PRE_RATS_TXMODE_WR;
              end else begin
                state <= S_TRX_FAIL;
              end
            end
            TRX_RATS: begin
              if (trx_rx_len_reg >= 6'd1) begin
                post_rats_idx <= 3'd0;
                state <= S_POST_RATS_WR;
              end else begin
                state <= S_TRX_FAIL;
              end
            end
            default: begin
              rx_data <= trx_rx_buf;
              rx_len <= trx_rx_len_reg[4:0];
              rx_last_bits <= trx_rx_last_bits_reg;
              rx_valid <= 1'b1;
              state <= S_ACTIVE;
            end
          endcase
        end

        S_TRX_FAIL: begin
          if (trx_kind == TRX_HOST) begin
            rx_data <= 256'd0;
            rx_len <= 5'd0;
            rx_last_bits <= 3'd0;
            rx_valid <= 1'b1;
            state <= S_ACTIVE;
          end else begin
            card_present <= 1'b0;
            ready <= 1'b0;
            wait_counter <= 32'd0;
            state <= S_FAIL_RETRY;
          end
        end

        S_ANTI_COLL_WR: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(REG_COLL, 8'h80);
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_ANTI_COLL_WR_WAIT;
          end
        end

        S_ANTI_COLL_WR_WAIT: begin
          if (spi_done) begin
            trx_kind <= TRX_ANTI;
            trx_tx_buf <= set_byte(set_byte(256'd0, 6'd0, 8'h93), 6'd1, 8'h20);
            trx_tx_len <= 6'd2;
            trx_tx_last_bits <= 3'd0;
            state <= S_TRX_BEGIN;
          end
        end

        S_SELECT_PREP: begin
          crc_buf <= set_byte(
              set_byte(
                  set_byte(
                      set_byte(
                          set_byte(
                              set_byte(
                                  set_byte(256'd0, 6'd0, 8'h93),
                                  6'd1,
                                  8'h70
                              ),
                              6'd2,
                              get_byte(trx_rx_buf, 6'd0)
                          ),
                          6'd3,
                          get_byte(trx_rx_buf, 6'd1)
                      ),
                      6'd4,
                      get_byte(trx_rx_buf, 6'd2)
                  ),
                  6'd5,
                  get_byte(trx_rx_buf, 6'd3)
              ),
              6'd6,
              anti_bcc
          );
          crc_len <= 6'd7;
          state <= S_CRC_BEGIN;
        end

        S_CRC_BEGIN: begin
          if (!spi_busy) begin
            if (crc_begin_step == 2'd0) begin
              spi_tx_data <= pack_wr(REG_COMMAND, CMD_IDLE);
            end else if (crc_begin_step == 2'd1) begin
              spi_tx_data <= pack_wr(REG_DIV_IRQ, 8'h04);
            end else begin
              spi_tx_data <= pack_wr(REG_FIFO_LEVEL, 8'h80);
            end
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_CRC_BEGIN_WAIT;
          end
        end

        S_CRC_BEGIN_WAIT: begin
          if (spi_done) begin
            if (crc_begin_step == 2'd2) begin
              crc_begin_step <= 2'd0;
              crc_idx <= 6'd0;
              state <= S_CRC_FIFO_WR;
            end else begin
              crc_begin_step <= crc_begin_step + 1'b1;
              state <= S_CRC_BEGIN;
            end
          end
        end

        S_CRC_FIFO_WR: begin
          if (crc_idx < crc_len) begin
            if (!spi_busy) begin
              spi_tx_data <= pack_wr(REG_FIFO_DATA, get_byte(crc_buf, crc_idx));
              spi_w_len <= 6'd2;
              spi_r_len <= 6'd0;
              spi_start <= 1'b1;
              state <= S_CRC_FIFO_WR_WAIT;
            end
          end else begin
            state <= S_CRC_CMD_WR;
          end
        end

        S_CRC_FIFO_WR_WAIT: begin
          if (spi_done) begin
            crc_idx <= crc_idx + 1'b1;
            state <= S_CRC_FIFO_WR;
          end
        end

        S_CRC_CMD_WR: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(REG_COMMAND, CMD_CALC_CRC);
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_CRC_CMD_WR_WAIT;
          end
        end

        S_CRC_CMD_WR_WAIT: begin
          if (spi_done) begin
            state <= S_CRC_IRQ_RD;
          end
        end

        S_CRC_IRQ_RD: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_rd(REG_DIV_IRQ);
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_start <= 1'b1;
            state <= S_CRC_IRQ_RD_WAIT;
          end
        end

        S_CRC_IRQ_RD_WAIT: begin
          if (spi_done) begin
            if (get_byte(spi_rx_data, 6'd0) & 8'h04) begin
              state <= S_CRC_IDLE_WR;
            end else begin
              state <= S_CRC_IRQ_RD;
            end
          end
        end

        S_CRC_IDLE_WR: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(REG_COMMAND, CMD_IDLE);
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_CRC_IDLE_WR_WAIT;
          end
        end

        S_CRC_IDLE_WR_WAIT: begin
          if (spi_done) begin
            state <= S_CRC_RES_L_RD;
          end
        end

        S_CRC_RES_L_RD: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_rd(REG_CRC_RES_L);
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_start <= 1'b1;
            state <= S_CRC_RES_L_RD_WAIT;
          end
        end

        S_CRC_RES_L_RD_WAIT: begin
          if (spi_done) begin
            crc_l <= get_byte(spi_rx_data, 6'd0);
            state <= S_CRC_RES_H_RD;
          end
        end

        S_CRC_RES_H_RD: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_rd(REG_CRC_RES_H);
            spi_w_len <= 6'd1;
            spi_r_len <= 6'd1;
            spi_start <= 1'b1;
            state <= S_CRC_RES_H_RD_WAIT;
          end
        end

        S_CRC_RES_H_RD_WAIT: begin
          if (spi_done) begin
            crc_h <= get_byte(spi_rx_data, 6'd0);
            trx_kind <= TRX_SELECT;
            trx_tx_buf <= set_byte(set_byte(crc_buf, 6'd7, crc_l), 6'd8, get_byte(spi_rx_data, 6'd0));
            trx_tx_len <= 6'd9;
            trx_tx_last_bits <= 3'd0;
            state <= S_TRX_BEGIN;
          end
        end

        S_RATS_PREP: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(REG_TX_MODE, 8'h80);
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_POST_RATS_WR_WAIT;
            post_rats_idx <= 3'd7;
          end
        end

        S_RATS_PREP_WAIT: begin
          state <= S_RATS_PREP;
        end

        S_RATS_RXMODE_WR: begin
          state <= S_RATS_PREP;
        end

        S_RATS_RXMODE_WR_WAIT: begin
          state <= S_RATS_PREP;
        end

        S_PRE_RATS_TXMODE_WR: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(REG_TX_MODE, 8'h80);
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_PRE_RATS_TXMODE_WR_WAIT;
          end
        end

        S_PRE_RATS_TXMODE_WR_WAIT: begin
          if (spi_done) begin
            state <= S_RATS_PREP;
          end
        end

        S_POST_RATS_WR: begin
          if (!spi_busy) begin
            spi_tx_data <= pack_wr(post_rats_reg_by_idx(post_rats_idx[1:0]), post_rats_val_by_idx(post_rats_idx[1:0]));
            spi_w_len <= 6'd2;
            spi_r_len <= 6'd0;
            spi_start <= 1'b1;
            state <= S_POST_RATS_WR_WAIT;
          end
        end

        S_POST_RATS_WR_WAIT: begin
          if (spi_done) begin
            if (post_rats_idx == 3'd7) begin
              trx_kind <= TRX_RATS;
              trx_tx_buf <= set_byte(set_byte(256'd0, 6'd0, 8'hE0), 6'd1, 8'h50);
              trx_tx_len <= 6'd2;
              trx_tx_last_bits <= 3'd0;
              post_rats_idx <= 3'd0;
              state <= S_TRX_BEGIN;
            end else if (post_rats_idx == 3'd3) begin
              ready <= 1'b1;
              card_present <= 1'b1;
              state <= S_ACTIVE;
            end else begin
              post_rats_idx <= post_rats_idx + 1'b1;
              state <= S_POST_RATS_WR;
            end
          end
        end

        S_ACTIVE: begin
          tx_ready <= !spi_busy;
          ready <= !spi_busy;
          if (tx_valid && tx_ready) begin
            host_tx_buf <= tx_data;
            host_tx_len <= {1'b0, tx_len};
            host_tx_last_bits <= tx_last_bits;
            trx_kind <= TRX_HOST;
            trx_tx_buf <= tx_data;
            trx_tx_len <= {1'b0, tx_len};
            trx_tx_last_bits <= tx_last_bits;
            state <= S_TRX_BEGIN;
          end
        end

        S_FAIL_RETRY: begin
          tx_ready <= 1'b0;
          if (wait_counter >= WAIT_REQA_RETRY) begin
            reqa_cfg_idx <= 3'd0;
            state <= S_REQA_CFG;
          end else begin
            wait_counter <= wait_counter + 1'b1;
          end
        end

        default: begin
          state <= S_BOOT_RESET_WR;
        end
      endcase
    end
  end

endmodule
