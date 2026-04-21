module brick_sorting_engine #(
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

    // ----------------------------------------------------------
    // Internal Parameters and State Encoding
    // ----------------------------------------------------------
    localparam IDLE = 2'd0,
               LOAD = 2'd1,
               SORT = 2'd2,
               DONE = 2'd3;

    // ----------------------------------------------------------
    // Internal Registers
    // ----------------------------------------------------------
    reg [1:0]  state, next_state;

    // Store data in a register array for easy swapping
    reg [WIDTH-1:0] data_array [0:N-1];

    // Pass counter: we will run up to N passes
    reg [$clog2(N+1)-1:0] pass_cnt;

    // Pair index: on each pass, we compare-swap one pair per clock
    reg [$clog2(N/2+1):0] pair_idx;

    // ----------------------------------------------------------
    // Next-State Logic
    // ----------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
            end

            LOAD: begin
                // After loading input data, go to SORT state
                next_state = SORT;
            end

            SORT: begin
                // Once we've completed N passes, sorting is done
                if (pass_cnt == N)
                    next_state = DONE;
            end

            DONE: begin
                // Optionally return to IDLE if desired
                // For a one-shot, we can just stay in DONE unless reset
                // Here, we return to IDLE if start is deasserted
                if (!start)
                    next_state = IDLE;
            end
        endcase
    end

    // ----------------------------------------------------------
    // Sequential State Update
    // ----------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ----------------------------------------------------------
    // Main Control: pass_cnt, pair_idx, and compare-swap
    // ----------------------------------------------------------
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            done      <= 1'b0;
            pass_cnt  <= 0;
            pair_idx  <= 0;
        end
        else begin
            case (state)

                //--------------------------------------
                // IDLE: wait for start, clear signals
                //--------------------------------------
                IDLE: begin
                    done     <= 1'b0;
                    pass_cnt <= 0;
                    pair_idx <= 0;
                end

                //--------------------------------------
                // LOAD: capture input data into array
                //--------------------------------------
                LOAD: begin
                    // Load all N elements from in_data
                    for (i = 0; i < N; i = i + 1) begin
                        data_array[i] <= in_data[i*WIDTH +: WIDTH];
                    end
                    // Initialize counters
                    pass_cnt <= 0;
                    pair_idx <= 0;
                end

                //--------------------------------------
                // SORT: perform Brick Sort passes
                //--------------------------------------
                SORT: begin
                    // Compare-swap the current pair
                    // Check if we are within the valid pair range
                    // Distinguish odd-even pass from even-odd pass
                    if (pass_cnt[0] == 1'b0) begin
                        // even-odd pass => pair = (2*pair_idx, 2*pair_idx+1)
                        for(pair_idx=0; pair_idx<(N+1)/2; pair_idx=pair_idx+1) begin
                            if (data_array[2*pair_idx] > data_array[2*pair_idx+1]) begin
                                // Swap
                                {data_array[2*pair_idx], data_array[2*pair_idx+1]} <= {data_array[2*pair_idx+1], data_array[2*pair_idx]};
                            end
                        end
                    end
                    else begin
                        // odd-even pass => pair = (2*pair_idx+1, 2*pair_idx+2
                        for(pair_idx=0; pair_idx<((N+1)/2) - 1; pair_idx=pair_idx+1) begin
                            if ((2*pair_idx+2) < N) begin
                                if (data_array[2*pair_idx+1] > data_array[2*pair_idx+2]) begin
                                    // Swap
                                    {data_array[2*pair_idx+1], data_array[2*pair_idx+2]} <= {data_array[2*pair_idx+2], data_array[2*pair_idx+1]};
                                end
                            end
                        end
                    end

                    // Completed all pairs in this pass -> next pass
                    pass_cnt <= pass_cnt + 1;

                end // SORT

                //--------------------------------------
                // DONE: output final data, assert done
                //--------------------------------------
                DONE: begin
                    done <= 1'b1;
                    // Drive out_data from data_array
                    for (i = 0; i < N; i = i + 1) begin
                        out_data[i*WIDTH +: WIDTH] <= data_array[i];
                    end
                end

            endcase
        end
    end

endmodule