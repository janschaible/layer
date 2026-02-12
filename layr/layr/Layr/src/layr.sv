module layr(
    input logic clk,
    input logic rst,
    input logic card_present,
    output logic verify_id

    output logic status,
    output logic status_valid,
);

logic initialize_auth, generate_challenge, auth, get_id, verify_id;
logic auth_initialized, challenge_generated, authenticated;

logic [128,0] id_cipher;
logic [128:0] card_challenge_rc;
logic [128:0] chip_challenge_rt, chip_challenge_rt_new;

logic rst_;
assign rst_ = rst | ~card_present;

layr_controller controller(
    .clk(clk),
    .rst(rst_),
    .start(card_present),

    .auth_initialized(auth_initialized),
    .challenge_generated(challenge_generated),

    .initialize_auth(initialize_auth),
    .generate_challenge(generate_challenge)
);

command_writer cmd_writer (
    .clk(clk),
    .rst(rst_),

    .start(initialize_auth), // todo js this is not right...
    .data_in({cla, ins, 8'h00, 8'h00}), // todo js this is not complete

    .tx_ready(),

    .tx(tx),
    .tx_valid(tx_valid),
    .tx_last(tx_last),
)

auth_verify_id auth_v(
    .clk(clk),
    .rst(rst),
    .external_valid(verify_id),
    .id_cipher(id_cipher),
    .rc(card_challenge_rc),
    .rt(chip_challenge_rt),
    // todo js error stuff...
);

auth_generate_challenge auth_g(
    .clk(clk),
    .rst(rst),
    .external_valid_i(generate_challenge),
    .input_cipher_i(card_challenge_rc),

    // todo js output logic error_o,
    // todo js output logic internal_ready_o,
    .internal_valid_o(challenge_generated),
    .challenge_response_o(chip_challenge_rt_new)
)

always_ff @(posedge clk) begin
    if(challenge_generated)begin
        chip_challenge_rt <= chip_challenge_rt_new;
    end
end



endmodule