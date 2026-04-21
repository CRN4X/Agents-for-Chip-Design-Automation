`timescale 1ns/1ns

module event_array #(
    parameter NS_ROWS = 'd4,
    parameter NS_COLS = 'd4,
    parameter NBW_COL = 'd2,
    parameter NBW_STR = 'd8,
    parameter NS_EVT  = 'd8,
    parameter NBW_EVT = 'd3
) (
    input  logic                                 clk,
    input  logic                                 rst_async_n,
    input  logic [NBW_COL-1:0]                   i_col_sel,
    input  logic [(NS_ROWS*NS_COLS)-1:0]         i_en_overflow,
    input  logic [(NS_ROWS*NS_COLS*NS_EVT)-1:0]  i_event,
    input  logic [(NS_COLS*NBW_STR)-1:0]         i_data,
    input  logic [NS_ROWS-1:0]                   i_bypass,
    input  logic [NBW_EVT-1:0]                   i_raddr,
    output logic [NBW_STR-1:0]                   o_data
);

localparam int TOTAL_CELLS = NS_ROWS * NS_COLS;
logic [(TOTAL_CELLS*NBW_STR)-1:0] data_out_flat;
logic [(NS_COLS*NBW_STR)-1:0] data_col_sel;

generate
    for (genvar row = 0; row < NS_ROWS; row++) begin : gen_rows
        for (genvar col = 0; col < NS_COLS; col++) begin : gen_cols
            localparam int CELL_INDEX = row * NS_COLS + col;
            localparam int EVENT_MSB  = (TOTAL_CELLS*NS_EVT) - (CELL_INDEX*NS_EVT) - 1;
            localparam int OUT_MSB    = (TOTAL_CELLS*NBW_STR) - (CELL_INDEX*NBW_STR) - 1;

            if (row == 0) begin : first_row
                event_storage #(
                    .NBW_STR(NBW_STR),
                    .NS_EVT (NS_EVT),
                    .NBW_EVT(NBW_EVT)
                ) u_event_storage (
                    .clk          (clk),
                    .rst_async_n  (rst_async_n),
                    .i_en_overflow(i_en_overflow[CELL_INDEX]),
                    .i_event      (i_event[EVENT_MSB-:NS_EVT]),
                    .i_data       (i_data[(NS_COLS*NBW_STR)-col*NBW_STR-1-:NBW_STR]),
                    .i_bypass     (i_bypass[row]),
                    .i_raddr      (i_raddr),
                    .o_data       (data_out_flat[OUT_MSB-:NBW_STR])
                );
            end else begin : other_rows
                localparam int UP_CELL_INDEX = (row-1) * NS_COLS + col;
                localparam int UP_OUT_MSB    = (TOTAL_CELLS*NBW_STR) - (UP_CELL_INDEX*NBW_STR) - 1;

                event_storage #(
                    .NBW_STR(NBW_STR),
                    .NS_EVT (NS_EVT),
                    .NBW_EVT(NBW_EVT)
                ) u_event_storage (
                    .clk          (clk),
                    .rst_async_n  (rst_async_n),
                    .i_en_overflow(i_en_overflow[CELL_INDEX]),
                    .i_event      (i_event[EVENT_MSB-:NS_EVT]),
                    .i_data       (data_out_flat[UP_OUT_MSB-:NBW_STR]),
                    .i_bypass     (i_bypass[row]),
                    .i_raddr      (i_raddr),
                    .o_data       (data_out_flat[OUT_MSB-:NBW_STR])
                );
            end
        end
    end

    for (genvar col = 0; col < NS_COLS; col++) begin : gen_last_row_sel
        localparam int LAST_ROW_INDEX = (NS_ROWS-1) * NS_COLS + col;
        localparam int LAST_ROW_MSB   = (TOTAL_CELLS*NBW_STR) - (LAST_ROW_INDEX*NBW_STR) - 1;
        assign data_col_sel[(NS_COLS*NBW_STR)-col*NBW_STR-1-:NBW_STR] = data_out_flat[LAST_ROW_MSB-:NBW_STR];
    end
endgenerate

column_selector #(
    .NBW_STR(NBW_STR),
    .NBW_COL(NBW_COL),
    .NS_COLS(NS_COLS)
) u_column_selector (
    .i_col_sel(i_col_sel),
    .i_data   (data_col_sel),
    .o_data   (o_data)
);

endmodule : event_array
