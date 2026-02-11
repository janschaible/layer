module layr_controller(
    input logic clk,
    input logic rst,

    input logic start,

    output logic initialize_auth,
    output logic generate_challenge
);

enum {READY, InitializeAuth, GenerateChallenge, Authenticate, GetId} state, next_state;


always_comb begin
    next_state = state;
    case (state)
        READY: begin
            if(start)
                next_state = InitializeAuth;
        end
        InitializeAuth: begin
            if(message_recieved)
            

        end
    endcase
end

always_ff @(posedge clk or negedge rst) begin
    if (rst) begin
        state = READY;
    end else begin
        state <= next_state;
    end
end

endmodule
