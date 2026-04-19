module barrel_shifter (
    input  [7:0] data_in,
    input  [2:0] shift_bits,
    input        left_right,
    output reg [7:0] data_out
);

    always @(*) begin
        if (left_right) begin
            data_out = data_in << shift_bits;
        end else begin
            data_out = data_in >> shift_bits;
        end
    end

endmodule
