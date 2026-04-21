`timescale 1ns/1ns

module nmea_decoder (
    input wire clk,
    input wire reset,
    input wire [7:0] serial_in,
    input wire serial_valid,
    input wire watchdog_timeout_en,
    output reg [15:0] data_out,
    output reg data_valid,
    output reg [7:0] data_out_bin,
    output reg data_bin_valid,
    output reg watchdog_timeout,
    output reg error_overflow
);

    localparam [1:0] STATE_IDLE  = 2'b00;
    localparam [1:0] STATE_PARSE = 2'b01;

    localparam integer MAX_BUFFER_SIZE = 80;
    localparam integer WATCHDOG_CYCLES = 2000;

    reg [1:0] state;
    reg [6:0] buffer_index;
    reg [7:0] buffer [0:MAX_BUFFER_SIZE-1];
    reg [11:0] watchdog_counter;

    integer i;
    integer comma_pos;
    reg sentence_ok;
    reg [7:0] ch0;
    reg [7:0] ch1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
            buffer_index <= 7'd0;
            watchdog_counter <= 12'd0;
            data_out <= 16'h0000;
            data_valid <= 1'b0;
            data_out_bin <= 8'h00;
            data_bin_valid <= 1'b0;
            watchdog_timeout <= 1'b0;
            error_overflow <= 1'b0;
        end else begin
            if (watchdog_timeout_en) begin
                if (serial_valid && (serial_in == 8'h0D)) begin
                    watchdog_counter <= 12'd0;
                    watchdog_timeout <= 1'b0;
                end else if (watchdog_counter >= WATCHDOG_CYCLES - 1) begin
                    watchdog_timeout <= 1'b1;
                end else begin
                    watchdog_counter <= watchdog_counter + 12'd1;
                end
            end else begin
                watchdog_counter <= 12'd0;
                watchdog_timeout <= 1'b0;
            end

            if (serial_valid) begin
                case (state)
                    STATE_IDLE: begin
                        if (serial_in == 8'h24) begin
                            state <= STATE_PARSE;
                            buffer_index <= 7'd0;
                            data_valid <= 1'b0;
                            data_bin_valid <= 1'b0;
                            watchdog_timeout <= 1'b0;
                            if (MAX_BUFFER_SIZE > 0) begin
                                buffer[0] <= serial_in;
                                buffer_index <= 7'd1;
                            end
                        end
                    end

                    STATE_PARSE: begin
                        if (serial_in == 8'h0D) begin
                            sentence_ok = 1'b0;
                            comma_pos = -1;
                            ch0 = 8'h00;
                            ch1 = 8'h00;

                            if (buffer_index >= 7'd7) begin
                                if ((buffer[0] == 8'h24) && (buffer[1] == 8'h47) &&
                                    (buffer[2] == 8'h50) && (buffer[3] == 8'h52) &&
                                    (buffer[4] == 8'h4D) && (buffer[5] == 8'h43)) begin
                                    for (i = 6; i < MAX_BUFFER_SIZE; i = i + 1) begin
                                        if ((i < buffer_index) && (comma_pos < 0) && (buffer[i] == 8'h2C)) begin
                                            comma_pos = i;
                                        end
                                    end

                                    if ((comma_pos >= 0) && ((comma_pos + 2) < buffer_index)) begin
                                        ch0 = buffer[comma_pos + 1];
                                        ch1 = buffer[comma_pos + 2];
                                        sentence_ok = 1'b1;
                                    end
                                end
                            end

                            if (sentence_ok) begin
                                data_out <= {ch0, ch1};
                                data_valid <= 1'b1;

                                if ((ch0 >= 8'h30) && (ch0 <= 8'h39) &&
                                    (ch1 >= 8'h30) && (ch1 <= 8'h39)) begin
                                    data_out_bin <= ((ch0 - 8'h30) * 8'd10) + (ch1 - 8'h30);
                                    data_bin_valid <= 1'b1;
                                end else begin
                                    data_out_bin <= 8'h00;
                                    data_bin_valid <= 1'b0;
                                end
                            end else begin
                                data_valid <= 1'b0;
                                data_bin_valid <= 1'b0;
                            end

                            state <= STATE_IDLE;
                            buffer_index <= 7'd0;
                            watchdog_counter <= 12'd0;
                        end else if (buffer_index < (MAX_BUFFER_SIZE - 1)) begin
                            buffer[buffer_index] <= serial_in;
                            buffer_index <= buffer_index + 7'd1;
                        end else begin
                            error_overflow <= 1'b1;
                            state <= STATE_IDLE;
                            buffer_index <= 7'd0;
                            watchdog_counter <= 12'd0;
                        end
                    end

                    default: begin
                        state <= STATE_IDLE;
                        buffer_index <= 7'd0;
                    end
                endcase
            end
        end
    end

endmodule
