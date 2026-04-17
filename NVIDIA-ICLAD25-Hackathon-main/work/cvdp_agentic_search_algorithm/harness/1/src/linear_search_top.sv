module linear_search_top #(
  parameter DATA_WIDTH  = 8              ,
  parameter ADDR_WIDTH  = 4              ,
  parameter MEM_DEPTH   = 1 << ADDR_WIDTH,  // Total memory entries
  parameter MAX_MATCHES = 8                 // Max matching indices to store
) (
  input  logic                                clk             ,
  input  logic                                srst            ,  // Active High Synchronous reset
  input  logic                                start           ,  // Start signal for search
  input  logic                                pause           ,  // Pause signal to temporarily halt search
  input  logic [              DATA_WIDTH-1:0] key             ,  // Key to search for

  // New memory write interface
  input  logic                                mem_write_en    ,  // Memory write enable
  input  logic [              ADDR_WIDTH-1:0] mem_write_addr  ,  // Address to write data to
  input  logic [              DATA_WIDTH-1:0] mem_write_data  ,  // Data to write into memory

  output logic                                done            ,  // Indicates search is complete
  output logic [   $clog2(MAX_MATCHES+1)-1:0] match_count     ,  // Number of matches found
  output logic [(MAX_MATCHES*ADDR_WIDTH)-1:0] match_indices   ,  // List of match indices
  output logic                                match_overflow     // High if more matches than MAX_MATCHES
);

  // Internal signals
  logic                  enable        ;  // Signal to enable the datapath
  logic                  search_done   ;  // Signal from datapath indicating search is complete
  logic [ADDR_WIDTH-1:0] mem_read_addr ;  // Address to be read from memory
  logic [DATA_WIDTH-1:0] mem_read_data ;  // Data read from memory

  // Dual-port style memory:
  // Allows search datapath to read while controller (external or user) writes
  logic [DATA_WIDTH-1:0] memory[0:MEM_DEPTH-1];

  // Memory write logic (only allowed when datapath is not enabled)
  always_ff @(posedge clk) begin
    if (mem_write_en && !enable) begin
      memory[mem_write_addr] <= mem_write_data;
    end
  end

  // Memory read logic for datapath (1-cycle latency)
  always_ff @(posedge clk) begin
    if (enable)
      mem_read_data <= memory[mem_read_addr];
  end

  // Datapath instantiation:
  // Performs linear search and stores match indices
  linear_search_datapath #(
    .DATA_WIDTH (DATA_WIDTH ),
    .ADDR_WIDTH (ADDR_WIDTH ),
    .MAX_MATCHES(MAX_MATCHES)
  ) datapath (
    .clk           (clk           ),
    .srst          (srst          ),
    .enable        (enable        ),
    .pause         (pause         ),
    .key           (key           ),
    .mem_read_data (mem_read_data ),
    .mem_read_addr (mem_read_addr ),
    .match_indices (match_indices ),
    .match_count   (match_count   ),
    .search_done   (search_done   ),
    .match_overflow(match_overflow)
  );

  // Controller instantiation:
  // Controls the enable signal and handles start/pause/done logic
  linear_search_ctrl ctrl (
    .clk        (clk        ),
    .srst       (srst       ),
    .start      (start      ),
    .pause      (pause      ),
    .search_done(search_done),
    .enable     (enable     ),
    .done       (done       )
  );

endmodule
