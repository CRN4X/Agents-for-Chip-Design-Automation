module async_fifo
    #(
        parameter p_data_width = 32,
        parameter p_addr_width = 16
    )(
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
    wire [p_addr_width-1:0] w_rd_bin_addr;
    wire [p_addr_width:0]   w_wr_grey_addr;
    wire [p_addr_width:0]   w_rd_grey_addr;
    wire [p_addr_width:0]   w_rd_ptr_sync;
    wire [p_addr_width:0]   w_wr_ptr_sync;

    read_to_write_pointer_sync #(
        .p_addr_width(p_addr_width)
    ) u_read_to_write_pointer_sync (
        .i_wr_clk(i_wr_clk),
        .i_wr_rst_n(i_wr_rst_n),
        .i_rd_grey_addr(w_rd_grey_addr),
        .o_rd_ptr_sync(w_rd_ptr_sync)
    );

    write_to_read_pointer_sync #(
        .p_addr_width(p_addr_width)
    ) u_write_to_read_pointer_sync (
        .i_rd_clk(i_rd_clk),
        .i_rd_rst_n(i_rd_rst_n),
        .i_wr_grey_addr(w_wr_grey_addr),
        .o_wr_ptr_sync(w_wr_ptr_sync)
    );

    wptr_full #(
        .p_addr_width(p_addr_width)
    ) u_wptr_full (
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
    ) u_fifo_memory (
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
    ) u_rptr_empty (
        .i_rd_clk(i_rd_clk),
        .i_rd_rst_n(i_rd_rst_n),
        .i_rd_en(i_rd_en),
        .i_wr_ptr_sync(w_wr_ptr_sync),
        .o_fifo_empty(o_fifo_empty),
        .o_rd_bin_addr(w_rd_bin_addr),
        .o_rd_grey_addr(w_rd_grey_addr)
    );

endmodule
