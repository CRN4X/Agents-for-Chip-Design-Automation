module nmea_decoder (
    input wire clk,
    input wire reset,
    input wire [7:0] serial_in,         // ASCII character input
    input wire serial_valid,            // Valid signal for character
    output reg [15:0] data_out,         // Decoded 16-bit output
    output reg data_valid               // Valid signal for output
);

    // FSM States
    localparam 
        STATE_IDLE   = 2'b00,
        STATE_PARSE  = 2'b01,
        STATE_OUTPUT = 2'b10;

    // Configuration
    localparam MAX_BUFFER_SIZE = 80;    // Maximum NMEA sentence length
    integer i;
    

    // Internal registers
    reg [7:0] buffer [0:MAX_BUFFER_SIZE-1];  // Sentence buffer
    reg [6:0] buffer_index;            // Current buffer index
    reg [6:0] next_buffer_index;       // Next buffer index (combinational)
    reg [1:0] state, next_state;       // FSM states
    reg [6:0] comma_count;             // Comma counter
    reg [6:0] field_index;             // Field position tracker

    // Character identifiers
    wire is_start = (serial_in == 8'h24);  // '$'
    wire is_comma = (serial_in == 8'h2C);  // ','
    wire is_end = (serial_in == 8'h0D);    // '\r'

    // Sequential logic (clocked)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
            buffer_index <= 0;
        end else begin
            state <= next_state;
            buffer_index <= next_buffer_index;
        end
    end

    // Combinational logic
    always @(*) begin
        next_state = state;
        next_buffer_index = buffer_index;
        data_out = 16'b0;
        data_valid = 0;
        comma_count = 0;
        field_index = 0;

        case (state)
            STATE_IDLE: begin
                if (serial_valid && is_start) begin
                    next_state = STATE_PARSE;
                    next_buffer_index = 0;  
                end
            end

            STATE_PARSE: begin
                if (serial_valid) begin
                    if (is_end) begin
                        next_state = STATE_OUTPUT;
                    end else if (buffer_index < MAX_BUFFER_SIZE-1) begin
                        buffer[next_buffer_index] = serial_in;
                        next_buffer_index = buffer_index + 1;
                    end else begin
                        next_state = STATE_IDLE;  // Buffer overflow
                        next_buffer_index = 0;
                    end
                end
            end

            STATE_OUTPUT: begin
                if (buffer[0] == 8'h47 &&  // 'G'
                    buffer[1] == 8'h50 &&  // 'P'
                    buffer[2] == 8'h52 &&  // 'R'
                    buffer[3] == 8'h4D &&  // 'M'
                    buffer[4] == 8'h43)    // 'C'
                begin
                    for (i=0; i<MAX_BUFFER_SIZE; i=i+1) begin
                        if (i < buffer_index) begin
                            if (buffer[i] == 8'h2C) begin
                                comma_count = comma_count + 1;
                                if (comma_count == 1) begin
                                    field_index = i + 1;  // First data field
                                end
                            end
                        end
                    end

                    if (field_index+1 < buffer_index) begin
                        data_out = {buffer[field_index], 
                                   buffer[field_index+1]};
                        data_valid = 1;
                    end
                end
                next_state = STATE_IDLE;  
            end

            default: next_state = STATE_IDLE;
        endcase
    end

endmodule