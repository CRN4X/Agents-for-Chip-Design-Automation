`timescale 1ns/1ns

module awgn #(
    parameter DATA_WIDTH = 16,
    parameter LUT_SIZE   = 16
)(
    input  logic signed [DATA_WIDTH-1:0] signal_in,
    input  logic        [3:0]            noise_index,
    input  logic signed [DATA_WIDTH-1:0] noise_scale,
    output logic signed [DATA_WIDTH-1:0] signal_out
);
    logic signed [DATA_WIDTH-1:0] noise_sample;
    logic signed [(2*DATA_WIDTH)-1:0] noise_mult;
    logic signed [DATA_WIDTH-1:0] noise_scaled;

    always_comb begin
        case (noise_index)
            4'd0:  noise_sample = 16'sd2048;
            4'd1:  noise_sample = -16'sd1024;
            4'd2:  noise_sample = 16'sd128;
            4'd3:  noise_sample = -16'sd3072;
            4'd4:  noise_sample = 16'sd1024;
            4'd5:  noise_sample = -16'sd2048;
            4'd6:  noise_sample = 16'sd3072;
            4'd7:  noise_sample = -16'sd128;
            4'd8:  noise_sample = 16'sd0;
            4'd9:  noise_sample = 16'sd512;
            4'd10: noise_sample = -16'sd512;
            4'd11: noise_sample = 16'sd256;
            4'd12: noise_sample = -16'sd256;
            4'd13: noise_sample = 16'sd768;
            4'd14: noise_sample = -16'sd768;
            4'd15: noise_sample = 16'sd0;
            default: noise_sample = '0;
        endcase

        noise_mult   = noise_sample * noise_scale;
        noise_scaled = noise_mult >>> 13;
        signal_out   = signal_in + noise_scaled;
    end

endmodule
