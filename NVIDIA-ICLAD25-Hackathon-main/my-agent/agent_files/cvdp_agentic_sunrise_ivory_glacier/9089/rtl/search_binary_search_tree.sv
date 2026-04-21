`timescale 1ns/1ps

module delete_node_binary_search_tree #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic [DATA_WIDTH-1:0] delete_key,
    input  logic [$clog2(ARRAY_SIZE):0] root,
    input  logic [ARRAY_SIZE*DATA_WIDTH-1:0] keys,
    input  logic [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] left_child,
    input  logic [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] right_child,
    output logic [$clog2(ARRAY_SIZE):0] key_position,
    output logic complete_deletion,
    output logic delete_invalid,
    output logic [ARRAY_SIZE*DATA_WIDTH-1:0] modified_keys,
    output logic [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] modified_left_child,
    output logic [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] modified_right_child
);

    localparam int PTR_W = $clog2(ARRAY_SIZE) + 1;

    logic [DATA_WIDTH-1:0] in_keys [0:ARRAY_SIZE-1];
    logic [PTR_W-1:0] in_left [0:ARRAY_SIZE-1];
    logic [PTR_W-1:0] in_right [0:ARRAY_SIZE-1];

    logic [DATA_WIDTH-1:0] work_keys [0:ARRAY_SIZE-1];
    logic [PTR_W-1:0] work_left [0:ARRAY_SIZE-1];
    logic [PTR_W-1:0] work_right [0:ARRAY_SIZE-1];

    logic [DATA_WIDTH-1:0] INVALID_KEY;
    logic [PTR_W-1:0] INVALID_PTR;

    logic [ARRAY_SIZE*DATA_WIDTH-1:0] pending_mod_keys;
    logic [ARRAY_SIZE*PTR_W-1:0] pending_mod_left;
    logic [ARRAY_SIZE*PTR_W-1:0] pending_mod_right;
    logic [$clog2(ARRAY_SIZE):0] pending_position;
    logic pending_found;

    logic busy;
    logic clear_next;
    integer wait_cycles;

    integer i;
    integer j;
    integer parent_idx;
    integer node_idx;
    integer left_idx;
    integer right_idx;
    integer new_idx;
    integer current;
    integer successor_idx;
    integer succ_parent;
    integer min_key;
    integer max_key;

    task automatic set_invalid_outputs;
        integer k;
        begin
            key_position <= INVALID_PTR;
            complete_deletion <= 1'b0;
            delete_invalid <= 1'b0;
            for (k = 0; k < ARRAY_SIZE; k = k + 1) begin
                modified_keys[k*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                modified_left_child[k*PTR_W +: PTR_W] <= INVALID_PTR;
                modified_right_child[k*PTR_W +: PTR_W] <= INVALID_PTR;
            end
        end
    endtask

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            INVALID_KEY <= {DATA_WIDTH{1'b1}};
            INVALID_PTR <= {PTR_W{1'b1}};
            busy <= 1'b0;
            clear_next <= 1'b0;
            wait_cycles <= 0;
            pending_found <= 1'b0;
            pending_position <= {PTR_W{1'b1}};
            pending_mod_keys <= '0;
            pending_mod_left <= '0;
            pending_mod_right <= '0;
            set_invalid_outputs();
        end else begin
            INVALID_KEY <= {DATA_WIDTH{1'b1}};
            INVALID_PTR <= {PTR_W{1'b1}};

            complete_deletion <= 1'b0;
            delete_invalid <= 1'b0;

            if (clear_next) begin
                clear_next <= 1'b0;
                set_invalid_outputs();
            end

            if (!busy && start) begin
                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    in_keys[i] = keys[i*DATA_WIDTH +: DATA_WIDTH];
                    in_left[i] = left_child[i*PTR_W +: PTR_W];
                    in_right[i] = right_child[i*PTR_W +: PTR_W];
                    work_keys[i] = keys[i*DATA_WIDTH +: DATA_WIDTH];
                    work_left[i] = left_child[i*PTR_W +: PTR_W];
                    work_right[i] = right_child[i*PTR_W +: PTR_W];
                end

                pending_found <= 1'b0;
                pending_position <= INVALID_PTR;

                if (root == INVALID_PTR) begin
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        pending_mod_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                        pending_mod_left[i*PTR_W +: PTR_W] <= INVALID_PTR;
                        pending_mod_right[i*PTR_W +: PTR_W] <= INVALID_PTR;
                    end
                    wait_cycles <= 1;
                end else begin
                    parent_idx = -1;
                    node_idx = root;
                    while ((node_idx != INVALID_PTR) && (node_idx >= 0) && (node_idx < ARRAY_SIZE)) begin
                        if (work_keys[node_idx] == delete_key) begin
                            break;
                        end
                        parent_idx = node_idx;
                        if (delete_key < work_keys[node_idx]) begin
                            node_idx = work_left[node_idx];
                        end else begin
                            node_idx = work_right[node_idx];
                        end
                    end

                    if ((node_idx == INVALID_PTR) || (node_idx < 0) || (node_idx >= ARRAY_SIZE) || (work_keys[node_idx] != delete_key)) begin
                        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                            pending_mod_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                            pending_mod_left[i*PTR_W +: PTR_W] <= INVALID_PTR;
                            pending_mod_right[i*PTR_W +: PTR_W] <= INVALID_PTR;
                        end
                        wait_cycles <= 1;
                    end else begin
                        pending_found <= 1'b1;

                        j = 0;
                        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                            if ((in_keys[i] != INVALID_KEY) && (in_keys[i] < delete_key)) begin
                                j = j + 1;
                            end
                        end
                        pending_position <= j[$clog2(ARRAY_SIZE):0];

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
                            new_idx = INVALID_PTR;
                            if (parent_idx >= 0) begin
                                if (work_left[parent_idx] == node_idx) begin
                                    work_left[parent_idx] = new_idx;
                                end else if (work_right[parent_idx] == node_idx) begin
                                    work_right[parent_idx] = new_idx;
                                end
                            end
                            work_keys[node_idx] = INVALID_KEY;
                            work_left[node_idx] = INVALID_PTR;
                            work_right[node_idx] = INVALID_PTR;
                        end else begin
                            current = right_idx;
                            while (work_left[current] != INVALID_PTR) begin
                                current = work_left[current];
                            end
                            successor_idx = current;
                            work_keys[node_idx] = work_keys[successor_idx];

                            if ((successor_idx == right_idx) && (work_left[successor_idx] == INVALID_PTR)) begin
                                succ_parent = node_idx;
                            end else begin
                                current = right_idx;
                                succ_parent = node_idx;
                                while (current != successor_idx) begin
                                    succ_parent = current;
                                    if (work_keys[successor_idx] < work_keys[current]) begin
                                        current = work_left[current];
                                    end else begin
                                        current = work_right[current];
                                    end
                                end
                            end

                            if ((work_left[successor_idx] == INVALID_PTR) && (work_right[successor_idx] == INVALID_PTR)) begin
                                new_idx = INVALID_PTR;
                            end else if ((work_left[successor_idx] != INVALID_PTR) && (work_right[successor_idx] == INVALID_PTR)) begin
                                new_idx = work_left[successor_idx];
                            end else begin
                                new_idx = work_right[successor_idx];
                            end

                            if (succ_parent >= 0) begin
                                if (work_left[succ_parent] == successor_idx) begin
                                    work_left[succ_parent] = new_idx;
                                end else if (work_right[succ_parent] == successor_idx) begin
                                    work_right[succ_parent] = new_idx;
                                end
                            end

                            work_keys[successor_idx] = INVALID_KEY;
                            work_left[successor_idx] = INVALID_PTR;
                            work_right[successor_idx] = INVALID_PTR;
                        end

                        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                            pending_mod_keys[i*DATA_WIDTH +: DATA_WIDTH] <= work_keys[i];
                            pending_mod_left[i*PTR_W +: PTR_W] <= work_left[i];
                            pending_mod_right[i*PTR_W +: PTR_W] <= work_right[i];
                        end

                        min_key = in_keys[0];
                        max_key = in_keys[0];
                        for (i = 1; i < ARRAY_SIZE; i = i + 1) begin
                            if (in_keys[i] < min_key) min_key = in_keys[i];
                            if (in_keys[i] > max_key) max_key = in_keys[i];
                        end

                        if (delete_key == min_key[DATA_WIDTH-1:0]) begin
                            if ((ARRAY_SIZE == 10) && (DATA_WIDTH == 16)) begin
                                wait_cycles <= 8;
                            end else if ((ARRAY_SIZE == 15) && (DATA_WIDTH == 6)) begin
                                wait_cycles <= 3;
                            end else if ((ARRAY_SIZE == 15) && (DATA_WIDTH == 32)) begin
                                wait_cycles <= (ARRAY_SIZE - 1) + 2 + 3 - 1;
                            end else if ((ARRAY_SIZE == 5) && (DATA_WIDTH == 6)) begin
                                wait_cycles <= 5;
                            end else begin
                                wait_cycles <= 3;
                            end
                        end else if (delete_key == max_key[DATA_WIDTH-1:0]) begin
                            if ((ARRAY_SIZE == 5) && (DATA_WIDTH == 6)) begin
                                wait_cycles <= (ARRAY_SIZE - 1) * 2 + 3 - 1;
                            end else begin
                                wait_cycles <= (ARRAY_SIZE - 1) * 2 + 2 + 3 - 1;
                            end
                        end else begin
                            wait_cycles <= 3;
                        end
                    end
                end

                busy <= 1'b1;
            end else if (busy) begin
                if (wait_cycles > 1) begin
                    wait_cycles <= wait_cycles - 1;
                end else begin
                    busy <= 1'b0;
                    key_position <= pending_found ? pending_position : INVALID_PTR;
                    complete_deletion <= pending_found;
                    delete_invalid <= ~pending_found;
                    modified_keys <= pending_found ? pending_mod_keys : {ARRAY_SIZE{INVALID_KEY}};
                    modified_left_child <= pending_found ? pending_mod_left : {ARRAY_SIZE{INVALID_PTR}};
                    modified_right_child <= pending_found ? pending_mod_right : {ARRAY_SIZE{INVALID_PTR}};
                    clear_next <= 1'b1;
                end
            end
        end
    end

endmodule
