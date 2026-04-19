//module of full_adder
module full_adder(       
                  input a,     // First Addend input
                  input b,     // Second Addend input
                  input cin,   // Carry input
                  output sum,  // Sum output
                  output cout  // Carry output
                );
                  
  assign sum = a ^ b ^ cin;                      
  assign cout = (a & b) | (b & cin) | (a & cin); 
  
endmodule