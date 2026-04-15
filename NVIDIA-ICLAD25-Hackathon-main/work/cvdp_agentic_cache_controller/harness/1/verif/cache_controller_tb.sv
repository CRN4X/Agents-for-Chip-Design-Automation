`timescale 1ns/1ps
module cache_controller_tb ();

  reg         clk           ;
  reg         reset         ;
  reg  [ 4:0] address       ;
  reg  [31:0] write_data    ;
  reg         read          ;
  reg         write         ;
  wire [31:0] read_data     ;
  wire        hit           ;
  wire        miss          ;
  wire        mem_write     ;
  wire [31:0] mem_address   ;
  wire [31:0] mem_write_data;
  reg  [31:0] mem_read_data ;
  reg         mem_ready     ;

  cache_controller uut (
    .clk           (clk           ),
    .reset         (reset         ),
    .address       (address       ),
    .write_data    (write_data    ),
    .read          (read          ),
    .write         (write         ),
    .read_data     (read_data     ),
    .hit           (hit           ),
    .miss          (miss          ),
    .mem_write     (mem_write     ),
    .mem_address   (mem_address   ),
    .mem_write_data(mem_write_data),
    .mem_read_data (mem_read_data ),
    .mem_ready     (mem_ready     )
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    reset = 1;
    address = 0;
    write_data = 0;
    read = 0;
    write = 0;
    mem_ready = 0;

    #10 reset = 0;

    // Test case 1: Read miss
    address = 5'h01;
    read = 1;
    mem_read_data = 32'hDEADBEEF;
    mem_ready = 1;
    #10 read = 0;
    #20;

    // Test case 2: Write hit
    address = 5'h01;
    write = 1;
    write_data = 32'hCAFEBABE;
    #10 write = 0;
    #20;

    // Test case 3: Read hit
    address = 5'h01;
    read = 1;
    #10 read = 0;
    #20;

    #100 $finish;
  end

  initial begin
    $dumpfile("cache_controller.vcd");
    $dumpvars(0, cache_controller_tb);
  end

endmodule