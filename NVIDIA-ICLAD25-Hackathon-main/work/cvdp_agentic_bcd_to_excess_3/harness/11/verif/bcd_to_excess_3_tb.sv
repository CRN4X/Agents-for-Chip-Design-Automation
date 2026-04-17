`timescale 1ns / 1ps
module bcd_to_excess_3_tb;

    // Inputs
    reg [3:0] bcd;

    // Outputs
    wire [3:0] excess3;
    wire error;
    wire valid;

    bcd_to_excess_3 dut (
        .bcd(bcd), 
        .excess3(excess3),
        .error(error),
        .valid(valid)
    );
    initial begin
        bcd = 0;
        #10;
        $display("BCD | Excess-3");
        for (bcd = 0; bcd < 15; bcd = bcd + 1) begin
            #10; 
            $display("%b | %b", bcd, excess3);
        end
        #10;
         bcd = 0;
          #10;
        $display("BCD | Excess-3");
        for (bcd = 0; bcd < 10; bcd = bcd + 1) begin
            #10; 
            $display("%b | %b", bcd, excess3);
        end
        #10;
        $finish;  
    end
    initial begin
    $dumpfile("test.vcd");          
    $dumpvars(0, bcd_to_excess_3_tb);     
  end 
  
endmodule