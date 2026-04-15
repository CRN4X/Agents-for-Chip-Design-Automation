module dynamic_equalizer #(
    parameter TAP_NUM     = 7,
    parameter DATA_WIDTH  = 16,
    parameter COEFF_WIDTH = 16,
    parameter MU          = 15  // Learning rate = 2^(-15)
)(
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic signed [DATA_WIDTH-1:0] data_in_real,
    input  logic signed [DATA_WIDTH-1:0] data_in_imag,
    output logic signed [DATA_WIDTH-1:0] data_out_real,
    output logic signed [DATA_WIDTH-1:0] data_out_imag
);

    // Input storage (shift register)
    logic signed [DATA_WIDTH-1:0] shift_real [TAP_NUM-1:0];
    logic signed [DATA_WIDTH-1:0] shift_imag [TAP_NUM-1:0];

    // Coefficients signals
    logic signed [COEFF_WIDTH-1:0] coeff_real [TAP_NUM-1:0];
    logic signed [COEFF_WIDTH-1:0] coeff_imag [TAP_NUM-1:0];

    // Saída temporária
    logic signed [DATA_WIDTH+COEFF_WIDTH:0] acc_real_rnd;
    logic signed [DATA_WIDTH+COEFF_WIDTH:0] acc_imag_rnd;
    logic signed [DATA_WIDTH+COEFF_WIDTH:0] acc_real;
    logic signed [DATA_WIDTH+COEFF_WIDTH:0] acc_imag;

    // Error
    logic signed [DATA_WIDTH-1:0] error_real;
    logic signed [DATA_WIDTH-1:0] error_imag;
 
    // Shift register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < TAP_NUM; i++) begin
                shift_real[i] <= '0;
                shift_imag[i] <= '0;
            end
        end else begin
            for (int i = TAP_NUM-1; i > 0; i--) begin
                shift_real[i] <= shift_real[i-1];
                shift_imag[i] <= shift_imag[i-1];
            end
            shift_real[0] <= data_in_real;
            shift_imag[0] <= data_in_imag;
        end
    end

    // Complex sum FIR
    always_comb begin
        acc_real = 0;
        acc_imag = 0;
        for (int i = 0; i < TAP_NUM; i++) begin
            acc_real += (shift_real[i] * coeff_real[i]) - (shift_imag[i] * coeff_imag[i]);
            acc_imag += (shift_real[i] * coeff_imag[i]) + (shift_imag[i] * coeff_real[i]);
        end
    end

    // Round the result
    assign acc_real_rnd = acc_real <<< 4;
    assign acc_imag_rnd = acc_imag <<< 4;

    assign data_out_real = acc_real_rnd[DATA_WIDTH+COEFF_WIDTH -: DATA_WIDTH];
    assign data_out_imag = acc_imag_rnd[DATA_WIDTH+COEFF_WIDTH -: DATA_WIDTH];

    // Error calculation
    error_calc #(
        .DATA_WIDTH (DATA_WIDTH)
    ) uu_error_calc (
        .data_real    (data_out_real),
        .data_imag    (data_out_imag),
        .error_real   (error_real   ),
        .error_imag   (error_imag   )
    );

    // Update of coefficients
    coeff_update #(
        .TAP_NUM     (TAP_NUM    ),
        .DATA_WIDTH  (DATA_WIDTH ),
        .COEFF_WIDTH (COEFF_WIDTH),
        .MU          (MU         )
    ) uu_coeff_update (
        .clk        (clk       ),
        .rst_n      (rst_n     ),
        .data_real  (shift_real),
        .data_imag  (shift_imag),
        .error_real (error_real),
        .error_imag (error_imag),
        .coeff_real (coeff_real),
        .coeff_imag (coeff_imag)
    );
endmodule