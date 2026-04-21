module selection_sorting_engine #(
    parameter N = 8,
    parameter WIDTH = 8
)(
    input  wire                clk,
    input  wire                rst,
    input  wire                start,
    input  wire [N*WIDTH-1:0]  in_data,
    output reg                 done,
    output reg [N*WIDTH-1:0]   out_data
);

    typedef enum logic [2:0] {
        IDLE  = 3'd0,
        LOAD  = 3'd1,
        FIND  = 3'd2,
        CHECK = 3'd3,
        SWAP  = 3'd4,
        NEXT  = 3'd5,
        DONE  = 3'd6
    } state_t;

    state_t current_state, next_state;

    reg [WIDTH-1:0] data_array [0:N-1];

    reg [$clog2(N)-1:0] i;
    reg [$clog2(N)-1:0] j;
    reg [$clog2(N)-1:0] min_idx;

    reg [WIDTH-1:0] min_val;
    integer idx;
    integer k;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
            end

            LOAD: begin
                next_state = FIND;
            end

            FIND: begin
                next_state = CHECK;
            end

            CHECK: begin
                if (j == N-1)
                    next_state = SWAP;
                else
                    next_state = CHECK;
            end

            SWAP: begin
                next_state = NEXT;
            end

            NEXT: begin
                if (i == N-2)
                    next_state = DONE;
                else
                    next_state = FIND;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            done     <= 1'b0;
            out_data <= {N*WIDTH{1'b0}};
        end
        else begin
            done <= (current_state == DONE);

            if (current_state == DONE) begin
                for (idx = 0; idx < N; idx = idx + 1) begin
                    out_data[idx*WIDTH +: WIDTH] <= data_array[idx];
                end
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (k = 0; k < N; k = k + 1) begin
                data_array[k] <= {WIDTH{1'b0}};
            end
            i       <= 0;
            j       <= 0;
            min_idx <= 0;
            min_val <= {WIDTH{1'b0}};
        end
        else begin
            case (current_state)

                IDLE: begin
                end

                LOAD: begin
                    for (k = 0; k < N; k = k + 1) begin
                        data_array[k] <= in_data[k*WIDTH +: WIDTH];
                    end
                    i       <= 0;
                    j       <= 0;
                    min_idx <= 0;
                    min_val <= {WIDTH{1'b0}};
                end

                FIND: begin
                    j          <= i + 1;
                    min_idx    <= i;
                    min_val    <= data_array[i];
                end

                CHECK: begin
                    if (data_array[j] < min_val) begin
                        min_val    <= data_array[j];
                        min_idx    <= j;
                    end

                    if (j < N-1) begin
                        j <= j + 1;
                    end
                end

                SWAP: begin
                    if (min_idx != i) begin
                        data_array[i]        <= data_array[min_idx];
                        data_array[min_idx]  <= data_array[i];
                    end
                end

                NEXT: begin
                    i <= i + 1;
                end

                DONE: begin
                end

                default: begin
                end
            endcase
        end
    end

endmodule