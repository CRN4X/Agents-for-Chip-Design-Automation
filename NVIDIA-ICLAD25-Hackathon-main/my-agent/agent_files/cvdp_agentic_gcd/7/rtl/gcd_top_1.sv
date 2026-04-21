module gcd_top_1 #(
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
   logic [1:0] controlpath_state;

   gcd_controlpath_3 ctrl_inst (
      .clk               (clk),
      .rst               (rst),
      .go                (go),
      .equal             (equal),
      .controlpath_state (controlpath_state),
      .done              (done)
   );

   gcd_datapath_6 #( .WIDTH(WIDTH) ) dp_inst (
      .clk               (clk),
      .rst               (rst),
      .A                 (A),
      .B                 (B),
      .controlpath_state (controlpath_state),
      .equal             (equal),
      .OUT               (OUT)
   );

endmodule