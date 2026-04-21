`timescale 1ns/1ps

module sigma_delta_audio (
    input  wire              clk_sig,
    input  wire              clk_en_sig,
    input  wire signed [14:0] load_data_sum,
    input  wire signed [14:0] read_data_sum,
    output reg               left_sig,
    output reg               right_sig
);

    reg [15:0] seed_1;
    reg [15:0] seed_2;
    initial begin
        left_sig  = 1'b0;
        right_sig = 1'b0;
        seed_1    = 16'h1ACE;
        seed_2    = 16'h2BDF;
    end

    always @(posedge clk_sig) begin
        if (clk_en_sig) begin
            seed_1 <= {seed_1[14:0], seed_1[15] ^ seed_1[13] ^ seed_1[12] ^ seed_1[10]};
            seed_2 <= {seed_2[14:0], seed_2[15] ^ seed_2[14] ^ seed_2[12] ^ seed_2[3]};
            left_sig  <= 1'b0;
            right_sig <= 1'b0;
        end
    end

endmodule
