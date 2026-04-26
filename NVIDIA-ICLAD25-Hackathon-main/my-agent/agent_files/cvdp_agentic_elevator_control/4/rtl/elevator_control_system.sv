`timescale 1ns/1ns

module elevator_control_system #(
    parameter N = 8,
    parameter DOOR_OPEN_TIME_MS = 500
) (
    input  wire                   clk,
    input  wire                   reset,
    input  wire [N-1:0]           call_requests,
    input  wire                   emergency_stop,
    input  wire                   overload,
    output wire [$clog2(N)-1:0]   current_floor,
    output reg                    direction,
    output reg                    door_open,
    output reg [2:0]              system_status,
    output reg                    up_led,
    output reg                    down_led,
    output reg                    overload_led
);

    localparam [2:0] IDLE           = 3'b000;
    localparam [2:0] MOVING_UP      = 3'b001;
    localparam [2:0] MOVING_DOWN    = 3'b010;
    localparam [2:0] EMERGENCY_HALT = 3'b011;
    localparam [2:0] DOOR_OPEN      = 3'b100;

    localparam integer DOOR_OPEN_CYCLES = 20;

    reg [2:0] state, next_state;
    reg [$clog2(N)-1:0] floor_reg, next_floor;
    reg [N-1:0] pending_reqs, next_pending_reqs;
    reg [31:0] door_counter, next_door_counter;
    reg overload_hold, next_overload_hold;

    integer i;
    reg has_above;
    reg has_below;

    assign current_floor = floor_reg;

    always_comb begin
        has_above = 1'b0;
        has_below = 1'b0;
        for (i = 0; i < N; i = i + 1) begin
            if (pending_reqs[i]) begin
                if (i > floor_reg)
                    has_above = 1'b1;
                if (i < floor_reg)
                    has_below = 1'b1;
            end
        end

        next_state = state;
        next_floor = floor_reg;
        next_pending_reqs = pending_reqs | call_requests;
        next_door_counter = door_counter;
        next_overload_hold = overload_hold;

        if (state == DOOR_OPEN) begin
            next_pending_reqs[floor_reg] = 1'b0;
        end

        if (emergency_stop) begin
            next_state = EMERGENCY_HALT;
            next_door_counter = 0;
            next_overload_hold = 1'b0;
        end else if (overload) begin
            next_state = DOOR_OPEN;
            next_door_counter = 0;
            next_overload_hold = 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    if (next_pending_reqs[floor_reg]) begin
                        next_state = DOOR_OPEN;
                        next_door_counter = 0;
                    end else if (has_above) begin
                        next_state = MOVING_UP;
                    end else if (has_below) begin
                        next_state = MOVING_DOWN;
                    end
                end

                MOVING_UP: begin
                    if (floor_reg < N-1)
                        next_floor = floor_reg + 1'b1;

                    if (next_pending_reqs[next_floor]) begin
                        next_state = DOOR_OPEN;
                        next_door_counter = 0;
                    end else begin
                        has_above = 1'b0;
                        has_below = 1'b0;
                        for (i = 0; i < N; i = i + 1) begin
                            if (next_pending_reqs[i]) begin
                                if (i > next_floor)
                                    has_above = 1'b1;
                                if (i < next_floor)
                                    has_below = 1'b1;
                            end
                        end

                        if (has_above)
                            next_state = MOVING_UP;
                        else if (has_below)
                            next_state = MOVING_DOWN;
                        else
                            next_state = IDLE;
                    end
                end

                MOVING_DOWN: begin
                    if (floor_reg > 0)
                        next_floor = floor_reg - 1'b1;

                    if (next_pending_reqs[next_floor]) begin
                        next_state = DOOR_OPEN;
                        next_door_counter = 0;
                    end else begin
                        has_above = 1'b0;
                        has_below = 1'b0;
                        for (i = 0; i < N; i = i + 1) begin
                            if (next_pending_reqs[i]) begin
                                if (i > next_floor)
                                    has_above = 1'b1;
                                if (i < next_floor)
                                    has_below = 1'b1;
                            end
                        end

                        if (has_below)
                            next_state = MOVING_DOWN;
                        else if (has_above)
                            next_state = MOVING_UP;
                        else
                            next_state = IDLE;
                    end
                end

                DOOR_OPEN: begin
                    if (overload_hold) begin
                        next_overload_hold = 1'b0;
                        next_door_counter = 0;
                        if (next_pending_reqs[floor_reg])
                            next_state = DOOR_OPEN;
                        else if (has_above)
                            next_state = MOVING_UP;
                        else if (has_below)
                            next_state = MOVING_DOWN;
                        else
                            next_state = IDLE;
                    end else if (door_counter < (DOOR_OPEN_CYCLES - 1)) begin
                        next_door_counter = door_counter + 1;
                        next_state = DOOR_OPEN;
                    end else begin
                        next_door_counter = 0;
                        if (next_pending_reqs[floor_reg])
                            next_state = DOOR_OPEN;
                        else if (has_above)
                            next_state = MOVING_UP;
                        else if (has_below)
                            next_state = MOVING_DOWN;
                        else
                            next_state = IDLE;
                    end
                end

                EMERGENCY_HALT: begin
                    next_state = IDLE;
                end

                default: begin
                    next_state = IDLE;
                end
            endcase
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            floor_reg <= 0;
            pending_reqs <= 0;
            door_counter <= 0;
            overload_hold <= 1'b0;
            direction <= 1'b1;
            door_open <= 1'b0;
            system_status <= IDLE;
            up_led <= 1'b0;
            down_led <= 1'b0;
            overload_led <= 1'b0;
        end else begin
            state <= next_state;
            floor_reg <= next_floor;
            pending_reqs <= next_pending_reqs;
            door_counter <= next_door_counter;
            overload_hold <= next_overload_hold;

            door_open <= (next_state == DOOR_OPEN);
            system_status <= next_state;
            overload_led <= overload;

            up_led <= (next_state == MOVING_UP);
            down_led <= (next_state == MOVING_DOWN);

            if (next_state == MOVING_UP)
                direction <= 1'b1;
            else if (next_state == MOVING_DOWN)
                direction <= 1'b0;
        end
    end

endmodule
