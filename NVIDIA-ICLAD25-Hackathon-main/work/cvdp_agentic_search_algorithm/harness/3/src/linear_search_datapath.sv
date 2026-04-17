module linear_search_datapath #(
  parameter DATA_WIDTH  = 8              ,
  parameter ADDR_WIDTH  = 4              ,
  parameter MEM_DEPTH   = 1 << ADDR_WIDTH,  // Total memory size
  parameter MAX_MATCHES = 8                 // Max number of indices to store in buffer
) (
  input  logic                                clk            ,  // Clock
  input  logic                                srst           ,  // Active High Synchronous reset
  input  logic                                enable         ,  // Enable signal from control FSM
  input  logic                                pause          ,  // Pause signal from control FSM
  input  logic [              DATA_WIDTH-1:0] key            ,  // Key to match against memory contents
  input  logic [              DATA_WIDTH-1:0] mem_read_data  ,  // Data read from memory
  output logic [              ADDR_WIDTH-1:0] mem_read_addr  ,  // Address to read from memory
  output logic [(MAX_MATCHES*ADDR_WIDTH)-1:0] match_indices  ,  // Buffer storing match indices
  output logic [   $clog2(MAX_MATCHES+1)-1:0] match_count    ,  // Number of matches found
  output logic                                search_done    ,  // High when search completes
  output logic                                match_overflow    // High if match buffer overflows
);

  logic [           ADDR_WIDTH-1:0] addr               ;
  logic [           ADDR_WIDTH-1:0] addr_dly           ;
  logic [$clog2(MAX_MATCHES+1)-1:0] match_count_temp   ;
  logic                             match_overflow_temp;
  logic                             enable_reg         ;
  logic                             mem_valid          ;
  logic                             pause_dly          ;

  always_ff @(posedge clk)
    enable_reg <= enable;

  always_ff @(posedge clk)
    pause_dly <= pause;

  always_ff @(posedge clk or posedge srst)
    if (srst) begin
      mem_valid <= 0;
    end else if (enable && !enable_reg) begin
      mem_valid <= 1;
    end else if (addr_dly == MEM_DEPTH - 1) begin
      mem_valid <= 0;
    end


  // Address generation logic
  always_ff @(posedge clk or posedge srst) begin
    if (srst) begin
      addr <= '0;  // Reset address
      addr_dly <= '0;
    end else if (pause_dly) begin
      // Hold address during pause
    end else if (enable && !enable_reg && addr == 0) begin
      addr <= 1;
      addr_dly <= addr;
    end else if (addr != 0) begin
      // Increment address or reset to 0 if search ends
      if (addr == MEM_DEPTH - 1) begin
        addr <= 0;
        addr_dly <= addr;
      end else begin
        addr <= addr + 1;
        addr_dly <= addr;
      end
    end else begin
      addr_dly <= addr;
    end
  end

  // Match logic and match buffer handling
  always_ff @(posedge clk or posedge srst) begin
    if (srst) begin
      match_count_temp    <= 0;
      match_overflow_temp <= 0;

      // Clear match_indices buffer
      for (int i = 0; i < MAX_MATCHES; i++) begin
        match_indices[i*ADDR_WIDTH+:ADDR_WIDTH] <= 0;
      end
    end else if (pause_dly) begin
      // Hold match logic during pause
    end else if (mem_valid && !search_done) begin
      if (mem_read_data == key) begin
        // If match found and room in buffer, store address
        if (match_count_temp < MAX_MATCHES) begin
        `ifndef BUG_1
          match_indices[match_count_temp*ADDR_WIDTH+:ADDR_WIDTH] <= addr_dly;
        `else 
          match_indices[match_count_temp*ADDR_WIDTH+:ADDR_WIDTH] <= addr;    
        `endif
          match_count_temp                <= match_count_temp + 1;
        `ifndef BUG_3
        `else 
          match_overflow_temp <= 1;
        `endif
        end else begin
        `ifndef BUG_2
          match_overflow_temp <= 1;  // Set overflow if buffer full
        `else 
          match_overflow_temp <= 0;
        `endif
        end
      end
    end
    else if (search_done) begin
      match_count_temp    <= 0;
      match_overflow_temp <= 0;
    end
  end

  always_ff @(posedge clk or posedge srst)
    if (srst) begin
      match_count <= '0;
      match_overflow <= 0;
    end
    else if (search_done) begin
      match_count <= match_count_temp; 
      match_overflow <= match_overflow_temp;
    end

  // Search done signal generation
  always_ff @(posedge clk or posedge srst) begin
    if (srst) begin
      search_done <= 0;
    end else if (pause_dly) begin
      // Hold done state during pause
    end else if (enable && !search_done) begin
      // Set done when last address is reached
      if (addr_dly == MEM_DEPTH - 1) begin
        search_done <= 1;
      end
    end
    else begin
      search_done <= 0;
    end
  end

  // Connect internal address to memory read address output
  assign mem_read_addr = addr;

endmodule
