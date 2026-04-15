module sync_serial_communication_tb();

// Declaration of registers and wires
reg clk;                    // Clock signal
reg reset_n;                // Active-low reset signal
reg [2:0] sel;              // Selection signal
reg [63:0] data_in;         // Data input signal
wire done;                  // Done signal (output from DUT)
wire [63:0] data_out;       // Data output signal
wire [63:0]gray_out;        // gray output

integer i;                  // Loop variable for tasks


sync_serial_communication_tx_rx uut (
    .clk(clk),
    .reset_n(reset_n),
    .sel(sel),
    .data_in(data_in),
    .data_out(data_out),
    .done(done),
    .gray_out(gray_out)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end


initial begin
    reset_n = 0;                        		             
    @(posedge clk);
    @(posedge clk);
    initialization();                   		             
    @(negedge clk);
    reset_n = 1;                        		            
    @(posedge clk);
    repeat(2) begin
        drive_byte();                                        
        @(posedge clk);
        reset_n = 1'b0;                                      
        @(posedge clk);
        initialization();                                   
        @(negedge clk);
        reset_n = 1'b1;                                      
        drive_half_word();                                   
        @(posedge clk);
        reset_n = 1'b0;                                      
        @(posedge clk);
        initialization();                                  
        @(negedge clk);
        reset_n = 1'b1;                                      
        drive_word();                                        
        @(posedge clk);
        reset_n = 1'b0;                                     
        @(posedge clk);
        initialization();                                   
        @(negedge clk);
        reset_n = 1'b1;                                     
        double_word();                                       
        @(posedge clk);
        reset_n = 1'b0;                                      
        @(posedge clk);
        initialization();                                    
        @(negedge clk);
        reset_n = 1'b1;                                     
    end
    #100;    						                         
    $finish();                                               
end

task initialization();
begin
    @(posedge clk);
    if (!reset_n) begin
        data_in <= 64'd0;                		             
        sel     <= 3'b000;               		             
    end
end
endtask

task drive_byte();
begin
    @(posedge clk);
    data_in <= {$random()}%127;					            
    for (i = 0; i <= 7; i = i + 1) begin
        sel <= 3'b001;                   		            
        @(posedge clk);
    end
    wait(done);
    $display("-------------------------------------------------------------------------------------------------");
    $display("%t DRIVE_BYTE:: sel = %h, data_in = %h, data_out = %h, done = %b,gray_out = %b", $time,sel,data_in,data_out,done,gray_out);
end
endtask

task drive_half_word();
begin
    @(posedge clk);
    data_in <= {$random()}%1023;             		       
    for (i = 0; i <= 15; i = i + 1) begin
        @(posedge clk);
        sel <= 3'b010;                   		            
    end
    wait(done);
    $display("-------------------------------------------------------------------------------------------------");
    $display("%t DRIVE_HALF_WORD:: sel = %h, data_in = %h, data_out = %h, done = %b,gray_out = %b", $time,sel,data_in,data_out,done,gray_out);
end
endtask

task drive_word();
begin
    @(posedge clk);
    data_in <= {$random()}%4196;             		    
    for (i = 0; i <= 31; i = i + 1) begin
        @(posedge clk);
        sel <= 3'b011;                  		            
    end
    wait(done);
    $display("-------------------------------------------------------------------------------------------------");
    $display("%t DRIVE_WORD:: sel = %h, data_in = %h, data_out = %h, done = %b,gray_out = %b", $time,sel,data_in,data_out,done,gray_out);
end
endtask

task double_word();
begin
    @(posedge clk);
    data_in <= {$random()}%8192;             		        
    for (i = 0; i <= 63; i = i + 1) begin
        @(posedge clk);
        sel <= 3'b100;                  	                
    end
    wait(done);
    $display("-------------------------------------------------------------------------------------------------");
    $display("%t DRIVE_DOUBLE_WORD:: sel = %h, data_in = %h, data_out = %h, done = %b,gray_out = %b", $time,sel,data_in,data_out,done,gray_out);
end
endtask

initial begin
$dumpfile("dump.vcd");
$dumpvars(0,sync_serial_communication_tb);
end

endmodule