module binary_search_tree_sort_construct #(
    parameter DATA_WIDTH = 16,
    parameter ARRAY_SIZE = 5
) (
    input clk,
    input reset,
    input reg [ARRAY_SIZE*DATA_WIDTH-1:0] data_in, // Input data to be sorted
    input start,
    output reg [ARRAY_SIZE*DATA_WIDTH-1:0] sorted_out, // Sorted output
    output reg done
);

    // Parameters for top-level FSM states
    parameter IDLE = 2'b00, BUILD_TREE = 2'b01, SORT_TREE = 2'b10;

    // Parameters for nested FSM states (Build Tree)
    parameter INIT = 2'b00, INSERT = 2'b01, TRAVERSE = 2'b10, COMPLETE = 2'b11;

    // Parameters for nested FSM states (Sort Tree)
    parameter S_INIT = 2'b00, S_TRAVERSE_LEFT = 2'b01, S_PROCESS_NODE = 2'b10, S_TRAVERSE_RIGHT = 2'b11;

    // Registers for FSM states
    reg [1:0] top_state, build_state, sort_state;

    // BST representation
    reg [ARRAY_SIZE*DATA_WIDTH-1:0] data_in_copy;
    reg [ARRAY_SIZE*DATA_WIDTH-1:0] temp_out;
    reg [ARRAY_SIZE*DATA_WIDTH-1:0] keys; // Array to store node keys
    reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] left_child; // Left child pointers
    reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] right_child; // Right child pointers
    reg [$clog2(ARRAY_SIZE):0] root; // Root node pointer
    reg [$clog2(ARRAY_SIZE):0] next_free_node; // Pointer to the next free node

    // Stack for in-order traversal
    reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] stack; // Stack for traversal
    reg [$clog2(ARRAY_SIZE):0] sp; // Stack pointer

    // Working registers
    reg [$clog2(ARRAY_SIZE):0] current_node; // Current node being processed
    reg [$clog2(ARRAY_SIZE):0] input_index; // Index for input data
    reg [$clog2(ARRAY_SIZE):0] output_index; // Index for output data
    reg [DATA_WIDTH-1:0] temp_data; // Temporary data register

    // Initialize all variables
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all states and variables
            top_state <= IDLE;
            build_state <= INIT;
            sort_state <= S_INIT;
            root <= {($clog2(ARRAY_SIZE)+1){1'b1}}; // Null pointer
            next_free_node <= 0;
            sp <= 0;
            input_index <= 0;
            output_index <= 0;
            done <= 0;

            // Clear tree arrays
            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                keys[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
                left_child[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}}; 
                right_child[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                stack[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                temp_out[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
                sorted_out[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
            end

        end else begin
            case (top_state)
                IDLE: begin
                    done <= 0;
                    input_index <= 0;
                    output_index <= 0; 
                    root <= {($clog2(ARRAY_SIZE)+1){1'b1}}; ; // Null pointer
                    next_free_node <= 0;
                    sp <= 0;
                    for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        keys[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
                        left_child[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}}; 
                        right_child[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                        stack[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                        temp_out[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
                        sorted_out[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
                    end
                    if (start) begin
                        // Load input data into input array
                        top_state <= BUILD_TREE;
                        build_state <= INIT;
                        data_in_copy <= data_in;
                    end
                end
                BUILD_TREE: begin
                    case (build_state)
                        INIT: begin
                            if (input_index < ARRAY_SIZE) begin
                                temp_data <= data_in_copy[input_index*DATA_WIDTH +: DATA_WIDTH]; 
                                input_index <= input_index + 1;
                                build_state <= INSERT;
                            end else begin
                                build_state <= COMPLETE;
                            end
                        end

                        INSERT: begin
                            if (root == {($clog2(ARRAY_SIZE)+1){1'b1}}) begin
                                // Tree is empty, insert at root
                                root <= next_free_node;
                                keys[next_free_node*DATA_WIDTH +: DATA_WIDTH] <= temp_data;
                                next_free_node <= next_free_node + 1; 
                                build_state <= INIT;
                            end else begin
                                // Traverse the tree to find the correct position
                                current_node <= root; 
                                build_state <= TRAVERSE;
                            end
                        end
                        
                        TRAVERSE: begin      
                            if ((temp_data < keys[current_node*DATA_WIDTH +: DATA_WIDTH])) begin
                                if (left_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] == {($clog2(ARRAY_SIZE)+1){1'b1}}) begin 
                                    left_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= next_free_node; 
                                    keys[next_free_node*DATA_WIDTH +: DATA_WIDTH] <= temp_data;
                                    next_free_node <= next_free_node + 1;
                                    build_state <= INIT;
                                end else begin
                                    current_node <= left_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]; 
                                end
                            end else begin
                                if (right_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] == {($clog2(ARRAY_SIZE)+1){1'b1}}) begin 
                                    right_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= next_free_node; 
                                    keys[next_free_node*DATA_WIDTH +: DATA_WIDTH] <= temp_data; 
                                    next_free_node <= next_free_node + 1;
                                    build_state <= INIT;
                                end else begin
                                    current_node <= right_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]; 
                                end
                            end
                        end
                        COMPLETE: begin
                            // Tree construction complete
                            top_state <= SORT_TREE;
                            sort_state <= S_INIT;
                        end
                    endcase
                end

                SORT_TREE: begin
                    case (sort_state)
                        S_INIT: begin
                            
                            if (root != {($clog2(ARRAY_SIZE)+1){1'b1}}) begin 
                                current_node <= root; // Start from the root node
                                sp <= 0;
                                sort_state <= S_TRAVERSE_LEFT;
                            end
                        end

                        S_TRAVERSE_LEFT: begin
                            if (current_node != {($clog2(ARRAY_SIZE)+1){1'b1}}) begin
                                stack[sp*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= current_node;
                                sp <= sp + 1;
                                current_node <= left_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];
                            end else begin
                                sort_state <= S_PROCESS_NODE;
                            end
                        end

                        S_PROCESS_NODE: begin
                            if (sp > 0) begin
                                sp <= sp - 1;
                                current_node <= stack[(sp-1)*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];
                                output_index <= output_index + 1; 
                                temp_out[output_index*DATA_WIDTH +: DATA_WIDTH] <= keys[stack[($unsigned(sp)-1)*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]*DATA_WIDTH +: DATA_WIDTH]; // Output the key
                                sort_state <= S_TRAVERSE_RIGHT;
                            end else begin
                                done <= 1; // All nodes processed
                                sort_state <= S_INIT;
                                top_state <= IDLE;
                                sorted_out <= temp_out;
                            end
                        end

                        S_TRAVERSE_RIGHT: begin
                            current_node <= right_child[current_node*($clog2(ARRAY_SIZE)+1) +:($clog2(ARRAY_SIZE)+1)];
                            sort_state <= S_TRAVERSE_LEFT;
                        end
                    endcase    
                end

                default: begin
                    top_state <= IDLE; // Default behavior for top-level FSM
                end
            endcase
        end
    end
endmodule