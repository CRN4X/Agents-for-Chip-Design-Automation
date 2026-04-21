module CA_3(
	input wire clock,		//Clock input
	input wire reset,		//Reset input
	input wire [7:0] CA_seed, 	//8-bit Cellular Automata (CA) seed
	output reg [7:0] CA_out); 	//8-bit CA output
	
	wire q1,q2,q3,q4,q5,q6,q7,q8;
	
	//Rule combination considered for 8-bit CA is R150-R150-R90-R150-R90-R150-R90-R150
	
	//Internal XORing based on rules 90 and 150 combination
  assign q1 = CA_out[7] ^ CA_out[6]; 				        //R150
  assign q2 = CA_out[7] ^ CA_out[6] ^ CA_out[5]; 		//R150
  assign q3 = CA_out[6] ^ CA_out[4]; 	              //R90
  assign q4 = CA_out[5] ^ CA_out[4] ^ CA_out[3]; 		//R150
  assign q5 = CA_out[4] ^ CA_out[2];               	//R90
  assign q6 = CA_out[3] ^ CA_out[2] ^ CA_out[1]; 		//R150
  assign q7 = CA_out[2] ^ CA_out[0]; 	              //R90
  assign q8 = CA_out[1] ^ CA_out[0]; 				        //R150

	always_ff @(posedge clock)
	begin
		if (reset)    //If reset is HIGH, 8-bit CA seed will be initialised at CA output
			CA_out <= CA_seed;
		else
			CA_out <= {q1,q2,q3,q4,q5,q6,q7,q8};   //Shift register based on the CA rules
	end
endmodule