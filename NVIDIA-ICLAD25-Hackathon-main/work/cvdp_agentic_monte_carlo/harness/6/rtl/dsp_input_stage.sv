module dsp_input_stage #(
    parameter DATA_WIDTH = 16     
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                   valid_in,
    input  wire [DATA_WIDTH-1:0] rand_mask,

    output reg  [DATA_WIDTH-1:0] data_out,
    output reg                   valid_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= 0;
            valid_out <= 0;
        end else begin
            data_out  <= data_in ^ rand_mask;
            valid_out <= valid_in;
        end
    end

endmodule