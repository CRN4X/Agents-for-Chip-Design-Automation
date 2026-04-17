`timescale 1ns / 1ps
module bcd_to_excess_3(
    input [3:0] bcd,          // 4-bit BCD input
    output reg [3:0] excess3, // 4-bit Excess-3 output
    output reg error,          // Error flag to indicate invalid input
    output reg valid           // Valid flag for correct input
);

always @(bcd)

begin
    error = 1'b0; 
    valid = 1'b1;
    case(bcd)
        4'b0000: excess3 = 4'b0011;  
        `ifndef BUG_0
        4'b0001: excess3 = 4'b0100;  
        `else 
        4'b0001: excess3 = 4'b0101; 
        `endif
        4'b0010: excess3 = 4'b0101;  
        4'b0011: excess3 = 4'b0110;  
        4'b0100: excess3 = 4'b0111;
        `ifndef BUG_2  
        4'b0101: excess3 = 4'b1000;  
        `else
        4'b0101: excess3 = 4'b0010;
        `endif
        4'b0110: excess3 = 4'b1001;  
        4'b0111: excess3 = 4'b1010;  
        `ifndef BUG_1
        4'b1000: excess3 = 4'b1011;  
        `else 
        4'b0001: excess3 = 4'b0111; 
        `endif
        4'b1001: excess3 = 4'b1100;  
        default: begin
            excess3 = 4'b0000;   
            error = 1'b1;  
            valid   = 1'b0;      
        end
    endcase
end

endmodule