`timescale 1ns/1ns

module scrambler_descrambler #(
    parameter POLY_LENGTH = 31,
    parameter POLY_TAP    = 3,
    parameter WIDTH       = 16,
    parameter CHECK_MODE  = 0
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             bypass_scrambling,
    input  logic [WIDTH-1:0] data_in,
    input  logic             valid_in,
    output logic [WIDTH-1:0] data_out,
    output logic [1:0]       valid_out,
    output logic [31:0]      bit_count
);

logic [WIDTH-1:0] prbs_data_out;
logic [WIDTH-1:0] bypass_data_d;
logic [WIDTH-1:0] check_data_d;
logic [1:0]       valid_d1;
logic [1:0]       valid_d2;

prbs_gen_check #(
    .CHECK_MODE (CHECK_MODE),
    .POLY_LENGTH(POLY_LENGTH),
    .POLY_TAP   (POLY_TAP),
    .WIDTH      (WIDTH)
) u_prbs_gen_check (
    .clk     (clk),
    .rst     (rst),
    .data_in (data_in),
    .data_out(prbs_data_out)
);

always_ff @(posedge clk) begin
    if (rst) begin
        bypass_data_d <= '0;
        check_data_d  <= '0;
        valid_d1      <= 2'b00;
        valid_d2      <= 2'b00;
        bit_count     <= 32'd0;
    end else begin
        bypass_data_d <= data_in;
        check_data_d  <= prbs_data_out;
        valid_d1      <= valid_in ? 2'b01 : 2'b00;
        valid_d2      <= valid_d1;

        if (valid_in) begin
            bit_count <= bit_count + WIDTH;
        end
    end
end

always_comb begin
    data_out  = '0;
    valid_out = 2'b00;

    if (bypass_scrambling) begin
        data_out  = bypass_data_d;
        valid_out = valid_d1;
    end else if (CHECK_MODE == 0) begin
        data_out  = prbs_data_out;
        valid_out = valid_d1;
    end else begin
        data_out  = check_data_d;
        valid_out = valid_d2;
    end
end

endmodule
