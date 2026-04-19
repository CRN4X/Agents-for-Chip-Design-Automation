module async_fifo #(
    parameter integer p_data_width = 32,
    parameter integer p_addr_width = 16
) (
    input  wire                    i_wr_clk,
    input  wire                    i_wr_rst_n,
    input  wire                    i_wr_en,
    input  wire [p_data_width-1:0] i_wr_data,
    output wire                    o_fifo_full,
    input  wire                    i_rd_clk,
    input  wire                    i_rd_rst_n,
    input  wire                    i_rd_en,
    output wire [p_data_width-1:0] o_rd_data,
    output wire                    o_fifo_empty
);

    wire [p_addr_width-1:0] w_wr_bin_addr;
    wire [p_addr_width:0]   w_wr_grey_addr;
    wire [p_addr_width:0]   w_wr_ptr_sync;
    wire [p_addr_width-1:0] w_rd_bin_addr;
    wire [p_addr_width:0]   w_rd_grey_addr;
    wire [p_addr_width:0]   w_rd_ptr_sync;

    read_to_write_pointer_sync #(
        .p_addr_width(p_addr_width)
    ) read_to_write_pointer_sync_inst (
        .i_wr_clk(i_wr_clk),
        .i_wr_rst_n(i_wr_rst_n),
        .i_rd_grey_addr(w_rd_grey_addr),
        .o_rd_ptr_sync(w_rd_ptr_sync)
    );

    write_to_read_pointer_sync #(
        .p_addr_width(p_addr_width)
    ) write_to_read_pointer_sync_inst (
        .i_rd_clk(i_rd_clk),
        .i_rd_rst_n(i_rd_rst_n),
        .i_wr_grey_addr(w_wr_grey_addr),
        .o_wr_ptr_sync(w_wr_ptr_sync)
    );

    wptr_full #(
        .p_addr_width(p_addr_width)
    ) wptr_full_inst (
        .i_wr_clk(i_wr_clk),
        .i_wr_rst_n(i_wr_rst_n),
        .i_wr_en(i_wr_en),
        .i_rd_ptr_sync(w_rd_ptr_sync),
        .o_fifo_full(o_fifo_full),
        .o_wr_bin_addr(w_wr_bin_addr),
        .o_wr_grey_addr(w_wr_grey_addr)
    );

    fifo_memory #(
        .p_data_width(p_data_width),
        .p_addr_width(p_addr_width)
    ) fifo_memory_inst (
        .i_wr_clk(i_wr_clk),
        .i_wr_clk_en(i_wr_en),
        .i_wr_addr(w_wr_bin_addr),
        .i_wr_data(i_wr_data),
        .i_wr_full(o_fifo_full),
        .i_rd_clk(i_rd_clk),
        .i_rd_clk_en(i_rd_en),
        .i_rd_addr(w_rd_bin_addr),
        .o_rd_data(o_rd_data)
    );

    rptr_empty #(
        .p_addr_width(p_addr_width)
    ) rptr_empty_inst (
        .i_rd_clk(i_rd_clk),
        .i_rd_rst_n(i_rd_rst_n),
        .i_rd_en(i_rd_en),
        .i_wr_ptr_sync(w_wr_ptr_sync),
        .o_fifo_empty(o_fifo_empty),
        .o_rd_bin_addr(w_rd_bin_addr),
        .o_rd_grey_addr(w_rd_grey_addr)
    );

endmodule

module fifo_memory #(
    parameter integer p_data_width = 32,
    parameter integer p_addr_width = 16
) (
    input  wire                    i_wr_clk,
    input  wire                    i_wr_clk_en,
    input  wire [p_addr_width-1:0] i_wr_addr,
    input  wire [p_data_width-1:0] i_wr_data,
    input  wire                    i_wr_full,
    input  wire                    i_rd_clk,
    input  wire                    i_rd_clk_en,
    input  wire [p_addr_width-1:0] i_rd_addr,
    output reg  [p_data_width-1:0] o_rd_data
);

    localparam integer LP_DEPTH = (1 << p_addr_width);
    reg [p_data_width-1:0] mem [0:LP_DEPTH-1];

    always @(posedge i_wr_clk) begin
        if (i_wr_clk_en && !i_wr_full) begin
            mem[i_wr_addr] <= i_wr_data;
        end
    end

    always @(posedge i_rd_clk) begin
        if (i_rd_clk_en) begin
            o_rd_data <= mem[i_rd_addr];
        end
    end

endmodule

module read_to_write_pointer_sync #(
    parameter integer p_addr_width = 16
) (
    input  wire                    i_wr_clk,
    input  wire                    i_wr_rst_n,
    input  wire [p_addr_width:0]   i_rd_grey_addr,
    output reg  [p_addr_width:0]   o_rd_ptr_sync
);

    reg [p_addr_width:0] r_sync_ff1;

    always @(posedge i_wr_clk or negedge i_wr_rst_n) begin
        if (!i_wr_rst_n) begin
            r_sync_ff1   <= {(p_addr_width+1){1'b0}};
            o_rd_ptr_sync <= {(p_addr_width+1){1'b0}};
        end else begin
            r_sync_ff1   <= i_rd_grey_addr;
            o_rd_ptr_sync <= r_sync_ff1;
        end
    end

endmodule

module write_to_read_pointer_sync #(
    parameter integer p_addr_width = 16
) (
    input  wire                    i_rd_clk,
    input  wire                    i_rd_rst_n,
    input  wire [p_addr_width:0]   i_wr_grey_addr,
    output reg  [p_addr_width:0]   o_wr_ptr_sync
);

    reg [p_addr_width:0] r_sync_ff1;

    always @(posedge i_rd_clk or negedge i_rd_rst_n) begin
        if (!i_rd_rst_n) begin
            r_sync_ff1   <= {(p_addr_width+1){1'b0}};
            o_wr_ptr_sync <= {(p_addr_width+1){1'b0}};
        end else begin
            r_sync_ff1   <= i_wr_grey_addr;
            o_wr_ptr_sync <= r_sync_ff1;
        end
    end

endmodule

module wptr_full #(
    parameter integer p_addr_width = 16
) (
    input  wire                  i_wr_clk,
    input  wire                  i_wr_rst_n,
    input  wire                  i_wr_en,
    input  wire [p_addr_width:0] i_rd_ptr_sync,
    output reg                   o_fifo_full,
    output wire [p_addr_width-1:0] o_wr_bin_addr,
    output reg  [p_addr_width:0] o_wr_grey_addr
);

    reg  [p_addr_width:0] r_wr_bin_ptr;
    wire [p_addr_width:0] w_wr_bin_next;
    wire [p_addr_width:0] w_wr_grey_next;
    wire                  w_full_next;

    assign o_wr_bin_addr = r_wr_bin_ptr[p_addr_width-1:0];
    assign w_wr_bin_next = r_wr_bin_ptr + {{p_addr_width{1'b0}}, (i_wr_en && !o_fifo_full)};
    assign w_wr_grey_next = (w_wr_bin_next >> 1) ^ w_wr_bin_next;
    assign w_full_next = (w_wr_grey_next == {~i_rd_ptr_sync[p_addr_width:p_addr_width-1], i_rd_ptr_sync[p_addr_width-2:0]});

    always @(posedge i_wr_clk or negedge i_wr_rst_n) begin
        if (!i_wr_rst_n) begin
            r_wr_bin_ptr <= {(p_addr_width+1){1'b0}};
            o_wr_grey_addr <= {(p_addr_width+1){1'b0}};
            o_fifo_full <= 1'b0;
        end else begin
            r_wr_bin_ptr <= w_wr_bin_next;
            o_wr_grey_addr <= w_wr_grey_next;
            o_fifo_full <= w_full_next;
        end
    end

endmodule

module rptr_empty #(
    parameter integer p_addr_width = 16
) (
    input  wire                    i_rd_clk,
    input  wire                    i_rd_rst_n,
    input  wire                    i_rd_en,
    input  wire [p_addr_width:0]   i_wr_ptr_sync,
    output reg                     o_fifo_empty,
    output wire [p_addr_width-1:0] o_rd_bin_addr,
    output reg  [p_addr_width:0]   o_rd_grey_addr
);

    reg  [p_addr_width:0] r_rd_bin_ptr;
    wire [p_addr_width:0] w_rd_bin_next;
    wire [p_addr_width:0] w_rd_grey_next;
    wire                  w_empty_next;

    assign o_rd_bin_addr = r_rd_bin_ptr[p_addr_width-1:0];
    assign w_rd_bin_next = r_rd_bin_ptr + {{p_addr_width{1'b0}}, (i_rd_en && !o_fifo_empty)};
    assign w_rd_grey_next = (w_rd_bin_next >> 1) ^ w_rd_bin_next;
    assign w_empty_next = (w_rd_grey_next == i_wr_ptr_sync);

    always @(posedge i_rd_clk or negedge i_rd_rst_n) begin
        if (!i_rd_rst_n) begin
            r_rd_bin_ptr <= {(p_addr_width+1){1'b0}};
            o_rd_grey_addr <= {(p_addr_width+1){1'b0}};
            o_fifo_empty <= 1'b1;
        end else begin
            r_rd_bin_ptr <= w_rd_bin_next;
            o_rd_grey_addr <= w_rd_grey_next;
            o_fifo_empty <= w_empty_next;
        end
    end

endmodule
