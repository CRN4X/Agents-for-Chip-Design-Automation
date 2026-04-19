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
 wire pop_beat;
 wire accept_beat;

 reg [7:0] data0_reg;
 reg [7:0] data1_reg;
 reg [1:0] count_reg;

 assign all_m_ready = m_axis_tready_1 && m_axis_tready_2 && m_axis_tready_3;
 assign pop_beat = (count_reg != 2'd0) && all_m_ready;
 assign accept_beat = s_axis_tvalid && s_axis_tready;

 always @(posedge clk or negedge rst_n)
 begin
     if (~rst_n)
     begin
         data0_reg      <= 8'b0;
         data1_reg      <= 8'b0;
         count_reg      <= 2'd0;
         s_axis_tready  <= 1'b0;
     end
     else
     begin
         s_axis_tready <= (count_reg != 2'd2);

         case ({accept_beat, pop_beat})
             2'b10:
             begin
                 if (count_reg == 2'd0)
                     data0_reg <= s_axis_tdata;
                 else if (count_reg == 2'd1)
                     data1_reg <= s_axis_tdata;
                 count_reg <= count_reg + 2'd1;
             end
             2'b01:
             begin
                 if (count_reg == 2'd2)
                     data0_reg <= data1_reg;
                 count_reg <= count_reg - 2'd1;
             end
             2'b11:
             begin
                 if (count_reg == 2'd1)
                     data0_reg <= s_axis_tdata;
                 else if (count_reg == 2'd2)
                 begin
                     data0_reg <= data1_reg;
                     data1_reg <= s_axis_tdata;
                 end
             end
             default:
             begin
                 count_reg <= count_reg;
             end
         endcase
     end
 end

 assign m_axis_tdata_1 = data0_reg;
 assign m_axis_tvalid_1 = (count_reg != 2'd0);
 assign m_axis_tdata_2 = data0_reg;
 assign m_axis_tvalid_2 = (count_reg != 2'd0);
 assign m_axis_tdata_3 = data0_reg;
 assign m_axis_tvalid_3 = (count_reg != 2'd0);

endmodule
