module S1(
    input  logic [5:0] i_data,
    output logic [3:0] o_data
);

always_comb begin
    case (i_data)
        6'b0_0000_0 : o_data = 4'd14;
        6'b0_0001_0 : o_data = 4'd4;
        6'b0_0010_0 : o_data = 4'd13;
        6'b0_0011_0 : o_data = 4'd1;
        6'b0_0100_0 : o_data = 4'd2;
        6'b0_0101_0 : o_data = 4'd15;
        6'b0_0110_0 : o_data = 4'd11;
        6'b0_0111_0 : o_data = 4'd8;
        6'b0_1000_0 : o_data = 4'd3;
        6'b0_1001_0 : o_data = 4'd10;
        6'b0_1010_0 : o_data = 4'd6;
        6'b0_1011_0 : o_data = 4'd12;
        6'b0_1100_0 : o_data = 4'd5;
        6'b0_1101_0 : o_data = 4'd9;
        6'b0_1110_0 : o_data = 4'd0;
        6'b0_1111_0 : o_data = 4'd7;
        6'b0_0000_1 : o_data = 4'd0;
        6'b0_0001_1 : o_data = 4'd15;
        6'b0_0010_1 : o_data = 4'd7;
        6'b0_0011_1 : o_data = 4'd4;
        6'b0_0100_1 : o_data = 4'd14;
        6'b0_0101_1 : o_data = 4'd2;
        6'b0_0110_1 : o_data = 4'd13;
        6'b0_0111_1 : o_data = 4'd1;
        6'b0_1000_1 : o_data = 4'd10;
        6'b0_1001_1 : o_data = 4'd6;
        6'b0_1010_1 : o_data = 4'd12;
        6'b0_1011_1 : o_data = 4'd11;
        6'b0_1100_1 : o_data = 4'd9;
        6'b0_1101_1 : o_data = 4'd5;
        6'b0_1110_1 : o_data = 4'd3;
        6'b0_1111_1 : o_data = 4'd8;
        6'b1_0000_0 : o_data = 4'd4;
        6'b1_0001_0 : o_data = 4'd1;
        6'b1_0010_0 : o_data = 4'd14;
        6'b1_0011_0 : o_data = 4'd8;
        6'b1_0100_0 : o_data = 4'd13;
        6'b1_0101_0 : o_data = 4'd6;
        6'b1_0110_0 : o_data = 4'd2;
        6'b1_0111_0 : o_data = 4'd11;
        6'b1_1000_0 : o_data = 4'd15;
        6'b1_1001_0 : o_data = 4'd12;
        6'b1_1010_0 : o_data = 4'd9;
        6'b1_1011_0 : o_data = 4'd7;
        6'b1_1100_0 : o_data = 4'd3;
        6'b1_1101_0 : o_data = 4'd10;
        6'b1_1110_0 : o_data = 4'd5;
        6'b1_1111_0 : o_data = 4'd0;
        6'b1_0000_1 : o_data = 4'd15;
        6'b1_0001_1 : o_data = 4'd12;
        6'b1_0010_1 : o_data = 4'd8;
        6'b1_0011_1 : o_data = 4'd2;
        6'b1_0100_1 : o_data = 4'd4;
        6'b1_0101_1 : o_data = 4'd9;
        6'b1_0110_1 : o_data = 4'd1;
        6'b1_0111_1 : o_data = 4'd7;
        6'b1_1000_1 : o_data = 4'd5;
        6'b1_1001_1 : o_data = 4'd11;
        6'b1_1010_1 : o_data = 4'd3;
        6'b1_1011_1 : o_data = 4'd14;
        6'b1_1100_1 : o_data = 4'd10;
        6'b1_1101_1 : o_data = 4'd0;
        6'b1_1110_1 : o_data = 4'd6;
        6'b1_1111_1 : o_data = 4'd13;
        default: o_data = 4'd0;
    endcase
end

endmodule : S1