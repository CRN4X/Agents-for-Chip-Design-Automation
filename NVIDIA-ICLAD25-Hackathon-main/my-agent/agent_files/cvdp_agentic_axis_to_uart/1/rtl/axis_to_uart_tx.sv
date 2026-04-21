`timescale 1ns/1ns

module axis_to_uart_tx #(
    parameter int CLK_FREQ      = 100,    // MHz
    parameter int BIT_RATE      = 115200, // bps
    parameter int BIT_PER_WORD  = 8,
    parameter int PARITY_BIT    = 0,      // 0:none, 1:odd, 2:even
    parameter int STOP_BITS_NUM = 1       // 1 or 2
) (
    input  logic                   aclk,
    input  logic                   aresetn,
    input  logic [BIT_PER_WORD-1:0] tdata,
    input  logic                   tvalid,
    output logic                   tready,
    output logic                   TX
);

  localparam int CYCLE_PER_PERIOD = (CLK_FREQ * 1_000_000) / BIT_RATE;
  localparam int CLKS_PER_BIT     = (CYCLE_PER_PERIOD < 1) ? 1 : CYCLE_PER_PERIOD;
  localparam int CLKCNT_W         = (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);
  localparam int BITCNT_W         = (BIT_PER_WORD <= 1) ? 1 : $clog2(BIT_PER_WORD);

  localparam logic [2:0] ST_IDLE   = 3'd0;
  localparam logic [2:0] ST_START  = 3'd1;
  localparam logic [2:0] ST_DATA   = 3'd2;
  localparam logic [2:0] ST_PARITY = 3'd3;
  localparam logic [2:0] ST_STOP1  = 3'd4;
  localparam logic [2:0] ST_STOP2  = 3'd5;

  logic [2:0] state, next_state;
  logic [BIT_PER_WORD-1:0] data_reg;
  logic [CLKCNT_W-1:0] clk_count;
  logic [BITCNT_W-1:0] bit_count;
  logic tx_reg;
  logic parity_value;
  logic clk_count_done;
  logic bit_count_done;

  assign tready = (state == ST_IDLE);
  assign TX = tx_reg;
  assign clk_count_done = (clk_count == (CLKS_PER_BIT - 1));
  assign bit_count_done = (bit_count == (BIT_PER_WORD - 1));

  always_comb begin
    unique case (PARITY_BIT)
      1: parity_value = ~(^data_reg); // odd parity
      2: parity_value =  (^data_reg); // even parity
      default: parity_value = 1'b1;
    endcase
  end

  always_comb begin
    next_state = state;
    unique case (state)
      ST_IDLE: begin
        if (tvalid) begin
          next_state = ST_START;
        end
      end
      ST_START: begin
        if (clk_count_done) begin
          next_state = ST_DATA;
        end
      end
      ST_DATA: begin
        if (clk_count_done && bit_count_done) begin
          if (PARITY_BIT == 0) begin
            next_state = ST_STOP1;
          end else begin
            next_state = ST_PARITY;
          end
        end
      end
      ST_PARITY: begin
        if (clk_count_done) begin
          next_state = ST_STOP1;
        end
      end
      ST_STOP1: begin
        if (clk_count_done) begin
          if (STOP_BITS_NUM == 2) begin
            next_state = ST_STOP2;
          end else begin
            next_state = ST_IDLE;
          end
        end
      end
      ST_STOP2: begin
        if (clk_count_done) begin
          next_state = ST_IDLE;
        end
      end
      default: next_state = ST_IDLE;
    endcase
  end

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      state      <= ST_IDLE;
      data_reg   <= '0;
      clk_count  <= '0;
      bit_count  <= '0;
      tx_reg     <= 1'b1;
    end else begin
      state <= next_state;

      if (state == ST_IDLE) begin
        clk_count <= '0;
      end else if (clk_count_done) begin
        clk_count <= '0;
      end else begin
        clk_count <= clk_count + 1'b1;
      end

      if ((state == ST_IDLE) && tvalid) begin
        data_reg  <= tdata;
        bit_count <= '0;
      end else if ((state == ST_DATA) && clk_count_done) begin
        if (!bit_count_done) begin
          bit_count <= bit_count + 1'b1;
        end
      end else if (state != ST_DATA) begin
        bit_count <= '0;
      end

      unique case (state)
        ST_IDLE:   tx_reg <= 1'b1;
        ST_START:  tx_reg <= 1'b0;
        ST_DATA:   tx_reg <= data_reg[bit_count];
        ST_PARITY: tx_reg <= parity_value;
        ST_STOP1:  tx_reg <= 1'b1;
        ST_STOP2:  tx_reg <= 1'b1;
        default:   tx_reg <= 1'b1;
      endcase
    end
  end

endmodule
