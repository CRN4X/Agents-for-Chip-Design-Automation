`timescale 1ns/1ps

module dsp_output_stage #(
    parameter DATA_WIDTH = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                   valid_in,
    input  wire [DATA_WIDTH-1:0] rand_mask,

    output reg  [DATA_WIDTH-1:0] data_out,
    output reg                   valid_out,
    output reg  [31:0]           transfer_count
);

    reg valid_in_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out       <= 0;
            valid_out      <= 0;
            transfer_count <= 0;
            valid_in_d     <= 0;
        end else begin
            valid_out  <= valid_in & ~valid_in_d;
            valid_in_d <= valid_in;

            if (valid_in & ~valid_in_d) begin
                data_out  <= data_in ^ rand_mask;
                transfer_count <= transfer_count + 1;
            end
        end
    end

endmodule
