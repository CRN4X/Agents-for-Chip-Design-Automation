module column_selector #(
    parameter NBW_STR = 'd8,
    parameter NBW_COL = 'd2,
    parameter NS_COLS = 'd4
) (
    input  logic [NBW_COL-1:0]           i_col_sel,
    input  logic [(NBW_STR*NS_COLS)-1:0] i_data,
    output logic [NBW_STR-1:0]           o_data
);

// ----------------------------------------
// - Wires/Registers creation
// ----------------------------------------
logic [NBW_STR-1:0] data [0:NS_COLS-1];

// ----------------------------------------
// - Unpack input data
// ----------------------------------------
generate
    for(genvar i = 0; i < NS_COLS; i++) begin : unpack_data
        assign data[i] = i_data[(NBW_STR*NS_COLS)-i*NBW_STR-1-:NBW_STR];
    end
endgenerate

// ----------------------------------------
// - Output assignment
// ----------------------------------------
always_comb begin : output_assignment
    o_data = data[i_col_sel];
end

endmodule : column_selector