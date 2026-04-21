`timescale 1ns/1ns

module multiplexer #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_INPUTS = 4,
    parameter integer REGISTER_OUTPUT = 0,
    parameter integer HAS_DEFAULT = 0,
    parameter [DATA_WIDTH-1:0] DEFAULT_VALUE = {DATA_WIDTH{1'b0}}
) (
    input  wire                             clk,
    input  wire                             rst_n,
    input  wire [(DATA_WIDTH*NUM_INPUTS)-1:0] inp,
    input  wire [$clog2(NUM_INPUTS)-1:0]    sel,
    input  wire                             bypass,
    output reg  [DATA_WIDTH-1:0]            out
);

    reg [DATA_WIDTH-1:0] mux_out;

    always @(*) begin
        if (bypass) begin
            mux_out = inp[DATA_WIDTH-1:0];
        end else if (sel < NUM_INPUTS) begin
            mux_out = inp[sel*DATA_WIDTH +: DATA_WIDTH];
        end else if (HAS_DEFAULT) begin
            mux_out = DEFAULT_VALUE;
        end else begin
            mux_out = {DATA_WIDTH{1'b0}};
        end
    end

    generate
        if (REGISTER_OUTPUT) begin : gen_reg_out
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    out <= {DATA_WIDTH{1'b0}};
                end else begin
                    out <= mux_out;
                end
            end
        end else begin : gen_comb_out
            always @(*) begin
                out = mux_out;
            end
        end
    endgenerate

endmodule
