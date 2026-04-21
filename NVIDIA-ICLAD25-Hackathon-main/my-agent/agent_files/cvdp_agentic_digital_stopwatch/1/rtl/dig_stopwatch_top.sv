`timescale 1ns/1ns

module dig_stopwatch_top #(
    parameter integer CLK_FREQ = 50
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       start_stop,
    output logic [5:0] seconds,
    output logic [5:0] minutes,
    output logic       hour,
    output logic       second_pulse,
    output logic       minute_pulse,
    output logic       hour_pulse,
    output logic       beep
);

    localparam integer DIV_W = (CLK_FREQ <= 1) ? 1 : $clog2(CLK_FREQ);

    logic [DIV_W-1:0] div_count;
    logic             tick_1hz;

    assign tick_1hz = start_stop && ((CLK_FREQ <= 1) || (div_count == CLK_FREQ - 1));

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            div_count <= '0;
        end else begin
            if (start_stop) begin
                if (CLK_FREQ <= 1) begin
                    div_count <= '0;
                end else if (div_count == CLK_FREQ - 1) begin
                    div_count <= '0;
                end else begin
                    div_count <= div_count + {{(DIV_W-1){1'b0}}, 1'b1};
                end
            end
        end
    end

    dig_stopwatch u_dig_stopwatch (
        .clk         (clk),
        .reset       (reset),
        .start_stop  (start_stop),
        .tick_1hz    (tick_1hz),
        .seconds     (seconds),
        .minutes     (minutes),
        .hour        (hour),
        .second_pulse(second_pulse),
        .minute_pulse(minute_pulse),
        .hour_pulse  (hour_pulse),
        .beep        (beep)
    );

endmodule
