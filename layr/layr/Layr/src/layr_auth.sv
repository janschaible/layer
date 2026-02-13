/**
This module handles the interface to the auth module.
*/
module layr_auth(
    input logic clk,
    input logic rst,

    input logic generate_challenge,
    input logic verify_id,

    input logic [127:0] card_cipher,
    input logic [127:0] id_cipher,

    output logic chip_challenge_generated,
    output logic [127:0] chip_challenge,

    output logic id_verified,
    output logic id_valid
);

logic start;
logic operation;
logic auth_valid;
logic [127:0] auth_data_in;
logic [127:0] auth_data_out;

// update the input data for the auth
always_ff @(posedge clk) begin
    if(rst)begin
        auth_data_in <= '0;
        operation <= '0;
    end else begin
        if(generate_challenge) begin
            auth_data_in <= card_cipher;
            operation <= '0;
            start <= '1;
        end else if(verify_id) begin
            auth_data_in = id_cipher;
            operation <= 1;
            start <= '1;
        end
    end
end

// process output data from auth
always_ff @(posedge clk) begin
    if(rst) begin
        chip_challenge_generated <= 0;
        chip_challenge <= 0;
        id_verified <= 0;
        id_valid <= 0;
        start <= 0;
    end else begin
        if(auth_valid)begin
            start <= 0;
            if(operation==0) begin
                chip_challenge <= auth_data_out;
                chip_challenge_generated <= 1;
            end else begin
                id_valid <= auth_data_out[0];
                id_verified <= 1;
            end
        end
    end
end

auth auth_i(
    .clk(clk),
    .rst(rst),

    .operation_i(operation),

    .start_i(start),
    .data_i(auth_data_in),
    .data_o(auth_data_out),

    .valid_o(auth_valid)
);

endmodule

