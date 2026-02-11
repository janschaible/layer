module auth_generate_challenge(
    input logic clk,
    input logic rst,
    input logic external_ready,
    input logic external_valid,
    input logic [7:0] input_cipher,

    output logic error,
    output logic internal_ready,
    output logic internal_valid,
    output logic [7:0] challenge_response
);

    reg [127:0] reg_input_cipher;
    reg [127:0] reg_challenge_response;
    reg [3:0]   recv_count;
    reg [3:0]   resp_count;
    reg response_ready;

    assign error = 1'b0;
    assign response_ready = 1'b0;
    assign internal_ready = (byte_count != 4'd16);

    always_ff @(posedge clk) begin
        if (rst) begin
            reg_input_cipher <= 128'd0;
            recv_count <= 4'd0;
        end else if (external_valid && internal_ready)
            // This automatically shifts the register value by 8 bytes.
            reg_input_cipher <= {reg_input_cipher[119:0], input_cipher};
            recv_count <= byte_count +4'd1;
        end
    end

    // TODO: decrypt reg_input_chiper (AES ECB)
    // TODO: obtain rc
    // TODO: get random value rt
    // TODO: create AES_psk(rt || rc)
    // TODO: store AES_psk(rt || rc) in reg_challenge_response

    // TODO: Placeholder value
    assign reg_challenge_response = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;

    assign internal_valid = response_ready && (recv_count == 4'd16) && (resp_count <= 4'd16);
    assign challenge_response = reg_challenge_response[127 - resp_cnt*8 -: 8];

    always_ff @(posedge clk) begin
        if (rst) begin
            resp_count <= 4'd0;
        end else if (internal_valid && external_ready) begin
            resp_count <= resp_count + 4'd1;
        end
    end

    //Reset input register and counter after challenge_response has been
    //transmitted
    always_ff @(posedge clk) begin
        if (rst || (internal_valid && external_ready && resp_count == 4'd15)) begin
            reg_input_cipher <= 128'd0;
            recv_count <= 4'd0;
            resp_count <= 4'd0;
        end
    end

endmodule
