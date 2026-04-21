`timescale 1ns/1ns

module traffic_light_controller_top #(
    parameter integer SHORT_COUNT_PARAM = 10,
    parameter integer LONG_COUNT_PARAM  = 20
) (
    input  wire       i_clk,
    input  wire       i_rst_b,
    input  wire       i_vehicle_sensor_input,
    output wire [2:0] o_main,
    output wire [2:0] o_side
);

wire w_short_trigger;
wire w_long_trigger;
wire w_short_timer;
wire w_long_timer;

traffic_controller_fsm u_traffic_controller_fsm (
    .i_clk(i_clk),
    .i_rst_b(i_rst_b),
    .i_vehicle_sensor_input(i_vehicle_sensor_input),
    .i_short_timer(w_short_timer),
    .i_long_timer(w_long_timer),
    .o_short_trigger(w_short_trigger),
    .o_long_trigger(w_long_trigger),
    .o_main(o_main),
    .o_side(o_side)
);

timer_module #(
    .SHORT_COUNT(SHORT_COUNT_PARAM),
    .LONG_COUNT(LONG_COUNT_PARAM)
) u_timer_module (
    .i_clk(i_clk),
    .i_rst_b(i_rst_b),
    .i_short_trigger(w_short_trigger),
    .i_long_trigger(w_long_trigger),
    .o_short_timer(w_short_timer),
    .o_long_timer(w_long_timer)
);

endmodule
