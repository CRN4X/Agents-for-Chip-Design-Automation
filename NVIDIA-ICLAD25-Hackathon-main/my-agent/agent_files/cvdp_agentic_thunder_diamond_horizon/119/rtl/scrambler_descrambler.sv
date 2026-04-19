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

logic [WIDTH-1:0] prbs_data;
logic [WIDTH-1:0] data_in_d1;
logic [WIDTH-1:0] prbs_data_in;
logic             valid_d1;

assign prbs_data_in = (CHECK_MODE == 0) ? data_in_d1 : data_in;

prbs_gen_check #(
    .CHECK_MODE(CHECK_MODE),
    .POLY_LENGTH(POLY_LENGTH),
    .POLY_TAP(POLY_TAP),
    .WIDTH(WIDTH)
) u_prbs_gen_check (
    .clk(clk),
    .rst(rst),
    .data_in(prbs_data_in),
    .data_out(prbs_data)
);

always_ff @(posedge clk) begin
    if (rst) begin
        data_in_d1 <= '0;
        valid_d1   <= 1'b0;
        data_out   <= '0;
        valid_out  <= 2'b00;
        bit_count  <= 32'd0;
    end else begin
        data_in_d1 <= data_in;
        valid_d1   <= valid_in;

        if (bypass_scrambling) begin
            valid_out <= valid_in ? 2'b01 : 2'b00;
            if (valid_in) begin
                data_out <= data_in;
            end
        end else if (CHECK_MODE == 0) begin
            valid_out <= valid_in ? 2'b01 : 2'b00;
            if (valid_in) begin
                data_out <= data_in;
            end
        end else begin
            valid_out <= valid_d1 ? 2'b01 : 2'b00;
            if (valid_d1) begin
                data_out <= prbs_data;
            end
        end

        if (valid_in) begin
            bit_count <= bit_count + WIDTH;
        end
    end
end

endmodule
