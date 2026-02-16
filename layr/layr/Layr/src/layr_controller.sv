/*
This module is responsible for tracking the overall protocol.
Including the handshakes with the nfc card and the local computations required for the authentication.
*/
module layr_controller(
    input logic clk,
    input logic rst,

    input logic start,
    input logic auth_initialized,
    input logic challenge_generated,
    input logic authed,
    input logic id_retrieved,

    output logic auth_init,
    output logic generate_challenge,
    output logic auth,
    output logic get_id,
    output logic verify_id
);

enum {READY, AUTH_INIT, GENERATE_CHALLENGE, AUTH, GET_ID, VERIFY_ID} state, next_state;

// Driving the state
always_comb begin
    next_state = state;

    case (state)
        READY: begin
            if(start) begin
                next_state = AUTH_INIT;
            end
        end
        AUTH_INIT: begin
            if(auth_initialized) begin
                next_state = GENERATE_CHALLENGE;
            end
        end
        GENERATE_CHALLENGE: begin
            if(challenge_generated) begin
                next_state = AUTH;
            end
        end
        AUTH: begin
            if(authed) begin
                next_state = GET_ID;
            end
        end
        GET_ID: begin
            if(id_retrieved) begin
                next_state = VERIFY_ID;
            end
        end
        VERIFY_ID: begin
        end
    endcase
end

// Advancing the state
always_ff @(posedge clk) begin
    if (rst) begin
        state <= READY;
        auth_init <= 0;
        generate_challenge <= 0;
        auth <= 0;
        get_id <= 0;
        verify_id <= 0;
    end else begin
        state <= next_state;
        auth_init <= 0;
        generate_challenge <= 0;
        auth <= 0;
        get_id <= 0;
        verify_id <= 0;

        case (next_state)
            READY: begin
            end
            AUTH_INIT: begin
                auth_init <= (state != AUTH_INIT);
            end
            GENERATE_CHALLENGE: begin
                generate_challenge <= (state != GENERATE_CHALLENGE);
            end
            AUTH: begin
                auth <= (state != AUTH);
            end
            GET_ID: begin
                get_id <= (state != GET_ID);
            end
            VERIFY_ID: begin
                verify_id <= (state != VERIFY_ID);
            end
        endcase
    end
end

endmodule
