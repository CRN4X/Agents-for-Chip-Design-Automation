module resonator_bank (
    input logic clk,
    input logic rst,
    input logic calibrate,
    input logic signed [15:0] audio_in,
    input logic [15:0] base_freq,
    input logic [7:0] q_factor,
    input logic [15:0] mod_signal,
    output logic [2:0] cal_done_flags,
    output logic signed [15:0] audio_out
);
    logic signed [15:0] out_l, out_m, out_h;
    logic [15:0] f_l, f_m, f_h;

    assign f_l = base_freq + mod_signal[7:0];
    assign f_m = base_freq + mod_signal[9:2];
    assign f_h = base_freq + mod_signal[11:4];

    helmholtz_resonator low (
        .clk(clk), .rst(rst), .calibrate(calibrate),
        .audio_in(audio_in), .target_freq(f_l), .q_factor(q_factor),
        .cal_done(cal_done_flags[0]), .audio_out(out_l)
    );

    helmholtz_resonator mid (
        .clk(clk), .rst(rst), .calibrate(calibrate),
        .audio_in(audio_in), .target_freq(f_m), .q_factor(q_factor),
        .cal_done(cal_done_flags[1]), .audio_out(out_m)
    );

    helmholtz_resonator high (
        .clk(clk), .rst(rst), .calibrate(calibrate),
        .audio_in(audio_in), .target_freq(f_h), .q_factor(q_factor),
        .cal_done(cal_done_flags[2]), .audio_out(out_h)
    );

    assign audio_out = (out_l >>> 2) + (out_m >>> 2) + (out_h >>> 2);
endmodule