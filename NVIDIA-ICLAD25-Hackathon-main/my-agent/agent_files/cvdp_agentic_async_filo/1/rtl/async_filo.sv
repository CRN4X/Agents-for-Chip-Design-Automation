`timescale 1ns/1ps

module async_filo #(
    parameter integer DATA_WIDTH = 16,
    parameter integer DEPTH      = 8
) (
    input  wire                  w_clk,
    input  wire                  w_rst,
    input  wire                  push,
    input  wire                  r_clk,
    input  wire                  r_rst,
    input  wire                  pop,
    input  wire [DATA_WIDTH-1:0] w_data,
    output reg  [DATA_WIDTH-1:0] r_data,
    output wire                  r_empty,
    output wire                  w_full
);

    localparam integer ADDR_W = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    localparam integer PTR_W  = ADDR_W + 1;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    reg [PTR_W-1:0] w_count_bin;
    reg [PTR_W-1:0] w_ptr;
    reg [PTR_W-1:0] r_count_bin;
    reg [PTR_W-1:0] r_ptr;

    reg [PTR_W-1:0] wq1_rptr, wq2_rptr;
    reg [PTR_W-1:0] rq1_wptr, rq2_wptr;

    function [PTR_W-1:0] bin2gray;
        input [PTR_W-1:0] bin;
        begin
            bin2gray = (bin >> 1) ^ bin;
        end
    endfunction

    function [PTR_W-1:0] gray2bin;
        input [PTR_W-1:0] gray;
        integer i;
        begin
            gray2bin[PTR_W-1] = gray[PTR_W-1];
            for (i = PTR_W-2; i >= 0; i = i - 1) begin
                gray2bin[i] = gray2bin[i+1] ^ gray[i];
            end
        end
    endfunction

    wire [PTR_W-1:0] r_count_sync_w = gray2bin(wq2_rptr);
    wire [PTR_W-1:0] w_count_sync_r = gray2bin(rq2_wptr);

    wire [PTR_W-1:0] w_count_next = w_count_bin + 1'b1;
    wire [PTR_W-1:0] r_count_next = r_count_bin - 1'b1;

    wire do_push = push && !w_full;
    wire do_pop  = pop && !r_empty;

    wire [ADDR_W-1:0] w_addr = w_count_bin[ADDR_W-1:0];
    wire [ADDR_W-1:0] r_addr = r_count_next[ADDR_W-1:0];

    assign w_full  = (w_count_bin - r_count_sync_w) == DEPTH;
    assign r_empty = (r_count_bin == w_count_sync_r);

    always @(posedge w_clk) begin
        if (w_rst) begin
            w_count_bin <= {PTR_W{1'b0}};
            w_ptr       <= {PTR_W{1'b0}};
            wq1_rptr    <= {PTR_W{1'b0}};
            wq2_rptr    <= {PTR_W{1'b0}};
        end else begin
            wq1_rptr <= r_ptr;
            wq2_rptr <= wq1_rptr;

            if (do_push) begin
                mem[w_addr] <= w_data;
                w_count_bin <= w_count_next;
                w_ptr       <= bin2gray(w_count_next);
            end
        end
    end

    always @(posedge r_clk) begin
        if (r_rst) begin
            r_count_bin <= {PTR_W{1'b0}};
            r_ptr       <= {PTR_W{1'b0}};
            rq1_wptr    <= {PTR_W{1'b0}};
            rq2_wptr    <= {PTR_W{1'b0}};
            r_data      <= {DATA_WIDTH{1'b0}};
        end else begin
            rq1_wptr <= w_ptr;
            rq2_wptr <= rq1_wptr;

            if (w_count_sync_r > r_count_bin) begin
                r_count_bin <= w_count_sync_r;
                r_ptr       <= bin2gray(w_count_sync_r);
            end else if (do_pop) begin
                r_data      <= mem[r_addr];
                r_count_bin <= r_count_next;
                r_ptr       <= bin2gray(r_count_next);
            end
        end
    end

endmodule
