`timescale 1ns/1ns

module continuous_adder #(
    parameter integer DATA_WIDTH       = 32,
    parameter integer ENABLE_THRESHOLD = 0,
    parameter integer THRESHOLD        = 16,
    parameter integer REGISTER_OUTPUT  = 0
) (
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
    reg [DATA_WIDTH-1:0] sum_out_next;
    reg                  sum_valid_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_reg <= {DATA_WIDTH{1'b0}};
        end else if (flush) begin
            sum_reg <= {DATA_WIDTH{1'b0}};
        end else if (valid_in && accumulate_enable) begin
            sum_reg <= sum_reg + data_in;
        end
    end

    always @(*) begin
        sum_out_next = sum_reg;
        if (ENABLE_THRESHOLD != 0) begin
            sum_valid_next = (sum_reg >= THRESHOLD[DATA_WIDTH-1:0]);
        end else begin
            sum_valid_next = (sum_reg != {DATA_WIDTH{1'b0}});
        end
    end

    generate
        if (REGISTER_OUTPUT != 0) begin : g_reg_output
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    sum_out   <= {DATA_WIDTH{1'b0}};
                    sum_valid <= 1'b0;
                end else begin
                    sum_out   <= sum_out_next;
                    sum_valid <= sum_valid_next;
                end
            end
        end else begin : g_comb_output
            always @(*) begin
                if (!rst_n) begin
                    sum_out   = {DATA_WIDTH{1'b0}};
                    sum_valid = 1'b0;
                end else begin
                    sum_out   = sum_out_next;
                    sum_valid = sum_valid_next;
                end
            end
        end
    endgenerate

endmodule
