`timescale 1ns/1ns

module sorting_engine #(parameter WIDTH = 8)(
    input                     clk,
    input                     rst,
    input                     start,      // Start the sort when start=1
    input  [8*WIDTH-1:0]      in_data,    // 8 inputs, each WIDTH bits
    output reg                done,
    output reg [8*WIDTH-1:0]  out_data    // 8 outputs, sorted ascending
);

  // FSM state encoding
  localparam IDLE      = 3'd0,
             LOAD      = 3'd1,
             SORT_PAIRS= 3'd2,
             MERGE_2   = 3'd3,  // Merge both pair-groups into two 4-element groups in parallel
             FINALIZE  = 3'd4,  // One-cycle staging between final merge and output pack
             MERGE_4   = 3'd5,  // Merge the two 4-element groups into final 8-element sorted list
             DONE      = 3'd6;

  reg [2:0] state;

  // Internal storage for data at different stages.
  reg [WIDTH-1:0] stage0 [7:0];           // Loaded input data
  reg [WIDTH-1:0] sorted_pairs [7:0];     // After pair compare–swap
  reg [WIDTH-1:0] merge4_right [3:0];      // First 4–element sorted group (from indices 0–3)
  reg [WIDTH-1:0] merge4_left [3:0];     // Second 4–element sorted group (from indices 4–7)
  reg [WIDTH-1:0] final_sorted [7:0];     // Final 8–element sorted result

  // Merge pointers and counters.
  reg [3:0] merge_count;  // Counts how many outputs have been merged in current merge stage
  reg [2:0] ptr1, ptr2;   // Pointers for the two arrays being merged
  reg [1:0] ptr1_r, ptr2_r; // Pointers for merging sorted_pairs[0:1] with sorted_pairs[2:3]
  reg [1:0] ptr1_l, ptr2_l; // Pointers for merging sorted_pairs[4:5] with sorted_pairs[6:7]

  integer i; // loop variable for for–loops

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state      <= IDLE;
      done       <= 0;
      out_data   <= 0;
      merge_count<= 0;
      ptr1       <= 0;
      ptr2       <= 0;
      ptr1_r     <= 0;
      ptr2_r     <= 0;
      ptr1_l     <= 0;
      ptr2_l     <= 0;
    end else begin
      case (state)
        // Wait for the start signal.
        IDLE: begin
          done <= 0;
          if (start)
            state <= LOAD;
        end

        // Capture the 8 input elements from the flat bus into an array.
        LOAD: begin
          for (i = 0; i < 8; i = i + 1) begin
            stage0[i] <= in_data[i*WIDTH +: WIDTH];
          end
          state <= SORT_PAIRS;
        end

        // Stage 1: Compare-swap each adjacent pair.
        // The 8 numbers are divided into 4 pairs: indices {0,1}, {2,3}, {4,5}, {6,7}.
        SORT_PAIRS: begin
          // Pair 0
          if (stage0[0] <= stage0[1]) begin
            sorted_pairs[0] <= stage0[0];
            sorted_pairs[1] <= stage0[1];
          end else begin
            sorted_pairs[0] <= stage0[1];
            sorted_pairs[1] <= stage0[0];
          end
          // Pair 1
          if (stage0[2] <= stage0[3]) begin
            sorted_pairs[2] <= stage0[2];
            sorted_pairs[3] <= stage0[3];
          end else begin
            sorted_pairs[2] <= stage0[3];
            sorted_pairs[3] <= stage0[2];
          end
          // Pair 2
          if (stage0[4] <= stage0[5]) begin
            sorted_pairs[4] <= stage0[4];
            sorted_pairs[5] <= stage0[5];
          end else begin
            sorted_pairs[4] <= stage0[5];
            sorted_pairs[5] <= stage0[4];
          end
          // Pair 3
          if (stage0[6] <= stage0[7]) begin
            sorted_pairs[6] <= stage0[6];
            sorted_pairs[7] <= stage0[7];
          end else begin
            sorted_pairs[6] <= stage0[7];
            sorted_pairs[7] <= stage0[6];
          end
          // Initialize pointers for merge stage (MERGE_2)
          ptr1        <= 0;
          ptr2        <= 0;
          ptr1_r      <= 0;
          ptr2_r      <= 0;
          ptr1_l      <= 0;
          ptr2_l      <= 0;
          merge_count <= 0;
          state       <= MERGE_2;
        end

        // Stage 2: Merge both pair groups in parallel.
        MERGE_2: begin
          // Merge sorted_pairs[0:1] with sorted_pairs[2:3] -> merge4_right
          if ((ptr1_r < 2) && (ptr2_r < 2)) begin
            if (sorted_pairs[ptr1_r] <= sorted_pairs[ptr2_r+2]) begin
              merge4_right[merge_count] <= sorted_pairs[ptr1_r];
              ptr1_r <= ptr1_r + 1;
            end else begin
              merge4_right[merge_count] <= sorted_pairs[ptr2_r+2];
              ptr2_r <= ptr2_r + 1;
            end
          end else if (ptr1_r < 2) begin
            merge4_right[merge_count] <= sorted_pairs[ptr1_r];
            ptr1_r <= ptr1_r + 1;
          end else if (ptr2_r < 2) begin
            merge4_right[merge_count] <= sorted_pairs[ptr2_r+2];
            ptr2_r <= ptr2_r + 1;
          end

          // Merge sorted_pairs[4:5] with sorted_pairs[6:7] -> merge4_left
          if ((ptr1_l < 2) && (ptr2_l < 2)) begin
            if (sorted_pairs[ptr1_l+4] <= sorted_pairs[ptr2_l+6]) begin
              merge4_left[merge_count] <= sorted_pairs[ptr1_l+4];
              ptr1_l <= ptr1_l + 1;
            end else begin
              merge4_left[merge_count] <= sorted_pairs[ptr2_l+6];
              ptr2_l <= ptr2_l + 1;
            end
          end else if (ptr1_l < 2) begin
            merge4_left[merge_count] <= sorted_pairs[ptr1_l+4];
            ptr1_l <= ptr1_l + 1;
          end else if (ptr2_l < 2) begin
            merge4_left[merge_count] <= sorted_pairs[ptr2_l+6];
            ptr2_l <= ptr2_l + 1;
          end

          // Check if both 4-element merges are complete.
          if (merge_count == 3) begin
            merge_count <= 0;
            ptr1        <= 0;
            ptr2        <= 0;
            state       <= MERGE_4;
          end else begin
            merge_count <= merge_count + 1;
          end
        end

        // Stage 3: Merge the two 4–element groups (merge4_right and merge4_left)
        MERGE_4: begin
          if ((ptr1 < 4) && (ptr2 < 4)) begin
            if (merge4_right[ptr1] <= merge4_left[ptr2]) begin
              final_sorted[merge_count] <= merge4_right[ptr1];
              ptr1 <= ptr1 + 1;
            end else begin
              final_sorted[merge_count] <= merge4_left[ptr2];
              ptr2 <= ptr2 + 1;
            end
          end else if (ptr1 < 4) begin
            final_sorted[merge_count] <= merge4_right[ptr1];
            ptr1 <= ptr1 + 1;
          end else if (ptr2 < 4) begin
            final_sorted[merge_count] <= merge4_left[ptr2];
            ptr2 <= ptr2 + 1;
          end
          // Check if all 8 elements have been merged.
          if (merge_count == 7) begin
            merge_count <= 0;
            state       <= FINALIZE;
          end else begin
            merge_count <= merge_count + 1;
          end
        end

        FINALIZE: begin
          state <= DONE;
        end

        // Final state: pack the final_sorted array back into out_data and assert done.
        DONE: begin
          for (i = 0; i < 8; i = i + 1) begin
            out_data[i*WIDTH +: WIDTH] <= final_sorted[i];
          end
          done  <= 1;
          // Optionally, return to IDLE (or hold in DONE) so a new sort can begin.
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
