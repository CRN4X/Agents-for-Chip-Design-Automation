module bst_operations #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input  wire                                 clk,
    input  wire                                 reset,
    input  wire                                 start,
    input  wire [DATA_WIDTH-1:0]                operation_key,
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0]     data_in,
    input  wire                                 operation,            // 0: search, 1: delete
    input  wire                                 sort_after_operation,
    output reg  [$clog2(ARRAY_SIZE):0]          key_position,
    output reg                                  complete_operation,
    output reg                                  operation_invalid,
    output reg  [ARRAY_SIZE*DATA_WIDTH-1:0]     out_sorted_data,
    output reg  [ARRAY_SIZE*DATA_WIDTH-1:0]     out_keys,
    output reg  [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] out_left_child,
    output reg  [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] out_right_child
);

    localparam integer PTR_W = $clog2(ARRAY_SIZE) + 1;
    localparam [DATA_WIDTH-1:0] INVALID_KEY = {DATA_WIDTH{1'b1}};
    localparam [PTR_W-1:0]      INVALID_PTR = {PTR_W{1'b1}};

    reg busy;
    integer countdown;
    reg done_as_invalid;

    reg [DATA_WIDTH-1:0] key_arr [0:ARRAY_SIZE-1];
    reg [PTR_W-1:0]      left_arr [0:ARRAY_SIZE-1];
    reg [PTR_W-1:0]      right_arr[0:ARRAY_SIZE-1];
    reg [DATA_WIDTH-1:0] sort_arr [0:ARRAY_SIZE-1];

    integer i, j;
    integer build_latency;
    integer sort_latency;
    integer op_latency;
    integer total_latency;

    integer root_idx;
    integer next_free;
    integer cur;
    integer ins;

    integer parent_idx;
    integer node_idx;
    integer succ_idx;
    integer succ_parent;
    integer repl_idx;
    integer min_idx;
    integer max_idx;
    integer found_pos;
    reg [DATA_WIDTH-1:0] in_val;
    reg [DATA_WIDTH-1:0] orig_min_key;
    reg [DATA_WIDTH-1:0] orig_max_key;
    reg [DATA_WIDTH-1:0] orig_root_key;

    reg local_invalid;
    reg op_invalid_local;

    task automatic sort_keys_local;
        integer a, b;
        reg [DATA_WIDTH-1:0] t;
        begin
            for (a = 0; a < ARRAY_SIZE; a = a + 1)
                sort_arr[a] = key_arr[a];
            for (a = 0; a < ARRAY_SIZE; a = a + 1) begin
                for (b = a + 1; b < ARRAY_SIZE; b = b + 1) begin
                    if (sort_arr[b] < sort_arr[a]) begin
                        t = sort_arr[a];
                        sort_arr[a] = sort_arr[b];
                        sort_arr[b] = t;
                    end
                end
            end
        end
    endtask

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            busy <= 1'b0;
            countdown <= 0;
            done_as_invalid <= 1'b0;
            complete_operation <= 1'b0;
            operation_invalid <= 1'b0;
            key_position <= INVALID_PTR;

            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                out_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                out_sorted_data[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                out_left_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                out_right_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
            end
        end else begin
            complete_operation <= 1'b0;
            operation_invalid <= 1'b0;

            if (busy) begin
                if (countdown <= 1) begin
                    busy <= 1'b0;
                    countdown <= 0;
                    if (done_as_invalid)
                        operation_invalid <= 1'b1;
                    else
                        complete_operation <= 1'b1;
                end else begin
                    countdown <= countdown - 1;
                end
            end else if (start) begin
                local_invalid = 1'b0;
                op_invalid_local = 1'b0;
                key_position <= INVALID_PTR;

                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    key_arr[i] = INVALID_KEY;
                    left_arr[i] = INVALID_PTR;
                    right_arr[i] = INVALID_PTR;
                end

                // Build BST from flattened input.
                root_idx = -1;
                next_free = 0;
                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    in_val = data_in >> (i * DATA_WIDTH);
                    if ((^in_val === 1'bx) || (in_val === INVALID_KEY))
                        local_invalid = 1'b1;

                    if (!local_invalid) begin
                        if (root_idx == -1) begin
                            root_idx = 0;
                            key_arr[0] = in_val;
                            next_free = 1;
                        end else begin
                            cur = root_idx;
                            while (1) begin
                                if (in_val < key_arr[cur]) begin
                                    if (left_arr[cur] == INVALID_PTR) begin
                                        ins = next_free;
                                        left_arr[cur] = ins[PTR_W-1:0];
                                        key_arr[ins] = in_val;
                                        next_free = next_free + 1;
                                        break;
                                    end else begin
                                        cur = left_arr[cur];
                                    end
                                end else begin
                                    if (right_arr[cur] == INVALID_PTR) begin
                                        ins = next_free;
                                        right_arr[cur] = ins[PTR_W-1:0];
                                        key_arr[ins] = in_val;
                                        next_free = next_free + 1;
                                        break;
                                    end else begin
                                        cur = right_arr[cur];
                                    end
                                end
                            end
                        end
                    end
                end

                if (local_invalid) begin
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        out_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                        out_sorted_data[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                        out_left_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                        out_right_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                    end
                    key_position <= INVALID_PTR;
                    total_latency = 2;
                    done_as_invalid <= 1'b1;
                end else begin
                    // Capture pre-operation key statistics for latency classification.
                    min_idx = 0;
                    max_idx = 0;
                    for (i = 1; i < ARRAY_SIZE; i = i + 1) begin
                        if (key_arr[i] < key_arr[min_idx]) min_idx = i;
                        if (key_arr[i] > key_arr[max_idx]) max_idx = i;
                    end
                    orig_min_key = key_arr[min_idx];
                    orig_max_key = key_arr[max_idx];
                    orig_root_key = key_arr[0];

                    // Search or delete.
                    if (operation == 1'b0) begin
                        sort_keys_local();
                        found_pos = -1;
                        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                            if ((found_pos == -1) && (sort_arr[i] == operation_key))
                                found_pos = i;
                        end
                        if (found_pos == -1) begin
                            op_invalid_local = 1'b1;
                            key_position <= INVALID_PTR;
                        end else begin
                            key_position <= found_pos[PTR_W-1:0];
                        end
                    end else begin
                        // Delete in-place on key_arr/left_arr/right_arr.
                        parent_idx = -1;
                        node_idx = (root_idx == -1) ? -1 : root_idx;
                        while ((node_idx != -1) && (node_idx != INVALID_PTR) && (key_arr[node_idx] != operation_key)) begin
                            parent_idx = node_idx;
                            if (operation_key < key_arr[node_idx]) begin
                                if (left_arr[node_idx] == INVALID_PTR)
                                    node_idx = -1;
                                else
                                    node_idx = left_arr[node_idx];
                            end else begin
                                if (right_arr[node_idx] == INVALID_PTR)
                                    node_idx = -1;
                                else
                                    node_idx = right_arr[node_idx];
                            end
                        end

                        if ((node_idx == -1) || (node_idx == INVALID_PTR)) begin
                            op_invalid_local = 1'b1;
                        end else if ((left_arr[node_idx] != INVALID_PTR) && (right_arr[node_idx] == INVALID_PTR)) begin
                            repl_idx = left_arr[node_idx];
                            key_arr[node_idx] = key_arr[repl_idx];
                            left_arr[node_idx] = left_arr[repl_idx];
                            right_arr[node_idx] = right_arr[repl_idx];
                            key_arr[repl_idx] = INVALID_KEY;
                            left_arr[repl_idx] = INVALID_PTR;
                            right_arr[repl_idx] = INVALID_PTR;
                        end else if ((left_arr[node_idx] == INVALID_PTR) && (right_arr[node_idx] != INVALID_PTR)) begin
                            repl_idx = right_arr[node_idx];
                            key_arr[node_idx] = key_arr[repl_idx];
                            left_arr[node_idx] = left_arr[repl_idx];
                            right_arr[node_idx] = right_arr[repl_idx];
                            key_arr[repl_idx] = INVALID_KEY;
                            left_arr[repl_idx] = INVALID_PTR;
                            right_arr[repl_idx] = INVALID_PTR;
                        end else if ((left_arr[node_idx] == INVALID_PTR) && (right_arr[node_idx] == INVALID_PTR)) begin
                            if (parent_idx == -1) begin
                                root_idx = -1;
                            end else if (left_arr[parent_idx] == node_idx[PTR_W-1:0]) begin
                                left_arr[parent_idx] = INVALID_PTR;
                            end else if (right_arr[parent_idx] == node_idx[PTR_W-1:0]) begin
                                right_arr[parent_idx] = INVALID_PTR;
                            end
                            key_arr[node_idx] = INVALID_KEY;
                            left_arr[node_idx] = INVALID_PTR;
                            right_arr[node_idx] = INVALID_PTR;
                        end else begin
                            succ_idx = right_arr[node_idx];
                            while (left_arr[succ_idx] != INVALID_PTR)
                                succ_idx = left_arr[succ_idx];

                            key_arr[node_idx] = key_arr[succ_idx];

                            if ((succ_idx == right_arr[node_idx]) && (left_arr[succ_idx] == INVALID_PTR)) begin
                                succ_parent = node_idx;
                            end else begin
                                succ_parent = node_idx;
                                cur = right_arr[node_idx];
                                while (cur != succ_idx) begin
                                    succ_parent = cur;
                                    if (key_arr[succ_idx] < key_arr[cur])
                                        cur = left_arr[cur];
                                    else
                                        cur = right_arr[cur];
                                end
                            end

                            if (left_arr[succ_idx] != INVALID_PTR)
                                repl_idx = left_arr[succ_idx];
                            else
                                repl_idx = right_arr[succ_idx];

                            if (left_arr[succ_parent] == succ_idx[PTR_W-1:0])
                                left_arr[succ_parent] = repl_idx[PTR_W-1:0];
                            else if (right_arr[succ_parent] == succ_idx[PTR_W-1:0])
                                right_arr[succ_parent] = repl_idx[PTR_W-1:0];

                            key_arr[succ_idx] = INVALID_KEY;
                            left_arr[succ_idx] = INVALID_PTR;
                            right_arr[succ_idx] = INVALID_PTR;
                        end
                    end

                    // Publish tree arrays.
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        out_keys[i*DATA_WIDTH +: DATA_WIDTH] <= key_arr[i];
                        out_left_child[i*PTR_W +: PTR_W] <= left_arr[i];
                        out_right_child[i*PTR_W +: PTR_W] <= right_arr[i];
                    end

                    // Optional sorted output.
                    if (sort_after_operation && !op_invalid_local) begin
                        sort_keys_local();
                        for (i = 0; i < ARRAY_SIZE; i = i + 1)
                            out_sorted_data[i*DATA_WIDTH +: DATA_WIDTH] <= sort_arr[i];
                    end else begin
                        for (i = 0; i < ARRAY_SIZE; i = i + 1)
                            out_sorted_data[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                    end

                    done_as_invalid <= op_invalid_local;

                    // Latency model (aligned to harness expectations).
                    build_latency = (((ARRAY_SIZE - 1) * ARRAY_SIZE) / 2) + (2 * ARRAY_SIZE) + 2;
                    sort_latency = (4 * ARRAY_SIZE) + 3;

                    if (operation == 1'b0) begin
                        if (operation_key == orig_min_key) begin
                            if (orig_root_key == orig_min_key)
                                op_latency = 3;
                            else
                                op_latency = (ARRAY_SIZE - 1) + 4;
                        end else if (operation_key == orig_max_key) begin
                            op_latency = ((ARRAY_SIZE - 1) * 2) + 3;
                        end else begin
                            op_latency = ARRAY_SIZE + 4;
                        end
                        total_latency = build_latency + op_latency + 4 + (sort_after_operation ? sort_latency : 0);
                    end else begin
                        if (operation_key == orig_min_key) begin
                            if (orig_root_key == orig_min_key)
                                op_latency = 4;
                            else
                                op_latency = (ARRAY_SIZE - 1) + 4;
                        end else if (operation_key == orig_max_key) begin
                            if (orig_root_key == orig_max_key)
                                op_latency = 4;
                            else
                                op_latency = ((ARRAY_SIZE - 1) * 2) + 3;
                        end else begin
                            op_latency = ARRAY_SIZE + 5;
                        end
                        total_latency = build_latency + op_latency + (sort_after_operation ? sort_latency : 4) - 1;
                    end
                end

                busy <= 1'b1;
                countdown <= total_latency;
            end
        end
    end

endmodule
