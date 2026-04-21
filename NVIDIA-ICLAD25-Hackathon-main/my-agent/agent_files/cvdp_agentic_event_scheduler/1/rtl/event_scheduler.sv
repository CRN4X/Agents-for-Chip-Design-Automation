`timescale 1ns/1ns

module event_scheduler #(
    parameter int MAX_EVENTS = 16,
    parameter int TIMESTAMP_WIDTH = 16,
    parameter int PRIORITY_WIDTH = 4,
    parameter int TIME_INCREMENT = 10
) (
    input  logic                           clk,
    input  logic                           reset,
    input  logic                           add_event,
    input  logic                           cancel_event,
    input  logic [$clog2(MAX_EVENTS)-1:0] event_id,
    input  logic [TIMESTAMP_WIDTH-1:0]     timestamp,
    input  logic [PRIORITY_WIDTH-1:0]      priority_in,
    output logic                           event_triggered,
    output logic [$clog2(MAX_EVENTS)-1:0]  triggered_event_id,
    output logic                           error,
    output logic [TIMESTAMP_WIDTH-1:0]     current_time
);

    logic [TIMESTAMP_WIDTH-1:0] event_timestamps [0:MAX_EVENTS-1];
    logic [PRIORITY_WIDTH-1:0]  event_priorities [0:MAX_EVENTS-1];
    logic                       event_valid      [0:MAX_EVENTS-1];

    logic [TIMESTAMP_WIDTH-1:0] next_event_timestamps [0:MAX_EVENTS-1];
    logic [PRIORITY_WIDTH-1:0]  next_event_priorities [0:MAX_EVENTS-1];
    logic                       next_event_valid      [0:MAX_EVENTS-1];

    logic [TIMESTAMP_WIDTH-1:0] next_current_time;
    logic                       next_event_triggered;
    logic [$clog2(MAX_EVENTS)-1:0] next_triggered_event_id;
    logic                       next_error;

    integer i;
    integer best_idx;
    logic found_eligible;

    always_comb begin
        next_current_time = current_time + TIMESTAMP_WIDTH'(TIME_INCREMENT);
        next_event_triggered = 1'b0;
        next_triggered_event_id = '0;
        next_error = 1'b0;

        for (i = 0; i < MAX_EVENTS; i = i + 1) begin
            next_event_timestamps[i] = event_timestamps[i];
            next_event_priorities[i] = event_priorities[i];
            next_event_valid[i] = event_valid[i];
        end

        if (add_event) begin
            if (event_valid[event_id]) begin
                next_error = 1'b1;
            end else begin
                next_event_timestamps[event_id] = timestamp;
                next_event_priorities[event_id] = priority_in;
                next_event_valid[event_id] = 1'b1;
            end
        end

        if (cancel_event) begin
            if (next_event_valid[event_id]) begin
                next_event_valid[event_id] = 1'b0;
            end else begin
                next_error = 1'b1;
            end
        end

        found_eligible = 1'b0;
        best_idx = 0;
        for (i = 0; i < MAX_EVENTS; i = i + 1) begin
            if (next_event_valid[i] && (next_event_timestamps[i] <= next_current_time)) begin
                if (!found_eligible || (next_event_priorities[i] > next_event_priorities[best_idx])) begin
                    found_eligible = 1'b1;
                    best_idx = i;
                end
            end
        end

        if (found_eligible) begin
            next_event_triggered = 1'b1;
            next_triggered_event_id = $clog2(MAX_EVENTS)'(best_idx);
            next_event_valid[best_idx] = 1'b0;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_time <= '0;
            event_triggered <= 1'b0;
            triggered_event_id <= '0;
            error <= 1'b0;
            for (i = 0; i < MAX_EVENTS; i = i + 1) begin
                event_timestamps[i] <= '0;
                event_priorities[i] <= '0;
                event_valid[i] <= 1'b0;
            end
        end else begin
            current_time <= next_current_time;
            event_triggered <= next_event_triggered;
            triggered_event_id <= next_triggered_event_id;
            error <= next_error;
            for (i = 0; i < MAX_EVENTS; i = i + 1) begin
                event_timestamps[i] <= next_event_timestamps[i];
                event_priorities[i] <= next_event_priorities[i];
                event_valid[i] <= next_event_valid[i];
            end
        end
    end

endmodule
