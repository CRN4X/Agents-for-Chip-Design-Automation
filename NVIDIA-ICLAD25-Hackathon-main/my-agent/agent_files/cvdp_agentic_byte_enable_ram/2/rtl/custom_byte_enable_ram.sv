module custom_byte_enable_ram #(
    parameter int XLEN  = 32,
    parameter int LINES = 8192
) (
    input  logic                   clk,
    input  logic [$clog2(LINES)-1:0] addr_a,
    input  logic                   en_a,
    input  logic [XLEN/8-1:0]      be_a,
    input  logic [XLEN-1:0]        data_in_a,
    output logic [XLEN-1:0]        data_out_a,
    input  logic [$clog2(LINES)-1:0] addr_b,
    input  logic                   en_b,
    input  logic [XLEN/8-1:0]      be_b,
    input  logic [XLEN-1:0]        data_in_b,
    output logic [XLEN-1:0]        data_out_b
);
  localparam int ADDR_WIDTH = $clog2(LINES);
  localparam int BYTE_COUNT = XLEN / 8;

  logic [XLEN-1:0] ram [0:LINES-1];

  logic [ADDR_WIDTH-1:0] addr_a_reg, addr_b_reg;
  logic                  en_a_reg, en_b_reg;
  logic [BYTE_COUNT-1:0] be_a_reg, be_b_reg;
  logic [XLEN-1:0]       data_in_a_reg, data_in_b_reg;

  integer idx;
  initial begin
    for (idx = 0; idx < LINES; idx = idx + 1) begin
      ram[idx] = '0;
    end
    addr_a_reg  = '0;
    addr_b_reg  = '0;
    en_a_reg    = 1'b0;
    en_b_reg    = 1'b0;
    be_a_reg    = '0;
    be_b_reg    = '0;
    data_in_a_reg = '0;
    data_in_b_reg = '0;
    data_out_a  = '0;
    data_out_b  = '0;
  end

  always_ff @(posedge clk) begin
    logic [XLEN-1:0] word_a;
    logic [XLEN-1:0] word_b;
    logic [XLEN-1:0] merged_word;
    integer byte_idx;

    word_a = ram[addr_a_reg];
    word_b = ram[addr_b_reg];

    if (en_a_reg && en_b_reg && (addr_a_reg == addr_b_reg)) begin
      merged_word = ram[addr_a_reg];
      for (byte_idx = 0; byte_idx < BYTE_COUNT; byte_idx = byte_idx + 1) begin
        if (be_a_reg[byte_idx]) begin
          merged_word[8*byte_idx +: 8] = data_in_a_reg[8*byte_idx +: 8];
        end else if (be_b_reg[byte_idx]) begin
          merged_word[8*byte_idx +: 8] = data_in_b_reg[8*byte_idx +: 8];
        end
      end
      ram[addr_a_reg] <= merged_word;
      word_a = merged_word;
      word_b = merged_word;
    end else begin
      if (en_a_reg) begin
        word_a = ram[addr_a_reg];
        for (byte_idx = 0; byte_idx < BYTE_COUNT; byte_idx = byte_idx + 1) begin
          if (be_a_reg[byte_idx]) begin
            word_a[8*byte_idx +: 8] = data_in_a_reg[8*byte_idx +: 8];
          end
        end
        ram[addr_a_reg] <= word_a;
      end

      if (en_b_reg) begin
        word_b = ram[addr_b_reg];
        for (byte_idx = 0; byte_idx < BYTE_COUNT; byte_idx = byte_idx + 1) begin
          if (be_b_reg[byte_idx]) begin
            word_b[8*byte_idx +: 8] = data_in_b_reg[8*byte_idx +: 8];
          end
        end
        ram[addr_b_reg] <= word_b;
      end
    end

    data_out_a <= word_a;
    data_out_b <= word_b;

    addr_a_reg    <= addr_a;
    addr_b_reg    <= addr_b;
    en_a_reg      <= en_a;
    en_b_reg      <= en_b;
    be_a_reg      <= be_a;
    be_b_reg      <= be_b;
    data_in_a_reg <= data_in_a;
    data_in_b_reg <= data_in_b;
  end

endmodule
