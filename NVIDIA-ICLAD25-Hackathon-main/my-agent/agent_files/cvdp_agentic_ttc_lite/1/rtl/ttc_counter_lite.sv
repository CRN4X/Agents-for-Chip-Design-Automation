`timescale 1ns/1ns

module ttc_counter_lite (
    input  wire        clk,
    input  wire        reset,
    input  wire [3:0]  axi_addr,
    input  wire [31:0] axi_wdata,
    input  wire        axi_write_en,
    input  wire        axi_read_en,
    output reg  [31:0] axi_rdata,
    output reg         interrupt
);

    // Registers visible to cocotb by hierarchical access.
    reg [15:0] count;
    reg [15:0] match_value;
    reg [15:0] reload_value;
    reg        enable;
    reg        interval_mode;
    reg        interrupt_enable;
    reg [3:0]  prescaler;

    reg [3:0] prescale_cnt;
    reg       interrupt_status;

    always @(posedge clk) begin
        if (reset) begin
            count             <= 16'd0;
            match_value       <= 16'hFFFF;
            reload_value      <= 16'd0;
            enable            <= 1'b0;
            interval_mode     <= 1'b0;
            interrupt_enable  <= 1'b0;
            prescaler         <= 4'd0;
            prescale_cnt      <= 4'd0;
            interrupt_status  <= 1'b0;
            interrupt         <= 1'b0;
            axi_rdata         <= 32'd0;
        end else begin
            // Simplified AXI-like write path.
            if (axi_write_en) begin
                case (axi_addr)
                    4'h1: match_value <= axi_wdata[15:0];
                    4'h2: reload_value <= axi_wdata[15:0];
                    4'h3: begin
                        enable           <= axi_wdata[0];
                        interval_mode    <= axi_wdata[1];
                        interrupt_enable <= axi_wdata[2];
                    end
                    4'h4: interrupt_status <= axi_wdata[0];
                    4'h5: begin
                        prescaler    <= axi_wdata[3:0];
                        prescale_cnt <= 4'd0;
                    end
                    default: ;
                endcase
            end

            // Counter and interrupt generation.
            if (enable) begin
                if (prescale_cnt >= prescaler) begin
                    prescale_cnt <= 4'd0;

                    if (count == match_value) begin
                        if (interrupt_enable) begin
                            interrupt_status <= 1'b1;
                        end

                        if (interval_mode) begin
                            count <= reload_value;
                        end else begin
                            enable <= 1'b0;
                        end
                    end else begin
                        count <= count + 16'd1;
                    end
                end else begin
                    prescale_cnt <= prescale_cnt + 4'd1;
                end
            end

            // Interrupt output follows status.
            interrupt <= interrupt_status;

            // Simplified AXI-like read path.
            if (axi_read_en) begin
                case (axi_addr)
                    4'h0: axi_rdata <= {16'd0, count};
                    4'h1: axi_rdata <= {16'd0, match_value};
                    4'h2: axi_rdata <= {16'd0, reload_value};
                    4'h3: axi_rdata <= {29'd0, interrupt_enable, interval_mode, enable};
                    4'h4: axi_rdata <= {31'd0, interrupt_status};
                    4'h5: axi_rdata <= {28'd0, prescaler};
                    default: axi_rdata <= 32'd0;
                endcase
            end
        end
    end

endmodule
