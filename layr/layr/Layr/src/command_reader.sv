module command_reader #(
    // Number of bytes to receive for each command
    parameter int unsigned NUM_BYTES = 2
)(
    input  logic clk,
    input  logic rst,

    // Incoming byte stream
    input  logic [7:0] rx,
    input  logic       rx_valid,
    input  logic       rx_last,
    output logic       rx_ready,

    // Assembled command
    output logic [8*NUM_BYTES-1:0] data_out,
    output logic                   data_valid
);
    // FSM states
    typedef enum logic [0:0] {
        WAIT = 1'b0,
        RECV = 1'b1
    } state_t;

    state_t state, next_state;

    // Index of the byte currently being stored
    logic [$clog2(NUM_BYTES)-1:0] byte_idx;

    // Always ready to receive in this simple implementation
    always_comb begin
        rx_ready = 1'b1;
    end

    // FSM sequential logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= WAIT;
        else
            state <= next_state;
    end

    // FSM next-state logic
    always_comb begin
        next_state = state;
        case (state)
            WAIT: begin
                if (rx_valid)
                    next_state = (NUM_BYTES == 1 || rx_last) ? WAIT : RECV;
            end

            RECV: begin
                if (rx_valid && (rx_last || (byte_idx == NUM_BYTES-1)))
                    next_state = WAIT;
            end

            default: next_state = WAIT;
        endcase
    end

    // Data assembly and output logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            data_out   <= '0;
            data_valid <= 1'b0;
            byte_idx   <= '0;
        end else begin
            data_valid <= 1'b0; // default: pulse on completion only

            case (state)
                WAIT: begin
                    byte_idx <= '0;

                    if (rx_valid) begin
                        // Store first byte at index 0
                        data_out[7:0] <= rx;

                        // If this is also the last/only byte, command is complete
                        if (NUM_BYTES == 1 || rx_last) begin
                            data_valid <= 1'b1;
                        end else begin
                            byte_idx <= 1'b1;
                        end
                    end
                end

                RECV: begin
                    if (rx_valid) begin
                        // Store current byte
                        data_out[8*byte_idx +: 8] <= rx;

                        // Check if this was the final byte of the command
                        if (rx_last || (byte_idx == NUM_BYTES-1)) begin
                            data_valid <= 1'b1;
                            byte_idx   <= '0;
                        end else begin
                            byte_idx <= byte_idx + 1'b1;
                        end
                    end
                end
            endcase
        end
    end

endmodule
