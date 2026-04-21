`timescale 1ns/1ns

module jpeg_runlength_stage1 (
    input  wire               clk_in,
    input  wire               reset_in,
    input  wire               enable_in,
    input  wire               go_in,
    input  wire signed [11:0] din_in,
    output reg  [3:0]         rlen_out,
    output reg  [3:0]         size_out,
    output reg  signed [11:0] amp_out,
    output reg                den_out,
    output reg                dcterm_out
);

    reg [6:0] block_pos;
    reg [4:0] zero_run;
    reg [6:0] block_pos_n;
    reg [4:0] zero_run_n;
    reg       hold_cycle;
    reg       hold_cycle_n;

    function automatic [3:0] coeff_size;
        input signed [11:0] value;
        reg [11:0] mag;
        begin
            if (value < 0) begin
                mag = -value;
            end else begin
                mag = value;
            end

            if (mag[11])      coeff_size = 4'd12;
            else if (mag[10]) coeff_size = 4'd11;
            else if (mag[9])  coeff_size = 4'd10;
            else if (mag[8])  coeff_size = 4'd9;
            else if (mag[7])  coeff_size = 4'd8;
            else if (mag[6])  coeff_size = 4'd7;
            else if (mag[5])  coeff_size = 4'd6;
            else if (mag[4])  coeff_size = 4'd5;
            else if (mag[3])  coeff_size = 4'd4;
            else if (mag[2])  coeff_size = 4'd3;
            else if (mag[1])  coeff_size = 4'd2;
            else if (mag[0])  coeff_size = 4'd1;
            else              coeff_size = 4'd0;
        end
    endfunction

    always @(*) begin
        rlen_out   = 4'd0;
        size_out   = 4'd0;
        amp_out    = 12'sd0;
        den_out    = 1'b0;
        dcterm_out = 1'b0;

        block_pos_n  = block_pos;
        zero_run_n   = zero_run;
        hold_cycle_n = hold_cycle;

        if (enable_in) begin
            if (hold_cycle) begin
                hold_cycle_n = 1'b0;
            end else begin
                if (go_in) begin
                    rlen_out   = 4'd0;
                    size_out   = coeff_size(din_in);
                    amp_out    = din_in;
                    den_out    = 1'b1;
                    dcterm_out = 1'b1;

                    block_pos_n = 7'd0;
                    zero_run_n  = 5'd0;
                end else begin
                    block_pos_n = block_pos + 7'd1;
                    if (din_in == 12'sd0) begin
                        if (zero_run == 5'd15) begin
                            rlen_out   = 4'd15;
                            size_out   = 4'd0;
                            amp_out    = 12'sd0;
                            den_out    = 1'b1;
                            zero_run_n = 5'd0;
                        end else begin
                            zero_run_n = zero_run + 5'd1;
                            if (block_pos == 7'd62) begin
                                rlen_out = 4'd0;
                                size_out = 4'd0;
                                amp_out  = 12'sd0;
                                den_out  = 1'b1;
                            end
                        end
                    end else begin
                        rlen_out   = zero_run[3:0];
                        size_out   = coeff_size(din_in);
                        amp_out    = din_in;
                        den_out    = 1'b1;
                        zero_run_n = 5'd0;
                    end
                end

                if (den_out && !dcterm_out) begin
                    hold_cycle_n = 1'b1;
                end
            end
        end
    end

    always @(posedge clk_in) begin
        if (reset_in) begin
            block_pos   <= 7'd0;
            zero_run    <= 5'd0;
            hold_cycle  <= 1'b0;
        end else if (enable_in) begin
            block_pos   <= block_pos_n;
            zero_run    <= zero_run_n;
            hold_cycle  <= hold_cycle_n;
        end
    end

endmodule
