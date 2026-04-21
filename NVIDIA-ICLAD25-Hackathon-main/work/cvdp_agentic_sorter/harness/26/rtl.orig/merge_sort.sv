module merge_sorting_engine #(
    parameter N = 8,             // Number of elements to sort
    parameter WIDTH = 8          // Bit-width of each element
)(
    input  wire                clk,
    input  wire                rst,
    input  wire                start,
    input  wire [N*WIDTH-1:0]  in_data,
    output reg                 done,
    output reg [N*WIDTH-1:0]   out_data
);

    //-------------------------------------------------
    // Local Parameters & Functions
    //-------------------------------------------------
    localparam IDLE  = 0;
    localparam LOAD  = 1;
    localparam SORT  = 2;
    localparam MERGE = 3;
    localparam DONE  = 4;

    // Function to compute floor(log2(value)) at compile time
    function integer clog2;
        input integer value;
        integer i;
        begin
            clog2 = 0;
            for (i = 1; i < value; i = i << 1) begin
                clog2 = clog2 + 1;
            end
        end
    endfunction

    // We choose ADDR_WIDTH big enough so we can store up to ~4*N in subarray_size
    // For N=8, 4*N=32 => log2(32)=5 => plus 1 => 6 bits => can store up to 63 safely.
    localparam ADDR_WIDTH = clog2(4 * N) + 1;

    //-------------------------------------------------
    // Internal Signals
    //-------------------------------------------------
    reg [2:0]                 state; // Enough for 5 states: IDLE..DONE

    // Internal memory of N elements
    reg [WIDTH-1:0]           data_mem [0:N-1];

    // Indices and counters with widened bit-width
    reg [ADDR_WIDTH-1:0]      base_idx;
    reg [ADDR_WIDTH-1:0]      left_idx;
    reg [ADDR_WIDTH-1:0]      right_idx;
    reg [ADDR_WIDTH-1:0]      merge_idx;
    reg [ADDR_WIDTH-1:0]      subarray_size;

    // Temporary buffer for merged sub-array
    reg [WIDTH-1:0]           tmp_merge [0:N-1];

    // Temporary registers for current left/right values
    reg [WIDTH-1:0]           left_val;
    reg [WIDTH-1:0]           right_val;

    integer i, k;
    integer left_end, right_end;
    integer l_addr,    r_addr;

    //-------------------------------------------------
    // State Machine
    //-------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset
            state         <= IDLE;
            done          <= 1'b0;
            out_data      <= {N*WIDTH{1'b0}};
            base_idx      <= 0;
            left_idx      <= 0;
            right_idx     <= 0;
            merge_idx     <= 0;
            subarray_size <= 1;
        end else begin
            case (state)

                //----------------------------------
                // IDLE: Wait for start signal
                //----------------------------------
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                //----------------------------------
                // LOAD: Copy from in_data to data_mem
                //----------------------------------
                LOAD: begin
                    for (i = 0; i < N; i = i + 1) begin
                        data_mem[i] <= in_data[i*WIDTH +: WIDTH];
                    end

                    // Initialize for sorting
                    base_idx      <= 0;
                    left_idx      <= 0;
                    right_idx     <= 0;
                    merge_idx     <= 0;
                    subarray_size <= 1;

                    state <= SORT;
                end

                //----------------------------------
                // SORT: Each pass merges sub-arrays of size subarray_size
                //----------------------------------
                SORT: begin
                    // If subarray_size is strictly greater than N, we've fully sorted
                    // (ensures we do a merge pass at subarray_size == N)
                    if (subarray_size >= N) begin
                        state <= DONE;
                    end else begin
                        // Prepare to merge pairs of sub-arrays
                        base_idx  <= 0;
                        merge_idx <= 0;
                        left_idx  <= 0;
                        right_idx <= 0;
                        state     <= MERGE;
                    end
                end

                //----------------------------------
                // MERGE: Merge one pair of sub-arrays
                //----------------------------------
                MERGE: begin
                    // Compare/pick smaller
                    if ((l_addr <= left_end) && (r_addr <= right_end)) begin
                        if (left_val <= right_val) begin
                            tmp_merge[merge_idx] <= left_val;
                            left_idx <= left_idx + 1;
                        end else begin
                            tmp_merge[merge_idx] <= right_val;
                            right_idx <= right_idx + 1;
                        end
                        merge_idx <= merge_idx + 1;
                    end
                    else if (l_addr <= left_end) begin
                        // Only left sub-array has data
                        tmp_merge[merge_idx] <= left_val;
                        left_idx <= left_idx + 1;
                        merge_idx <= merge_idx + 1;
                    end
                    else if (r_addr <= right_end) begin
                        // Only right sub-array has data
                        tmp_merge[merge_idx] <= right_val;
                        right_idx <= right_idx + 1;
                        merge_idx <= merge_idx + 1;
                    end
                    else begin
                        // Both sub-arrays are exhausted => write back merged results
                        for (k = 0; k < N; k = k + 1) begin
                            if ( (k < merge_idx) && (k < (subarray_size << 1)) && ((base_idx + k) < N) )
                            begin
                                data_mem[base_idx + k] <= tmp_merge[k];
                            end
                        end

                        // Move base_idx to next pair of sub-arrays
                        base_idx  <= base_idx + (subarray_size << 1);
                        left_idx  <= 0;
                        right_idx <= 0;
                        merge_idx <= 0;

                        // If we merged all pairs in this pass, double subarray_size
                        if ((base_idx + (subarray_size << 1)) >= N) begin
                            subarray_size <= subarray_size << 1;
                            state         <= SORT;
                        end
                    end
                end

                //----------------------------------
                // DONE: Output the fully sorted array
                //----------------------------------
                DONE: begin
                    for (i = 0; i < N; i = i + 1) begin
                        out_data[i*WIDTH +: WIDTH] <= data_mem[i];
                    end
                    done  <= 1'b1;
                    state <= IDLE;  // or remain in DONE, your preference
                end

                default: state <= IDLE;
            endcase
        end
    end

always @ (*) begin
    if(state == MERGE) begin
        left_end  = base_idx + subarray_size - 1;
        right_end = base_idx + (subarray_size << 1) - 1;

        // Boundaries of left and right sub-arrays
        if (left_end >= N) left_end = N - 1;
        if (right_end >= N) right_end = N - 1;

        // Calculate addresses
        l_addr = base_idx + left_idx;
        r_addr = base_idx + subarray_size + right_idx;

        // Safe read for left_val
        if ((l_addr <= left_end) && (l_addr < N))
            left_val = data_mem[l_addr];
        else
            left_val = {WIDTH{1'b1}};  // or '0' if you prefer

        // Safe read for right_val
        if ((r_addr <= right_end) && (r_addr < N))
            right_val = data_mem[r_addr];
        else
            right_val = {WIDTH{1'b1}};
    end else begin
        left_end = 0;
        right_end = 0;
        l_addr = 0;
        r_addr = 0;
        left_val = 0;
        right_val = 0;
    end
end

endmodule