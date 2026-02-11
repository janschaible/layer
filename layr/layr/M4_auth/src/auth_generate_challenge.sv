module auth_generate_challenge(
    input logic clk,
    input logic rst,
    input logic consumer_ready,
    input logic consumer_valid,
    input logic [7:0] input_cipher,

    output logic error,
    output logic producer_ready,
    output logic producer_valid,
    output logic [7:0] challenge_response
);

endmodule
