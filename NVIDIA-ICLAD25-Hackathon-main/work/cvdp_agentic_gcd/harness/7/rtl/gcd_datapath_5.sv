module gcd_datapath_5  #(
   parameter WIDTH = 4
   )(
   input                     clk,
   input                     rst,
   input  [WIDTH-1:0]        A,
   input  [WIDTH-1:0]        B,
   input  [1:0]              controlpath_state,
   output logic              equal,
   output logic              greater_than,
   output logic  [WIDTH-1:0] OUT
);

   logic [WIDTH-1:0] A_ff;
   logic [WIDTH-1:0] B_ff;

   localparam S0 = 2'd0;
   localparam S1 = 2'd1;
   localparam S2 = 2'd2;
   localparam S3 = 2'd3;

   always_ff @ (posedge clk) begin
      if (rst) begin
         A_ff <= 'b0;
         B_ff <= 'b0;
         OUT  <= 'b0;
      end else begin
         case (controlpath_state)
            S0: begin
                A_ff <= A;
                B_ff <= B;
             end
            S1: begin
                OUT  <= A_ff;
             end
            S2: begin
                if (greater_than)
                   A_ff <= A_ff - B_ff;
             end
            S3: begin
                if (!equal & !greater_than)
                   B_ff <= B_ff - A_ff;
             end
            default: begin
                A_ff <= 'b0;
                B_ff <= 'b0;
                OUT <= 'b0;
            end
         endcase
      end
   end

   always_comb begin
      case(controlpath_state)
         S0: begin
            equal        = (A == B)? 1'b1 : 1'b0;
            greater_than = (A >  B)? 1'b1 : 1'b0;
          end
          default: begin
            equal        = (A_ff == B_ff)? 1'b1 : 1'b0;
            greater_than = (A_ff >  B_ff)? 1'b1 : 1'b0;
          end
      endcase
   end
endmodule