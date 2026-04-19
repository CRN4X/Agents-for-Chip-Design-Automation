//module of four_bit_adder
module four_bit_adder(        
                      input [3:0] a,           // 4-bit input a
                      input [3:0] b,           // 4-bit input b
                      input cin,               // Carry input
                      output [3:0] sum,        // 4-bit sum output
                      output cout              // Carry output
                     );

  wire [2:0] carry;         

  genvar i;                 

  generate
    for (i = 0; i < 4; i = i + 1) begin: adder 

      if (i == 0) begin
        full_adder fa (       
                       .a(a[i]),           
                       .b(b[i]),           
                       .cin(cin),          
                       .sum(sum[i]),       
                       .cout(carry[i])     
                      );
      end 
      else if (i < 3) begin
        full_adder fa (       
                       .a(a[i]),           
                       .b(b[i]),           
                       .cin(carry[i-1]),   
                       .sum(sum[i]),       
                       .cout(carry[i])     
                      );
      end
      else begin
        full_adder fa (       
                       .a(a[i]),           
                       .b(b[i]),           
                       .cin(carry[i-1]),   
                       .sum(sum[i]),       
                       .cout(cout)         
                     );
      end
    end
  endgenerate

endmodule   