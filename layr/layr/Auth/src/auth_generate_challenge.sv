module auth_generate_challenge(
    input logic clk,
    input logic rst,
    input logic ready_i,
    input reg [127:0] input_cipher_i,

    output logic error_o,
    output logic challenge_valid_o,
    output logic [127:0] challenge_response_o,
    output reg aes_cs_o,
    output reg aes_we_o,
    output reg [7:0] aes_address_o,
    output reg [31:0] aes_write_data_o
);
    enum {
        IDLE,
        READ_CHAL,
        DECRYPT,
        GET_RNG,
        ENCRYPT,
        SEND
    } current_state, next_state;

    enum {
        DECRYPT_SET_MODE,
        DECRYPT_WRITE,
        DECRYPT_RUN,
        DECRYPT_READ
    } decrypt_current_state, decrypt_next_state;

    enum {
        ENCRYPT_SET_MODE,
        ENCRYPT_WRITE_CR,
        ENCRYPT_READ_CR,
        ENCRYPT_WRITE_SK,
        ENCRYPT_READ_SK,
        ENCRYPT_RUN,
    } encrypt_current_state, encrypt_next_state;

    reg [2:0] key_index;

    always_ff @(posedge clk or posedge rst) begin
        current_state <= next_state;

        if (rst) begin
            key_index <= 3'd0;
            current_state <= IDLE;
            decrypt_current_state <= DECRYPT_SET_MODE;
            encrypt_current_state <= ENCRYPT_SET_MODE;
            decrypt_next_state <= DECRYPT_WRITE;
            encrypt_next_state <= ENCRYPT_WRITE_CR;

        end else if (current_state == IDLE) begin
            if (ready_i) begin
                reg_input_chiper <= input_cipher_i;
                current_state <= DECRYPT;
            end

        end else if (current_state == DECRYPT) begin
            if (decrypt_current_state == DECRYPT_SET_MODE) begin
                // TODO
            end else if (decrypt_current_state == DECRYPT_WRITE) begin
                if (data_index == 8'd4) begin
                    // TODO: Clean up variables

                end else begin
                    // TODO: Write cipher into aes core

                end
            end
        end
    end

    always_comb begin
        if (current_state == DECRYPT) begin
            if (decrypt_current_state == DECRYPT_SET_MODE) begin

            end else if (decrypt_current_state == DECRYPT_WRITE) begin
                if (data_index == 8'd4) begin
                    // TODO: Clean up variables

                end else begin
                    // TODO: Write cipher into aes core

                end

            end else if (decrypt_current_state == DECRYPT_RUN) begin
                aes_address_o = 8'h08;
                aes_write_data_o = 32'h1;
                aes_cs_o = 1'b1;
                aes_we_o = 1'b1;

                // TODO: Wait for run to finish

            end else if (decrypt_current_state == DECRYPT_READ) begin
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
