module delete_node_binary_search_tree #(
    parameter DATA_WIDTH = 16,         // Width of the data (of a single element)
    parameter ARRAY_SIZE = 5          // Maximum number of elements in the BST
) (

    input clk,                                  // Clock signal
    input reset,                                // Reset signal
    input reg start,                            // Start signal to initiate the search
    input reg [DATA_WIDTH-1:0] delete_key,      // Key to delete in the BST
    input reg [$clog2(ARRAY_SIZE):0] root,      // Root node of the BST
    input reg [ARRAY_SIZE*DATA_WIDTH-1:0] keys, // Node keys in the BST
    input reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] left_child,           // Left child pointers
    input reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] right_child,           // Right child pointers
    output reg [ARRAY_SIZE*DATA_WIDTH-1:0] modified_keys,                    // Node keys in the BST
    output reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] modified_left_child,  // Left child pointers
    output reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] modified_right_child, // Right child pointers
    output reg complete_deletion,         // Signal indicating search completion
    output reg delete_invalid            // Signal indicating invalid search
);
                                                                                                                                       
    // Parameters for FSM states
    parameter S_IDLE = 3'b000,                   // Idle state
              S_INIT = 3'b001,                   // Initialization state
              S_SEARCH_LEFT = 3'b010,            // Search in left subtree
              S_SEARCH_RIGHT = 3'b011,           // Search in both left and right subtrees
              S_DELETE = 3'b100,                 // Delete a node
              S_DELETE_COMPLETE = 3'b101,        // Complete deletion
              S_FIND_INORDER_SUCCESSOR = 3'b110; // State to find inorder successor

   
    // Registers to store the current FSM state
    reg [2:0] delete_state;

    // Variables to manage traversal
    reg found;                                 // Indicates if the key is found

    // Stacks for managing traversal of left and right subtrees
    reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] left_stack;  // Stack for left subtree traversal
    reg [ARRAY_SIZE*($clog2(ARRAY_SIZE)+1)-1:0] right_stack; // Stack for right subtree traversal
    reg [$clog2(ARRAY_SIZE)-1:0] sp_left;         // Stack pointer for left subtree
    reg [$clog2(ARRAY_SIZE)-1:0] sp_right;        // Stack pointer for right subtree

    // Pointers for the current nodes in left and right subtrees
    reg [$clog2(ARRAY_SIZE):0] current_left_node;  // Current node in the left subtree
    reg [$clog2(ARRAY_SIZE):0] current_right_node; // Current node in the right subtree
    reg [$clog2(ARRAY_SIZE):0] current_node;       // Current node

    // Integer for loop iterations
    integer i, j;
    reg [$clog2(ARRAY_SIZE):0] null_node;

    // Registers for inorder successor search
    reg [$clog2(ARRAY_SIZE):0] min_node;       // Inorder successor node

    // The INVALID pointer value used in comparisons.
    localparam [($clog2(ARRAY_SIZE)+1)-1:0] INVALID = {($clog2(ARRAY_SIZE)+1){1'b1}};
    localparam [DATA_WIDTH-1:0] INVALID_KEY = {DATA_WIDTH{1'b1}};

     // FSM for inorder successor search
    reg inorder_search_active;                 // Flag to activate inorder successor search

    // Always block triggered on the rising edge of the clock or reset signal
    always @(posedge clk or posedge reset) begin
         reg [$clog2(ARRAY_SIZE):0] lchild, rchild;
        if (reset) begin
            // Reset all states and variables
            delete_state <= S_IDLE;  // Set state to IDLE
            found <= 0;              // Reset found flag
            complete_deletion <= 0;     // Reset complete_deletion signal
            sp_left <= 0;            // Reset left stack pointer
            sp_right <= 0;           // Reset right stack pointer
            delete_invalid <= 0;     // Set invalid_key to 0
            inorder_search_active <= 0;           
            // Clear the stacks
            for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                left_stack[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                right_stack[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                modified_left_child[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                modified_right_child[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                modified_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
            end

        end else begin
            // Main FSM logic
            case (delete_state)
                S_IDLE: begin
                    // Reset intermediate variables
                     for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                        left_stack[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                        right_stack[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                        modified_left_child[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                        modified_right_child[i*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= {($clog2(ARRAY_SIZE)+1){1'b1}};
                        modified_keys[i*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                    end
                    complete_deletion <= 0;
                    delete_invalid <= 0;
                    inorder_search_active <= 0;
                    if (start) begin
                        // Start the search
                        sp_left <= 0;
                        sp_right <= 0;
                        found <= 0;
                        delete_state <= S_INIT; // Move to INIT state
                    end
                end

                S_INIT: begin
                    if (root != {($clog2(ARRAY_SIZE)+1){1'b1}}) begin
                        // Compare the delete key with the root key
                        if (delete_key == keys[root*DATA_WIDTH +: DATA_WIDTH]) begin
                            found <= 1;
                            current_node <= 0;
                            delete_state <= S_DELETE; // Move to complete search state
                        end else if (keys[0*DATA_WIDTH +: DATA_WIDTH] > delete_key) begin // Else if the first key in the keys array is greater than the delete key
                            delete_state <= S_SEARCH_LEFT;
                            current_left_node <= left_child[root*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];    // Set current left node pointer from the root's left child
                        end else begin
                            current_left_node <= left_child[root*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];    // Set current left node pointer from the root's left child
                            current_right_node <= right_child[root*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];  // Set current right node pointer from the root's right child
                            delete_state <= S_SEARCH_RIGHT; // Search in both left and right subtrees
                        end
                    end else begin
                        delete_invalid <= 1;
                        complete_deletion <= 0;
                        delete_state <= S_IDLE;
                    end
                end

                S_SEARCH_LEFT: begin
                    // Traverse the left subtree
                    if (current_left_node != {($clog2(ARRAY_SIZE)+1){1'b1}}) begin                // If left traversal is not finished and the current left node is valid
                        left_stack[sp_left*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= current_left_node;  // Push the current left node index onto the left stack
                        sp_left <= sp_left + 1;
                        current_left_node <= left_child[current_left_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];  // Move to the left child of the current node
                        if (delete_key == keys[current_left_node*DATA_WIDTH +: DATA_WIDTH]) begin    // If the key at the retrieved node matches the search key
                            found <= 1;
                            current_node <= current_left_node;  
                            delete_state <= S_DELETE; // Move to complete search state
                        end
                    end else if (sp_left > 0) begin
                        sp_left <= sp_left - 1;
                        current_left_node <= right_child[left_stack[(sp_left - 1)*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];   // Move to the right child of the popped node for further traversal
                    end else begin
                        if (found == 1) begin
                            delete_state <= S_DELETE; // Move to complete search state
                        end else begin
                            delete_invalid <= 1;
                            complete_deletion <= 0;
                            delete_state <= S_IDLE;
                        end
                    end
                end

                S_SEARCH_RIGHT: begin
                    if (current_right_node != {($clog2(ARRAY_SIZE)+1){1'b1}}) begin
                        right_stack[sp_right*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= current_right_node;
                        sp_right <= sp_right + 1;
                        current_right_node <= left_child[current_right_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]; // Move to left child of the current right node
                        if (delete_key == keys[current_right_node*DATA_WIDTH +: DATA_WIDTH]) begin
                            current_node <= current_right_node;
                            found <= 1;
                            delete_state <= S_DELETE;  
                        end
                    end else if (sp_right > 0) begin
                        sp_right <= sp_right - 1;
                        current_right_node <= right_child[right_stack[(sp_right - 1)*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]; // Move to right child of the popped node
                    end else begin
                        if (found == 1) begin
                            delete_state <= S_DELETE; // Move to complete search state
                        end else begin
                            delete_invalid <= 1;
                            complete_deletion <= 0;
                            delete_state <= S_IDLE;
                        end
                    end
                end

                S_DELETE: begin
                    // First, load the left and right child indices of the node.
                    modified_keys <= keys;     //if not copied here then will give buggy output with only valid values with the moddified tree without the original tree values
                    modified_left_child <= left_child;
                    modified_right_child <= right_child;

                    rchild = right_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];
                    lchild = left_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];

                    if (left_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] == INVALID
                                    && right_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] != INVALID) begin
                        // Node has only right child
                        // Replace the current node's key and pointers with those of its right child.
                        modified_keys[current_node*DATA_WIDTH +: DATA_WIDTH] <= keys[rchild*DATA_WIDTH +: DATA_WIDTH];
                        modified_left_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= left_child[rchild*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];
                        modified_right_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= right_child[rchild*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];
                        null_node <= rchild;
                        delete_state <= S_DELETE_COMPLETE;
                    end
                    else if (right_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] == INVALID
                                && left_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] != INVALID) begin
                        // Node has only left child.
                        modified_keys[current_node*DATA_WIDTH +: DATA_WIDTH] <= keys[lchild*DATA_WIDTH +: DATA_WIDTH];
                        modified_left_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= left_child[lchild*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];
                        modified_right_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= right_child[lchild*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];
                        null_node <= lchild;
                        delete_state <= S_DELETE_COMPLETE;
                    end
                    else if (right_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] == INVALID    //Will give bug 'x' is both condition set to != INVAALID
                                && left_child[current_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] == INVALID) begin
                        // Node has no right or left child
                        null_node <= current_node;
                        delete_state <= S_DELETE_COMPLETE;
                    end
                    else begin
                        // Node has two children.
                        // Start finding the inorder successor.
                        min_node <= rchild;
                        inorder_search_active <= 1;
                        delete_state <= S_FIND_INORDER_SUCCESSOR;
                        
                    end
                end

                S_FIND_INORDER_SUCCESSOR: begin
                    if (inorder_search_active) begin
                        if (left_child[min_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] != INVALID) begin
                            min_node <= left_child[min_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]; // Move to the left child
                        end else begin
                            // Copy the inorder successor's key into the current node.
                            modified_keys[current_node*DATA_WIDTH +: DATA_WIDTH] <= keys[min_node*DATA_WIDTH +: DATA_WIDTH];

                            // Delete the inorder successor by replacing it with its right child.
                            if (right_child[min_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]!= INVALID) begin
                                modified_keys[min_node*DATA_WIDTH +: DATA_WIDTH] <= keys[right_child[min_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]*DATA_WIDTH +: DATA_WIDTH];
                                modified_right_child[min_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= right_child[right_child[min_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];
                                modified_left_child[min_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= left_child[right_child[min_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)]*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];
                                null_node <= right_child[min_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)];
                            end else begin
                                null_node <= min_node;
                            end

                            delete_state <= S_DELETE_COMPLETE;
                            inorder_search_active <= 0;
                        end
                    end

                end

                S_DELETE_COMPLETE:begin
                    modified_keys[null_node*DATA_WIDTH +: DATA_WIDTH] <= INVALID_KEY;
                    modified_left_child[null_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= INVALID;
                    modified_right_child[null_node*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= INVALID;
 
                    for (j=0; j < ARRAY_SIZE; j++) begin
                        if (modified_left_child[j*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] == null_node) begin  //Buggy output if instead of modified child the original child is checked
                            modified_left_child[j*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= INVALID;
                        end
                        if (modified_right_child[j*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] == null_node) begin
                            modified_right_child[j*($clog2(ARRAY_SIZE)+1) +: ($clog2(ARRAY_SIZE)+1)] <= INVALID;
                        end
                    end
                    delete_state <= S_IDLE;
                    complete_deletion <= 1;
                end

                default: begin
                    delete_state <= S_IDLE; // Default to IDLE state
                end
            endcase
        end
    end

endmodule