module auth_init(
    input logic clk,
    input logic rst,
    input logic start_i, // manually trigger init process

    output logic busy_o, // to system controller
    output logic done_o // to system controller
);

    enum {
        IDLE,
        FETCH,
        CONFIG
    } current_state, next_state;

    // TODO: Add register to keep key locally to prevent it from being read
    // from EEPROM every time this module is triggered manually.

    reg [31:0] reg_key [0:7];
    reg [2:0] key_index;

    // For AES core
    reg cs;
    reg we;
    reg [3:0] aes_address;
    reg [31:0] write_data;

    assign start = start_i;

    aes aes(
        .clk(clk),
        .reset_n(!rst),
        .cs(cs),
        .we(we),
        .address(aes_address),
        .write_data(write_data)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst || start) begin
            current_state <= FETCH;
            key_index <= 4'd0;

        end else if (current_state == FETCH) begin
            // TODO: Is it possible to directly direct the read data from the
            //       EEPROM to the aes core? would skip the local register
            //       completely.
            if (key_index == 4'd3) begin
                key_index <= 4'd0;
                current_state <= CONFIG;
                busy_o <= 1'b0;
            end else begin
                key_index <= key_index + 4'd1;
                busy_o <= 1'b1;
            end

        // Handle key index while writing key to aes core.
        end else if (current_state == CONFIG) begin
            if (key_index == 4'd3) begin
                key_index <= 4'd0;
                cs = 1'b0;
                we = 1'b0;
                current_state <= IDLE;
                busy_o <= 1'b0;
                done_o <= 1'b1;
            end else begin
                key_index <= key_index + 4'd1;
            end

        end else begin
            key_index <= 4'd0;
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        busy_o = 1'b0;
        done_o = 1'b0;

        case (current_state)
            IDLE: begin
                next_state = IDLE;
                busy_o = 1'b0;
            end

            FETCH: begin
                busy_o = 1'b1;
                // TODO: Get key from EEPROM, prolly not possible in one cycle.
                // Only change state to config after key has been loaded.
                reg_key[key_index] = 32'b1;
            end

            CONFIG: begin
                //  Key addresses (32 bit write bus):
                //      start: 8'h10
                //      end:   8'h17
                busy_o = 1'b1;
                cs = 1'b1;
                we = 1'b1;
                aes_address = 8'h10 + key_index;
                write_data = reg_key[key_index];
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
