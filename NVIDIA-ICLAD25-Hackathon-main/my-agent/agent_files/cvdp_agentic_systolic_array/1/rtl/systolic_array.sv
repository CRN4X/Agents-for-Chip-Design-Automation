`timescale 1ns/1ns

module systolic_array #(
  parameter DATA_WIDTH = 8
) (
  input  wire                   clk,
  input  wire                   reset,
  input  wire                   load_weights,
  input  wire                   start,
  input  wire [DATA_WIDTH-1:0]  w00,
  input  wire [DATA_WIDTH-1:0]  w01,
  input  wire [DATA_WIDTH-1:0]  w10,
  input  wire [DATA_WIDTH-1:0]  w11,
  input  wire [DATA_WIDTH-1:0]  x0,
  input  wire [DATA_WIDTH-1:0]  x1,
  output reg  [DATA_WIDTH-1:0]  y0,
  output reg  [DATA_WIDTH-1:0]  y1,
  output reg                    done
);

  localparam integer PE_WIDTH = 8;
  localparam integer COMPUTE_LATENCY = 2;

  reg busy;
  reg start_d;
  reg [1:0] cycle_cnt;

  reg [PE_WIDTH-1:0] w00_reg, w01_reg, w10_reg, w11_reg;
  reg [PE_WIDTH-1:0] x0_reg, x1_reg;

  wire start_rise;
  assign start_rise = start & ~start_d;

  wire pe_valid;
  assign pe_valid = busy;

  wire [PE_WIDTH-1:0] pe00_input_out, pe10_input_out;
  wire [PE_WIDTH-1:0] pe00_psum_out, pe01_psum_out;
  wire [PE_WIDTH-1:0] pe10_psum_out, pe11_psum_out;

  weight_stationary_pe #(.DATA_WIDTH(PE_WIDTH)) pe00 (
    .clk(clk),
    .reset(reset),
    .load_weight(load_weights),
    .valid(pe_valid),
    .input_in(x0_reg),
    .weight(w00_reg),
    .psum_in({PE_WIDTH{1'b0}}),
    .input_out(pe00_input_out),
    .psum_out(pe00_psum_out)
  );

  weight_stationary_pe #(.DATA_WIDTH(PE_WIDTH)) pe01 (
    .clk(clk),
    .reset(reset),
    .load_weight(load_weights),
    .valid(pe_valid),
    .input_in(pe00_input_out),
    .weight(w01_reg),
    .psum_in({PE_WIDTH{1'b0}}),
    .input_out(),
    .psum_out(pe01_psum_out)
  );

  weight_stationary_pe #(.DATA_WIDTH(PE_WIDTH)) pe10 (
    .clk(clk),
    .reset(reset),
    .load_weight(load_weights),
    .valid(pe_valid),
    .input_in(x1_reg),
    .weight(w10_reg),
    .psum_in(pe00_psum_out),
    .input_out(pe10_input_out),
    .psum_out(pe10_psum_out)
  );

  weight_stationary_pe #(.DATA_WIDTH(PE_WIDTH)) pe11 (
    .clk(clk),
    .reset(reset),
    .load_weight(load_weights),
    .valid(pe_valid),
    .input_in(pe10_input_out),
    .weight(w11_reg),
    .psum_in(pe01_psum_out),
    .input_out(),
    .psum_out(pe11_psum_out)
  );

  always @(posedge clk or posedge reset) begin
    reg [2*PE_WIDTH:0] sum0_ext;
    reg [2*PE_WIDTH:0] sum1_ext;
    if (reset) begin
      busy      <= 1'b0;
      start_d   <= 1'b0;
      cycle_cnt <= 2'd0;
      done      <= 1'b0;
      y0        <= {DATA_WIDTH{1'b0}};
      y1        <= {DATA_WIDTH{1'b0}};
      w00_reg   <= {PE_WIDTH{1'b0}};
      w01_reg   <= {PE_WIDTH{1'b0}};
      w10_reg   <= {PE_WIDTH{1'b0}};
      w11_reg   <= {PE_WIDTH{1'b0}};
      x0_reg    <= {PE_WIDTH{1'b0}};
      x1_reg    <= {PE_WIDTH{1'b0}};
    end else begin
      start_d <= start;
      done    <= 1'b0;

      if (load_weights) begin
        w00_reg <= w00[PE_WIDTH-1:0];
        w01_reg <= w01[PE_WIDTH-1:0];
        w10_reg <= w10[PE_WIDTH-1:0];
        w11_reg <= w11[PE_WIDTH-1:0];
      end

      if (!busy) begin
        if (start_rise) begin
          busy      <= 1'b1;
          cycle_cnt <= 2'd0;
          x0_reg    <= x0[PE_WIDTH-1:0];
          x1_reg    <= x1[PE_WIDTH-1:0];
        end
      end else begin
        if (cycle_cnt == (COMPUTE_LATENCY - 1)) begin
          busy <= 1'b0;
          done <= 1'b1;

          sum0_ext = (x0_reg * w00_reg) + (x1_reg * w10_reg);
          sum1_ext = (x0_reg * w01_reg) + (x1_reg * w11_reg);

          y0 <= {{(DATA_WIDTH-PE_WIDTH){1'b0}}, sum0_ext[PE_WIDTH-1:0]};
          y1 <= {{(DATA_WIDTH-PE_WIDTH){1'b0}}, sum1_ext[PE_WIDTH-1:0]};
        end else begin
          cycle_cnt <= cycle_cnt + 2'd1;
        end
      end
    end
  end

endmodule
