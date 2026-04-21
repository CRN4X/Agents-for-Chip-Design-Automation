`timescale 1ns/1ns

module hdbn_encoder #(
    parameter integer encoder_type = 3,
    parameter logic pulse_active_state = 1'b1
) (
    input  logic reset_in,
    input  logic clk_in,
    input  logic clk_enable_in,
    input  logic data_in,
    input  logic output_gate_in,
    output logic [1:0] p_out,
    output logic [1:0] n_out
);

    localparam logic PULSE_INACTIVE = ~pulse_active_state;

    integer zero_run_count;
    logic next_polarity;

    always_ff @(posedge clk_in or posedge reset_in) begin
        if (reset_in) begin
            p_out         <= 2'b00;
            n_out         <= 2'b00;
            p_out[0]      <= PULSE_INACTIVE;
            n_out[0]      <= PULSE_INACTIVE;
            zero_run_count <= 0;
            next_polarity <= 1'b1;
        end else if (clk_enable_in) begin
            p_out    <= 2'b00;
            n_out    <= 2'b00;
            p_out[0] <= PULSE_INACTIVE;
            n_out[0] <= PULSE_INACTIVE;

            if (output_gate_in) begin
                if (data_in || (zero_run_count >= (encoder_type - 1))) begin
                    if (next_polarity) begin
                        p_out[0] <= pulse_active_state;
                    end else begin
                        n_out[0] <= pulse_active_state;
                    end
                    next_polarity  <= ~next_polarity;
                    zero_run_count <= 0;
                end else begin
                    zero_run_count <= zero_run_count + 1;
                end
            end else begin
                zero_run_count <= 0;
            end
        end
    end

endmodule
