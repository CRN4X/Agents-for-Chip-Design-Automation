module write_to_read_pointer_sync 
    #(
        parameter p_addr_width = 16  // Parameter to define the address width of the FIFO
    )(
        input  wire              i_rd_clk,         // Read clock
        input  wire              i_rd_rst_n,       // Read reset (active low)
        input  wire [p_addr_width:0] i_wr_grey_addr, // Input Gray-coded write address
        output reg  [p_addr_width:0] o_wr_ptr_sync // Output synchronized write pointer
        
    );

    // Internal register to hold the intermediate synchronized write pointer
    reg [p_addr_width:0] r_wr_ptr_ff;

    // Always block for synchronizing the write pointer to the read clock domain
    always @(posedge i_rd_clk or negedge i_rd_rst_n) 
    begin
        if (!i_rd_rst_n) begin
            // If reset is asserted (active low), reset the synchronized pointers to 0
            o_wr_ptr_sync <= {p_addr_width+1{1'b0}};
            r_wr_ptr_ff <= {p_addr_width+1{1'b0}};
        end else begin
            // If reset is not asserted, synchronize the write pointer to the read clock domain
            r_wr_ptr_ff <= i_wr_grey_addr;  // First stage of synchronization
            o_wr_ptr_sync <= r_wr_ptr_ff;   // Second stage of synchronization
        end
    end

endmodule