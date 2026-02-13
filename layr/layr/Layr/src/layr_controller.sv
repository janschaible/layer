module layr_controller(
    input logic clk,
    input logic rst,

    input logic start,
    input logic auth_initialized,
    input logic challenge_generated,
    input logic authenticated,
    input logic id_retrieved,

    output logic auth_init,
    output logic generate_challenge,
    output logic auth,
    output logic get_id,
    output logic verify_id
);

enum {READY, AUTH_INIT, GENERATE_CHALLENGE, AUTH, GET_ID, VERIFY_ID} state, next_state;


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
                next_state=GENERATE_CHALLENGE;
            end
        end
        GENERATE_CHALLENGE: begin
            if(challenge_generated) begin
                next_state=AUTH;
            end
        end
        AUTH: begin
            if(authenticated) begin
                next_state=GET_ID;
            end
        end
        GET_ID: begin
            if(id_retrieved) begin
                next_state=VERIFY_ID;
            end
        end
        VERIFY_ID: begin

        end
    endcase
end

always_ff @(posedge clk) begin
    auth_init = 0;
    generate_challenge = 0;
    auth = 0;
    get_id = 0;
    verify_id = 0;

    case (next_state)
        READY: begin
        end
        AUTH_INIT: begin
            auth_init=1;
        end
        GENERATE_CHALLENGE: begin
            generate_challenge=1;
        end
        AUTH: begin
            auth=1;
        end
        GET_ID: begin
            get_id=1;
        end
        VERIFY_ID: begin
            verify_id=1;
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
