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
    input wire [p_address_width-1:0]   i_addr,
    input wire [p_data_width-1:0]      i_data_in,
    input wire                         i_read_write_enable,
    input wire                         i_capture_pulse,

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
reg  secure_sync_ff1;
reg  secure_sync_ff2;

wire heater_full_w;
wire heater_medium_w;
wire heater_low_w;
wire aircon_full_w;
wire aircon_medium_w;
wire aircon_low_w;
wire fan_w;
wire [2:0] state_w;

security_module #(
    .p_address_width(p_address_width),
    .p_data_width   (p_data_width),
    .p_unlock_code_0(p_unlock_code_0),
    .p_unlock_code_1(p_unlock_code_1)
) u_security_module (
    .i_clk              (i_capture_pulse),
    .i_rst              (i_rst),
    .i_addr             (i_addr),
    .i_data_in          (i_data_in),
    .i_read_write_enable(i_read_write_enable),
    .o_secure_enable    (secure_enable_capture)
);

always @(posedge i_clk or negedge i_rst) begin
    if (!i_rst) begin
        secure_sync_ff1 <= 1'b0;
        secure_sync_ff2 <= 1'b0;
    end else begin
        secure_sync_ff1 <= secure_enable_capture;
        secure_sync_ff2 <= secure_sync_ff1;
    end
end

thermostat u_thermostat (
    .i_temp_feedback(i_temp_feedback),
    .i_fan_on       (i_fan_on),
    .i_enable       (secure_sync_ff2),
    .i_fault        (i_fault),
    .i_clr          (i_clr),
    .i_clk          (i_clk),
    .i_rst          (i_rst),
    .o_heater_full  (heater_full_w),
    .o_heater_medium(heater_medium_w),
    .o_heater_low   (heater_low_w),
    .o_aircon_full  (aircon_full_w),
    .o_aircon_medium(aircon_medium_w),
    .o_aircon_low   (aircon_low_w),
    .o_fan          (fan_w),
    .o_state        (state_w)
);

always @(*) begin
    o_heater_full   = heater_full_w;
    o_heater_medium = heater_medium_w;
    o_heater_low    = heater_low_w;
    o_aircon_full   = aircon_full_w;
    o_aircon_medium = aircon_medium_w;
    o_aircon_low    = aircon_low_w;
    o_fan           = fan_w;
    o_state         = state_w;
end

endmodule
