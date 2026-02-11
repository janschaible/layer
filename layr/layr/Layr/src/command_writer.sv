module command_writer #(
    // Number of bytes to send on each start pulse
    parameter int unsigned NUM_BYTES = 2
)(
    input  logic clk,
    input  logic rst,

    input  logic start,                     // trigger sending of bytes
    input  logic [8*NUM_BYTES-1:0] data_in, // packed bytes, byte 0 in bits [7:0]

    input  logic tx_ready,                  // handshake from receiver

    output logic [7:0] tx,                  // byte to transmit
    output logic tx_valid,                  // valid flag
    output logic tx_last,                   // last byte flag
    output logic rx_ready                   // ready to receive (kept high)
);
    // FSM states
    typedef enum logic [0:0] {
        IDLE = 1'b0,
        SEND = 1'b1
    } state_t;

    state_t state, next_state;

    // Index of the byte currently being sent
    logic [$clog2(NUM_BYTES)-1:0] byte_idx;

    // Helper function to extract a byte from packed data
    function automatic logic [7:0] get_byte(input logic [8*NUM_BYTES-1:0] din,
                                            input logic [$clog2(NUM_BYTES)-1:0] idx);
        get_byte = din[8*idx +: 8];
    endfunction

    // FSM sequential logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FSM next-state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = SEND;
            end

            SEND: begin
                // Return to IDLE after the last byte has been accepted
                if (tx_valid && tx_ready && (byte_idx == NUM_BYTES-1))
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output and byte index logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tx       <= '0;
            tx_valid <= 1'b0;
            tx_last  <= 1'b0;
            rx_ready <= 1'b1; // always ready to receive
            byte_idx <= '0;
        end else begin
            case (state)
                IDLE: begin
                    tx_valid <= 1'b0;
                    tx_last  <= 1'b0;
                    byte_idx <= '0;

                    if (start) begin
                        tx       <= get_byte(data_in, '0);
                        tx_valid <= 1'b1;
                        tx_last  <= (NUM_BYTES == 1);
                    end
                end

                SEND: begin
                    if (!tx_valid) begin
                        // Start sending the current byte
                        tx       <= get_byte(data_in, byte_idx);
                        tx_valid <= 1'b1;
                        tx_last  <= (byte_idx == NUM_BYTES-1);
                    end else if (tx_ready) begin
                        // Receiver accepted the byte
                        tx_valid <= 1'b0;
                        tx_last  <= 1'b0;

                        // Advance to next byte if any remain
                        if (byte_idx != NUM_BYTES-1)
                            byte_idx <= byte_idx + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule