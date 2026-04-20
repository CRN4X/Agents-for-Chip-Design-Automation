`timescale 1ns/1ps

module cic_decimator #(
    parameter integer WIDTH = 16,
    parameter integer RMAX = 2,
    parameter integer M = 1,
    parameter integer N = 2,
    parameter integer REG_WIDTH = WIDTH + $clog2((RMAX * M) ** N)
) (
    input  wire                          clk,
    input  wire                          rst,
    input  wire signed [WIDTH-1:0]       input_tdata,
    input  wire                          input_tvalid,
    output wire                          input_tready,
    output wire signed [REG_WIDTH-1:0]   output_tdata,
    output wire                          output_tvalid,
    input  wire                          output_tready,
    input  wire [$clog2(RMAX+1)-1:0]     rate
);

    localparam integer RATE_W = (RMAX > 1) ? $clog2(RMAX + 1) : 1;

    reg [RATE_W-1:0] cycle_reg;

    reg signed [REG_WIDTH-1:0] integrator      [0:N-1];
    reg signed [REG_WIDTH-1:0] integrator_next [0:N-1];

    reg signed [REG_WIDTH-1:0] comb_value [0:N-1];
    reg signed [REG_WIDTH-1:0] comb_delay [0:N-1][0:M-1];

    wire [RATE_W-1:0] rate_clamped;
    wire [RATE_W-1:0] decim_limit;
    wire              input_fire;
    wire              output_fire;

    integer i;
    integer j;

    assign rate_clamped = (rate == 0) ? RATE_W'(1) : ((rate > RMAX) ? RATE_W'(RMAX) : rate[RATE_W-1:0]);
    assign decim_limit = rate_clamped - RATE_W'(1);

    assign input_tready = output_tready || (cycle_reg != {RATE_W{1'b0}});
    assign output_tvalid = input_tvalid && (cycle_reg == {RATE_W{1'b0}});

    assign input_fire = input_tvalid && input_tready;
    assign output_fire = output_tvalid && output_tready;

    always @(*) begin
        for (i = 0; i < N; i = i + 1) begin
            integrator_next[i] = integrator[i];
        end

        if (input_fire) begin
            integrator_next[0] = integrator[0] + $signed(input_tdata);
            for (i = 1; i < N; i = i + 1) begin
                integrator_next[i] = integrator[i] + integrator_next[i-1];
            end
        end
    end

    assign output_tdata = comb_value[N-1];

    always @(posedge clk) begin
        if (rst) begin
            cycle_reg <= {RATE_W{1'b0}};

            for (i = 0; i < N; i = i + 1) begin
                integrator[i] <= '0;
                comb_value[i] <= '0;
                for (j = 0; j < M; j = j + 1) begin
                    comb_delay[i][j] <= '0;
                end
            end
        end else begin
            for (i = 0; i < N; i = i + 1) begin
                integrator[i] <= integrator_next[i];
            end

            if (input_fire) begin
                if (cycle_reg >= decim_limit) begin
                    cycle_reg <= {RATE_W{1'b0}};
                end else begin
                    cycle_reg <= cycle_reg + RATE_W'(1);
                end
            end

            if (output_fire) begin
                reg signed [REG_WIDTH-1:0] stage_in;
                reg signed [REG_WIDTH-1:0] stage_out;

                stage_in = integrator_next[N-1];

                for (i = 0; i < N; i = i + 1) begin
                    stage_out = stage_in - comb_delay[i][M-1];
                    comb_value[i] <= stage_out;

                    comb_delay[i][0] <= stage_in;
                    for (j = 1; j < M; j = j + 1) begin
                        comb_delay[i][j] <= comb_delay[i][j-1];
                    end

                    stage_in = stage_out;
                end
            end
        end
    end

endmodule
