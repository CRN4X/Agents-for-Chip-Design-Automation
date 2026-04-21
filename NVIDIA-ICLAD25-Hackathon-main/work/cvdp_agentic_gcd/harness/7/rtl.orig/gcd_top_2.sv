module gcd_top_2 #(
   parameter WIDTH = 4
)(
   input                     clk,
   input                     rst,
   input  [WIDTH-1:0]        A,
   input  [WIDTH-1:0]        B,
   input                     go,
   output logic [WIDTH-1:0]  OUT,
   output logic              done
);

   logic equal;
   logic greater_than;
   logic [1:0] controlpath_state;

   gcd_controlpath_4 ctrl_inst (
      .clk               (clk),
      .rst               (rst),
      .go                (go),
      .equal             (equal),
      .greater_than      (greater_than),
      .controlpath_state (controlpath_state),
      .done              (done)
   );

   gcd_datapath_5 #( .WIDTH(WIDTH) ) dp_inst (
      .clk               (clk),
      .rst               (rst),
      .A                 (A),
      .B                 (B),
      .controlpath_state (controlpath_state),
      .equal             (equal),
      .greater_than      (greater_than),
      .OUT               (OUT)
   );

endmodule