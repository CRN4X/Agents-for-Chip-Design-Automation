`timescale 1ns/1ns

module event_array #(
    parameter NS_ROWS = 'd4,
    parameter NS_COLS = 'd4,
    parameter NBW_COL = 'd2,
    parameter NBW_STR = 'd8,
    parameter NS_EVT  = 'd8,
    parameter NBW_EVT = 'd3
) (
    input  logic                               clk,
    input  logic                               rst_async_n,
    input  logic [NBW_COL-1:0]                 i_col_sel,
    input  logic [(NS_ROWS*NS_COLS)-1:0]       i_en_overflow,
    input  logic [(NS_ROWS*NS_COLS*NS_EVT)-1:0] i_event,
    input  logic [(NS_COLS*NBW_STR)-1:0]       i_data,
    input  logic [NS_ROWS-1:0]                 i_bypass,
    input  logic [NBW_EVT-1:0]                 i_raddr,
    output logic [NBW_STR-1:0]                 o_data
);

logic [NBW_STR-1:0] data_out [0:NS_ROWS-1][0:NS_COLS-1];
logic [(NS_COLS*NBW_STR)-1:0] data_col_sel;

generate
    for (genvar row = 0; row < NS_ROWS; row++) begin : g_row
        for (genvar col = 0; col < NS_COLS; col++) begin : g_col
            localparam int CELL_INDEX = row*NS_COLS + col;
            localparam int EVENT_MSB  = (NS_ROWS*NS_COLS*NS_EVT) - (CELL_INDEX*NS_EVT) - 1;
            localparam int DATA_MSB   = (NS_COLS*NBW_STR) - (col*NBW_STR) - 1;

            wire [NBW_STR-1:0] cell_data_in;
            if (row == 0) begin : g_first_row_input
                assign cell_data_in = i_data[DATA_MSB -: NBW_STR];
            end else begin : g_pipe_row_input
                assign cell_data_in = data_out[row-1][col];
            end

            event_storage #(
                .NBW_STR(NBW_STR),
                .NS_EVT(NS_EVT),
                .NBW_EVT(NBW_EVT)
            ) event_storage_inst (
                .clk(clk),
                .rst_async_n(rst_async_n),
                .i_en_overflow(i_en_overflow[CELL_INDEX]),
                .i_event(i_event[EVENT_MSB -: NS_EVT]),
                .i_data(cell_data_in),
                .i_bypass(i_bypass[row]),
                .i_raddr(i_raddr),
                .o_data(data_out[row][col])
            );
        end
    end
endgenerate

generate
    for (genvar col = 0; col < NS_COLS; col++) begin : g_last_row_pack
        localparam int DATA_MSB = (NS_COLS*NBW_STR) - (col*NBW_STR) - 1;
        assign data_col_sel[DATA_MSB -: NBW_STR] = data_out[NS_ROWS-1][col];
    end
endgenerate

column_selector #(
    .NBW_STR(NBW_STR),
    .NBW_COL(NBW_COL),
    .NS_COLS(NS_COLS)
) column_selector_inst (
    .i_col_sel(i_col_sel),
    .i_data(data_col_sel),
    .o_data(o_data)
);

endmodule : event_array
