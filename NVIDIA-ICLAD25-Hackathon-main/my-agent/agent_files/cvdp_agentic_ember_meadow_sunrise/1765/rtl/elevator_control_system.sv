/*
 * Elevator Control System
 */
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
    output reg [2:0]                system_status,
    output reg                      up_led,
    output reg                      down_led,
    output reg                      overload_led
);

    typedef enum logic [2:0] {
        IDLE           = 3'b000,
        MOVING_UP      = 3'b001,
        MOVING_DOWN    = 3'b010,
        EMERGENCY_HALT = 3'b011,
        DOOR_OPEN      = 3'b100
    } state_t;

`ifdef SIMULATION
    localparam integer DOOR_OPEN_CYCLES = 5000;
`else
    localparam integer DOOR_OPEN_CYCLES = DOOR_OPEN_TIME_MS * 100_000;
`endif

    localparam integer FLOOR_W = $clog2(N);
    localparam integer DOOR_CNT_W = $clog2(DOOR_OPEN_CYCLES + 1);

    state_t                  state_q, state_d;
    reg [FLOOR_W-1:0]        floor_q, floor_d;
    reg [N-1:0]              pending_q, pending_d;
    reg [DOOR_CNT_W-1:0]     door_cnt_q, door_cnt_d;
    reg [N-1:0]              req_mask;

    assign current_floor = floor_q;

    function automatic logic has_req_above(
        input logic [N-1:0] reqs,
        input logic [FLOOR_W-1:0] floor_idx
    );
        integer i;
        begin
            has_req_above = 1'b0;
            for (i = floor_idx + 1; i < N; i = i + 1) begin
                if (reqs[i]) has_req_above = 1'b1;
            end
        end
    endfunction

    function automatic logic has_req_below(
        input logic [N-1:0] reqs,
        input logic [FLOOR_W-1:0] floor_idx
    );
        integer i;
        begin
            has_req_below = 1'b0;
            for (i = 0; i < floor_idx; i = i + 1) begin
                if (reqs[i]) has_req_below = 1'b1;
            end
        end
    endfunction

    always_comb begin
        state_d = state_q;
        floor_d = floor_q;
        req_mask = pending_q | call_requests;
        pending_d = req_mask;
        door_cnt_d = door_cnt_q;

        if (state_q == DOOR_OPEN) begin
            pending_d[floor_q] = 1'b0;
        end

        unique case (state_q)
            IDLE: begin
                if (emergency_stop) begin
                    state_d = EMERGENCY_HALT;
                end else if (overload) begin
                    state_d = DOOR_OPEN;
                end else if (req_mask[floor_q]) begin
                    state_d = DOOR_OPEN;
                end else if (has_req_above(req_mask, floor_q)) begin
                    state_d = MOVING_UP;
                end else if (has_req_below(req_mask, floor_q)) begin
                    state_d = MOVING_DOWN;
                end
            end

            MOVING_UP: begin
                if (emergency_stop) begin
                    state_d = EMERGENCY_HALT;
                end else if (overload) begin
                    state_d = DOOR_OPEN;
                end else if (floor_q < N-1) begin
                    floor_d = floor_q + 1'b1;
                    if (req_mask[floor_q + 1'b1]) begin
                        state_d = DOOR_OPEN;
                        pending_d[floor_q + 1'b1] = 1'b0;
                    end else if (has_req_above(req_mask, floor_q + 1'b1)) begin
                        state_d = MOVING_UP;
                    end else if (has_req_below(req_mask, floor_q + 1'b1)) begin
                        state_d = MOVING_DOWN;
                    end else begin
                        state_d = IDLE;
                    end
                end else if (has_req_below(req_mask, floor_q)) begin
                    state_d = MOVING_DOWN;
                end else begin
                    state_d = IDLE;
                end
            end

            MOVING_DOWN: begin
                if (emergency_stop) begin
                    state_d = EMERGENCY_HALT;
                end else if (overload) begin
                    state_d = DOOR_OPEN;
                end else if (floor_q > 0) begin
                    floor_d = floor_q - 1'b1;
                    if (req_mask[floor_q - 1'b1]) begin
                        state_d = DOOR_OPEN;
                        pending_d[floor_q - 1'b1] = 1'b0;
                    end else if (has_req_below(req_mask, floor_q - 1'b1)) begin
                        state_d = MOVING_DOWN;
                    end else if (has_req_above(req_mask, floor_q - 1'b1)) begin
                        state_d = MOVING_UP;
                    end else begin
                        state_d = IDLE;
                    end
                end else if (has_req_above(req_mask, floor_q)) begin
                    state_d = MOVING_UP;
                end else begin
                    state_d = IDLE;
                end
            end

            DOOR_OPEN: begin
                if (emergency_stop) begin
                    state_d = EMERGENCY_HALT;
                end else if (overload) begin
                    state_d = DOOR_OPEN;
                end else if (door_cnt_q == 0) begin
                    if (has_req_above(pending_d, floor_q)) begin
                        state_d = MOVING_UP;
                    end else if (has_req_below(pending_d, floor_q)) begin
                        state_d = MOVING_DOWN;
                    end else begin
                        state_d = IDLE;
                    end
                end
            end

            EMERGENCY_HALT: begin
                if (!emergency_stop) begin
                    state_d = IDLE;
                end
            end

            default: begin
                state_d = IDLE;
            end
        endcase

        // Update door timer after final state_d is chosen.
        if ((state_q != DOOR_OPEN) && (state_d == DOOR_OPEN)) begin
            if (overload) begin
                door_cnt_d = '0;
            end else begin
                door_cnt_d = DOOR_OPEN_CYCLES[DOOR_CNT_W-1:0];
            end
        end else if (state_q == DOOR_OPEN) begin
            if (overload) begin
                door_cnt_d = '0;
            end else if (door_cnt_q != 0) begin
                door_cnt_d = door_cnt_q - 1'b1;
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state_q    <= IDLE;
            floor_q    <= '0;
            pending_q  <= '0;
            door_cnt_q <= '0;
        end else begin
            state_q    <= state_d;
            floor_q    <= floor_d;
            pending_q  <= pending_d;
            door_cnt_q <= door_cnt_d;
        end
    end

    always_comb begin
        system_status = state_q;
        direction = (state_q != MOVING_DOWN);

        door_open = (state_q == DOOR_OPEN);
        if (overload) begin
            door_open = 1'b1;
        end

        overload_led = overload;
        up_led = (state_q == MOVING_UP) && !overload;
        down_led = (state_q == MOVING_DOWN) && !overload;
    end

endmodule
