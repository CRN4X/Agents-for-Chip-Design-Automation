`timescale 1ns/1ns

module hdbn_decoder #(
    parameter integer encoder_type = 3,
    parameter logic pulse_active_state = 1'b1
) (
    input  logic reset_in,
    input  logic clk_in,
    input  logic clk_enable_in,
    input  logic [1:0] p_in,
    input  logic [1:0] n_in,
    output logic data_out,
    output logic code_error_out
);

    localparam integer DECODER_DELAY = 5;
    logic pulse_now;
    logic [DECODER_DELAY-1:0] pulse_pipe;

    always_ff @(posedge clk_in or posedge reset_in) begin
        if (reset_in) begin
            pulse_pipe      <= '0;
            data_out       <= 1'b0;
            code_error_out <= 1'b0;
        end else if (clk_enable_in) begin
            pulse_now  = ((p_in[0] == pulse_active_state) || (n_in[0] == pulse_active_state));
            pulse_pipe <= {pulse_pipe[DECODER_DELAY-2:0], pulse_now};
            data_out   <= pulse_pipe[DECODER_DELAY-1];
            if ((p_in[0] == pulse_active_state) && (n_in[0] == pulse_active_state)) begin
                code_error_out <= 1'b1;
            end else begin
                code_error_out <= 1'b0;
            end
        end
    end

endmodule
