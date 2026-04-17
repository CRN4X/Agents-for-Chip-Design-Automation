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