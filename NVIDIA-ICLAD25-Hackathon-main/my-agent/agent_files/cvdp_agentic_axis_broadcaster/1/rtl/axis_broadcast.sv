`timescale 1ns/1ps

module axis_broadcast (
     input  wire              clk,
     input  wire              rst_n,
     // AXI Stream Input
     input  wire [8-1:0]      s_axis_tdata,
     input  wire              s_axis_tvalid,
     output reg               s_axis_tready,
     // AXI Stream Outputs
     output wire  [8-1:0]     m_axis_tdata_1,
     output wire              m_axis_tvalid_1,
     input  wire              m_axis_tready_1,
 
     output wire  [8-1:0]     m_axis_tdata_2,
     output wire              m_axis_tvalid_2,
     input  wire              m_axis_tready_2,
 
     output wire  [8-1:0]     m_axis_tdata_3,
     output wire              m_axis_tvalid_3,
     input  wire              m_axis_tready_3
 );
 wire all_m_ready;
 wire pop_broadcast;
 wire push_input;

 reg [7:0] out_data_buf;
 reg       out_data_valid;
 reg [7:0] pending_data_buf;
 reg       pending_data_valid;

 assign all_m_ready   = m_axis_tready_1 && m_axis_tready_2 && m_axis_tready_3;
 assign pop_broadcast = out_data_valid && all_m_ready;
 assign push_input    = s_axis_tvalid && s_axis_tready;

 always @(*) begin
     s_axis_tready = ~(out_data_valid && pending_data_valid);
 end

 always @(posedge clk or negedge rst_n) begin
     if (~rst_n) begin
         out_data_buf      <= 8'd0;
         out_data_valid    <= 1'b0;
         pending_data_buf  <= 8'd0;
         pending_data_valid<= 1'b0;
     end else begin
         case ({push_input, pop_broadcast})
             2'b10: begin
                 if (~out_data_valid) begin
                     out_data_buf   <= s_axis_tdata;
                     out_data_valid <= 1'b1;
                 end else if (~pending_data_valid) begin
                     pending_data_buf   <= s_axis_tdata;
                     pending_data_valid <= 1'b1;
                 end
             end
             2'b01: begin
                 if (pending_data_valid) begin
                     out_data_buf       <= pending_data_buf;
                     out_data_valid     <= 1'b1;
                     pending_data_valid <= 1'b0;
                 end else begin
                     out_data_valid <= 1'b0;
                 end
             end
             2'b11: begin
                 if (pending_data_valid) begin
                     out_data_buf      <= pending_data_buf;
                     out_data_valid    <= 1'b1;
                     pending_data_buf  <= s_axis_tdata;
                     pending_data_valid<= 1'b1;
                 end else begin
                     out_data_buf   <= s_axis_tdata;
                     out_data_valid <= 1'b1;
                 end
             end
             default: begin
                 out_data_valid <= out_data_valid;
             end
         endcase
     end
 end

 assign m_axis_tdata_1  = out_data_buf;
 assign m_axis_tvalid_1 = out_data_valid;
 assign m_axis_tdata_2  = out_data_buf;
 assign m_axis_tvalid_2 = out_data_valid;
 assign m_axis_tdata_3  = out_data_buf;
 assign m_axis_tvalid_3 = out_data_valid;

endmodule
