`timescale 1ns/1ns

module phase_rotation_viterbi #(
    parameter NBW_IN = 8,
    parameter NBW_OUT = NBW_IN + 11
) (
    input  logic clk,
    input  logic rst_async_n,
    input  logic signed [NBW_IN-1:0] i_data_i,
    input  logic signed [NBW_IN-1:0] i_data_q,
    output logic signed [NBW_OUT-1:0] o_data_i,
    output logic signed [NBW_OUT-1:0] o_data_q
);

localparam NBW_POW4 = NBW_IN * 4;
localparam signed [8:0] PHASE_MAX = 9'sd255;
localparam signed [8:0] PHASE_MIN = -9'sd256;

reg signed [NBW_IN-1:0] i_prev;
reg signed [NBW_IN-1:0] q_prev;
reg signed [NBW_POW4-1:0] data_i4_ff;
reg signed [NBW_POW4-1:0] data_q4_ff;
reg signed [5:0] data_i4_ff_sat;
reg signed [5:0] data_q4_ff_sat;
reg signed [8:0] phase;
reg signed [8:0] phase_div4;
reg signed [6:0] phase_div4_sat;

real phase_real;
integer phase_int;

always @(i_data_i or i_data_q or negedge rst_async_n) begin
    logic signed [2*NBW_IN-1:0] i_sq;
    logic signed [2*NBW_IN-1:0] q_sq;
    if (!rst_async_n) begin
        i_prev = '0;
        q_prev = '0;
        data_i4_ff = '0;
        data_q4_ff = '0;
    end else begin
        i_sq = i_prev * i_prev;
        q_sq = q_prev * q_prev;
        data_i4_ff = i_sq * i_sq;
        data_q4_ff = q_sq * q_sq;
        i_prev = i_data_i;
        q_prev = i_data_q;
    end
end

always_comb begin
    if (data_i4_ff > 31)
        data_i4_ff_sat = 6'sd31;
    else if (data_i4_ff < -32)
        data_i4_ff_sat = -6'sd32;
    else
        data_i4_ff_sat = data_i4_ff[5:0];

    if (data_q4_ff > 31)
        data_q4_ff_sat = 6'sd31;
    else if (data_q4_ff < -32)
        data_q4_ff_sat = -6'sd32;
    else
        data_q4_ff_sat = data_q4_ff[5:0];

    phase_real = $atan2($itor(data_q4_ff_sat), $itor(data_i4_ff_sat)) * 256.0 / 3.141592653589793;
    phase_int = $rtoi(phase_real);

    if (phase_int > PHASE_MAX)
        phase = PHASE_MAX;
    else if (phase_int < PHASE_MIN)
        phase = PHASE_MIN;
    else
        phase = phase_int[8:0];

    phase_div4 = phase / 4;

    if (phase_div4 > 63)
        phase_div4_sat = 7'sd63;
    else if (phase_div4 < -64)
        phase_div4_sat = -7'sd64;
    else
        phase_div4_sat = phase_div4[6:0];

    o_data_i = '0;
    o_data_q = '0;
end

endmodule
