module slicer_top #(
   parameter NBW_REF   = 'd7,
   parameter NBW_TH    = 'd7,
   parameter NBW_IN    = 'd7,
   parameter NS_TH     = 'd2
)
(
   input logic  clk,
   input logic  rst_async_n,
   input logic  i_calc_cost,
   input logic  signed [NBW_IN-1:0]         i_data_i,
   input logic  signed [NBW_IN-1:0]         i_data_q,
   input logic  [NBW_TH*NS_TH-1 :0 ] i_threshold,
   input logic  signed [NBW_REF-1:0]        i_sample_1_pos,
   input logic  signed [NBW_REF-1:0]        i_sample_0_pos,
   input logic  signed [NBW_REF-1:0]        i_sample_0_neg,
   input logic  signed [NBW_REF-1:0]        i_sample_1_neg,
   output logic signed [(2*NBW_REF+1)-1:0]  o_energy,
   output logic o_cost_rdy
);
   logic signed [NBW_REF-1:0]  slicer_i;
   logic signed [NBW_REF-1:0]  slicer_q;
   logic signed [NBW_REF-1:0]  slicer_i_dff;
   logic signed [NBW_REF-1:0]  slicer_q_dff; 

   logic [1:0] calc_cost_ff;

   slicer #(
      .NBW_IN  ( NBW_IN    ),
      .NBW_TH  ( NBW_TH    ),
      .NBW_REF ( NBW_REF   ),
      .NS_TH   ( NS_TH     )
   )
   uu_slicer_i (
      .i_data         ( i_data_i       ),
      .i_threshold    ( i_threshold    ),
      .i_sample_1_pos ( i_sample_1_pos ),
      .i_sample_0_pos ( i_sample_0_pos ),
      .i_sample_0_neg ( i_sample_0_neg ),
      .i_sample_1_neg ( i_sample_1_neg ),
      .o_data         ( slicer_i     )
   );

   slicer #(
      .NBW_IN  ( NBW_IN    ),
      .NBW_TH  ( NBW_TH    ),
      .NBW_REF ( NBW_REF   ),
      .NS_TH   ( NS_TH     )
   )
   uu_slicer_q (
      .i_data         ( i_data_q       ),
      .i_threshold    ( i_threshold    ),
      .i_sample_1_pos ( i_sample_1_pos ),
      .i_sample_0_pos ( i_sample_0_pos ),
      .i_sample_0_neg ( i_sample_0_neg ),
      .i_sample_1_neg ( i_sample_1_neg ),
      .o_data         ( slicer_q     )
   );

   always_ff @(posedge clk or negedge rst_async_n) begin
      if(!rst_async_n) begin
         calc_cost_ff <= 2'b00;
      end
      else begin
         calc_cost_ff <= {calc_cost_ff[0],i_calc_cost};
      end
   end

   assign o_cost_rdy = calc_cost_ff[1];

   always_ff @(posedge clk or negedge rst_async_n) begin
      if(!rst_async_n) begin
         slicer_i_dff  <= 'd0;
         slicer_q_dff  <= 'd0;
      end
      else begin
         if(calc_cost_ff[0]) begin
            slicer_i_dff  <= slicer_i;
            slicer_q_dff  <= slicer_q;
         end
      end
   end

   assign o_energy = slicer_i_dff*slicer_i_dff + slicer_q_dff*slicer_q_dff;
endmodule