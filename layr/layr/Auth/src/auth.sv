module auth(
    //--------------------------------------
    // = Required =
    //--------------------------------------
    input wire clk,
    input wire rst,

    //--------------------------------------
    // = Control =
    //
    // operation_i:
    //   0 = Generate challenge response
    //   1 = Verify ID
    //
    // start_i:
    //   0 = Do nothing
    //   1 = Run selected operation with
    //       data_i as input.
    //--------------------------------------
    input wire operation_i,
    input wire start_i,

    //--------------------------------------
    // = Data bus =
    //
    // data_i:
    //   Input data for any selected operation.
    //
    // data_o:
    //   Output data for any selected operation.
    //
    // valid_o:
    //   0 = the operation is still running
    //   1 = the operation is done, data
    //       can be read from data_o
    //--------------------------------------
    input wire [127:0] data_i,
    output wire [127:0] data_o,
    output wire valid_o
);
    reg reg_operation;
    reg error;
    reg generate_challenge_valid;
    reg verify_id_valid;
    reg [127:0] reg_data_i;
    reg [127:0] reg_data_o;

    auth_generate_challenge generate_challenge(
        .clk(clk),
        .rst(rst),

        // Inputs
        .input_cipher_i(reg_data_i),

        // Outputs
        .error_o(error),
        .challenge_valid_o(generate_challenge_valid),
        .data_o(reg_data_o)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_temp <= 128'd0;

        end else if (operation == 0) begin
            // TODO: generate_challenge_response stuff

        end else if (operation == 1) begin
            // TODO: verify_id stuff

        end
    end

    always_comb begin
        // TODO
    end

endmodule
