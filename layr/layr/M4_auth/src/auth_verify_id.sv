module auth_verify_id(
    input logic clk,
    input logic rst,
    input logic consumer_ready,
    input logic [7:0] id_cipher,

    output logic error,
    output logic success,
    output logic producer_valid
);

endmodule
