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
 wire s_axis_tready_t1;
 
 reg [7:0]m_axis_tdata_1_reg;
 reg [7:0]m_axis_tvalid_1_reg;
 reg [7:0]m_axis_tdata_2_reg;
 reg [7:0]m_axis_tvalid_2_reg;
 reg [7:0]m_axis_tdata_3_reg;
 reg [7:0]m_axis_tvalid_3_reg;
 // Broadcast logic: forward input to all outputs
 assign s_axis_tready_t1 = m_axis_tready_1 && m_axis_tready_2 && m_axis_tready_3 ;  // Ready only if all outputs are ready
 
 // Generate output signals
 always @(posedge clk or negedge rst_n) 
 begin
     if (~rst_n) 
     begin
         m_axis_tdata_1_reg <= 0;
         m_axis_tvalid_1_reg <= 0;
         m_axis_tdata_2_reg <= 0;
         m_axis_tvalid_2_reg <= 0;
         m_axis_tdata_3_reg <= 0;
         m_axis_tvalid_3_reg <= 0;
     end 
     else if (s_axis_tready_t1)
     begin
         m_axis_tdata_1_reg  <= s_axis_tdata;
         m_axis_tvalid_1_reg <= s_axis_tvalid;
         m_axis_tdata_2_reg  <= s_axis_tdata;
         m_axis_tvalid_2_reg <= s_axis_tvalid;
         m_axis_tdata_3_reg  <= s_axis_tdata;
         m_axis_tvalid_3_reg <= s_axis_tvalid;
     end
 end
 
 always @(posedge clk or negedge rst_n) 
 begin
     if (~rst_n) 
          s_axis_tready <= 0;
     else 
          s_axis_tready <= s_axis_tready_t1 ;
 end
 
 assign m_axis_tdata_1 = m_axis_tdata_1_reg;
 assign m_axis_tvalid_1 = m_axis_tvalid_1_reg;
 assign m_axis_tdata_2 = m_axis_tdata_2_reg;
 assign m_axis_tvalid_2 = m_axis_tvalid_2_reg;
 assign m_axis_tdata_3 = m_axis_tdata_3_reg;
 assign m_axis_tvalid_3 = m_axis_tvalid_3_reg;

endmodule