/**************************************************************************
FILENAME:    prbs_gen_check.sv
DESCRIPTION: This module generates or checks a PRBS pattern.
**************************************************************************/

module prbs_gen_check #(
   parameter CHECK_MODE  = 0,              // 0: uses LFSR structure to generate a PRBS pattern, 1: the incoming data is loaded into prbs registers and compared with locally generated PRBS pattern.
   parameter POLY_LENGTH = 31,             // length of the polynomial.(number of shift register stages)
   parameter POLY_TAP    = 3,              // Intermedite stage that is xored with the last stage to generate the next prbs bit.
   parameter WIDTH       = 16              // Bus size of data_in and data_out.
   )(
   input                         clk     , // clock input
   input                         rst     , // synchronous reset, active high
   input         [WIDTH-1:0]     data_in , // input data to be checked(checker mode), tied to 0 (generator mode)
   output logic  [WIDTH-1:0]     data_out  // generated prbs pattern (generator mode), error found (checker mode).
);

logic [1:POLY_LENGTH] prbs [WIDTH:0];
logic [WIDTH-1:0]     prbs_xor_a;
logic [WIDTH-1:0]     prbs_xor_b;
logic [WIDTH:1]       prbs_msb;
logic [1:POLY_LENGTH] prbs_reg = {(POLY_LENGTH){1'b1}};

assign prbs[0]   = prbs_reg;

genvar i;
generate for(i=0; i<WIDTH; i=i+1) begin
   assign prbs_xor_a[i] = prbs[i][POLY_TAP] ^ prbs[i][POLY_LENGTH];
   assign prbs_xor_b[i] = prbs_xor_a[i] ^ data_in[i];
   assign prbs_msb[i+1] = (CHECK_MODE==0) ? prbs_xor_a[i] : data_in[i];
   assign prbs[i+1]     = {prbs_msb[i+1],prbs[i][1:POLY_LENGTH-1]};
end
endgenerate

always_ff @ (posedge clk) begin
   if(rst) begin
      prbs_reg <= {POLY_LENGTH{1'b1}};
      data_out <= {WIDTH{1'b1}};
   end else begin
      prbs_reg <= prbs[WIDTH];
      data_out <= prbs_xor_b;   
   end
end
  
endmodule