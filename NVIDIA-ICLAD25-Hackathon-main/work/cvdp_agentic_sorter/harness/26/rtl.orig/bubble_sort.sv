module bubble_sorting_engine #(
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

    // Internal registers to hold the array
    reg [WIDTH-1:0] array [0:N-1];

    // FSM states
    localparam IDLE    = 2'd0;
    localparam SORTING = 2'd1;
    localparam DONE    = 2'd2;

    reg [1:0]  state, next_state;

    // Variables for bubble sort indexing
    reg [$clog2(N)-1:0] i;  // Outer loop index
    reg [$clog2(N)-1:0] j;  // Inner loop index

    // Wires for comparison and swap
    wire [WIDTH-1:0] val_j;
    wire [WIDTH-1:0] val_j1;

    assign val_j  = array[j];
    assign val_j1 = array[j+1];

    // FSM: Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = SORTING;
            end
            SORTING: begin
                // Transition to DONE once all passes are complete
                if (i == (N-1) && j == (N-2))
                    next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // FSM: Output and counter updates
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            i <= 0;
            j <= 0;
            done <= 0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Load the array from in_data
                        for (int k = 0; k < N; k = k + 1) begin
                            array[k] <= in_data[(k+1)*WIDTH-1 -: WIDTH];
                        end
                        i <= 0;
                        j <= 0;
                    end
                end

                SORTING: begin
                    // Perform a single comparison and swap if needed
                    if (val_j > val_j1) begin
                        array[j]   <= val_j1;
                        array[j+1] <= val_j;
                    end

                    // Update j
                    if (j == N-2) begin
                        // One pass completed, increment i
                        j <= 0;
                        i <= i + 1;
                    end else begin
                        j <= j + 1;
                    end
                end

                DONE: begin
                    // Sorting complete
                    done <= 1;
                    // Output the sorted data
                    for (int m = 0; m < N; m = m + 1) begin
                        out_data[(m+1)*WIDTH-1 -: WIDTH] <= array[m];
                    end
                end
                default: begin
                end
            endcase
        end
    end

endmodule