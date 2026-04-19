`timescale 1ns/1ps

module async_filo #(
    parameter integer DATA_WIDTH = 16,
    parameter integer DEPTH = 8
) (
    input  wire                  w_clk,
    input  wire                  w_rst,
    input  wire                  push,
    input  wire                  r_clk,
    input  wire                  r_rst,
    input  wire                  pop,
    input  wire [DATA_WIDTH-1:0] w_data,
    output logic [DATA_WIDTH-1:0] r_data,
    output logic                 r_empty,
    output logic                 w_full
);

    localparam integer COUNT_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH + 1);
    localparam integer ADDR_W  = (DEPTH <= 2) ? 1 : $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [COUNT_W-1:0] w_count_bin;
    logic [COUNT_W-1:0] r_count_bin;
    logic [COUNT_W-1:0] w_ptr;
    logic [COUNT_W-1:0] r_ptr;

    logic [COUNT_W-1:0] wq1_rptr, wq2_rptr;
    logic [COUNT_W-1:0] rq1_wptr, rq2_wptr;

    logic [COUNT_W-1:0] w_count_sync;
    logic [COUNT_W-1:0] r_count_sync;
    logic [COUNT_W-1:0] r_base_count;

    function automatic [COUNT_W-1:0] bin2gray(input [COUNT_W-1:0] bin);
        bin2gray = (bin >> 1) ^ bin;
    endfunction

    function automatic [COUNT_W-1:0] gray2bin(input [COUNT_W-1:0] gray);
        integer i;
        begin
            gray2bin[COUNT_W-1] = gray[COUNT_W-1];
            for (i = COUNT_W - 2; i >= 0; i = i - 1) begin
                gray2bin[i] = gray2bin[i+1] ^ gray[i];
            end
        end
    endfunction

    always_comb begin
        w_count_sync = gray2bin(wq2_rptr);
        r_count_sync = gray2bin(rq2_wptr);

        w_full  = ((w_count_bin - w_count_sync) >= DEPTH);
        r_empty = (r_count_bin == r_count_sync);

        r_base_count = (r_count_sync > r_count_bin) ? r_count_sync : r_count_bin;
    end

    always_ff @(posedge w_clk) begin
        if (w_rst) begin
            w_count_bin <= '0;
            w_ptr       <= '0;
            wq1_rptr    <= '0;
            wq2_rptr    <= '0;
        end else begin
            wq1_rptr <= r_ptr;
            wq2_rptr <= wq1_rptr;

            if (push && !w_full) begin
                mem[w_count_bin[ADDR_W-1:0]] <= w_data;
                w_count_bin <= w_count_bin + 1'b1;
                w_ptr       <= bin2gray(w_count_bin + 1'b1);
            end
        end
    end

    always_ff @(posedge r_clk) begin
        logic [COUNT_W-1:0] pop_count;

        if (r_rst) begin
            r_count_bin <= '0;
            r_ptr       <= '0;
            rq1_wptr    <= '0;
            rq2_wptr    <= '0;
            r_data      <= '0;
        end else begin
            rq1_wptr <= w_ptr;
            rq2_wptr <= rq1_wptr;

            if (pop && !r_empty) begin
                pop_count = r_base_count - 1'b1;
                r_count_bin <= pop_count;
                r_ptr       <= bin2gray(pop_count);
                r_data      <= mem[pop_count[ADDR_W-1:0]];
            end else if (r_count_bin < r_count_sync) begin
                r_count_bin <= r_count_sync;
                r_ptr       <= bin2gray(r_count_sync);
            end
        end
    end

endmodule
