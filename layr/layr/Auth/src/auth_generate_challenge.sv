module auth_generate_challenge(
    input logic clk,
    input logic rst,
    input logic external_ready_i,
    input logic external_valid_i,
    input logic [7:0] input_cipher_i,

    output logic error_o,
    output logic internal_ready_o,
    output logic internal_valid_o,
    output logic [7:0] challenge_response_o
);

    reg [127:0] reg_input_cipher;
    reg [127:0] reg_challenge_response;
    reg [5:0] recv_count;
    reg [5:0] resp_count;
    reg response_ready;

    assign error = 1'b0;
    assign response_ready = 1'b0;
    assign internal_ready = (byte_count != 5'd16);

    always_ff @(posedge clk) begin
        if (rst) begin
            reg_input_cipher <= 128'd0;
            recv_count <= 4'd0;
        end else if (external_valid && internal_ready) begin
            // This automatically shifts the register value by 8 bytes.
            reg_input_cipher <= {reg_input_cipher[119:0], input_cipher};
            recv_count <= recv_count + 4'd1;
        end
    end

    // TODO: set ecb 128 bit decrypt mode for aes core, key is already set
    // TODO: set init bit for aes core
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

    // TODO: Placeholder value
    assign reg_challenge_response = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;

    assign internal_valid_o = response_ready && (recv_count == 5'd16) && (resp_count <= 5'd16);
    assign challenge_response_o = reg_challenge_response[127 - resp_cnt*8 -: 8];

    always_ff @(posedge clk) begin
        if (rst) begin
            resp_count <= 4'd0;
        end else if (internal_valid_o && external_ready_i) begin
            resp_count <= resp_count + 4'd1;
        end
    end

    //Reset input register and counter after challenge_response has been
    //transmitted
    always_ff @(posedge clk) begin
        if (rst || (internal_valid_o && external_ready_i && resp_count == 4'd15)) begin
            reg_input_cipher <= 128'd0;
            recv_count <= 4'd0;
            resp_count <= 4'd0;
        end
    end

endmodule
