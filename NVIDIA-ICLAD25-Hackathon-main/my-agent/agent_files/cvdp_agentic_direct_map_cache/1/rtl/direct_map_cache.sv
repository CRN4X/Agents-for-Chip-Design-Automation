module direct_map_cache #(
    parameter int CACHE_SIZE   = 256,
    parameter int DATA_WIDTH   = 16,
    parameter int TAG_WIDTH    = 5,
    parameter int OFFSET_WIDTH = 3,
    parameter int INDEX_WIDTH  = $clog2(CACHE_SIZE)
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    enable,
    input  wire [INDEX_WIDTH-1:0]  index,
    input  wire [OFFSET_WIDTH-1:0] offset,
    input  wire                    comp,
    input  wire                    write,
    input  wire [TAG_WIDTH-1:0]    tag_in,
    input  wire [DATA_WIDTH-1:0]   data_in,
    input  wire                    valid_in,
    output reg                     hit,
    output reg                     dirty,
    output reg  [TAG_WIDTH-1:0]    tag_out,
    output reg  [DATA_WIDTH-1:0]   data_out,
    output reg                     valid,
    output reg                     error
);

    localparam int LINE_WORDS = (1 << OFFSET_WIDTH);

    reg [TAG_WIDTH-1:0]  tags      [0:CACHE_SIZE-1];
    reg [DATA_WIDTH-1:0] data_mem  [0:CACHE_SIZE-1][0:LINE_WORDS-1];
    reg                  valid_bits[0:CACHE_SIZE-1];
    reg                  dirty_bits[0:CACHE_SIZE-1];

    integer i;
    integer j;

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
            hit   <= 1'b0;
            error <= 1'b0;

            if (offset[0]) begin
                error   <= 1'b1;
                hit     <= 1'b0;
                dirty   <= 1'b0;
                valid   <= 1'b0;
                tag_out <= {TAG_WIDTH{1'b0}};
                data_out<= {DATA_WIDTH{1'b0}};
            end else if (comp) begin
                if (write) begin
                    if (valid_bits[index] && (tags[index] == tag_in)) begin
                        data_mem[index][offset] <= data_in;
                        dirty_bits[index]       <= 1'b1;
                        hit                     <= 1'b1;
                    end

                    tag_out <= tags[index];
                    data_out<= data_mem[index][offset];
                    valid   <= valid_bits[index];
                    dirty   <= dirty_bits[index] | (valid_bits[index] && (tags[index] == tag_in));
                end else begin
                    if (valid_bits[index] && (tags[index] == tag_in)) begin
                        hit     <= 1'b1;
                        tag_out <= tags[index];
                        data_out<= data_mem[index][offset];
                        valid   <= valid_bits[index];
                        dirty   <= dirty_bits[index];
                    end else begin
                        hit     <= 1'b0;
                        tag_out <= tags[index];
                        data_out<= {DATA_WIDTH{1'b0}};
                        valid   <= valid_bits[index];
                        dirty   <= dirty_bits[index];
                    end
                end
            end else begin
                if (write) begin
                    tags[index]              <= tag_in;
                    data_mem[index][offset]  <= data_in;
                    valid_bits[index]        <= valid_in;
                    dirty_bits[index]        <= 1'b0;

                    hit     <= 1'b0;
                    tag_out <= tag_in;
                    data_out<= data_in;
                    valid   <= valid_in;
                    dirty   <= 1'b0;
                end else begin
                    hit     <= 1'b0;
                    tag_out <= tags[index];
                    data_out<= data_mem[index][offset];
                    valid   <= valid_bits[index];
                    dirty   <= dirty_bits[index];
                end
            end
        end
    end

endmodule
