module req_res_ctrl(
    input logic clk,
    input logic rst,
    
    input logic start,
    input logic sent,
    input logic recieved_response,

    output logic 
);

enum {READY, REQUESTING, READING_RESPONSE} state, next_state;

always_comb begin
    next_state = state;

    case (state)
        READY: begin
            if(start) begin
                next_state = REQUESTING;
            end
        end
        INITIALIZE_AUTH: begin
            if(sent) begin
                
            end
        end
        GENERATE_CHALLENGE: begin
            if(challenge_generated) begin
                next_state=AUTHENTICATE;
                authenticate=1;
            end
        end
        AUTHENTICATE: begin
            if(authenticated) begin
                next
            end
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
