module aes_init(
    input logic ckl,
    input logic rst,
    output logic busy, // to system controller
    output logic done, // to system controller
    output logic cs, // to aes core
    output logic we, // to aes core
    output logic [7:0] aes_address, // to aes core
    output logic [31:0] write_data // to aes core
);

    typedef enum logic {
        IDLE,
        FETCH,
        CONFIG
    } state_t;

    state_t current_state, next_state;

    reg [31:0] reg_key [0:7];
    reg key_index;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= FETCH;
            key_index <= 4'd0;
            encryption_mode_set <= 1'b0;

        // Handle key index while writing key to aes core.
        end else if (current_state == CONFIG) begin
            if (key_index == 4'd7) begin
                key_index <= 4'd0;
                current_state <= IDLE;
                busy = 1'b0;
                done = 1'b1;
            end else begin
                key_index <= key_index + 4'd1;
            end
        end else if (current_state == FETCH) begin
            // TODO: handle write to reg_key, can also use key_index.
            // TODO: reset key_index once write is finished.
            // TODO: Is it possible to directly direct the read data from the
            //       EEPROM to the aes core? would skip storing it locally.
        end else begin
            key_index <= 4'd0;
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        busy = 1'b0;
        done = 1'b0;

        unique case (current_state)
            IDLE: begin
                next_state = IDLE;
                busy = 1'b0;
            end

            FETCH: begin
                // TODO: Get key from EEPROM, prolly not possible in one cycle.
                // Only change state to config after key has been loaded.
                next_state = CONFIG;
                busy = 1'b1;
            end

            CONFIG: begin
                //  Key addresses (32 bit write bus):
                //      start: 8'h10
                //      end:   8'h17
                busy = 1'b1;
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
