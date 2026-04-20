module coeff_update #(
    parameter integer TAP_NUM = 7,
    parameter integer DATA_WIDTH = 16,
    parameter integer COEFF_WIDTH = 16,
    parameter integer MU = 15
) (
    input  wire                                  clk,
    input  wire                                  rst_n,
    input  wire signed [TAP_NUM*DATA_WIDTH-1:0] data_real,
    input  wire signed [TAP_NUM*DATA_WIDTH-1:0] data_imag,
    input  wire signed [DATA_WIDTH-1:0]         error_real,
    input  wire signed [DATA_WIDTH-1:0]         error_imag,
    output reg  signed [TAP_NUM*COEFF_WIDTH-1:0] coeff_real,
    output reg  signed [TAP_NUM*COEFF_WIDTH-1:0] coeff_imag
);

    localparam integer Q_FRAC = 13;
    localparam signed [COEFF_WIDTH-1:0] CENTER_TAP_INIT = (1 <<< Q_FRAC);

    integer i;
    integer center_idx;

    reg signed [COEFF_WIDTH-1:0] coeff_r [0:TAP_NUM-1];
    reg signed [COEFF_WIDTH-1:0] coeff_i [0:TAP_NUM-1];

    reg signed [DATA_WIDTH-1:0] data_r_i;
    reg signed [DATA_WIDTH-1:0] data_i_i;

    reg signed [2*DATA_WIDTH-1:0] grad_rr;
    reg signed [2*DATA_WIDTH-1:0] grad_ii;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            center_idx = TAP_NUM / 2;
            for (i = 0; i < TAP_NUM; i = i + 1) begin
                coeff_r[i] <= (i == center_idx) ? CENTER_TAP_INIT : '0;
                coeff_i[i] <= '0;
            end
        end else begin
            for (i = 0; i < TAP_NUM; i = i + 1) begin
                data_r_i = data_real[i*DATA_WIDTH +: DATA_WIDTH];
                data_i_i = data_imag[i*DATA_WIDTH +: DATA_WIDTH];

                grad_rr = error_real * data_r_i;
                grad_ii = error_imag * data_i_i;

                coeff_r[i] <= coeff_r[i] + (grad_rr >>> MU);
                coeff_i[i] <= coeff_i[i] + (grad_ii >>> MU);
            end
        end
    end

    always @(*) begin
        for (i = 0; i < TAP_NUM; i = i + 1) begin
            coeff_real[i*COEFF_WIDTH +: COEFF_WIDTH] = coeff_r[i];
            coeff_imag[i*COEFF_WIDTH +: COEFF_WIDTH] = coeff_i[i];
        end
    end

endmodule
