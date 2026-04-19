`timescale 1ns/1ps

module axis_to_uart_tx #(
    parameter integer CLK_FREQ      = 100,
    parameter integer BIT_RATE      = 115200,
    parameter integer BIT_PER_WORD  = 8,
    parameter integer PARITY_BIT    = 1,
    parameter integer STOP_BITS_NUM = 1
) (
    input  logic                    aclk,
    input  logic                    aresetn,
    input  logic [BIT_PER_WORD-1:0] tdata,
    input  logic                    tvalid,
    output logic                    tready,
    output logic                    TX
);

    localparam integer CYCLES_PER_PERIOD = (CLK_FREQ * 1000000) / BIT_RATE;
    localparam integer BAUD_CNT_W = (CYCLES_PER_PERIOD <= 1) ? 1 : $clog2(CYCLES_PER_PERIOD);
    localparam integer BIT_CNT_W  = (BIT_PER_WORD <= 1) ? 1 : $clog2(BIT_PER_WORD);

    typedef enum logic [2:0] {
        IDLE   = 3'd0,
        START  = 3'd1,
        DATA   = 3'd2,
        PARITY = 3'd3,
        STOP1  = 3'd4,
        STOP2  = 3'd5
    } state_t;

    state_t                       state;
    logic [BAUD_CNT_W-1:0]       clk_count;
    logic [BIT_CNT_W-1:0]        bit_count;
    logic [BIT_PER_WORD-1:0]     data_shift;
    logic                        parity_val;
    logic                        clk_count_done;

    assign tready = (state == IDLE);
    assign clk_count_done = (clk_count == CYCLES_PER_PERIOD - 1);

    function automatic logic calc_parity(input logic [BIT_PER_WORD-1:0] din);
        logic p;
        begin
            p = ^din;
            if (PARITY_BIT == 1) begin
                calc_parity = ~p;
            end else begin
                calc_parity = p;
            end
        end
    endfunction

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state      <= IDLE;
            clk_count  <= '0;
            bit_count  <= '0;
            data_shift <= '0;
            parity_val <= 1'b0;
            TX         <= 1'b1;
        end else begin
            if (state == IDLE) begin
                clk_count <= '0;
            end else if (clk_count_done) begin
                clk_count <= '0;
            end else begin
                clk_count <= clk_count + 1'b1;
            end

            case (state)
                IDLE: begin
                    TX <= 1'b1;
                    bit_count <= '0;
                    if (tvalid) begin
                        data_shift <= tdata;
                        parity_val <= calc_parity(tdata);
                        state <= START;
                        TX <= 1'b0;
                    end
                end

                START: begin
                    TX <= 1'b0;
                    if (clk_count_done) begin
                        state <= DATA;
                        bit_count <= '0;
                        TX <= data_shift[0];
                    end
                end

                DATA: begin
                    TX <= data_shift[0];
                    if (clk_count_done) begin
                        if (bit_count == BIT_PER_WORD - 1) begin
                            if (PARITY_BIT == 0) begin
                                state <= STOP1;
                                TX <= 1'b1;
                            end else begin
                                state <= PARITY;
                                TX <= parity_val;
                            end
                        end else begin
                            bit_count <= bit_count + 1'b1;
                            data_shift <= {1'b0, data_shift[BIT_PER_WORD-1:1]};
                        end
                    end
                end

                PARITY: begin
                    TX <= parity_val;
                    if (clk_count_done) begin
                        state <= STOP1;
                        TX <= 1'b1;
                    end
                end

                STOP1: begin
                    TX <= 1'b1;
                    if (clk_count_done) begin
                        if (STOP_BITS_NUM == 2) begin
                            state <= STOP2;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end

                STOP2: begin
                    TX <= 1'b1;
                    if (clk_count_done) begin
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                    TX <= 1'b1;
                end
            endcase
        end
    end

endmodule
