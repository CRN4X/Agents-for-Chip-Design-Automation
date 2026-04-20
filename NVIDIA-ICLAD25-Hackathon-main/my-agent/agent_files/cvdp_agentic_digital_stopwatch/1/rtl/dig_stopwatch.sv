module dig_stopwatch #(
    parameter integer CLK_FREQ = 50_000_000
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       start_stop,
    output logic [5:0] seconds,
    output logic [5:0] minutes,
    output logic       hour,
    output logic       second_pulse,
    output logic       minute_pulse,
    output logic       hour_pulse,
    output logic       beep
);

    localparam integer COUNTER_W = (CLK_FREQ > 1) ? $clog2(CLK_FREQ) : 1;
    logic [COUNTER_W-1:0] tick_counter;

    wire saturated;
    assign saturated = hour && (minutes == 6'd0) && (seconds == 6'd0);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            tick_counter  <= '0;
            seconds       <= 6'd0;
            minutes       <= 6'd0;
            hour          <= 1'b0;
            second_pulse  <= 1'b0;
            minute_pulse  <= 1'b0;
            hour_pulse    <= 1'b0;
            beep          <= 1'b0;
        end else begin
            if (start_stop && !saturated) begin
                if (tick_counter == CLK_FREQ - 1) begin
                    tick_counter <= '0;
                    second_pulse <= 1'b1;

                    if (seconds == 6'd59) begin
                        seconds <= 6'd0;

                        if (minutes == 6'd59) begin
                            minutes <= 6'd0;
                            hour <= 1'b1;
                            minute_pulse <= 1'b1;
                            hour_pulse   <= 1'b1;
                            beep         <= 1'b0;
                        end else begin
                            minutes <= minutes + 6'd1;
                            minute_pulse <= 1'b1;
                        end
                    end else begin
                        seconds <= seconds + 6'd1;
                    end

                    // Clear beep on the next second pulse (including rollover cycle).
                    if (beep) begin
                        beep <= 1'b0;
                    end
                end else begin
                    tick_counter <= tick_counter + {{(COUNTER_W-1){1'b0}}, 1'b1};
                end
            end
        end
    end

endmodule
