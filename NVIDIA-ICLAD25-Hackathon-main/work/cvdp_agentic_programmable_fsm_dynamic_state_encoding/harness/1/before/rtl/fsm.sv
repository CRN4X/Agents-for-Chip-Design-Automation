module fsm (
    input clk,
    input reset,
    input [3:0] input_signal,
    input [63:0] config_state_map_flat,
    input [127:0] config_transition_map_flat,
    output reg [7:0] current_state,
    output reg error_flag,
    output reg [7:0] operation_result
);

    
    reg [7:0] state;
    reg [7:0] next_state;
    
    wire [7:0] config_state_map0 = config_state_map_flat[7:0];
    wire [7:0] config_state_map1 = config_state_map_flat[15:8];
    wire [7:0] config_state_map2 = config_state_map_flat[23:16];
    wire [7:0] config_state_map3 = config_state_map_flat[31:24];
    wire [7:0] config_state_map4 = config_state_map_flat[39:32];
    wire [7:0] config_state_map5 = config_state_map_flat[47:40];
    wire [7:0] config_state_map6 = config_state_map_flat[55:48];
    wire [7:0] config_state_map7 = config_state_map_flat[63:56];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= 0;
            current_state <= 0;
            error_flag    <= 0;
        end else begin
            state         <= next_state;
            current_state <= next_state;
        end
    end

    always @(*) begin
        integer idx;
        idx = (state << 4) + input_signal; 
        next_state = config_transition_map_flat[(idx * 8) + 7 -: 8];
        
        if (next_state > 8'h7) begin
            error_flag = 1;
            next_state = 0; 
        end else begin
            error_flag = 0;
        end

        case (state)
            8'h0: operation_result = config_state_map0 + input_signal;
            8'h1: operation_result = config_state_map1 - input_signal;
            8'h2: operation_result = config_state_map2 & input_signal;
            8'h3: operation_result = config_state_map3 | input_signal;
            default: operation_result = 8'hFF; 
        endcase
    end

endmodule