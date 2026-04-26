`timescale 1ns/1ns

module slicer #(
   parameter NBW_IN  =  'd7,
   parameter NBW_TH  =  'd7,
   parameter NBW_REF =  'd7,
   parameter NBW_OUT =  'd8
)
(
   input logic signed [NBW_IN-1 :0]        i_data,
   input logic [NBW_TH-1:0]                i_threshold,
   input logic signed [NBW_REF-1:0]        i_sample_pos,

   output logic signed [NBW_OUT-1:0]       o_data
);
   localparam integer NBW_CMP = (NBW_IN > NBW_TH) ? (NBW_IN + 1) : (NBW_TH + 1);

   logic signed [NBW_CMP-1:0] i_data_cmp;
   logic signed [NBW_CMP-1:0] th_pos_cmp;
   logic signed [NBW_CMP-1:0] th_neg_cmp;
   logic signed [NBW_CMP-1:0] zero_cmp;
   logic signed [NBW_OUT-1:0] sample_pos_out;
   logic signed [NBW_OUT-1:0] th_pos_out;

   always_comb begin
      i_data_cmp    = $signed({i_data[NBW_IN-1], i_data});
      th_pos_cmp    = $signed({1'b0, i_threshold});
      th_neg_cmp    = -th_pos_cmp;
      zero_cmp      = '0;
      sample_pos_out = $signed(i_sample_pos);
      th_pos_out     = $signed({1'b0, i_threshold});

      if (i_data_cmp >= th_pos_cmp) begin
         o_data = sample_pos_out + th_pos_out;
      end
      else if ((i_data_cmp >= zero_cmp) && (i_data_cmp < th_pos_cmp)) begin
         o_data = sample_pos_out;
      end
      else if ((i_data_cmp >= th_neg_cmp) && (i_data_cmp < zero_cmp)) begin
         o_data = -sample_pos_out;
      end
      else begin
         o_data = -sample_pos_out - th_pos_out;
      end
   end
endmodule
