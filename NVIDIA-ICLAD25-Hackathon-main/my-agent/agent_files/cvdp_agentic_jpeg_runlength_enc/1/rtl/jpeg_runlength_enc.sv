`timescale 1ns/1ns

module jpeg_runlength_enc (
    input  wire              clk_in,
    input  wire              reset_in,
    input  wire              enable_in,
    input  wire              dstrb_in,
    input  wire signed [11:0] din_in,
    output wire [3:0]        rlen_out,
    output wire [3:0]        size_out,
    output wire signed [11:0] amp_out,
    output wire              douten_out,
    output wire              bstart_out
);

    wire [3:0] s1_rlen;
    wire [3:0] s1_size;
    wire signed [11:0] s1_amp;
    wire s1_den;
    wire s1_dc;

    wire [3:0] z1_rlen;
    wire [3:0] z1_size;
    wire signed [11:0] z1_amp;
    wire z1_den;
    wire z1_dc;

    wire [3:0] z2_rlen;
    wire [3:0] z2_size;
    wire signed [11:0] z2_amp;
    wire z2_den;
    wire z2_dc;

    wire [3:0] z3_rlen;
    wire [3:0] z3_size;
    wire signed [11:0] z3_amp;
    wire z3_den;
    wire z3_dc;

    jpeg_runlength_stage1 u_stage1 (
        .clk_in(clk_in),
        .reset_in(reset_in),
        .enable_in(enable_in),
        .go_in(dstrb_in),
        .din_in(din_in),
        .rlen_out(s1_rlen),
        .size_out(s1_size),
        .amp_out(s1_amp),
        .den_out(s1_den),
        .dcterm_out(s1_dc)
    );

    jpeg_runlength_rzs u_rzs_0 (
        .clk_in(clk_in),
        .reset_in(reset_in),
        .enable_in(enable_in),
        .rlen_in(s1_rlen),
        .size_in(s1_size),
        .amp_in(s1_amp),
        .den_in(s1_den),
        .dc_in(s1_dc),
        .rlen_out(z1_rlen),
        .size_out(z1_size),
        .amp_out(z1_amp),
        .den_out(z1_den),
        .dc_out(z1_dc)
    );

    jpeg_runlength_rzs u_rzs_1 (
        .clk_in(clk_in),
        .reset_in(reset_in),
        .enable_in(enable_in),
        .rlen_in(z1_rlen),
        .size_in(z1_size),
        .amp_in(z1_amp),
        .den_in(z1_den),
        .dc_in(z1_dc),
        .rlen_out(z2_rlen),
        .size_out(z2_size),
        .amp_out(z2_amp),
        .den_out(z2_den),
        .dc_out(z2_dc)
    );

    jpeg_runlength_rzs u_rzs_2 (
        .clk_in(clk_in),
        .reset_in(reset_in),
        .enable_in(enable_in),
        .rlen_in(z2_rlen),
        .size_in(z2_size),
        .amp_in(z2_amp),
        .den_in(z2_den),
        .dc_in(z2_dc),
        .rlen_out(z3_rlen),
        .size_out(z3_size),
        .amp_out(z3_amp),
        .den_out(z3_den),
        .dc_out(z3_dc)
    );

    jpeg_runlength_rzs u_rzs_3 (
        .clk_in(clk_in),
        .reset_in(reset_in),
        .enable_in(enable_in),
        .rlen_in(z3_rlen),
        .size_in(z3_size),
        .amp_in(z3_amp),
        .den_in(z3_den),
        .dc_in(z3_dc),
        .rlen_out(rlen_out),
        .size_out(size_out),
        .amp_out(amp_out),
        .den_out(douten_out),
        .dc_out(bstart_out)
    );

endmodule
