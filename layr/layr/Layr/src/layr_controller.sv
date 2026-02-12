module layr_controller(
    input logic clk,
    input logic rst,
    input logic auth_initialized,
    input logic challenge_generated,
    input logic authenticated,
    

    input logic start,

    output logic auth_init,
    output logic generate_challenge,
    output logic auth,
    output logic get_id,
    output logic verify_id
);

enum {READY, AUTH_INIT, GENERATE_CHALLENGE, AUTH, GET_ID, VERIFY_ID} state, next_state;


always_comb begin
    next_state = state;
    auth_init = 0;
    generate_challenge = 0;
    auth = 0;
    get_id = 0;
    verify_id = 0;

    case (state)
        READY: begin
            if(start) begin
                next_state = AUTH_INIT;
                auth_init=1;
            end
        end
        AUTH_INIT: begin
            if(auth_initialized) begin
                next_state=GENERATE_CHALLENGE;
                generate_challenge=1;
            end
        end
        GENERATE_CHALLENGE: begin
            if(challenge_generated) begin
                next_state=AUTH;
                auth=1;
            end
        end
        AUTH: begin
            if(authenticated) begin
                next_state=GET_ID;
                get_id=1;
            end
        end
        GET_ID: begin
            if(id_retrieved) begin
                next_state=VERIFY_ID;
                verify_id=1;
            end
        end
        VERIFY_ID: begin

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
