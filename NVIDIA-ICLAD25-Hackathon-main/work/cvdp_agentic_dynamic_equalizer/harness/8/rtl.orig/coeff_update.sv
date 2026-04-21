module coeff_update #(
    parameter TAP_NUM     = 7,
    parameter DATA_WIDTH  = 16,
    parameter COEFF_WIDTH = 16,
    parameter MU          = 15  // Learning rate = 2^(-15)
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic signed [DATA_WIDTH-1:0]  data_real [TAP_NUM-1:0],
    input  logic signed [DATA_WIDTH-1:0]  data_imag [TAP_NUM-1:0],
    input  logic signed [DATA_WIDTH-1:0]  error_real,
    input  logic signed [DATA_WIDTH-1:0]  error_imag,
    output logic signed [COEFF_WIDTH-1:0] coeff_real [TAP_NUM-1:0],
    output logic signed [COEFF_WIDTH-1:0] coeff_imag [TAP_NUM-1:0]
);
    // Internal signals
    logic signed [DATA_WIDTH+COEFF_WIDTH:0] coeff_real_aux [TAP_NUM-1:0];
    logic signed [DATA_WIDTH+COEFF_WIDTH:0] coeff_imag_aux [TAP_NUM-1:0];
    logic signed [DATA_WIDTH+COEFF_WIDTH:0] coeff_real_rnd [TAP_NUM-1:0];
    logic signed [DATA_WIDTH+COEFF_WIDTH:0] coeff_imag_rnd [TAP_NUM-1:0];
    logic signed [COEFF_WIDTH-1:0] coeff_real_acc [TAP_NUM-1:0];
    logic signed [COEFF_WIDTH-1:0] coeff_imag_acc [TAP_NUM-1:0];
    // Update of LMS coefficients
    always_comb begin
        for (int i = 0; i < TAP_NUM; ++i) begin
            coeff_real_aux[i] = (error_real * data_real[i] + error_imag * data_imag[i]);
            coeff_real_rnd[i] = coeff_real_aux[i] <<< 4;
            coeff_real_acc[i] = coeff_real_rnd[i][DATA_WIDTH+COEFF_WIDTH -: DATA_WIDTH] >>> MU;
            coeff_imag_aux[i] = (error_imag * data_real[i] - error_real * data_imag[i]);
            coeff_imag_rnd[i] = coeff_imag_aux[i] <<< 4;
            coeff_imag_acc[i] = coeff_imag_rnd[i][DATA_WIDTH+COEFF_WIDTH -: DATA_WIDTH] >>> MU;
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < TAP_NUM; i++) begin
                if ((i == (TAP_NUM-1)/2)) begin
                    coeff_real[i] <= 16'h2000; // Initialize central tap to 1 in signed Q2.13
                    coeff_imag[i] <= 16'h0000;
                end else begin
                    coeff_real[i] <= '0;
                    coeff_imag[i] <= '0;
                end
            end
        end else begin
            for (int i = 0; i < TAP_NUM; i++) begin
                coeff_real[i] <= coeff_real[i] - coeff_real_acc[i];
                coeff_imag[i] <= coeff_imag[i] - coeff_imag_acc[i];
            end
        end
    end
endmodule