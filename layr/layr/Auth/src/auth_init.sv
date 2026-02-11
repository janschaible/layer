module aes_init(
    input logic ckl,
    input logic rst,
    output logic busy,
    output logic done,
);

    typedef enum logic {
        IDLE,
        FETCH,
        CONFIG
    } state_t;

     state_t current_state, next_state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= FETCH;
        end else begin
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
                // TODO: Set cipher mode for aes core
                // TODO: set key for aes core
                // TODO: Do remaining AES stuff
                next_state = IDLE;
                busy = 1'b0;
                done = 1'b1;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
