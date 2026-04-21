module slicer #(
   parameter NBW_IN  =  'd7,
   parameter NBW_TH  =  'd7,
   parameter NBW_REF =  'd7,
   parameter NS_TH   =  'd2
)
(
   input logic signed [NBW_IN-1 :0]        i_data,
   input logic [NBW_TH*NS_TH-1 :0 ] i_threshold,
   input logic signed [NBW_REF-1:0]        i_sample_1_pos,
   input logic signed [NBW_REF-1:0]        i_sample_0_pos,
   input logic signed [NBW_REF-1:0]        i_sample_0_neg,
   input logic signed [NBW_REF-1:0]        i_sample_1_neg,

   output logic signed [NBW_REF-1 :0     ] o_data
);
   localparam ZERO = {NBW_IN{1'b0}};

   always_comb begin
      if ($signed(i_data) >= $signed(i_threshold[2*NBW_TH-1-:NBW_TH])) begin
         o_data = i_sample_1_pos;
      end
      else if (($signed(i_data) >= $signed(ZERO)) && ($signed(i_data) < $signed(i_threshold[2*NBW_TH-1-:NBW_TH]))) begin
         o_data = i_sample_0_pos;
      end
      else if (($signed(i_data) >= $signed(i_threshold[NBW_TH-1:0])) && ($signed(i_data) < $signed(ZERO))) begin
         o_data = i_sample_0_neg;
      end
      else begin
         o_data = i_sample_1_neg;
      end
   end
endmodule