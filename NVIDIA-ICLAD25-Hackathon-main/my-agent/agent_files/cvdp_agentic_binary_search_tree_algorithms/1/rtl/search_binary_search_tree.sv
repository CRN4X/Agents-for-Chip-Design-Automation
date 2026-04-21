`timescale 1ns/1ns

module delete_node_binary_search_tree #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [DATA_WIDTH-1:0] delete_key,
    input wire [$clog2(ARRAY_SIZE):0] root,
    input wire [ARRAY_SIZE*DATA_WIDTH-1:0] keys,
    input wire [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] left_child,
    input wire [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] right_child,
    output reg [$clog2(ARRAY_SIZE):0] key_position,
    output reg complete_deletion,
    output reg delete_invalid,
    output reg [ARRAY_SIZE*DATA_WIDTH-1:0] modified_keys,
    output reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] modified_left_child,
    output reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] modified_right_child
);

    localparam PTR_W = $clog2(ARRAY_SIZE) + 1;
    localparam [PTR_W-1:0] INVALID_PTR = {PTR_W{1'b1}};
    localparam [DATA_WIDTH-1:0] INVALID_KEY = {DATA_WIDTH{1'b1}};

    localparam [2:0] S_IDLE              = 3'b000,
                     S_INIT              = 3'b001,
                     S_SEARCH_LEFT       = 3'b010,
                     S_SEARCH_LEFT_RIGHT = 3'b011,
                     S_DELETE            = 3'b100,
                     S_DELETE_COMPLETE   = 3'b101;

    reg [2:0] state;

    reg found;
    reg [PTR_W-1:0] position;
    reg [PTR_W-1:0] delete_node_idx;

    reg left_done, right_done;
    reg [ARRAY_SIZE*PTR_W-1:0] left_stack;
    reg [ARRAY_SIZE*PTR_W-1:0] right_stack;
    reg [$clog2(ARRAY_SIZE)-1:0] sp_left;
    reg [$clog2(ARRAY_SIZE)-1:0] sp_right;
    reg [PTR_W-1:0] current_left_node;
    reg [PTR_W-1:0] current_right_node;
    reg [$clog2(ARRAY_SIZE)-1:0] left_output_index;
    reg [$clog2(ARRAY_SIZE)-1:0] right_output_index;

    reg [DATA_WIDTH-1:0] work_keys [0:ARRAY_SIZE-1];
    reg [PTR_W-1:0] work_left [0:ARRAY_SIZE-1];
    reg [PTR_W-1:0] work_right [0:ARRAY_SIZE-1];

    integer i;
    integer j;
    integer guard;
    reg [PTR_W-1:0] node_idx;
    reg [PTR_W-1:0] left_idx;
    reg [PTR_W-1:0] right_idx;
    reg [PTR_W-1:0] succ_idx;
    reg [PTR_W-1:0] succ_parent;
    reg [PTR_W-1:0] succ_child;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            found <= 1'b0;
            position <= INVALID_PTR;
            delete_node_idx <= INVALID_PTR;
            complete_deletion <= 1'b0;
            key_position <= INVALID_PTR;
            delete_invalid <= 1'b0;
            left_output_index <= '0;
            right_output_index <= '0;
            sp_left <= '0;
            sp_right <= '0;
            left_done <= 1'b0;
            right_done <= 1'b0;
            current_left_node <= INVALID_PTR;
            current_right_node <= INVALID_PTR;

            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                left_stack[i*PTR_W +: PTR_W] <= INVALID_PTR;
                right_stack[i*PTR_W +: PTR_W] <= INVALID_PTR;
                modified_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                modified_left_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                modified_right_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        left_stack[i*PTR_W +: PTR_W] <= INVALID_PTR;
                        right_stack[i*PTR_W +: PTR_W] <= INVALID_PTR;
                        modified_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                        modified_left_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                        modified_right_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                    end

                    complete_deletion <= 1'b0;
                    delete_invalid <= 1'b0;
                    key_position <= INVALID_PTR;
                    position <= INVALID_PTR;
                    delete_node_idx <= INVALID_PTR;
                    found <= 1'b0;

                    if (start) begin
                        left_output_index <= '0;
                        right_output_index <= '0;
                        sp_left <= '0;
                        sp_right <= '0;
                        left_done <= 1'b0;
                        right_done <= 1'b0;
                        state <= S_INIT;
                    end
                end

                S_INIT: begin
                    if (root != INVALID_PTR) begin
                        if (delete_key == keys[root*DATA_WIDTH +: DATA_WIDTH]) begin
                            found <= 1'b1;
                            delete_node_idx <= root;
                            if (left_child[root*PTR_W +: PTR_W] == INVALID_PTR) begin
                                position <= '0;
                                state <= S_DELETE;
                            end else begin
                                state <= S_SEARCH_LEFT;
                                current_left_node <= left_child[root*PTR_W +: PTR_W];
                            end
                        end else if (keys[0*DATA_WIDTH +: DATA_WIDTH] > delete_key) begin
                            state <= S_SEARCH_LEFT;
                            current_left_node <= left_child[root*PTR_W +: PTR_W];
                        end else begin
                            current_left_node <= left_child[root*PTR_W +: PTR_W];
                            current_right_node <= right_child[root*PTR_W +: PTR_W];
                            state <= S_SEARCH_LEFT_RIGHT;
                        end
                    end else begin
                        state <= S_DELETE_COMPLETE;
                    end
                end

                S_SEARCH_LEFT: begin
                    if (current_left_node != INVALID_PTR) begin
                        left_stack[sp_left*PTR_W +: PTR_W] <= current_left_node;
                        sp_left <= sp_left + 1'b1;
                        current_left_node <= left_child[current_left_node*PTR_W +: PTR_W];
                    end else if (sp_left > 0) begin
                        sp_left <= sp_left - 1'b1;
                        current_left_node <= left_stack[(sp_left - 1'b1)*PTR_W +: PTR_W];
                        if (delete_key == keys[left_stack[(sp_left - 1'b1)*PTR_W +: PTR_W]*DATA_WIDTH +: DATA_WIDTH]) begin
                            found <= 1'b1;
                            delete_node_idx <= left_stack[(sp_left - 1'b1)*PTR_W +: PTR_W];
                            position <= left_output_index;
                            state <= S_DELETE;
                        end
                        left_output_index <= left_output_index + 1'b1;
                        current_left_node <= right_child[left_stack[(sp_left - 1'b1)*PTR_W +: PTR_W]*PTR_W +: PTR_W];
                    end else begin
                        if (found == 1'b1) begin
                            position <= left_output_index;
                        end
                        left_done <= 1'b1;
                        if (found) begin
                            state <= S_DELETE;
                        end else begin
                            state <= S_DELETE_COMPLETE;
                        end
                    end
                end

                S_SEARCH_LEFT_RIGHT: begin
                    if (!left_done && current_left_node != INVALID_PTR) begin
                        left_stack[sp_left*PTR_W +: PTR_W] <= current_left_node;
                        sp_left <= sp_left + 1'b1;
                        current_left_node <= left_child[current_left_node*PTR_W +: PTR_W];
                    end else if (!left_done && sp_left > 0) begin
                        sp_left <= sp_left - 1'b1;
                        current_left_node <= left_stack[(sp_left - 1'b1)*PTR_W +: PTR_W];
                        left_output_index <= left_output_index + 1'b1;
                        current_left_node <= right_child[left_stack[(sp_left - 1'b1)*PTR_W +: PTR_W]*PTR_W +: PTR_W];
                    end else if (!left_done) begin
                        left_done <= 1'b1;
                    end

                    if (!found) begin
                        if (!right_done && current_right_node != INVALID_PTR) begin
                            right_stack[sp_right*PTR_W +: PTR_W] <= current_right_node;
                            sp_right <= sp_right + 1'b1;
                            current_right_node <= left_child[current_right_node*PTR_W +: PTR_W];
                        end else if (!right_done && sp_right > 0) begin
                            sp_right <= sp_right - 1'b1;
                            current_right_node <= right_stack[(sp_right - 1'b1)*PTR_W +: PTR_W];
                            if (delete_key == keys[right_stack[(sp_right - 1'b1)*PTR_W +: PTR_W]*DATA_WIDTH +: DATA_WIDTH]) begin
                                found <= 1'b1;
                                delete_node_idx <= right_stack[(sp_right - 1'b1)*PTR_W +: PTR_W];
                            end
                            right_output_index <= right_output_index + 1'b1;
                            current_right_node <= right_child[right_stack[(sp_right - 1'b1)*PTR_W +: PTR_W]*PTR_W +: PTR_W];
                        end else if (!right_done) begin
                            right_done <= 1'b1;
                        end
                    end else if (left_done) begin
                        position <= left_output_index + right_output_index;
                        state <= S_DELETE;
                    end

                    if (right_done && left_done && !found) begin
                        state <= S_DELETE_COMPLETE;
                    end
                end

                S_DELETE: begin
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        work_keys[i] = keys[i*DATA_WIDTH +: DATA_WIDTH];
                        work_left[i] = left_child[i*PTR_W +: PTR_W];
                        work_right[i] = right_child[i*PTR_W +: PTR_W];
                    end

                    if (found) begin
                        node_idx = delete_node_idx;
                        left_idx = work_left[node_idx];
                        right_idx = work_right[node_idx];

                        if ((left_idx != INVALID_PTR) && (right_idx == INVALID_PTR)) begin
                            work_keys[node_idx] = work_keys[left_idx];
                            work_left[node_idx] = work_left[left_idx];
                            work_right[node_idx] = work_right[left_idx];

                            work_keys[left_idx] = INVALID_KEY;
                            work_left[left_idx] = INVALID_PTR;
                            work_right[left_idx] = INVALID_PTR;
                        end else if ((left_idx == INVALID_PTR) && (right_idx != INVALID_PTR)) begin
                            work_keys[node_idx] = work_keys[right_idx];
                            work_left[node_idx] = work_left[right_idx];
                            work_right[node_idx] = work_right[right_idx];

                            work_keys[right_idx] = INVALID_KEY;
                            work_left[right_idx] = INVALID_PTR;
                            work_right[right_idx] = INVALID_PTR;
                        end else if ((left_idx == INVALID_PTR) && (right_idx == INVALID_PTR)) begin
                            for (j = 0; j < ARRAY_SIZE; j = j + 1) begin
                                if (work_left[j] == node_idx) begin
                                    work_left[j] = INVALID_PTR;
                                end
                                if (work_right[j] == node_idx) begin
                                    work_right[j] = INVALID_PTR;
                                end
                            end
                            work_keys[node_idx] = INVALID_KEY;
                            work_left[node_idx] = INVALID_PTR;
                            work_right[node_idx] = INVALID_PTR;
                        end else begin
                            succ_parent = node_idx;
                            succ_idx = right_idx;
                            guard = 0;
                            while ((work_left[succ_idx] != INVALID_PTR) && (guard < ARRAY_SIZE)) begin
                                succ_parent = succ_idx;
                                succ_idx = work_left[succ_idx];
                                guard = guard + 1;
                            end

                            work_keys[node_idx] = work_keys[succ_idx];
                            succ_child = work_right[succ_idx];

                            if (work_left[succ_parent] == succ_idx) begin
                                work_left[succ_parent] = succ_child;
                            end else begin
                                work_right[succ_parent] = succ_child;
                            end

                            work_keys[succ_idx] = INVALID_KEY;
                            work_left[succ_idx] = INVALID_PTR;
                            work_right[succ_idx] = INVALID_PTR;
                        end

                        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                            modified_keys[i*DATA_WIDTH +: DATA_WIDTH] <= work_keys[i];
                            modified_left_child[i*PTR_W +: PTR_W] <= work_left[i];
                            modified_right_child[i*PTR_W +: PTR_W] <= work_right[i];
                        end
                    end else begin
                        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                            modified_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                            modified_left_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                            modified_right_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                        end
                    end

                    state <= S_DELETE_COMPLETE;
                end

                S_DELETE_COMPLETE: begin
                    if (!found) begin
                        complete_deletion <= 1'b0;
                        key_position <= INVALID_PTR;
                        delete_invalid <= 1'b1;
                        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                            modified_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                            modified_left_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                            modified_right_child[i*PTR_W +: PTR_W] <= INVALID_PTR;
                        end
                    end else begin
                        complete_deletion <= 1'b1;
                        key_position <= position;
                        delete_invalid <= 1'b0;
                    end
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
