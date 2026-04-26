`timescale 1ns/1ns
module phase_rotation #(
   parameter NBW_IN_DATA  = 8,
   parameter NBW_COS      = 8,
   parameter NBW_MULT     = NBW_IN_DATA + NBW_COS,
   parameter NBW_SUM      = NBW_MULT + 1,
   parameter NBW_OUT_DATA = NBW_SUM
) (
   input  logic clk,
   input  logic rst_async_n,
   input  logic i_bypass,
   input  logic signed [NBW_IN_DATA-1:0]  i_data_re,
   input  logic signed [NBW_IN_DATA-1:0]  i_data_im,
   input  logic signed [NBW_COS-1:0]      i_cos,
   input  logic signed [NBW_COS-1:0]      i_sin,
   output logic signed [NBW_OUT_DATA-1:0] o_data_re,
   output logic signed [NBW_OUT_DATA-1:0] o_data_im
);

   logic signed [NBW_IN_DATA-1:0]  data_re_reg;
   logic signed [NBW_IN_DATA-1:0]  data_im_reg;
   logic signed [NBW_COS-1:0]      cos_reg;
   logic signed [NBW_COS-1:0]      sin_reg;

   logic signed [NBW_MULT-1:0] data_a;
   logic signed [NBW_MULT-1:0] data_b;
   logic signed [NBW_MULT-1:0] data_c;
   logic signed [NBW_MULT-1:0] data_d;

   logic signed [NBW_SUM-1:0] sum_1;
   logic signed [NBW_SUM-1:0] sum_2;

   always_ff @(posedge clk or negedge rst_async_n) begin
      if(!rst_async_n) begin
         data_re_reg <= '0;
         data_im_reg <= '0;
         cos_reg     <= '0;
         sin_reg     <= '0;
      end
      else begin
         data_re_reg <= i_data_re;
         data_im_reg <= i_data_im;
         cos_reg     <= i_cos;
         sin_reg     <= i_sin;
      end
   end

   assign data_a = cos_reg*data_re_reg;
   assign data_b = sin_reg*data_im_reg;
   assign data_c = sin_reg*data_re_reg;
   assign data_d = cos_reg*data_im_reg;

   assign sum_1  = data_a - data_b;
   assign sum_2  = data_c + data_d;

   always_comb begin
      if(i_bypass) begin
         o_data_re = i_data_re;
         o_data_im = i_data_im;
      end
      else begin
         o_data_re = sum_1;
         o_data_im = sum_2;
      end
   end

endmodule
