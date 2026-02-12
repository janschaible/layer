module auth_verify_id(
    input logic clk,
    input logic rst,
    input logic external_valid_i,
    input logic [7:0] id_cipher_i,
    input logic [7:0] rc_i,
    input logic [7:0] rt_i,

    output logic error_o,
    output logic success_o,
    output logic internal_ready_o
);

    reg [127:0] reg_id_cipher;
    reg [3:0] recv_count;

    assign error_o = 1'b0;
    assign success_o = 1'b0;
    assign internal_ready = (recv_count <= 4'd15);

    always_ff @(posedge clk) begin
        if (rst) begin
            reg_id_cipher <= 128'd0;
            recv_count <= 4'd0;
        end else if (external_valid && internal_ready) begin
            reg_id_cipher <= {reg_id_cipher[119:0], id_cipher};
            recv_count <= recv_count + 4'd1;
        end
    end

    // TODO: calculate session_key = AES_psk(rc || rt)
    // TODO: decrypt reg_id_cipher with session_key
    // TODO: Verify that card ID is allowed
    // TODO: If the card ID is in the allowed list, set success to 1

endmodule
