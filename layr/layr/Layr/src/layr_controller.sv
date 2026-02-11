module layr_controller(
    input logic clk,
    input logic rst,
    input logic auth_initialized,

    input logic start,

    output logic initialize_auth,
    output logic generate_challenge
);

enum {READY, INITIALIZE_AUTH, GENERATE_CHALLENGE, Authenticate, GetId} state, next_state;


always_comb begin
    next_state = state;
    initialize_auth = 0;
    generate_challenge = 0;

    case (state)
        READY: begin
            if(start) begin
                next_state = INITIALIZE_AUTH;
            end
        end
        INITIALIZE_AUTH: begin
            initialize_auth=1;
            if(auth_initialized) begin
                next_state=GENERATE_CHALLENGE;
            end
        end
        GENERATE_CHALLENGE: begin
            generate_challenge=1;

        end
    endcase
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= READY;
    end else begin
        state <= next_state;
    end
end

endmodule
