module gcd_controlpath_3 (
   input                    clk,
   input                    rst,
   input                    go,
   input                    equal,
   output logic [1:0]       controlpath_state,
   output logic             done
);
   localparam S0 = 2'd0;
   localparam S1 = 2'd1;
   localparam S2 = 2'd2;

   logic [1:0] curr_state, next_state;

   always_comb begin
      next_state = curr_state;
      case (curr_state)
         S0: begin
            if (!go)
               next_state = S0;
            else
               next_state = S2;
         end
         S1: begin
            next_state = S0;
         end
         S2: begin
            if (equal)
               next_state = S1;
            else
               next_state = S2;
         end
         default: begin
            next_state = S0;
         end
      endcase
   end

   always_ff @(posedge clk) begin
      if (rst)
         curr_state <= S0;
      else
         curr_state <= next_state;
   end

   always_ff @(posedge clk) begin
      if (rst)
         done <= 1'b0;
      else
         done <= (curr_state == S1);
   end

   assign controlpath_state = curr_state;

endmodule