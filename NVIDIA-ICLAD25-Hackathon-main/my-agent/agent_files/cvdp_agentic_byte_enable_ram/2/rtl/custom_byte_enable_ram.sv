`timescale 1ns/1ns

module custom_byte_enable_ram #(
    parameter int XLEN = 32,
    parameter int LINES = 8192,
    parameter int ADDR_WIDTH = $clog2(LINES)
) (
    input  logic                  clk,
    input  logic [ADDR_WIDTH-1:0] addr_a,
    input  logic                  en_a,
    input  logic [XLEN/8-1:0]     be_a,
    input  logic [XLEN-1:0]       data_in_a,
    output logic [XLEN-1:0]       data_out_a,
    input  logic [ADDR_WIDTH-1:0] addr_b,
    input  logic                  en_b,
    input  logic [XLEN/8-1:0]     be_b,
    input  logic [XLEN-1:0]       data_in_b,
    output logic [XLEN-1:0]       data_out_b
);

    logic [XLEN-1:0] ram [0:LINES-1];

    logic [ADDR_WIDTH-1:0] addr_a_reg, addr_b_reg;
    logic                  en_a_reg, en_b_reg;
    logic [XLEN/8-1:0]     be_a_reg, be_b_reg;
    logic [XLEN-1:0]       data_in_a_reg, data_in_b_reg;

    function automatic logic [XLEN-1:0] apply_be(
        input logic [XLEN-1:0]      base_word,
        input logic [XLEN/8-1:0]    be,
        input logic [XLEN-1:0]      wr_data
    );
        logic [XLEN-1:0] result;
        integer i;
        begin
            result = base_word;
            for (i = 0; i < (XLEN/8); i = i + 1) begin
                if (be[i]) begin
                    result[(8*i)+:8] = wr_data[(8*i)+:8];
                end
            end
            apply_be = result;
        end
    endfunction

    integer init_i;
    initial begin
        for (init_i = 0; init_i < LINES; init_i = init_i + 1) begin
            ram[init_i] = '0;
        end
        addr_a_reg   = '0;
        en_a_reg     = 1'b0;
        be_a_reg     = '0;
        data_in_a_reg = '0;
        addr_b_reg   = '0;
        en_b_reg     = 1'b0;
        be_b_reg     = '0;
        data_in_b_reg = '0;
        data_out_a   = '0;
        data_out_b   = '0;
    end

    integer byte_idx;
    logic [XLEN-1:0] word_a_next;
    logic [XLEN-1:0] word_b_next;
    logic [XLEN-1:0] merged_same_addr;

    always_ff @(posedge clk) begin
        word_a_next = ram[addr_a_reg];
        word_b_next = ram[addr_b_reg];

        if (en_a_reg && en_b_reg && (addr_a_reg == addr_b_reg)) begin
            merged_same_addr = ram[addr_a_reg];
            for (byte_idx = 0; byte_idx < (XLEN/8); byte_idx = byte_idx + 1) begin
                if (be_a_reg[byte_idx]) begin
                    merged_same_addr[(8*byte_idx)+:8] = data_in_a_reg[(8*byte_idx)+:8];
                end else if (be_b_reg[byte_idx]) begin
                    merged_same_addr[(8*byte_idx)+:8] = data_in_b_reg[(8*byte_idx)+:8];
                end
            end
            ram[addr_a_reg] <= merged_same_addr;
            word_a_next = merged_same_addr;
            word_b_next = merged_same_addr;
        end else begin
            if (en_a_reg) begin
                word_a_next = apply_be(ram[addr_a_reg], be_a_reg, data_in_a_reg);
                ram[addr_a_reg] <= word_a_next;
            end
            if (en_b_reg) begin
                word_b_next = apply_be(ram[addr_b_reg], be_b_reg, data_in_b_reg);
                ram[addr_b_reg] <= word_b_next;
            end
        end

        data_out_a <= word_a_next;
        data_out_b <= word_b_next;

        addr_a_reg    <= addr_a;
        en_a_reg      <= en_a;
        be_a_reg      <= be_a;
        data_in_a_reg <= data_in_a;

        addr_b_reg    <= addr_b;
        en_b_reg      <= en_b;
        be_b_reg      <= be_b;
        data_in_b_reg <= data_in_b;
    end

endmodule
