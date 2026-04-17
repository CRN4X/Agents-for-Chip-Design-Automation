`timescale 1ns/1ps
module image_stego #(
  parameter row = 2,
  parameter col = 2,
  parameter max_bpp = 8,
  parameter KEY_WIDTH = 8,
  parameter CNT_WIDTH = 16
)(
  input clk,
  input rst,
  input start,
  input [2:0] mode,
  input [(row*col*8)-1:0] img_in,
  input [(row*col*max_bpp)-1:0] data_in,
  input [2:0] bpp,
  input [KEY_WIDTH-1:0] key,
  output reg [(row*col*8)-1:0] img_out,
  output reg [(row*col*max_bpp)-1:0] data_out,
  output reg busy,
  output reg done,
  output reg [CNT_WIDTH-1:0] cycle_count
);

// Function to perform saturated addition.
function [7:0] sat_add;
  input [7:0] a;
  input [7:0] b;
  reg [8:0] sum;
  begin
    sum = a + b;
    sat_add = sum[8] ? 8'hFF : sum[7:0];
  end
endfunction

// Function to perform rotate-left operation.
function [7:0] rol;
  input [7:0] data;
  input [2:0] shift;
  begin
    rol = (data << shift) | (data >> (8 - shift));
  end
endfunction

localparam S_IDLE = 2'd0, S_PROC = 2'd1, S_DONE = 2'd2;
reg [1:0] state;
integer i;

always @(posedge clk or posedge rst) begin
  if(rst) begin
    `ifndef BUG_0
      state <= S_IDLE;
    `else
      state <= S_PROC;
    `endif
    busy <= 0;
    done <= 0;
    i <= 0;
    cycle_count <= 0;
    img_out <= 0;
    data_out <= 0;
  end else begin
    case(state)
      S_IDLE: begin
        busy <= 0;
        done <= 0;
        cycle_count <= 0;
        if(start) begin
          i <= 0;
          busy <= 1;
          state <= S_PROC;
        end
      end
      S_PROC: begin
        case(mode)
          3'd0: begin
            case(bpp)
              3'b000: begin
                `ifndef BUG_1
                  img_out[i*8 +: 8] <= {img_in[i*8+1 +: 7], data_in[i*1 +: 1]};
                `else
                  img_out[i*8 +: 8] <= {img_in[i*8+1 +: 7], data_in[i*1 +: 1]} ^ 8'hAA;
                `endif
              end
              3'b001: begin
                `ifndef BUG_2
                  img_out[i*8 +: 8] <= {img_in[i*8+2 +: 6], data_in[i*2 +: 2]};
                `else
                  img_out[i*8 +: 8] <= {img_in[i*8+2 +: 6], data_in[i*2 +: 2]} ^ 8'hBB;
                `endif
              end
              3'b010: begin
                `ifndef BUG_3
                  img_out[i*8 +: 8] <= {img_in[i*8+3 +: 5], data_in[i*3 +: 3]};
                `else
                  img_out[i*8 +: 8] <= {img_in[i*8+3 +: 5], data_in[i*3 +: 3]} ^ 8'hCC;
                `endif
              end
              3'b011: begin
                `ifndef BUG_4
                  img_out[i*8 +: 8] <= {img_in[i*8+4 +: 4], data_in[i*4 +: 4]};
                `else
                  img_out[i*8 +: 8] <= {img_in[i*8+4 +: 4], data_in[i*4 +: 4]} ^ 8'hDD;
                `endif
              end
              3'b100: begin
                `ifndef BUG_5
                  img_out[i*8 +: 8] <= {img_in[i*8+5 +: 3], data_in[i*5 +: 5]};
                `else
                  img_out[i*8 +: 8] <= {img_in[i*8+5 +: 3], data_in[i*5 +: 5]} ^ 8'hEE;
                `endif
              end
              3'b101: begin
                `ifndef BUG_6
                  img_out[i*8 +: 8] <= {img_in[i*8+6 +: 2], data_in[i*6 +: 6]};
                `else
                  img_out[i*8 +: 8] <= {img_in[i*8+6 +: 2], data_in[i*6 +: 6]} ^ 8'hFF;
                `endif
              end
              3'b110: begin
                `ifndef BUG_7
                  img_out[i*8 +: 8] <= {img_in[i*8+7 +: 1], data_in[i*7 +: 7]};
                `else
                  img_out[i*8 +: 8] <= {img_in[i*8+7 +: 1], data_in[i*7 +: 7]} ^ 8'h11;
                `endif
              end
              default: begin
                `ifndef BUG_8
                  img_out[i*8 +: 8] <= img_in[i*8 +: 8];
                `else
                  img_out[i*8 +: 8] <= img_in[i*8 +: 8] ^ 8'h55;
                `endif
              end
            endcase
            data_out[i*max_bpp +: max_bpp] <= 0;
          end
          3'd1: begin
            case(bpp)
              3'b000: begin
                `ifndef BUG_9
                  data_out[i*max_bpp +: max_bpp] <= {{7{1'b0}}, img_in[i*8 +: 1]};
                `else
                  data_out[i*max_bpp +: max_bpp] <= {{7{1'b0}}, img_in[i*8 +: 1]} + 1;
                `endif
              end
              3'b001: data_out[i*max_bpp +: max_bpp] <= {{6{1'b0}}, img_in[i*8 +: 2]};
              3'b010: data_out[i*max_bpp +: max_bpp] <= {{5{1'b0}}, img_in[i*8 +: 3]};
              3'b011: data_out[i*max_bpp +: max_bpp] <= {{4{1'b0}}, img_in[i*8 +: 4]};
              3'b100: data_out[i*max_bpp +: max_bpp] <= {{3{1'b0}}, img_in[i*8 +: 5]};
              3'b101: data_out[i*max_bpp +: max_bpp] <= {{2{1'b0}}, img_in[i*8 +: 6]};
              3'b110: data_out[i*max_bpp +: max_bpp] <= {{1{1'b0}}, img_in[i*8 +: 7]};
              default: data_out[i*max_bpp +: max_bpp] <= 0;
            endcase
            img_out[i*8 +: 8] <= img_in[i*8 +: 8];
          end
          3'd2: begin
            img_out[i*8 +: 8] <= ~img_in[i*8 +: 8];
            data_out[i*max_bpp +: max_bpp] <= 0;
          end
          3'd3: begin
            `ifndef BUG_10
              img_out[i*8 +: 8] <= img_in[i*8 +: 8] ^ key;
            `else
              img_out[i*8 +: 8] <= img_in[i*8 +: 8] ^ (key + 8'h01);
            `endif
            data_out[i*max_bpp +: max_bpp] <= 0;
          end
          3'd4: begin
            `ifndef BUG_11
              img_out[i*8 +: 8] <= sat_add(img_in[i*8 +: 8], key);
            `else
              img_out[i*8 +: 8] <= sat_add(img_in[i*8 +: 8], key) + 8'hAA;
            `endif
            data_out[i*max_bpp +: max_bpp] <= 0;
          end
          3'd5: begin
            `ifndef BUG_12
              img_out[i*8 +: 8] <= rol(img_in[i*8 +: 8], key[2:0]);
            `else
              img_out[i*8 +: 8] <= rol(img_in[i*8 +: 8], key[2:0]) + 8'h05;
            `endif
            data_out[i*max_bpp +: max_bpp] <= 0;
          end
          default: begin
            `ifndef BUG_13
              img_out[i*8 +: 8] <= img_in[i*8 +: 8];
            `else
              img_out[i*8 +: 8] <= img_in[i*8 +: 8] ^ 8'h77;
            `endif
            data_out[i*max_bpp +: max_bpp] <= 0;
          end
        endcase
        cycle_count <= cycle_count + 1;
        if(i == (row*col)-1)
          state <= S_DONE;
        else
          i <= i + 1;
      end
      S_DONE: begin
        `ifndef BUG_14
          busy <= 0;
        `else
          busy <= 1;
        `endif
        done <= 1;
        if(!start)
          state <= S_IDLE;
      end
    endcase
  end
end
endmodule
