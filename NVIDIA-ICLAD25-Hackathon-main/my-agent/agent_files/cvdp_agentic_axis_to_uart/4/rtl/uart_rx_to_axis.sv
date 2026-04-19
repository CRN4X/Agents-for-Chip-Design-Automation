`timescale 1ns/1ps

module uart_rx_to_axis #(
    parameter integer CLK_FREQ     = 100,
    parameter integer BIT_RATE     = 115200,
    parameter integer BIT_PER_WORD = 8,
    parameter integer PARITY_BIT   = 1,
    parameter integer STOP_BITS_NUM = 1
) (
    input  wire                    aclk,
    input  wire                    aresetn,
    input  wire                    RX,
    output reg  [BIT_PER_WORD-1:0] tdata,
    output reg                     tuser,
    output reg                     tvalid
);

    localparam integer CYCLE_PER_PERIOD = (CLK_FREQ * 1000000) / BIT_RATE;
    localparam integer HALF_PERIOD       = (CYCLE_PER_PERIOD / 2);

    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] START  = 3'd1;
    localparam [2:0] DATA   = 3'd2;
    localparam [2:0] PARITY = 3'd3;
    localparam [2:0] STOP1  = 3'd4;
    localparam [2:0] STOP2  = 3'd5;
    localparam [2:0] OUT_RDY = 3'd6;

    reg [2:0] state;
    reg [31:0] clk_count;
    reg [7:0] bit_count;
    reg [BIT_PER_WORD-1:0] data_shift_reg;
    reg parity_error;
    reg rx_meta;
    reg rx_sync;
    reg rx_sync_d;

    wire rx_fall = rx_sync_d & ~rx_sync;
    wire data_xor = ^data_shift_reg;
    wire expected_parity = (PARITY_BIT == 1) ? ~data_xor : data_xor;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state <= IDLE;
            clk_count <= 32'd0;
            bit_count <= 8'd0;
            data_shift_reg <= {BIT_PER_WORD{1'b0}};
            parity_error <= 1'b0;
            tdata <= {BIT_PER_WORD{1'b0}};
            tuser <= 1'b0;
            tvalid <= 1'b0;
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
            rx_sync_d <= 1'b1;
        end else begin
            rx_meta <= RX;
            rx_sync <= rx_meta;
            rx_sync_d <= rx_sync;
            tvalid <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= 32'd0;
                    bit_count <= 8'd0;
                    parity_error <= 1'b0;
                    if (rx_fall) begin
                        state <= START;
                    end
                end

                START: begin
                    if (clk_count == (HALF_PERIOD - 1)) begin
                        clk_count <= 32'd0;
                        if (rx_sync == 1'b0) begin
                            state <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 32'd1;
                    end
                end

                DATA: begin
                    if (clk_count == (CYCLE_PER_PERIOD - 1)) begin
                        clk_count <= 32'd0;
                        data_shift_reg[bit_count] <= rx_sync;
                        if (bit_count == (BIT_PER_WORD - 1)) begin
                            bit_count <= 8'd0;
                            if (PARITY_BIT == 0) begin
                                state <= STOP1;
                            end else begin
                                state <= PARITY;
                            end
                        end else begin
                            bit_count <= bit_count + 8'd1;
                        end
                    end else begin
                        clk_count <= clk_count + 32'd1;
                    end
                end

                PARITY: begin
                    if (clk_count == (CYCLE_PER_PERIOD - 1)) begin
                        clk_count <= 32'd0;
                        parity_error <= (rx_sync != expected_parity);
                        state <= STOP1;
                    end else begin
                        clk_count <= clk_count + 32'd1;
                    end
                end

                STOP1: begin
                    if (clk_count == (CYCLE_PER_PERIOD - 1)) begin
                        clk_count <= 32'd0;
                        if (STOP_BITS_NUM == 2) begin
                            state <= STOP2;
                        end else begin
                            state <= OUT_RDY;
                        end
                    end else begin
                        clk_count <= clk_count + 32'd1;
                    end
                end

                STOP2: begin
                    if (clk_count == (CYCLE_PER_PERIOD - 1)) begin
                        clk_count <= 32'd0;
                        state <= OUT_RDY;
                    end else begin
                        clk_count <= clk_count + 32'd1;
                    end
                end

                OUT_RDY: begin
                    tdata <= data_shift_reg;
                    tuser <= parity_error;
                    tvalid <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
