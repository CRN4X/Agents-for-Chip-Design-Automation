module event_scheduler(
    input clk,
    input reset,
    input add_event,
    input cancel_event,
    input [3:0] event_id,
    input [15:0] timestamp,
    input [3:0] priority_in,
    output reg event_triggered,
    output reg [3:0] triggered_event_id,
    output reg error,
    output reg [15:0] current_time
);

    
    reg [15:0] event_timestamps [15:0];
    reg [3:0]  event_priorities [15:0];
    reg        event_valid      [15:0];
    reg [15:0] tmp_current_time;
    reg [15:0] tmp_event_timestamps [15:0];
    reg [3:0]  tmp_event_priorities [15:0];
    reg        tmp_event_valid [15:0];
    integer i, j;
    integer chosen_event;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_time <= 0;
            event_triggered <= 0;
            triggered_event_id <= 0;
            error <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                event_timestamps[i] <= 0;
                event_priorities[i] <= 0;
                event_valid[i] <= 0;
            end
        end else begin
            tmp_current_time = current_time + 10;
            for (j = 0; j < 16; j = j + 1) begin
                tmp_event_timestamps[j] = event_timestamps[j];
                tmp_event_priorities[j] = event_priorities[j];
                tmp_event_valid[j] = event_valid[j];
            end

            if (add_event) begin
                if (tmp_event_valid[event_id]) begin
                    error <= 1; 
                end else begin
                    tmp_event_timestamps[event_id] = timestamp;
                    tmp_event_priorities[event_id] = priority_in;
                    tmp_event_valid[event_id] = 1;
                    error <= 0;
                end
            end

            if (cancel_event) begin
                if (tmp_event_valid[event_id]) begin
                    tmp_event_valid[event_id] = 0;
                    error <= 0;
                end else begin
                    error <= 1; 
                end
            end

            chosen_event = -1;
            for (j = 0; j < 16; j = j + 1) begin
                if (tmp_event_valid[j] && (tmp_event_timestamps[j] <= tmp_current_time)) begin
                    if ((chosen_event == -1) || (tmp_event_priorities[j] > tmp_event_priorities[chosen_event])) begin
                        chosen_event = j;
                    end
                end
            end

            if (chosen_event != -1) begin
                event_triggered <= 1;
                triggered_event_id <= chosen_event;
                tmp_event_valid[chosen_event] = 0;
            end else begin
                event_triggered <= 0;
            end

            current_time <= tmp_current_time;
            for (j = 0; j < 16; j = j + 1) begin
                event_timestamps[j] <= tmp_event_timestamps[j];
                event_priorities[j] <= tmp_event_priorities[j];
                event_valid[j] <= tmp_event_valid[j];
            end
        end
    end

endmodule