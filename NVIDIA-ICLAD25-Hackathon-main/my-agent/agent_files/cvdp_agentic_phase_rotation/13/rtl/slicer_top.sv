`timescale 1ns/1ns

module slicer_top #(
   parameter NBW_REF   = 'd7,
   parameter NBW_TH    = 'd7,
   parameter NBW_IN    = 'd7,
   parameter NBW_OUT   = 'd8
)
(
   input logic  clk,
   input logic  rst_async_n,
   input logic  i_calc_cost,
   input logic  signed [NBW_IN-1:0]         i_data_i,
   input logic  signed [NBW_IN-1:0]         i_data_q,
   input logic  [NBW_TH-1:0]                i_threshold,
   input logic  signed [NBW_REF-1:0]        i_sample_pos,
   output logic signed [(2*NBW_OUT+1)-1:0]  o_energy,
   output logic o_cost_rdy
);
   logic signed [NBW_OUT-1:0]  slicer_i;
   logic signed [NBW_OUT-1:0]  slicer_q;
   logic signed [NBW_OUT-1:0]  slicer_i_dff;
   logic signed [NBW_OUT-1:0]  slicer_q_dff;

   logic [2:0] calc_cost_ff;

   slicer #(
      .NBW_IN  ( NBW_IN    ),
      .NBW_TH  ( NBW_TH    ),
      .NBW_REF ( NBW_REF   ),
      .NBW_OUT ( NBW_OUT   )
   )
   uu_slicer_i (
      .i_data       ( i_data_i     ),
      .i_threshold  ( i_threshold  ),
      .i_sample_pos ( i_sample_pos ),
      .o_data       ( slicer_i     )
   );

   slicer #(
      .NBW_IN  ( NBW_IN    ),
      .NBW_TH  ( NBW_TH    ),
      .NBW_REF ( NBW_REF   ),
      .NBW_OUT ( NBW_OUT   )
   )
   uu_slicer_q (
      .i_data       ( i_data_q     ),
      .i_threshold  ( i_threshold  ),
      .i_sample_pos ( i_sample_pos ),
      .o_data       ( slicer_q     )
   );

   always_ff @(posedge clk or negedge rst_async_n) begin
      if(!rst_async_n) begin
         calc_cost_ff <= 3'b000;
      end
      else begin
         calc_cost_ff <= {calc_cost_ff[1:0], (i_calc_cost === 1'b1)};
      end
   end

   assign o_cost_rdy = (calc_cost_ff[1] === 1'b1);

   always_ff @(posedge clk or negedge rst_async_n) begin
      if(!rst_async_n) begin
         slicer_i_dff  <= 'd0;
         slicer_q_dff  <= 'd0;
      end
      else begin
         if(calc_cost_ff[0] === 1'b1) begin
            slicer_i_dff  <= slicer_i;
            slicer_q_dff  <= slicer_q;
         end
      end
   end

   assign o_energy = slicer_i_dff*slicer_i_dff + slicer_q_dff*slicer_q_dff;
endmodule
