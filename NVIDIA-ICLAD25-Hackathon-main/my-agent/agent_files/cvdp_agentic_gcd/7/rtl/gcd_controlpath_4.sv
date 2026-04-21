module gcd_controlpath_4 (
   input                    clk,
   input                    rst,
   input                    go,
   input                    equal,
   input                    greater_than,
   output logic [1:0]       controlpath_state,
   output logic             done
);


   logic [1:0] curr_state;
   logic [1:0] next_state;

   localparam S0 = 2'd0;
   localparam S1 = 2'd1;
   localparam S2 = 2'd2;
   localparam S3 = 2'd3;

   always_ff @ (posedge clk) begin
      if (rst) begin
         curr_state   <= S0;
      end else begin
         curr_state   <= next_state;
      end
   end

   always_comb begin
      case(curr_state)
         S0: begin
             if(!go)
                next_state = S0;
             else if (equal)
                next_state = S1;
             else if (greater_than)
                next_state = S2;
             else
                next_state = S3;
         end
         S1: begin
             next_state = S0;
         end
         S2: begin
             if(equal)
                next_state = S1;
             else if (greater_than)
                next_state = S2;
             else
                next_state = S3;
         end
         S3: begin
             if (equal)
                next_state = S1;
             else if (greater_than)
                next_state = S2;
             else
                next_state = S3;
         end
         default: begin
             next_state = S0;
         end
      endcase
   end

   always_ff @ (posedge clk) begin
     if(rst) begin
        done <= 1'b0;
     end else begin
        done <= (curr_state == S1);
     end
   end

   assign controlpath_state = curr_state;

endmodule