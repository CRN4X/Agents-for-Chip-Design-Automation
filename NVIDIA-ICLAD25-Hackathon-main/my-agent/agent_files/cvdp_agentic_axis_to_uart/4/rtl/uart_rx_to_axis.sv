`timescale 1ns/1ps

module uart_rx_to_axis #(
    parameter int unsigned CLK_FREQ      = 100,
    parameter int unsigned BIT_RATE      = 115200,
    parameter int unsigned BIT_PER_WORD  = 8,
    parameter int unsigned PARITY_BIT    = 0,
    parameter int unsigned STOP_BITS_NUM = 1
) (
    input  logic                     aclk,
    input  logic                     aresetn,
    input  logic                     RX,
    output logic [BIT_PER_WORD-1:0]  tdata,
    output logic                     tuser,
    output logic                     tvalid
);

    localparam int unsigned CYCLE_PER_PERIOD = (CLK_FREQ * 1000000) / BIT_RATE;
    localparam int unsigned HALF_CYCLE       = CYCLE_PER_PERIOD / 2;
    localparam int unsigned CLK_CNT_W        = (CYCLE_PER_PERIOD > 1) ? $clog2(CYCLE_PER_PERIOD) : 1;
    localparam int unsigned BIT_CNT_W        = (BIT_PER_WORD > 1) ? $clog2(BIT_PER_WORD) : 1;

    typedef enum logic [2:0] {
        IDLE    = 3'd0,
        START   = 3'd1,
        DATA    = 3'd2,
        PARITY  = 3'd3,
        STOP1   = 3'd4,
        STOP2   = 3'd5,
        OUT_RDY = 3'd6
    } fsm_t;

    fsm_t state;

    logic [CLK_CNT_W-1:0]          clk_count;
    logic [BIT_CNT_W-1:0]          bit_count;
    logic [BIT_PER_WORD-1:0]       data_shift;
    logic                          parity_error;
    logic                          rx_d;

    logic parity_expected;

    always_comb begin
        parity_expected = ^data_shift;
        if (PARITY_BIT == 1) begin
            parity_expected = ~parity_expected;
        end
    end

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state         <= IDLE;
            clk_count     <= '0;
            bit_count     <= '0;
            data_shift    <= '0;
            parity_error  <= 1'b0;
            rx_d          <= 1'b1;
            tdata         <= '0;
            tuser         <= 1'b0;
            tvalid        <= 1'b0;
        end else begin
            rx_d   <= RX;
            tvalid <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count    <= '0;
                    bit_count    <= '0;
                    parity_error <= 1'b0;
                    if (rx_d && !RX) begin
                        state <= START;
                    end
                end

                START: begin
                    if (clk_count == HALF_CYCLE-1) begin
                        clk_count <= '0;
                        if (!RX) begin
                            state <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_count == CYCLE_PER_PERIOD-1) begin
                        clk_count <= '0;
                        data_shift[bit_count] <= RX;

                        if (bit_count == BIT_PER_WORD-1) begin
                            bit_count <= '0;
                            if (PARITY_BIT == 0) begin
                                state <= STOP1;
                            end else begin
                                state <= PARITY;
                            end
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                PARITY: begin
                    if (clk_count == CYCLE_PER_PERIOD-1) begin
                        clk_count <= '0;
                        parity_error <= (RX != parity_expected);
                        state <= STOP1;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP1: begin
                    if (clk_count == CYCLE_PER_PERIOD-1) begin
                        clk_count <= '0;
                        if (!RX) begin
                            parity_error <= 1'b1;
                        end

                        if (STOP_BITS_NUM == 2) begin
                            state <= STOP2;
                        end else begin
                            state <= OUT_RDY;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP2: begin
                    if (clk_count == CYCLE_PER_PERIOD-1) begin
                        clk_count <= '0;
                        if (!RX) begin
                            parity_error <= 1'b1;
                        end
                        state <= OUT_RDY;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                OUT_RDY: begin
                    tdata  <= data_shift;
                    tuser  <= (PARITY_BIT == 0) ? 1'b0 : parity_error;
                    tvalid <= 1'b1;
                    state  <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
