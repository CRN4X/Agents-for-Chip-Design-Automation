module gcd_datapath_6  #(
   parameter WIDTH = 4
)(
   input                     clk,
   input                     rst,
   input      [WIDTH-1:0]    A,
   input      [WIDTH-1:0]    B,
   input      [1:0]          controlpath_state,
   output logic              equal,
   output logic [WIDTH-1:0]  OUT
);
   logic [WIDTH-1:0] A_ff, B_ff, OUT_ff;
   logic [$clog2(WIDTH+1):0] k_ff;

   logic [WIDTH-1:0] next_A_ff, next_B_ff, next_OUT;
   logic [$clog2(WIDTH+1):0] next_k_ff;

   logic [WIDTH-1:0] diff;
   logic [WIDTH-1:0] gcd_val;
   logic both_even, a_even, b_even;

   localparam S0 = 2'd0;
   localparam S1 = 2'd1;
   localparam S2 = 2'd2;

   always_comb begin
      next_A_ff = A_ff;
      next_B_ff = B_ff;
      next_k_ff = k_ff;
      next_OUT  = OUT_ff;
      gcd_val   = OUT_ff;
      diff      = 'b0;

      a_even    = (A_ff[0] == 1'b0);
      b_even    = (B_ff[0] == 1'b0);
      both_even = a_even && b_even;
      equal     = (A_ff == B_ff);

      case (controlpath_state)
         S0: begin
            next_A_ff = A;
            next_B_ff = B;
            next_k_ff = 'b0;
            next_OUT  = 'b0;
         end

         S1: begin
            if (A_ff == 0 && B_ff == 0) begin
               gcd_val = 0;
            end else if (A_ff == 0) begin
               gcd_val = (B_ff << k_ff);
            end else begin
               gcd_val = (A_ff << k_ff);
            end
            next_OUT = gcd_val;
         end

         S2: begin
            if ((A_ff != 0) && (B_ff != 0)) begin
               if (both_even) begin
                  next_A_ff = A_ff >> 1;
                  next_B_ff = B_ff >> 1;
                  next_k_ff = k_ff + 1;
               end else if (a_even && !b_even) begin
                  next_A_ff = A_ff >> 1;
               end else if (b_even && !a_even) begin
                  next_B_ff = B_ff >> 1;
               end else begin
                  if (A_ff >= B_ff) begin
                     diff = A_ff - B_ff;
                     next_A_ff = diff >> 1;
                     next_B_ff = B_ff;
                  end else begin
                     diff = B_ff - A_ff;
                     next_B_ff = diff >> 1;
                     next_A_ff = A_ff;
                  end
               end
            end else if (A_ff == 0 && B_ff != 0) begin
               next_A_ff = B_ff;
               next_B_ff = B_ff;
            end else if (B_ff == 0 && A_ff != 0) begin
               next_B_ff = A_ff;
               next_A_ff = A_ff;
            end
         end

         default: begin
            next_A_ff = 'b0;
            next_B_ff = 'b0;
            next_k_ff = 'b0;
            next_OUT  = 'b0;
         end
      endcase
   end

   always_ff @(posedge clk) begin
      if (rst) begin
         A_ff  <= 'b0;
         B_ff  <= 'b0;
         k_ff  <= 'b0;
         OUT_ff <= 'b0;
      end else begin
         A_ff  <= next_A_ff;
         B_ff  <= next_B_ff;
         k_ff  <= next_k_ff;
         OUT_ff <= next_OUT;
      end
   end

   assign OUT = OUT_ff;

endmodule