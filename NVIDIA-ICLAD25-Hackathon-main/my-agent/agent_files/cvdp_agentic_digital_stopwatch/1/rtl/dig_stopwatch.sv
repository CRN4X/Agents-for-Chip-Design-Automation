`timescale 1ns/1ns

module dig_stopwatch (
    input  logic       clk,
    input  logic       reset,
    input  logic       start_stop,
    input  logic       tick_1hz,
    output logic [5:0] seconds,
    output logic [5:0] minutes,
    output logic       hour,
    output logic       second_pulse,
    output logic       minute_pulse,
    output logic       hour_pulse,
    output logic       beep
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            seconds      <= 6'd0;
            minutes      <= 6'd0;
            hour         <= 1'b0;
            second_pulse <= 1'b0;
            minute_pulse <= 1'b0;
            hour_pulse   <= 1'b0;
            beep         <= 1'b0;
        end else begin
            second_pulse <= start_stop && !(hour && (minutes == 6'd0) && (seconds == 6'd0));

            if (start_stop && tick_1hz) begin
                // Saturate at 1:00:00 per prompt/test expectation.
                if (!(hour && (minutes == 6'd0) && (seconds == 6'd0))) begin
                    if (seconds == 6'd59) begin
                        seconds <= 6'd0;

                        if (minutes == 6'd59) begin
                            minutes    <= 6'd0;
                            hour       <= 1'b1;
                            minute_pulse <= 1'b1;
                            hour_pulse <= 1'b1;
                        end else begin
                            minutes      <= minutes + 6'd1;
                            minute_pulse <= 1'b1;
                        end
                    end else begin
                        seconds <= seconds + 6'd1;
                    end
                end
            end

            // Beep is hour-triggered and cleared by the next second pulse.
            // If hour_pulse and second_pulse coincide, clear wins.
            if (hour_pulse) begin
                beep <= 1'b1;
            end
            if (second_pulse) begin
                beep <= 1'b0;
            end
        end
    end

endmodule
