`timescale 1ns/1ps

module elevator_control_system #(
    parameter integer N = 8,
    parameter integer DOOR_OPEN_TIME_MS = 500
) (
    input  wire                     clk,
    input  wire                     reset,
    input  wire [N-1:0]             call_requests,
    input  wire                     emergency_stop,
    input  wire                     overload,
    output wire [$clog2(N)-1:0]     current_floor,
    output reg                      direction,
    output reg                      door_open,
    output reg                      up_led,
    output reg                      down_led,
    output reg                      overload_led,
    output reg [2:0]                system_status
);

    typedef enum logic [2:0] {
        IDLE           = 3'b000,
        MOVING_UP      = 3'b001,
        MOVING_DOWN    = 3'b010,
        EMERGENCY_HALT = 3'b011,
        DOOR_OPEN      = 3'b100
    } state_t;

    localparam integer CLK_FREQ_MHZ = 100;
`ifdef SIMULATION
    localparam integer SIM_DOOR_OPEN_TIME_US = 50; // 0.05 ms
    localparam integer DOOR_OPEN_CYCLES = CLK_FREQ_MHZ * SIM_DOOR_OPEN_TIME_US;
`else
    localparam integer DOOR_OPEN_CYCLES = DOOR_OPEN_TIME_MS * CLK_FREQ_MHZ * 1000;
`endif

    state_t state, next_state;
    reg [$clog2(N)-1:0] current_floor_reg, current_floor_next;
    reg [N-1:0] pending_requests, pending_requests_next;
    reg [$clog2(DOOR_OPEN_CYCLES+1)-1:0] door_open_counter;
    reg [$clog2(DOOR_OPEN_CYCLES+1)-1:0] door_open_counter_next;
    reg direction_next;

    integer i;
    reg has_up_req;
    reg has_down_req;

    assign current_floor = current_floor_reg;

    always_comb begin
        has_up_req = 1'b0;
        has_down_req = 1'b0;

        for (i = 0; i < N; i = i + 1) begin
            if ((i > current_floor_reg) && pending_requests[i]) begin
                has_up_req = 1'b1;
            end
            if ((i < current_floor_reg) && pending_requests[i]) begin
                has_down_req = 1'b1;
            end
        end

        next_state = state;
        current_floor_next = current_floor_reg;
        pending_requests_next = pending_requests | call_requests;
        direction_next = direction;
        door_open_counter_next = door_open_counter;

        if (pending_requests[current_floor_reg]) begin
            pending_requests_next[current_floor_reg] = 1'b0;
        end

        if (state != DOOR_OPEN) begin
            door_open_counter_next = DOOR_OPEN_CYCLES[$clog2(DOOR_OPEN_CYCLES+1)-1:0];
        end

        case (state)
            IDLE: begin
                if (emergency_stop) begin
                    next_state = EMERGENCY_HALT;
                end else if (overload) begin
                    next_state = DOOR_OPEN;
                end else if (pending_requests[current_floor_reg]) begin
                    next_state = DOOR_OPEN;
                end else if (direction) begin
                    if (has_up_req) begin
                        next_state = MOVING_UP;
                        direction_next = 1'b1;
                    end else if (has_down_req) begin
                        next_state = MOVING_DOWN;
                        direction_next = 1'b0;
                    end
                end else begin
                    if (has_down_req) begin
                        next_state = MOVING_DOWN;
                        direction_next = 1'b0;
                    end else if (has_up_req) begin
                        next_state = MOVING_UP;
                        direction_next = 1'b1;
                    end
                end
            end

            MOVING_UP: begin
                if (emergency_stop) begin
                    next_state = EMERGENCY_HALT;
                end else if (overload) begin
                    next_state = DOOR_OPEN;
                end else if (current_floor_reg == N-1) begin
                    if (has_down_req) begin
                        next_state = MOVING_DOWN;
                        direction_next = 1'b0;
                    end else begin
                        next_state = IDLE;
                    end
                end else begin
                    current_floor_next = current_floor_reg + 1'b1;
                    if (pending_requests[current_floor_reg + 1'b1]) begin
                        next_state = DOOR_OPEN;
                    end else begin
                        next_state = MOVING_UP;
                    end
                end
            end

            MOVING_DOWN: begin
                if (emergency_stop) begin
                    next_state = EMERGENCY_HALT;
                end else if (overload) begin
                    next_state = DOOR_OPEN;
                end else if (current_floor_reg == 0) begin
                    if (has_up_req) begin
                        next_state = MOVING_UP;
                        direction_next = 1'b1;
                    end else begin
                        next_state = IDLE;
                    end
                end else begin
                    current_floor_next = current_floor_reg - 1'b1;
                    if (pending_requests[current_floor_reg - 1'b1]) begin
                        next_state = DOOR_OPEN;
                    end else begin
                        next_state = MOVING_DOWN;
                    end
                end
            end

            EMERGENCY_HALT: begin
                if (!emergency_stop) begin
                    next_state = IDLE;
                end
            end

            DOOR_OPEN: begin
                if (emergency_stop) begin
                    next_state = EMERGENCY_HALT;
                end else if (overload) begin
                    next_state = DOOR_OPEN;
                    door_open_counter_next = DOOR_OPEN_CYCLES[$clog2(DOOR_OPEN_CYCLES+1)-1:0];
                end else if (door_open_counter == 0) begin
                    if (direction) begin
                        if (has_up_req) begin
                            next_state = MOVING_UP;
                            direction_next = 1'b1;
                        end else if (has_down_req) begin
                            next_state = MOVING_DOWN;
                            direction_next = 1'b0;
                        end else begin
                            next_state = IDLE;
                        end
                    end else begin
                        if (has_down_req) begin
                            next_state = MOVING_DOWN;
                            direction_next = 1'b0;
                        end else if (has_up_req) begin
                            next_state = MOVING_UP;
                            direction_next = 1'b1;
                        end else begin
                            next_state = IDLE;
                        end
                    end
                end else begin
                    door_open_counter_next = door_open_counter - 1'b1;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            current_floor_reg <= '0;
            pending_requests <= '0;
            direction <= 1'b1;
            door_open_counter <= DOOR_OPEN_CYCLES[$clog2(DOOR_OPEN_CYCLES+1)-1:0];
            system_status <= IDLE;
        end else begin
            state <= next_state;
            current_floor_reg <= current_floor_next;
            pending_requests <= pending_requests_next;
            direction <= direction_next;
            door_open_counter <= door_open_counter_next;
            system_status <= next_state;
        end
    end

    always_comb begin
        door_open = (state == DOOR_OPEN);
        up_led = (state == MOVING_UP);
        down_led = (state == MOVING_DOWN);
        overload_led = overload;
    end

endmodule
