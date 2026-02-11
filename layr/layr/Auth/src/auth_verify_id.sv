module auth_verify_id(
    input logic clk,
    input logic rst,
    input logic external_valid,
    input logic [7:0] id_cipher,
    input logic [7:0] rc,
    input logic [7:0] rt,

    output logic error,
    output logic success,
    output logic internal_ready
);

    reg [127:0] reg_id_cipher;
    reg [3:0] recv_count;

    assign error = 1'b0;
    assign id_valid = 1'b0;
    assign internal_ready = (recv_count != 4'd16);

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
