module auth_init(
    `ifndef SYNTHESIS
    output logic [1:0] dbg_current_state,
    `endif

    input logic clk,
    input logic rst,
    output logic busy_o, // to system controller
    output logic done_o, // to system controller
    output logic cs_o, // to aes core
    output logic we_o, // to aes core
    output logic [7:0] aes_address_o, // to aes core
    output logic [31:0] write_data_o // to aes core
);

    typedef enum logic [1:0] {
        IDLE,
        FETCH,
        CONFIG
    } state_t;

    state_t current_state, next_state;

    reg [31:0] reg_key [0:7];
    reg [2:0] key_index;

    `ifndef SYNTHESIS
    assign dbg_current_state = current_state;
    `endif

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= FETCH;
            key_index <= 4'd0;

        end else if (current_state == FETCH) begin
            // TODO: Is it possible to directly direct the read data from the
            //       EEPROM to the aes core? would skip the local register
            //       completely.
            if (key_index == 4'd7) begin
                key_index <= 4'd0;
                current_state <= CONFIG;
                busy_o <= 1'b0;
            end else begin
                key_index <= key_index + 4'd1;
                busy_o <= 1'b1;
            end

        // Handle key index while writing key to aes core.
        end else if (current_state == CONFIG) begin
            if (key_index == 4'd7) begin
                key_index <= 4'd0;
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
                busy_o = 1'b1;
                //  Key addresses (32 bit write bus):
                //      start: 8'h10
                //      end:   8'h17
                cs_o = 1'b1;
                we_o = 1'b1;
                aes_address_o = 8'h10 + key_index;
                write_data_o = reg_key[key_index];
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
