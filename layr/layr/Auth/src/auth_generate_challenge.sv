module auth_generate_challenge(
    input logic clk,
    input logic rst,
    input logic ready_i,
    input logic [127:0] input_cipher_i,

    output logic error_o,
    output logic challenge_valid_o,
    output logic [127:0] challenge_response_o
);
    enum {
        IDLE,
        READ_CHAL,
        DECRYPT,
        GET_RNG,
        ENCRYPT,
        SEND
    } current_state, next_state;

    reg [127:0] reg_input_chiper;
    reg cs;
    reg we;

    aes aes(
        .cs(cs),
        .we(we)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;

        end else if (current_state == IDLE) begin
            if (ready_i) begin
                reg_input_chiper <= input_cipher_i;
                current_state <= DECRYPT;
            end
        end
    end

    // TODO: set ecb 128 bit decrypt mode for aes core, key is already set

    // TODO: Write input challenge to aes core input

    // TODO: set init bit for aes core
    /*
    cs          = 1'b1;
    we          = 1'b1;
    address     = 8'h08;
    write_data  = 32'h1;
    */
    // TODO: decrypt reg_input_chiper (AES ECB)
    // TODO: obtain rc
    // TODO: get random value rt (NFC reader apparently has RNG)
    // TODO: set ecb 128 bit encrypt mode for aes core, key is already set
    /*
    cs = 1'b1;
    we = 1'b1;
    aes_address = 8'h0a;
    write_data = 32'h0;
    */
    // TODO: set init bit for aes core
    /*
    cs          = 1'b1;
    we          = 1'b1;
    address     = 8'h08;
    write_data  = 32'h1;
    * */
    // TODO: create AES_psk(rt || rc)
    // TODO: send AES_psk(rt || rc) to auth_verify_id
    // TODO: store AES_psk(rt || rc) in reg_challenge_response

endmodule
