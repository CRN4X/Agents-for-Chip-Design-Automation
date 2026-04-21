`timescale 1ns/1ns

module rc5_enc_16bit (
    input  wire        clock,
    input  wire        reset,
    input  wire        enc_start,
    input  wire [15:0] p,
    output reg  [15:0] c,
    output reg         enc_done
);

  localparam [7:0] S0 = 8'hAB;
  localparam [7:0] S1 = 8'h29;
  localparam [7:0] S2 = 8'h6E;
  localparam [7:0] S3 = 8'hC1;

  localparam [2:0] ST_IDLE = 3'd0;
  localparam [2:0] ST_INIT = 3'd1;
  localparam [2:0] ST_MSB  = 3'd2;
  localparam [2:0] ST_LSB  = 3'd3;
  localparam [2:0] ST_OUT  = 3'd4;

  reg [2:0] state;
  reg [7:0] a_reg;
  reg [7:0] b_reg;

  function automatic [7:0] rotl8;
    input [7:0] data;
    input [2:0] sh;
    begin
      if (sh == 3'd0) begin
        rotl8 = data;
      end else begin
        rotl8 = (data << sh) | (data >> (4'd8 - sh));
      end
    end
  endfunction

  always_ff @(posedge clock) begin
    if (!reset) begin
      state    <= ST_IDLE;
      a_reg    <= 8'h00;
      b_reg    <= 8'h00;
      c        <= 16'h0000;
      enc_done <= 1'b0;
    end else begin
      case (state)
        ST_IDLE: begin
          enc_done <= 1'b0;
          if (enc_start) begin
            a_reg  <= p[15:8] + S0;
            b_reg  <= p[7:0]  + S1;
            state  <= ST_INIT;
          end
        end

        ST_INIT: begin
          state <= ST_MSB;
        end

        ST_MSB: begin
          a_reg <= rotl8(a_reg ^ b_reg, b_reg[2:0]) + S2;
          state <= ST_LSB;
        end

        ST_LSB: begin
          b_reg <= rotl8(b_reg ^ a_reg, a_reg[2:0]) + S3;
          state <= ST_OUT;
        end

        ST_OUT: begin
          c        <= {a_reg, b_reg};
          enc_done <= 1'b1;
          if (!enc_start) begin
            state <= ST_IDLE;
          end
        end

        default: begin
          state    <= ST_IDLE;
          enc_done <= 1'b0;
        end
      endcase
    end
  end

endmodule
