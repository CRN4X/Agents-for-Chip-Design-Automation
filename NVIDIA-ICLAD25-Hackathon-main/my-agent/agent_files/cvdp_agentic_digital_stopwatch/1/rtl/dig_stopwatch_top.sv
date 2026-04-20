module dig_stopwatch_top #(
    parameter integer CLK_FREQ = 50_000_000
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

    dig_stopwatch #(
        .CLK_FREQ(CLK_FREQ)
    ) u_dig_stopwatch (
        .clk(clk),
        .reset(reset),
        .start_stop(start_stop),
        .seconds(seconds),
        .minutes(minutes),
        .hour(hour),
        .second_pulse(second_pulse),
        .minute_pulse(minute_pulse),
        .hour_pulse(hour_pulse),
        .beep(beep)
    );

endmodule
