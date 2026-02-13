module layr(
    input logic clk,
    input logic rst,
    input logic card_present,

    input logic response_valid,
    input logic [127: 0] response,

    output logic command_valid,
    output logic [168: 0] command,

    output logic status,
    output logic status_valid
);

logic auth_init, generate_challenge, auth, get_id, verify_id;
logic auth_initialized, challenge_generated, authenticated, id_retrieved, id_verified;

logic [127:0] id_cipher;
logic [127:0] card_cipher;
logic [127:0] chip_cypher, chip_cypher_new;

logic rst_;
assign rst_ = rst | ~card_present;

layr_controller controller(
    .clk(clk),
    .rst(rst_),
    .start(card_present),

    .auth_initialized(auth_initialized),
    .challenge_generated(challenge_generated),
    .id_retrieved(id_retrieved),

    .auth_init(auth_init),
    .generate_challenge(generate_challenge),
    .auth(auth),
    .get_id(get_id),
    .verify_id(verify_id)
);

command_mux mux(
    .clk(clk),
    .rst(rst),

    .auth_init(auth_init),
    .auth(auth),
    .get_id(get_id),

    .chip_challenge(chip_cypher),

    .response_valid(),
    .response(),

    .auth_initialized(auth_initialized),
    .id_cipher(id_cipher),

    .card_challenge(card_cipher),

    .command(),
    .command_valid()
);

layr_auth auth_i(
    .clk(clk),
    .rst(rst),

    .generate_challenge(generate_challenge),
    .verify_id(verify_id),

    .card_cipher(card_cipher),
    .id_cipher(id_cipher),

    .chip_challenge_generated(challenge_generated),
    .chip_challenge(chip_cypher),

    .id_verified(id_verified),
    .id_valid()
);

/*
auth_verify_id auth_v(
    .clk(clk),
    .rst(rst),
    .external_valid(verify_id),
    .id_cipher(id_cipher),
    .rc(card_cipher),
    .rt(chip_cypher),
    // todo js error stuff...
);

auth_generate_challenge auth_g(
    .clk(clk),
    .rst(rst),
    .external_valid_i(generate_challenge),
    .input_cipher_i(card_cipher),

    // todo js output logic error_o,
    // todo js output logic internal_ready_o,
    .internal_valid_o(challenge_generated),
    .challenge_response_o(chip_cypher_new)
)
*/

always_ff @(posedge clk) begin
    if (challenge_generated) begin
        chip_cypher <= chip_cypher_new;
    end
end


endmodule