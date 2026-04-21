`timescale 1ns/1ns

module nbit_swizzling #(
    parameter int DATA_WIDTH = 64
) (
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic [1:0]            sel,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic [DATA_WIDTH-1:0] gray_out
);
    integer seg;
    integer bit_idx;
    integer segment_count;
    integer segment_size;
    integer src_idx;
    integer dst_idx;

    always_comb begin
        data_out = data_in;

        segment_count = 1 << sel;              // 1, 2, 4, or 8
        segment_size  = DATA_WIDTH / segment_count;

        for (seg = 0; seg < segment_count; seg = seg + 1) begin
            for (bit_idx = 0; bit_idx < segment_size; bit_idx = bit_idx + 1) begin
                src_idx = seg * segment_size + (segment_size - 1 - bit_idx);
                dst_idx = seg * segment_size + bit_idx;
                data_out[dst_idx] = data_in[src_idx];
            end
        end
    end

    always_comb begin
        gray_out[DATA_WIDTH-1] = data_out[DATA_WIDTH-1];
        for (bit_idx = 0; bit_idx < DATA_WIDTH-1; bit_idx = bit_idx + 1) begin
            gray_out[bit_idx] = data_out[bit_idx+1] ^ data_out[bit_idx];
        end
    end

endmodule
