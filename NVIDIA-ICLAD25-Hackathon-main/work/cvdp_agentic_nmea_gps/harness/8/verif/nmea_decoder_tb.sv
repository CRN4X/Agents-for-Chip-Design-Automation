`timescale 1ns / 1ps

module nmea_decoder_tb;

    reg clk;
    reg reset;
    reg [7:0] serial_in;
    reg serial_valid;
    reg watchdog_timeout_en;

    wire [15:0] data_out;
    wire data_valid;
    wire error_overflow;
    wire valid_sentence;
    wire watchdog_timeout;
    wire [15:0] data_out_bin;
    wire data_bin_valid;

    reg [7:0] sentence [0:79];
    integer i;

    nmea_decoder dut (
        .clk(clk),
        .reset(reset),
        .serial_in(serial_in),
        .serial_valid(serial_valid),
        .watchdog_timeout_en(watchdog_timeout_en),
        .data_out(data_out),
        .data_valid(data_valid),
        .data_out_bin(data_out_bin),
        .data_bin_valid(data_bin_valid),
        .error_overflow(error_overflow),
        .valid_sentence(valid_sentence),
        .watchdog_timeout(watchdog_timeout)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task send_char(input [7:0] char);
        begin
            serial_in = char;
            serial_valid = 1;
            #5;
            serial_valid = 0;
            #5;
        end
    endtask

    task send_sentence();
        integer i;
        begin
            for (i = 0; i < 80 && sentence[i] != 8'h00; i = i + 1)
                send_char(sentence[i]);
        end
    endtask

    initial begin
        reset = 1;
        serial_in = 0;
        serial_valid = 0;
        watchdog_timeout_en = 1;

        #20;
        reset = 0;

        $display("-------------------------------------------------------------------------");
        $display("Starting Test Case 1: Valid $GPRMC sentence");
        for (i = 0; i < 80; i = i + 1) sentence[i] = 8'h00;
        sentence[0]  = 8'h24; sentence[1]  = 8'h47; sentence[2]  = 8'h50; sentence[3]  = 8'h52;
        sentence[4]  = 8'h4D; sentence[5]  = 8'h43; sentence[6]  = 8'h2C; sentence[7]  = 8'h31;
        sentence[8]  = 8'h32; sentence[9]  = 8'h33; sentence[10] = 8'h35; sentence[11] = 8'h31;
        sentence[12] = 8'h39; sentence[13] = 8'h2C; sentence[14] = 8'h41; sentence[15] = 8'h2C;
        sentence[16] = 8'h34; sentence[17] = 8'h38; sentence[18] = 8'h30; sentence[19] = 8'h37;
        sentence[20] = 8'h2E; sentence[21] = 8'h30; sentence[22] = 8'h33; sentence[23] = 8'h38;
        sentence[24] = 8'h2C; sentence[25] = 8'h4E; sentence[26] = 8'h2C; sentence[27] = 8'h30;
        sentence[28] = 8'h31; sentence[29] = 8'h31; sentence[30] = 8'h33; sentence[31] = 8'h31;
        sentence[32] = 8'h2E; sentence[33] = 8'h30; sentence[34] = 8'h30; sentence[35] = 8'h30;
        sentence[36] = 8'h2C; sentence[37] = 8'h45; sentence[38] = 8'h2C; sentence[39] = 8'h30;
        sentence[40] = 8'h32; sentence[41] = 8'h32; sentence[42] = 8'h2E; sentence[43] = 8'h34;
        sentence[44] = 8'h2C; sentence[45] = 8'h30; sentence[46] = 8'h38; sentence[47] = 8'h34;
        sentence[48] = 8'h2E; sentence[49] = 8'h34; sentence[50] = 8'h2C; sentence[51] = 8'h32;
        sentence[52] = 8'h33; sentence[53] = 8'h30; sentence[54] = 8'h33; sentence[55] = 8'h39;
        sentence[56] = 8'h34; sentence[57] = 8'h2C; sentence[58] = 8'h30; sentence[59] = 8'h30;
        sentence[60] = 8'h33; sentence[61] = 8'h2E; sentence[62] = 8'h31; sentence[63] = 8'h2C;
        sentence[64] = 8'h57; sentence[65] = 8'h2A; sentence[66] = 8'h36; sentence[67] = 8'h41;
        sentence[68] = 8'h0D;
        #5;
        send_sentence();
        if (data_out !== 16'h3132) begin
            $display("ERROR: Expected 16'h3132, but got %h", data_out);
        end else begin
            $display("SUCCESS: Correct data_out = %h", data_out);
        end
        $display("INFO: data_valid = %b", data_valid);
        $display("INFO: valid_sentence = %b", valid_sentence);
        $display("INFO: error_overflow = %b", error_overflow);
        $display("INFO: watchdog_timeout = %b", watchdog_timeout);
        $display("INFO: data_bin_valid = %b", data_bin_valid);
        $display("INFO: data_out_bin = %0d (decimal)", data_out_bin);

        $display("-------------------------------------------------------------------------");
        $display("Starting Test Case 2: Invalid sentence");
        for (i = 0; i < 80; i = i + 1) sentence[i] = 8'h00;
        sentence[0]  = 8'h24; sentence[1]  = 8'h47; sentence[2]  = 8'h50; sentence[3]  = 8'h58;
        sentence[4]  = 8'h59; sentence[5]  = 8'h5A; sentence[6]  = 8'h2C; sentence[7]  = 8'h49;
        sentence[8]  = 8'h4E; sentence[9]  = 8'h56; sentence[10] = 8'h41; sentence[11] = 8'h4C;
        sentence[12] = 8'h49; sentence[13] = 8'h44; sentence[14] = 8'h2C; sentence[15] = 8'h53;
        sentence[16] = 8'h45; sentence[17] = 8'h4E; sentence[18] = 8'h54; sentence[19] = 8'h45;
        sentence[20] = 8'h4E; sentence[21] = 8'h43; sentence[22] = 8'h45; sentence[23] = 8'h0D;
        sentence[24] = 8'h0A;
        #5;
        send_sentence();
        if (data_valid !== 0) begin
            $display("ERROR: Expected data_valid = 0, but got %b", data_valid);
        end else begin
            $display("SUCCESS: Correctly handled invalid sentence with data_valid = %b", data_valid);
        end
        $display("INFO: valid_sentence = %b", valid_sentence);
        $display("INFO: error_overflow = %b", error_overflow);
        $display("INFO: watchdog_timeout = %b", watchdog_timeout);
        $display("INFO: data_bin_valid = %b", data_bin_valid);
        $display("INFO: data_out_bin = %0d (decimal)", data_out_bin);

        $display("-------------------------------------------------------------------------");
        $display("Starting Test Case 3: Buffer Overflow");
        for (i = 0; i < 80; i = i + 1) sentence[i] = 8'h41; // Fill with 'A'
        sentence[0] = 8'h24;  // '$'
        sentence[1] = 8'h47;  // 'G'
        sentence[2] = 8'h50;  // 'P'
        sentence[3] = 8'h52;  // 'R'
        sentence[4] = 8'h4D;  // 'M'
        sentence[5] = 8'h43;  // 'C'
        #5;
        send_sentence();
        #20;
        if (error_overflow !== 1) begin
            $display("ERROR: Expected error_overflow = 1, but got %b", error_overflow);
        end else begin
            $display("SUCCESS: Overflow correctly detected with error_overflow = %b", error_overflow);
        end
        $display("INFO: valid_sentence = %b", valid_sentence);
        $display("INFO: watchdog_timeout = %b", watchdog_timeout);
        $display("INFO: data_bin_valid = %b", data_bin_valid);
        $display("INFO: data_out_bin = %0d (decimal)", data_out_bin);

        $display("-------------------------------------------------------------------------");
        $display("Starting Test Case 4: Watchdog timeout");
        for (i = 0; i < 80; i = i + 1) sentence[i] = 8'h00;
        sentence[0] = 8'h24;
        sentence[1] = 8'h47;
        sentence[2] = 8'h50;
        sentence[3] = 8'h52;
        sentence[4] = 8'h4D;
        sentence[5] = 8'h43;
        sentence[6] = 8'h2C;
        sentence[7] = 8'h31;
        #5;
        for (i = 0; i <= 7; i = i + 1)
            send_char(sentence[i]);
        #25000;
        if (watchdog_timeout !== 1) begin
            $display("ERROR: Expected watchdog_timeout = 1, but got %b", watchdog_timeout);
        end else begin
            $display("SUCCESS: Watchdog timeout triggered correctly with watchdog_timeout = %b", watchdog_timeout);
        end
        $display("INFO: valid_sentence = %b", valid_sentence);
        $display("INFO: data_valid = %b", data_valid);
        $display("INFO: error_overflow = %b", error_overflow);
        $display("INFO: data_bin_valid = %b", data_bin_valid);
        $display("INFO: data_out_bin = %0d (decimal)", data_out_bin);

        reset = 1;
        #20;
        reset = 0;

        $display("-------------------------------------------------------------------------");
        $display("Starting Test Case 5: Valid $GPRMC sentence");
        for (i = 0; i < 80; i = i + 1) sentence[i] = 8'h00;
        sentence[0]  = 8'h24; sentence[1]  = 8'h47; sentence[2]  = 8'h50; sentence[3]  = 8'h52;
        sentence[4]  = 8'h4D; sentence[5]  = 8'h43; sentence[6]  = 8'h2C; sentence[7]  = 8'h33;
        sentence[8]  = 8'h34; sentence[9]  = 8'h33; sentence[10] = 8'h35; sentence[11] = 8'h31;
        sentence[12] = 8'h39; sentence[13] = 8'h2C; sentence[14] = 8'h41; sentence[15] = 8'h2C;
        sentence[16] = 8'h34; sentence[17] = 8'h38; sentence[18] = 8'h30; sentence[19] = 8'h37;
        sentence[20] = 8'h2E; sentence[21] = 8'h30; sentence[22] = 8'h33; sentence[23] = 8'h38;
        sentence[24] = 8'h2C; sentence[25] = 8'h4E; sentence[26] = 8'h2C; sentence[27] = 8'h30;
        sentence[28] = 8'h31; sentence[29] = 8'h31; sentence[30] = 8'h33; sentence[31] = 8'h31;
        sentence[32] = 8'h2E; sentence[33] = 8'h30; sentence[34] = 8'h30; sentence[35] = 8'h30;
        sentence[36] = 8'h2C; sentence[37] = 8'h45; sentence[38] = 8'h2C; sentence[39] = 8'h30;
        sentence[40] = 8'h32; sentence[41] = 8'h32; sentence[42] = 8'h2E; sentence[43] = 8'h34;
        sentence[44] = 8'h2C; sentence[45] = 8'h30; sentence[46] = 8'h38; sentence[47] = 8'h34;
        sentence[48] = 8'h2E; sentence[49] = 8'h34; sentence[50] = 8'h2C; sentence[51] = 8'h32;
        sentence[52] = 8'h33; sentence[53] = 8'h30; sentence[54] = 8'h33; sentence[55] = 8'h39;
        sentence[56] = 8'h34; sentence[57] = 8'h2C; sentence[58] = 8'h30; sentence[59] = 8'h30;
        sentence[60] = 8'h33; sentence[61] = 8'h2E; sentence[62] = 8'h31; sentence[63] = 8'h2C;
        sentence[64] = 8'h57; sentence[65] = 8'h2A; sentence[66] = 8'h36; sentence[67] = 8'h41;
        sentence[68] = 8'h0D;
        #5;
        send_sentence();
        if (data_out_bin !== 6'd34) begin
            $display("ERROR: Expected data_out_bin = 34, but got %0d (binary = %b)", data_out_bin, data_out_bin);
        end 
        else begin
            $display("SUCCESS: Correct data_out_bin = %0d (binary = %b)", data_out_bin, data_out_bin);
        end
        if (data_out !== 16'h3334) begin
            $display("ERROR: Expected 16'h3132, but got %h", data_out);
        end else begin
            $display("SUCCESS: Correct data_out = %h", data_out);
        end
        $display("INFO: data_valid = %b", data_valid);
        $display("INFO: valid_sentence = %b", valid_sentence);
        $display("INFO: error_overflow = %b", error_overflow);
        $display("INFO: watchdog_timeout = %b", watchdog_timeout);
        $display("INFO: data_bin_valid = %b", data_bin_valid);
        $display("INFO: data_out_bin = %0d (decimal)", data_out_bin);

        #100;
        $finish;
    end

endmodule