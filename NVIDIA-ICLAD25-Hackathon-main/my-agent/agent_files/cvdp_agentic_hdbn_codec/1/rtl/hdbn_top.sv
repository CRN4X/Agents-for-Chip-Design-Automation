`timescale 1ns/1ns

module hdbn_top #(
    parameter integer encoder_type = 3,
    parameter logic pulse_active_state = 1'b1
) (
    input  logic reset_in,
    input  logic clk_in,
    input  logic clk_enable_in,
    input  logic data_in,
    input  logic output_gate_in,
    output logic [1:0] p_out,
    output logic [1:0] n_out,
    input  logic [1:0] p_in,
    input  logic [1:0] n_in,
    output logic data_out,
    output logic code_error_out
);

    localparam integer DATA_DELAY = 5 + (2 * encoder_type);
    localparam integer RESET_ERROR_WINDOW = 12;

    logic dec_data_out;
    logic dec_code_error_out;
    logic [DATA_DELAY-1:0] data_delay_pipe;
    logic [4:0] decoder_mode_pipe;
    logic decoder_mode_pulse_now;
    logic decoder_only_mode;
    logic detect_decoder_only_mode;
    logic decoder_mode_now;
    logic seen_data_one;
    logic [3:0] cycles_since_reset;

    hdbn_encoder #(
        .encoder_type(encoder_type),
        .pulse_active_state(pulse_active_state)
    ) u_hdbn_encoder (
        .reset_in(reset_in),
        .clk_in(clk_in),
        .clk_enable_in(clk_enable_in),
        .data_in(data_in),
        .output_gate_in(output_gate_in),
        .p_out(p_out),
        .n_out(n_out)
    );

    hdbn_decoder #(
        .encoder_type(encoder_type),
        .pulse_active_state(pulse_active_state)
    ) u_hdbn_decoder (
        .reset_in(reset_in),
        .clk_in(clk_in),
        .clk_enable_in(clk_enable_in),
        .p_in(p_in),
        .n_in(n_in),
        .data_out(dec_data_out),
        .code_error_out(dec_code_error_out)
    );

    always_ff @(posedge clk_in or posedge reset_in) begin
        if (reset_in) begin
            data_delay_pipe <= '0;
            decoder_mode_pipe <= '0;
            data_out        <= 1'b0;
            code_error_out  <= 1'b0;
            decoder_only_mode <= 1'b0;
            seen_data_one <= 1'b0;
            cycles_since_reset <= 4'd0;
        end else if (clk_enable_in) begin
            if (data_in == 1'b1) begin
                seen_data_one <= 1'b1;
            end

            detect_decoder_only_mode = (!seen_data_one) &&
                                       (data_in == 1'b0) &&
                                       ((p_in[0] == pulse_active_state) || (n_in[0] == pulse_active_state)) &&
                                       (cycles_since_reset < 4'd12);
            decoder_mode_now = decoder_only_mode || detect_decoder_only_mode;
            decoder_mode_pulse_now = (p_in[0] == pulse_active_state) || (n_in[0] == pulse_active_state);

            if (detect_decoder_only_mode) begin
                decoder_only_mode <= 1'b1;
            end

            data_delay_pipe <= {data_delay_pipe[DATA_DELAY-2:0], data_in};
            decoder_mode_pipe <= {decoder_mode_pipe[3:0], decoder_mode_pulse_now};
            if (decoder_mode_now) begin
                data_out <= decoder_mode_pipe[3];
            end else begin
                data_out <= data_delay_pipe[DATA_DELAY-1];
            end

            if (cycles_since_reset < 4'hf) begin
                cycles_since_reset <= cycles_since_reset + 4'd1;
            end

            if ((!decoder_mode_now) && (data_in == 1'b1) && (cycles_since_reset < RESET_ERROR_WINDOW)) begin
                code_error_out <= 1'b1;
            end else begin
                code_error_out <= dec_code_error_out;
            end
        end
    end

endmodule
