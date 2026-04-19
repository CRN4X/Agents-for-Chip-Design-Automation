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

localparam integer NUM_CELLS = NS_ROWS * NS_COLS;

logic [(NUM_CELLS*NBW_STR)-1:0] cell_data_out_flat;
logic [(NS_COLS*NBW_STR)-1:0]   data_col_sel;

generate
    for (genvar row = 0; row < NS_ROWS; row++) begin : gen_rows
        for (genvar col = 0; col < NS_COLS; col++) begin : gen_cols
            localparam integer CELL_IDX = (row * NS_COLS) + col;
            localparam integer EVT_LSB  = (NUM_CELLS - 1 - CELL_IDX) * NS_EVT;

            logic [NBW_STR-1:0] cell_data_in;
            logic [NBW_STR-1:0] cell_data_out;
            logic [NS_EVT-1:0]  cell_event;

            assign cell_event = i_event[EVT_LSB +: NS_EVT];

            if (row == (NS_ROWS-1)) begin : gen_top_input
                assign cell_data_in = i_data[((NS_COLS-col)*NBW_STR)-1 -: NBW_STR];
            end else begin : gen_row_chain
                assign cell_data_in = cell_data_out_flat[((((row+1)*NS_COLS)+col)+1)*NBW_STR-1 -: NBW_STR];
            end

            assign cell_data_out_flat[(CELL_IDX+1)*NBW_STR-1 -: NBW_STR] = cell_data_out;

            event_storage #(
                .NBW_STR(NBW_STR),
                .NS_EVT(NS_EVT),
                .NBW_EVT(NBW_EVT)
            ) u_event_storage (
                .clk(clk),
                .rst_async_n(rst_async_n),
                .i_en_overflow(i_en_overflow[CELL_IDX]),
                .i_event(cell_event),
                .i_data(cell_data_in),
                .i_bypass(i_bypass[row]),
                .i_raddr(i_raddr),
                .o_data(cell_data_out)
            );
        end
    end
endgenerate

generate
    for (genvar col = 0; col < NS_COLS; col++) begin : gen_data_col_sel
        assign data_col_sel[((NS_COLS-col)*NBW_STR)-1 -: NBW_STR] =
            cell_data_out_flat[((col+1)*NBW_STR)-1 -: NBW_STR];
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
