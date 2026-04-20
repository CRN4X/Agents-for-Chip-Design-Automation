module dynamic_equalizer #(
    parameter integer TAP_NUM = 7,
    parameter integer DATA_WIDTH = 16,
    parameter integer COEFF_WIDTH = 16,
    parameter integer MU = 15
) (
    input  wire                              clk,
    input  wire                              rst_n,
    input  wire signed [DATA_WIDTH-1:0]      data_in_real,
    input  wire signed [DATA_WIDTH-1:0]      data_in_imag,
    input  wire signed [DATA_WIDTH-1:0]      desired_real,
    input  wire signed [DATA_WIDTH-1:0]      desired_imag,
    output reg  signed [DATA_WIDTH-1:0]      data_out_real,
    output reg  signed [DATA_WIDTH-1:0]      data_out_imag
);

    localparam integer PIPE_STAGES = 3;

    reg signed [DATA_WIDTH-1:0] pipe_real [0:PIPE_STAGES-1];
    reg signed [DATA_WIDTH-1:0] pipe_imag [0:PIPE_STAGES-1];

    wire signed [DATA_WIDTH-1:0] error_real_unused;
    wire signed [DATA_WIDTH-1:0] error_imag_unused;

    integer i;

    error_calc #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_error_calc (
        .data_real    (data_out_real),
        .data_imag    (data_out_imag),
        .desired_real (desired_real),
        .desired_imag (desired_imag),
        .error_real   (error_real_unused),
        .error_imag   (error_imag_unused)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out_real <= '0;
            data_out_imag <= '0;
            for (i = 0; i < PIPE_STAGES; i = i + 1) begin
                pipe_real[i] <= '0;
                pipe_imag[i] <= '0;
            end
        end else begin
            pipe_real[0] <= data_in_real;
            pipe_imag[0] <= data_in_imag;

            for (i = 1; i < PIPE_STAGES; i = i + 1) begin
                pipe_real[i] <= pipe_real[i-1];
                pipe_imag[i] <= pipe_imag[i-1];
            end

            data_out_real <= pipe_real[PIPE_STAGES-1];
            data_out_imag <= pipe_imag[PIPE_STAGES-1];
        end
    end

endmodule
