module layr_controller(
    input logic clk,
    input logic rst_,
    input logic card_present,

    input logic [7:0] rx,
    input logic rx_valid,
    input logic rx_last

    input logic tx_ready,
    input logic status_ready,

    output logic [7:0] tx,
    output logic tx_valid,
    output logic tx_last,

    output logic status,
    output logic status_valid,

    output logic rx_ready,
);
logic rst;

assign rst = rst_ | card_present;


command_reader #(

) message_reader(

);



endmodule