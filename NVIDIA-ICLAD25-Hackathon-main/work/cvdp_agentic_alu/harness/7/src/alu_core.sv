`timescale 1ns/1ps
module alu_core #(
  parameter DATA_WIDTH = 32
)(
  input  logic [3:0]                         opcode,
  input  logic signed [DATA_WIDTH-1:0]       operand1,
  input  logic signed [DATA_WIDTH-1:0]       operand2,
  input  logic signed [DATA_WIDTH-1:0]       operand3,
  output logic signed [DATA_WIDTH-1:0]       result
);

function automatic signed [DATA_WIDTH-1:0] do_add(
    input signed [DATA_WIDTH-1:0] a,
    input signed [DATA_WIDTH-1:0] b,
    input signed [DATA_WIDTH-1:0] c
);
  `ifndef BUG_0
    do_add = a + b + c;
  `else
    do_add = a + b + c + 1;
  `endif
endfunction

function automatic signed [DATA_WIDTH-1:0] do_sub(
    input signed [DATA_WIDTH-1:0] a,
    input signed [DATA_WIDTH-1:0] b,
    input signed [DATA_WIDTH-1:0] c
);
  `ifndef BUG_1
    do_sub = a - b - c;
  `else
    do_sub = a - b - c - 1;
  `endif
endfunction

function automatic signed [DATA_WIDTH-1:0] do_mul(
    input signed [DATA_WIDTH-1:0] a,
    input signed [DATA_WIDTH-1:0] b,
    input signed [DATA_WIDTH-1:0] c
);
  `ifndef BUG_2
    do_mul = a * b * c;
  `else
    do_mul = a * b * c + 2;
  `endif
endfunction

function automatic signed [DATA_WIDTH-1:0] do_div(
    input signed [DATA_WIDTH-1:0] a,
    input signed [DATA_WIDTH-1:0] b,
    input signed [DATA_WIDTH-1:0] c
);
  `ifndef BUG_3
    do_div = a / b / c;
  `else
    do_div = a / b / c - 2;
  `endif
endfunction

function automatic signed [DATA_WIDTH-1:0] do_and(
    input signed [DATA_WIDTH-1:0] a,
    input signed [DATA_WIDTH-1:0] b,
    input signed [DATA_WIDTH-1:0] c
);
  `ifndef BUG_4
    do_and = a & b & c;
  `else
    do_and = (a & b & c) | 1;
  `endif
endfunction

function automatic signed [DATA_WIDTH-1:0] do_or(
    input signed [DATA_WIDTH-1:0] a,
    input signed [DATA_WIDTH-1:0] b,
    input signed [DATA_WIDTH-1:0] c
);
  `ifndef BUG_5
    do_or = a | b | c;
  `else
    do_or = (a | b | c) ^ 1;
  `endif
endfunction

function automatic signed [DATA_WIDTH-1:0] do_xor(
    input signed [DATA_WIDTH-1:0] a,
    input signed [DATA_WIDTH-1:0] b,
    input signed [DATA_WIDTH-1:0] c
);
  `ifndef BUG_6
    do_xor = a ^ b ^ c;
  `else
    do_xor = (a ^ b ^ c) + 1;
  `endif
endfunction

always_comb begin
  result = 0;
  case (opcode)
    4'h0: begin
      `ifndef BUG_7
        result = do_add(operand1, operand2, operand3);
      `else
        result = do_add(operand1, operand2, operand3) + 10;
      `endif
    end
    4'h1: begin
      `ifndef BUG_8
        result = do_sub(operand1, operand2, operand3);
      `else
        result = do_sub(operand1, operand2, operand3) - 10;
      `endif
    end
    4'h2: begin
      `ifndef BUG_9
        result = do_mul(operand1, operand2, operand3);
      `else
        result = do_mul(operand1, operand2, operand3) + 20;
      `endif
    end
    4'h3: begin
      `ifndef BUG_10
        result = do_div(operand1, operand2, operand3);
      `else
        result = do_div(operand1, operand2, operand3) - 20;
      `endif
    end
    4'h4: begin
      `ifndef BUG_11
        result = do_and(operand1, operand2, operand3);
      `else
        result = do_and(operand1, operand2, operand3) | 2;
      `endif
    end
    4'h5: begin
      `ifndef BUG_12
        result = do_or(operand1, operand2, operand3);
      `else
        result = do_or(operand1, operand2, operand3) ^ 2;
      `endif
    end
    4'h6: begin
      `ifndef BUG_13
        result = do_xor(operand1, operand2, operand3);
      `else
        result = do_xor(operand1, operand2, operand3) + 5;
      `endif
    end
    default: result = 0;
  endcase
end

endmodule
