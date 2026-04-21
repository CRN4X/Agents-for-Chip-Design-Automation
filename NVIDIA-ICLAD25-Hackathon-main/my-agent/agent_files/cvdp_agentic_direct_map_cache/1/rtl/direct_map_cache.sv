`timescale 1ns/1ns

module direct_map_cache #(
    parameter integer CACHE_SIZE   = 256,
    parameter integer DATA_WIDTH   = 16,
    parameter integer TAG_WIDTH    = 5,
    parameter integer OFFSET_WIDTH = 3,
    parameter integer INDEX_WIDTH  = $clog2(CACHE_SIZE)
) (
    input  wire                     enable,
    input  wire [INDEX_WIDTH-1:0]   index,
    input  wire [OFFSET_WIDTH-1:0]  offset,
    input  wire                     comp,
    input  wire                     write,
    input  wire [TAG_WIDTH-1:0]     tag_in,
    input  wire [DATA_WIDTH-1:0]    data_in,
    input  wire                     valid_in,
    input  wire                     clk,
    input  wire                     rst,
    output reg                      hit,
    output reg                      dirty,
    output reg [TAG_WIDTH-1:0]      tag_out,
    output reg [DATA_WIDTH-1:0]     data_out,
    output reg                      valid,
    output reg                      error
);

    localparam integer LINE_WORDS = (1 << (OFFSET_WIDTH - 1));

    reg [TAG_WIDTH-1:0]  tags       [0:CACHE_SIZE-1];
    reg [DATA_WIDTH-1:0] data_mem   [0:CACHE_SIZE-1][0:LINE_WORDS-1];
    reg                  valid_bits [0:CACHE_SIZE-1];
    reg                  dirty_bits [0:CACHE_SIZE-1];

    integer i;
    integer j;
    reg hit_cond;

    always @(posedge clk) begin
        if (rst) begin
            hit     <= 1'b0;
            dirty   <= 1'b0;
            tag_out <= {TAG_WIDTH{1'b0}};
            data_out<= {DATA_WIDTH{1'b0}};
            valid   <= 1'b0;
            error   <= 1'b0;

            for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                tags[i]       <= {TAG_WIDTH{1'b0}};
                valid_bits[i] <= 1'b0;
                dirty_bits[i] <= 1'b0;
                for (j = 0; j < LINE_WORDS; j = j + 1) begin
                    data_mem[i][j] <= {DATA_WIDTH{1'b0}};
                end
            end
        end else if (enable) begin
            if (offset[0]) begin
                hit     <= 1'b0;
                dirty   <= 1'b0;
                tag_out <= {TAG_WIDTH{1'b0}};
                data_out<= {DATA_WIDTH{1'b0}};
                valid   <= 1'b0;
                error   <= 1'b1;
            end else begin
                error   <= 1'b0;
                hit_cond = valid_bits[index] && (tags[index] == tag_in);

                if (comp) begin
                    if (write) begin
                        hit <= hit_cond;

                        data_mem[index][offset[OFFSET_WIDTH-1:1]] <= data_in;
                        tags[index]       <= tag_in;
                        valid_bits[index] <= valid_in;

                        if (hit_cond) begin
                            dirty_bits[index] <= 1'b1;
                            dirty             <= 1'b1;
                        end else begin
                            dirty_bits[index] <= 1'b0;
                            dirty             <= 1'b0;
                        end

                        tag_out <= tag_in;
                        data_out<= data_in;
                        valid   <= valid_in;
                    end else begin
                        hit     <= hit_cond;
                        dirty   <= dirty_bits[index];
                        tag_out <= tags[index];
                        data_out<= data_mem[index][offset[OFFSET_WIDTH-1:1]];
                        valid   <= valid_bits[index];
                    end
                end else begin
                    hit <= 1'b0;

                    if (write) begin
                        data_mem[index][offset[OFFSET_WIDTH-1:1]] <= data_in;
                        tags[index]       <= tag_in;
                        valid_bits[index] <= valid_in;
                        dirty_bits[index] <= 1'b0;

                        dirty   <= 1'b0;
                        tag_out <= tag_in;
                        data_out<= data_in;
                        valid   <= valid_in;
                    end else begin
                        dirty   <= dirty_bits[index];
                        tag_out <= tags[index];
                        data_out<= data_mem[index][offset[OFFSET_WIDTH-1:1]];
                        valid   <= valid_bits[index];
                    end
                end
            end
        end
    end

endmodule
