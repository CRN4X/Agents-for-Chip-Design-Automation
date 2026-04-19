module event_array #(
    parameter NS_ROWS = 'd4,
    parameter NS_COLS = 'd4,
    parameter NBW_COL = 'd2,
    parameter NBW_STR = 'd8,
    parameter NS_EVT  = 'd8,
    parameter NBW_EVT = 'd3
) (
    input  logic                           clk,
    input  logic                           rst_async_n,
    input  logic [NBW_COL-1:0]             i_col_sel,
    input  logic [(NS_ROWS*NS_COLS)-1:0]   i_en_overflow,
    input  logic [(NS_ROWS*NS_COLS*NS_EVT)-1:0] i_event,
    input  logic [(NS_COLS*NBW_STR)-1:0]   i_data,
    input  logic [NS_ROWS-1:0]             i_bypass,
    input  logic [NBW_EVT-1:0]             i_raddr,
    output logic [NBW_STR-1:0]             o_data
);

localparam int TOT_CELLS = NS_ROWS * NS_COLS;
localparam int TOT_EVT_W = TOT_CELLS * NS_EVT;

logic [(TOT_CELLS*NBW_STR)-1:0] data_pipe;
logic [(NS_COLS*NBW_STR)-1:0] data_col_sel;

generate
    for (genvar row = 0; row < NS_ROWS; row++) begin : gen_rows
        for (genvar col = 0; col < NS_COLS; col++) begin : gen_cols
            localparam int CELL_IDX = (row * NS_COLS) + col;
            localparam int EVT_MSB  = TOT_EVT_W - (CELL_IDX * NS_EVT) - 1;
            localparam int CUR_MSB  = (TOT_CELLS * NBW_STR) - (CELL_IDX * NBW_STR) - 1;
            localparam int IN_MSB   = (NS_COLS * NBW_STR) - (col * NBW_STR) - 1;
            localparam int PREV_IDX = ((row - 1) * NS_COLS) + col;
            localparam int PREV_MSB = (TOT_CELLS * NBW_STR) - (PREV_IDX * NBW_STR) - 1;

            if (row == 0) begin : gen_first_row
                event_storage #(
                    .NBW_STR(NBW_STR),
                    .NS_EVT(NS_EVT),
                    .NBW_EVT(NBW_EVT)
                ) u_event_storage (
                    .clk(clk),
                    .rst_async_n(rst_async_n),
                    .i_en_overflow(i_en_overflow[CELL_IDX]),
                    .i_event(i_event[EVT_MSB -: NS_EVT]),
                    .i_data(i_data[IN_MSB -: NBW_STR]),
                    .i_bypass(i_bypass[row]),
                    .i_raddr(i_raddr),
                    .o_data(data_pipe[CUR_MSB -: NBW_STR])
                );
            end else begin : gen_other_rows
                event_storage #(
                    .NBW_STR(NBW_STR),
                    .NS_EVT(NS_EVT),
                    .NBW_EVT(NBW_EVT)
                ) u_event_storage (
                    .clk(clk),
                    .rst_async_n(rst_async_n),
                    .i_en_overflow(i_en_overflow[CELL_IDX]),
                    .i_event(i_event[EVT_MSB -: NS_EVT]),
                    .i_data(data_pipe[PREV_MSB -: NBW_STR]),
                    .i_bypass(i_bypass[row]),
                    .i_raddr(i_raddr),
                    .o_data(data_pipe[CUR_MSB -: NBW_STR])
                );
            end
        end
    end

    for (genvar col = 0; col < NS_COLS; col++) begin : gen_output_pack
        localparam int LAST_ROW_IDX = ((NS_ROWS - 1) * NS_COLS) + col;
        localparam int LAST_ROW_MSB = (TOT_CELLS * NBW_STR) - (LAST_ROW_IDX * NBW_STR) - 1;
        localparam int OUT_MSB = (NS_COLS * NBW_STR) - (col * NBW_STR) - 1;
        assign data_col_sel[OUT_MSB -: NBW_STR] = data_pipe[LAST_ROW_MSB -: NBW_STR];
    end
endgenerate

column_selector #(
    .NBW_STR(NBW_STR),
    .NBW_COL(NBW_COL),
    .NS_COLS(NS_COLS)
) u_column_selector (
    .i_col_sel(i_col_sel),
    .i_data(data_col_sel),
    .o_data(o_data)
);

endmodule : event_array
