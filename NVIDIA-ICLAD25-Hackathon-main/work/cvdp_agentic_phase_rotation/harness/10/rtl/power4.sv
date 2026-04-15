module power4 #(
   parameter NBW_IN = 8,
   parameter NBW_OUT= NBW_IN*4
)
(
   input  logic clk,
   input  logic rst_async_n,
   input  logic signed [NBW_IN-1:0]  i_data_i,
   input  logic signed [NBW_IN-1:0]  i_data_q,
   output logic signed [NBW_OUT-1:0] o_data_i,  
   output logic signed [NBW_OUT-1:0] o_data_q
);

localparam NBW_SQUARE = 2*NBW_IN;
localparam NBW_FOURTH = 2*NBW_SQUARE;
// Fourth power 
logic signed [NBW_SQUARE-1:0] data_i2;
logic signed [NBW_SQUARE-1:0] data_q2;
logic signed [NBW_FOURTH-1:0] data_i4;
logic signed [NBW_FOURTH-1:0] data_q4;


assign data_i2 = i_data_i*i_data_i;
assign data_i4 = data_i2*data_i2;

assign data_q2 = i_data_q*i_data_q;
assign data_q4 = data_q2*data_q2;

always_ff @(posedge clk or negedge rst_async_n) begin
   if(!rst_async_n) begin
      o_data_i <= 'd0;
      o_data_q <= 'd0;
   end
   else begin
      o_data_i <= data_i4;
      o_data_q <= data_q4;
   end
end


endmodule