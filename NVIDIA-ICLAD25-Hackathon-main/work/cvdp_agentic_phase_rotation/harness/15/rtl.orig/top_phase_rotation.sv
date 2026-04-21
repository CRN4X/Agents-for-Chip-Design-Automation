module top_phase_rotation #(
   parameter NBW_ANG  =  'd7,      
   parameter NBW_COS  =  'd10,
   parameter NBW_IN_DATA  = 8,
   parameter NS_IN        = 2,
   parameter NBW_MULT     = NBW_IN_DATA + NBW_COS,
   parameter NBW_SUM      = NBW_MULT + 1,
   parameter NBW_OUT_DATA = NBW_SUM    
)
(    
   input  logic clk,
   input  logic [NBW_IN_DATA*NS_IN-1:0]   i_data_re,
   input  logic [NBW_IN_DATA*NS_IN-1:0]   i_data_im,    
   input  logic [NBW_ANG*NS_IN-1:0]             i_angle,
   output logic signed [NBW_OUT_DATA*NS_IN-1:0] o_data_re,
   output logic signed [NBW_OUT_DATA*NS_IN-1:0] o_data_im   
);

logic signed [NBW_IN_DATA-1:0]  i_data_re_2d [NS_IN-1:0];
logic signed [NBW_IN_DATA-1:0]  i_data_im_2d [NS_IN-1:0];
logic signed [NBW_OUT_DATA-1:0] o_data_re_2d [NS_IN-1:0];
logic signed [NBW_OUT_DATA-1:0] o_data_im_2d [NS_IN-1:0];
logic signed [NBW_ANG-1:0]      i_angle_2d [NS_IN-1:0];
logic signed [NBW_COS-1:0]      cos_2d [NS_IN-1:0];
logic signed [NBW_COS-1:0]      sin_2d [NS_IN-1:0];

always_comb begin : convert_2d_array_to_1d_input_data
   for(int i=0; i < NS_IN; i++) begin
      i_data_re_2d[i] = $signed(i_data_re[(i+1)*NBW_IN_DATA-1-:NBW_IN_DATA]);
      i_data_im_2d[i] = $signed(i_data_im[(i+1)*NBW_IN_DATA-1-:NBW_IN_DATA]);
   end
end

always_comb begin : convert_2d_array_to_1d_input_angle
   for(int i=0; i < NS_IN; i++) begin
      i_angle_2d[i] = $signed(i_angle[(i+1)*NBW_ANG-1-:NBW_ANG]);
   end
end

genvar j;
generate
   for(j = 0; j < NS_IN; j++) begin : gen_lut_phase_rot
      gen_cos_sin_lut uu_gen_cos_sin_lut (
         .i_angle(i_angle_2d[j]),
         .o_cos(cos_2d[j]),
         .o_sin(sin_2d[j])
      );

      phase_rotation #(
         .NBW_IN_DATA (NBW_IN_DATA ),
         .NBW_COS     (NBW_COS     ),
         .NBW_MULT    (NBW_MULT    ),
         .NBW_SUM     (NBW_SUM     ),
         .NBW_OUT_DATA(NBW_OUT_DATA)
      ) uu_phase_rotation(
         .clk(clk),
         .i_data_re(i_data_re_2d[j]),
         .i_data_im(i_data_im_2d[j]),
         .i_cos(cos_2d[j]),
         .i_sin(sin_2d[j]),
         .o_data_re(o_data_re_2d[j]),
         .o_data_im(o_data_im_2d[j]) 
      );
   end
endgenerate


always_comb begin : convert_2d_array_to_1d_output_data
   for(int i=0; i < NS_IN; i++) begin
      o_data_re[(i+1)*NBW_OUT_DATA-1-:NBW_OUT_DATA] = $unsigned(o_data_re_2d[i]);
      o_data_im[(i+1)*NBW_OUT_DATA-1-:NBW_OUT_DATA] = $unsigned(o_data_im_2d[i]);
   end
end

endmodule