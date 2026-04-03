module traffic_controller_fsm ( 
    input i_clk,                     // System clock input
    input i_rst_b,                   // Active-low reset signal
    input i_vehicle_sensor_input,     // High when a vehicle is present on the side road
    input i_short_timer,              // High when the short timer expires
    input i_long_timer,               // High when the long timer expires
    output reg o_short_trigger,       // Trigger for the short timer (active high)
    output reg o_long_trigger,        // Trigger for the long timer (active high)
    output reg [2:0] o_main,          // Main road traffic lights (3-bit: Red, Yellow, Green)
    output reg [2:0] o_side           // Side road traffic lights (3-bit: Red, Yellow, Green)
);
    
// State encoding for the FSM using local parameters
localparam p_state_S1 = 2'd0 ;       // State S1: Main road green, side road red
localparam p_state_S2 = 2'd1 ;       // State S2: Main road yellow, side road red
localparam p_state_S3 = 2'd2 ;       // State S3: Main road red, side road green
localparam p_state_S4 = 2'd3 ;       // State S4: Main road red, side road yellow

// Registers for holding the current state and next state
reg [1:0]   r_state;                 // Current state of the FSM
reg [1:0]   r_next_state;            // Next state of the FSM

//-----------------------------------------------------------------------------
// Next State Logic
//-----------------------------------------------------------------------------
// This always block calculates the next state based on the current state and inputs
always @(*) begin
    if (!i_rst_b) begin              // If reset is asserted (active-low)
        r_next_state = p_state_S1;   // Go to initial state (S1) after reset
    end else begin
        case (r_state)
        // State S1: Main road green, side road red
        // Transition to S2 if a vehicle is detected and the long timer expires
        p_state_S1: begin
            if (i_vehicle_sensor_input & i_long_timer) begin
                r_next_state = p_state_S2;  // Move to state S2 (main road yellow)
            end else begin
                r_next_state = p_state_S1;  // Remain in state S1 if no conditions met
            end
        end
        // State S2: Main road yellow, side road red
        // Transition to S3 when the short timer expires
        p_state_S2: begin
            if (i_short_timer) begin
                r_next_state = p_state_S3;  // Move to state S3 (side road green)
            end else begin
                r_next_state = p_state_S2;  // Remain in state S2
            end
        end
        // State S3: Main road red, side road green
        // Transition to S4 if no vehicle is detected or the long timer expires
        p_state_S3: begin
            if ((!i_vehicle_sensor_input) | i_long_timer) begin
                r_next_state = p_state_S4;  // Move to state S4 (side road yellow)
            end else begin
                r_next_state = p_state_S3;  // Remain in state S3
            end
        end
        // State S4: Main road red, side road yellow
        // Transition to S1 when the short timer expires
        p_state_S4: begin
            if (i_short_timer) begin
                r_next_state = p_state_S1;  // Move to state S1 (main road green)
            end else begin
                r_next_state = p_state_S4;  // Remain in state S4
            end
        end
        endcase
    end
end

//-----------------------------------------------------------------------------
// State Assignment Logic
//-----------------------------------------------------------------------------
// This always block updates the current state on the rising edge of the clock or reset
always @(posedge i_clk or negedge i_rst_b) begin
    if (!i_rst_b) begin                  // If reset is asserted (active-low)
        r_state <= p_state_S1;           // Initialize to state S1 after reset
    end else begin
        r_state <= r_next_state;         // Move to the next state on the clock edge
    end
end

//-----------------------------------------------------------------------------
// Output Logic
//-----------------------------------------------------------------------------
// This always block defines the output signals based on the current state
always @(posedge i_clk or negedge i_rst_b) begin
    if (!i_rst_b) begin                  // If reset is asserted (active-low)
        o_main <= 3'd0;                  // Reset main road lights
        o_side <= 3'd0;                  // Reset side road lights
        o_long_trigger <= 1'b0;          // Reset long timer trigger
        o_short_trigger <= 1'b0;         // Reset short timer trigger
    end else begin
        case (r_state)
        // State S1: Main road green, side road red, trigger long timer
        p_state_S1: begin
            o_main <= 3'b001;            // Main road green light
            o_side <= 3'b100;            // Side road red light
            o_long_trigger <= 1'b1;      // Trigger long timer
            o_short_trigger <= 1'b0;     // Do not trigger short timer
        end
        // State S2: Main road yellow, side road red, trigger short timer
        p_state_S2: begin
            o_main <= 3'b010;            // Main road yellow light
            o_side <= 3'b100;            // Side road red light
            o_long_trigger <= 1'b0;      // Do not trigger long timer
            o_short_trigger <= 1'b1;     // Trigger short timer
        end
        // State S3: Main road red, side road green, trigger long timer
        p_state_S3: begin
            o_main <= 3'b100;            // Main road red light
            o_side <= 3'b001;            // Side road green light
            o_long_trigger <= 1'b1;      // Trigger long timer
            o_short_trigger <= 1'b0;     // Do not trigger short timer
        end
        // State S4: Main road red, side road yellow, trigger short timer
        p_state_S4: begin
            o_main <= 3'b100;            // Main road red light
            o_side <= 3'b010;            // Side road yellow light
            o_long_trigger <= 1'b0;      // Do not trigger long timer
            o_short_trigger <= 1'b1;     // Trigger short timer
        end
        endcase
    end
end

endmodule