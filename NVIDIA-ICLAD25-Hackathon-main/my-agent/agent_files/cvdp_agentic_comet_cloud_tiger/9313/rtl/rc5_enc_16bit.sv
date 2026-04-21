`timescale 1ns/1ns

module rc5_enc_16bit (
    input  wire        clock,
    input  wire        reset,      // Synchronous active-low reset
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
  localparam [2:0] ST_ADD  = 3'd1;
  localparam [2:0] ST_MSB  = 3'd2;
  localparam [2:0] ST_LSB  = 3'd3;
  localparam [2:0] ST_OUT  = 3'd4;

  reg [2:0] state;
  reg [7:0] a_reg;
  reg [7:0] b_reg;

  function [7:0] rol8;
    input [7:0] value;
    input [2:0] shamt;
    begin
      rol8 = (value << shamt) | (value >> (3'd8 - shamt));
    end
  endfunction

  always @(posedge clock) begin
    if (!reset) begin
      state    <= ST_IDLE;
      a_reg    <= 8'd0;
      b_reg    <= 8'd0;
      c        <= 16'd0;
      enc_done <= 1'b0;
    end else begin
      enc_done <= 1'b0;
      case (state)
        ST_IDLE: begin
          if (enc_start) begin
            a_reg <= p[15:8];
            b_reg <= p[7:0];
            state <= ST_ADD;
          end
        end

        ST_ADD: begin
          a_reg <= a_reg + S0;
          b_reg <= b_reg + S1;
          state <= ST_MSB;
        end

        ST_MSB: begin
          a_reg <= rol8(a_reg ^ b_reg, b_reg[2:0]) + S2;
          state <= ST_LSB;
        end

        ST_LSB: begin
          b_reg <= rol8(b_reg ^ a_reg, a_reg[2:0]) + S3;
          state <= ST_OUT;
        end

        ST_OUT: begin
          c        <= {a_reg, b_reg};
          enc_done <= 1'b1;
          state    <= ST_IDLE;
        end

        default: begin
          state <= ST_IDLE;
        end
      endcase
    end
  end

endmodule
