`timescale 1ns/1ps

module cic_decimator #(
    parameter int WIDTH = 16,
    parameter int RMAX = 2,
    parameter int M = 1,
    parameter int N = 2,
    parameter int REG_WIDTH = WIDTH + $clog2((RMAX * M) ** N)
) (
    input  logic                            clk,
    input  logic                            rst,
    input  logic signed [WIDTH-1:0]         input_tdata,
    input  logic                            input_tvalid,
    output logic                            input_tready,
    output logic signed [REG_WIDTH-1:0]     output_tdata,
    output logic                            output_tvalid,
    input  logic                            output_tready,
    input  logic [$clog2(RMAX+1)-1:0]       rate
);

    localparam int RATE_W = (RMAX > 1) ? $clog2(RMAX + 1) : 1;

    logic [RATE_W-1:0] rate_sat;
    logic [RATE_W-1:0] cycle_reg;

    logic signed [REG_WIDTH-1:0] integrator_reg [0:N-1];
    logic signed [REG_WIDTH-1:0] comb_reg       [0:N-1];
    logic signed [REG_WIDTH-1:0] delay_reg      [0:N-1][0:M-1];

    integer i;
    integer j;
    logic signed [REG_WIDTH-1:0] stage_in;
    logic signed [REG_WIDTH-1:0] stage_out;
    logic signed [REG_WIDTH-1:0] delayed_sample;

    always @(*) begin
        if (rate < 1) begin
            rate_sat = RATE_W'(1);
        end else if (rate > RMAX) begin
            rate_sat = RATE_W'(RMAX);
        end else begin
            rate_sat = rate;
        end
    end

    assign input_tready = (~output_tvalid) | output_tready;

    always @(posedge clk) begin
        if (rst) begin
            cycle_reg     <= '0;
            output_tdata  <= '0;
            output_tvalid <= 1'b0;

            for (i = 0; i < N; i = i + 1) begin
                integrator_reg[i] <= '0;
                comb_reg[i]       <= '0;
                for (j = 0; j < M; j = j + 1) begin
                    delay_reg[i][j] <= '0;
                end
            end
        end else begin
            if (output_tvalid && output_tready) begin
                output_tvalid <= 1'b0;
            end

            if (input_tvalid && input_tready) begin
                integrator_reg[0] <= integrator_reg[0] + $signed(input_tdata);
                for (i = 1; i < N; i = i + 1) begin
                    integrator_reg[i] <= integrator_reg[i] + integrator_reg[i-1];
                end

                if (cycle_reg == (rate_sat - RATE_W'(1))) begin
                    cycle_reg <= '0;
                    stage_in = integrator_reg[N-1];

                    for (i = 0; i < N; i = i + 1) begin
                        delayed_sample = delay_reg[i][M-1];
                        if (M > 1) begin
                            for (j = M-1; j > 0; j = j - 1) begin
                                delay_reg[i][j] <= delay_reg[i][j-1];
                            end
                        end
                        delay_reg[i][0] <= stage_in;

                        stage_out   = stage_in - delayed_sample;
                        comb_reg[i] <= stage_out;
                        stage_in    = stage_out;
                    end

                    output_tdata  <= stage_in;
                    output_tvalid <= 1'b1;
                end else begin
                    cycle_reg <= cycle_reg + RATE_W'(1);
                end
            end
        end
    end

endmodule
