`timescale 1ns/1ns

module thermostat_secure_top  #(
    parameter p_address_width = 8,
    parameter p_data_width = 8,
    parameter p_unlock_code_0 = 8'hAB,
    parameter p_unlock_code_1 = 8'hCD
) (
    input wire [5:0] i_temp_feedback,
    input wire i_fan_on,
    input wire i_fault,
    input wire i_clr,
    input wire i_clk,
    input wire i_rst,
    input wire [p_address_width-1:0] i_addr,
    input wire [p_data_width-1:0] i_data_in,
    input wire i_read_write_enable,
    input wire i_capture_pulse,

    output reg o_heater_full,
    output reg o_heater_medium,
    output reg o_heater_low,
    output reg o_aircon_full,
    output reg o_aircon_medium,
    output reg o_aircon_low,
    output reg o_fan,
    output reg [2:0] o_state
);

wire secure_enable_capture;
reg secure_enable_sync_ff1;
reg secure_enable_sync_ff2;

wire t_heater_full;
wire t_heater_medium;
wire t_heater_low;
wire t_aircon_full;
wire t_aircon_medium;
wire t_aircon_low;
wire t_fan;
wire [2:0] t_state;

security_module #(
    .p_address_width(p_address_width),
    .p_data_width(p_data_width),
    .p_unlock_code_0(p_unlock_code_0),
    .p_unlock_code_1(p_unlock_code_1)
) u_security_module (
    .i_capture_pulse(i_capture_pulse),
    .i_rst(i_rst),
    .i_addr(i_addr),
    .i_data_in(i_data_in),
    .i_read_write_enable(i_read_write_enable),
    .o_secure_enable(secure_enable_capture)
);

always @(posedge i_clk or negedge i_rst) begin
    if (!i_rst) begin
        secure_enable_sync_ff1 <= 1'b0;
        secure_enable_sync_ff2 <= 1'b0;
    end else begin
        secure_enable_sync_ff1 <= secure_enable_capture;
        secure_enable_sync_ff2 <= secure_enable_sync_ff1;
    end
end

thermostat u_thermostat (
    .i_temp_feedback(i_temp_feedback),
    .i_fan_on(i_fan_on),
    .i_enable(secure_enable_sync_ff2),
    .i_fault(i_fault),
    .i_clr(i_clr),
    .i_clk(i_clk),
    .i_rst(i_rst),
    .o_heater_full(t_heater_full),
    .o_heater_medium(t_heater_medium),
    .o_heater_low(t_heater_low),
    .o_aircon_full(t_aircon_full),
    .o_aircon_medium(t_aircon_medium),
    .o_aircon_low(t_aircon_low),
    .o_fan(t_fan),
    .o_state(t_state)
);

always @(*) begin
    o_heater_full = t_heater_full;
    o_heater_medium = t_heater_medium;
    o_heater_low = t_heater_low;
    o_aircon_full = t_aircon_full;
    o_aircon_medium = t_aircon_medium;
    o_aircon_low = t_aircon_low;
    o_fan = t_fan;
    o_state = t_state;
end

endmodule
