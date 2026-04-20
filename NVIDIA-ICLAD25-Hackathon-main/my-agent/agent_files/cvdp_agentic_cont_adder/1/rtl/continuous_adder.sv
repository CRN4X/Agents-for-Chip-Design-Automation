`timescale 1ns/1ps

module continuous_adder #(
    parameter integer DATA_WIDTH       = 32,
    parameter integer ENABLE_THRESHOLD = 0,
    parameter integer THRESHOLD        = 16,
    parameter integer REGISTER_OUTPUT  = 0
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  valid_in,
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                  accumulate_enable,
    input  wire                  flush,
    output reg  [DATA_WIDTH-1:0] sum_out,
    output reg                   sum_valid
);

    reg [DATA_WIDTH-1:0] sum_reg;
    reg [DATA_WIDTH-1:0] sum_next;
    reg                  sum_valid_next;

    always @(*) begin
        if (flush) begin
            sum_next = {DATA_WIDTH{1'b0}};
        end else if (valid_in && accumulate_enable) begin
            sum_next = sum_reg + data_in;
        end else begin
            sum_next = sum_reg;
        end

        if (ENABLE_THRESHOLD != 0) begin
            sum_valid_next = (sum_next >= THRESHOLD[DATA_WIDTH-1:0]);
        end else begin
            sum_valid_next = 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            sum_reg <= sum_next;
        end
    end

    generate
        if (REGISTER_OUTPUT != 0) begin : g_registered_output
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    sum_out   <= {DATA_WIDTH{1'b0}};
                    sum_valid <= 1'b0;
                end else begin
                    sum_out   <= sum_next;
                    sum_valid <= sum_valid_next;
                end
            end
        end else begin : g_comb_output
            always @(*) begin
                sum_out   = sum_next;
                sum_valid = sum_valid_next;
            end
        end
    endgenerate

endmodule
