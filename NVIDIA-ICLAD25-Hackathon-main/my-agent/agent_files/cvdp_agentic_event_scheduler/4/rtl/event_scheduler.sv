`timescale 1ns/1ns

module event_scheduler(
    input clk,
    input reset,
    input add_event,
    input cancel_event,
    input modify_event,
    input [3:0] event_id,
    input [15:0] timestamp,
    input [3:0] priority_in,
    input [15:0] new_timestamp,
    input [3:0] new_priority,
    input recurring_event,
    input [15:0] recurring_interval,
    output reg event_triggered,
    output reg [3:0] triggered_event_id,
    output reg error,
    output reg [15:0] current_time,
    output reg [15:0] log_event_time,
    output reg [3:0] log_event_id
);

    reg [15:0] event_timestamps [15:0];
    reg [3:0]  event_priorities [15:0];
    reg        event_valid [15:0];
    reg        event_recurring [15:0];
    reg [15:0] event_intervals [15:0];

    reg [15:0] tmp_current_time;
    reg [15:0] tmp_event_timestamps [15:0];
    reg [3:0]  tmp_event_priorities [15:0];
    reg        tmp_event_valid [15:0];
    reg        tmp_event_recurring [15:0];
    reg [15:0] tmp_event_intervals [15:0];

    integer i;
    integer chosen_event;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_time <= 16'd0;
            event_triggered <= 1'b0;
            triggered_event_id <= 4'd0;
            error <= 1'b0;
            log_event_time <= 16'd0;
            log_event_id <= 4'd0;

            for (i = 0; i < 16; i = i + 1) begin
                event_timestamps[i] <= 16'd0;
                event_priorities[i] <= 4'd0;
                event_valid[i] <= 1'b0;
                event_recurring[i] <= 1'b0;
                event_intervals[i] <= 16'd0;
            end
        end else begin
            tmp_current_time = current_time + 16'd10;

            for (i = 0; i < 16; i = i + 1) begin
                tmp_event_timestamps[i] = event_timestamps[i];
                tmp_event_priorities[i] = event_priorities[i];
                tmp_event_valid[i] = event_valid[i];
                tmp_event_recurring[i] = event_recurring[i];
                tmp_event_intervals[i] = event_intervals[i];
            end

            if (add_event) begin
                if (tmp_event_valid[event_id]) begin
                    error <= 1'b1;
                end else begin
                    tmp_event_timestamps[event_id] = timestamp;
                    tmp_event_priorities[event_id] = priority_in;
                    tmp_event_valid[event_id] = 1'b1;
                    tmp_event_recurring[event_id] = recurring_event;
                    tmp_event_intervals[event_id] = recurring_interval;
                    error <= 1'b0;
                end
            end

            if (modify_event) begin
                if (tmp_event_valid[event_id]) begin
                    tmp_event_timestamps[event_id] = new_timestamp;
                    tmp_event_priorities[event_id] = new_priority;
                    tmp_event_recurring[event_id] = recurring_event;
                    tmp_event_intervals[event_id] = recurring_interval;
                    error <= 1'b0;
                end else begin
                    error <= 1'b1;
                end
            end

            if (cancel_event) begin
                if (tmp_event_valid[event_id]) begin
                    tmp_event_valid[event_id] = 1'b0;
                    tmp_event_recurring[event_id] = 1'b0;
                    tmp_event_intervals[event_id] = 16'd0;
                    error <= 1'b0;
                end else begin
                    error <= 1'b1;
                end
            end

            chosen_event = -1;
            for (i = 0; i < 16; i = i + 1) begin
                if (tmp_event_valid[i] && (tmp_event_timestamps[i] <= tmp_current_time)) begin
                    if ((chosen_event == -1) ||
                        (tmp_event_priorities[i] > tmp_event_priorities[chosen_event])) begin
                        chosen_event = i;
                    end
                end
            end

            if (chosen_event != -1) begin
                event_triggered <= 1'b1;
                triggered_event_id <= chosen_event[3:0];
                log_event_time <= tmp_current_time;
                log_event_id <= chosen_event[3:0];

                if (tmp_event_recurring[chosen_event]) begin
                    tmp_event_timestamps[chosen_event] =
                        tmp_event_timestamps[chosen_event] + tmp_event_intervals[chosen_event];
                end else begin
                    tmp_event_valid[chosen_event] = 1'b0;
                end
            end else begin
                event_triggered <= 1'b0;
            end

            current_time <= tmp_current_time;

            for (i = 0; i < 16; i = i + 1) begin
                event_timestamps[i] <= tmp_event_timestamps[i];
                event_priorities[i] <= tmp_event_priorities[i];
                event_valid[i] <= tmp_event_valid[i];
                event_recurring[i] <= tmp_event_recurring[i];
                event_intervals[i] <= tmp_event_intervals[i];
            end
        end
    end

endmodule
