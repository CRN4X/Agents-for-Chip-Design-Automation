module helmholtz_resonator #(
    parameter WIDTH = 16,
    parameter FRAC_BITS = 8,
    parameter CAL_TOLERANCE = 10 // 10% tolerance
)(
    input logic clk,
    input logic rst,
    input logic calibrate,
    input logic signed [WIDTH-1:0] audio_in,
    input logic [15:0] target_freq,
    input logic [7:0] q_factor,
    output logic cal_done,
    output logic signed [WIDTH-1:0] audio_out
);

    typedef enum logic [1:0] { IDLE, CALIBRATING, DONE, PROCESSING } state_t;
    state_t state, next_state;

    logic [15:0] current_freq;
    logic signed [15:0] freq_error;
    logic [15:0] calibration_factor;

    logic signed [WIDTH-1:0] x, y, fb;
    logic signed [WIDTH-1:0] coeff_a, coeff_b;

    // Frequency error
    always_comb begin
        if (target_freq > current_freq)
            freq_error = target_freq - current_freq;
        else
            freq_error = current_freq - target_freq;
    end

    // State machine and calibration logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            calibration_factor <= 16'd128;
            current_freq <= 16'd100;
            cal_done <= 0;
        end else begin
            state <= next_state;

            if (state == CALIBRATING) begin
                if (current_freq < target_freq)
                    calibration_factor <= calibration_factor + 1;
                else if (current_freq > target_freq)
                    calibration_factor <= calibration_factor - 1;

                current_freq <= (calibration_factor * 2);
            end

            cal_done <= (state == DONE);
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (calibrate) next_state = CALIBRATING;
            CALIBRATING: if ((freq_error * 100 / target_freq) < CAL_TOLERANCE) next_state = DONE;
            DONE: if (!calibrate) next_state = PROCESSING;
            PROCESSING: if (calibrate) next_state = CALIBRATING;
        endcase
    end

    always_comb begin
        coeff_a = calibration_factor;
        coeff_b = q_factor;
    end

    // Filtering operation
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            x <= 0; y <= 0; fb <= 0;
        end else if (state == PROCESSING) begin
            x <= audio_in - (fb * coeff_b >>> FRAC_BITS);
            y <= (x * coeff_a >>> FRAC_BITS);
            fb <= y;
        end else begin
            x <= 0; y <= 0; fb <= 0;
        end
    end

    assign audio_out = y;
endmodule


module modulator (
    input logic clk,
    input logic rst,
    input logic enable,
    output logic [15:0] mod_signal
);
    logic [15:0] counter;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) counter <= 0;
        else if (enable) counter <= counter + 1;
    end

    assign mod_signal = counter;
endmodule


module soft_clipper #(
    parameter WIDTH = 16
)(
    input logic signed [WIDTH-1:0] in_signal,
    output logic signed [WIDTH-1:0] out_signal
);
    always_comb begin
        if (in_signal > 20480)
            out_signal = 20480;
        else if (in_signal < -20480)
            out_signal = -20480;
        else
            out_signal = in_signal - ((in_signal * in_signal) >>> 10);
    end
endmodule


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


module helmholtz_top_module (
    input logic clk,
    input logic rst,
    input logic calibrate,
    input logic signed [15:0] audio_in,
    input logic [15:0] base_freq,
    input logic [7:0] q_factor,
    input logic mod_enable,
    output logic [2:0] cal_done_flags,
    output logic signed [15:0] audio_out
);

    logic [15:0] mod_signal;
    logic signed [15:0] resonated_signal, clipped_signal;

    modulator mod (
        .clk(clk),
        .rst(rst),
        .enable(mod_enable),
        .mod_signal(mod_signal)
    );

    resonator_bank bank (
        .clk(clk),
        .rst(rst),
        .calibrate(calibrate),
        .audio_in(audio_in),
        .base_freq(base_freq),
        .q_factor(q_factor),
        .mod_signal(mod_signal),
        .cal_done_flags(cal_done_flags),
        .audio_out(resonated_signal)
    );

    soft_clipper clip (
        .in_signal(resonated_signal),
        .out_signal(clipped_signal)
    );

    assign audio_out = clipped_signal;
endmodule


