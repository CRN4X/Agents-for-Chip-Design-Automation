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
    input  logic [NS_ROWS*NS_COLS-1:0]     i_en_overflow,
    input  logic [NS_ROWS*NS_COLS*NS_EVT-1:0] i_event,
    input  logic [NS_COLS*NBW_STR-1:0]     i_data,
    input  logic [NS_ROWS-1:0]             i_bypass,
    input  logic [NBW_EVT-1:0]             i_raddr,
    output logic [NBW_STR-1:0]             o_data
);

logic [NBW_STR-1:0] data_pipe [0:NS_ROWS][0:NS_COLS-1];
logic [NS_COLS*NBW_STR-1:0] data_col_sel;

generate
    for (genvar col = 0; col < NS_COLS; col++) begin : input_unpack
        assign data_pipe[0][col] = i_data[(NBW_STR*NS_COLS)-1-(col*NBW_STR)-:NBW_STR];
    end

    for (genvar row = 0; row < NS_ROWS; row++) begin : gen_rows
        for (genvar col = 0; col < NS_COLS; col++) begin : gen_cols
            localparam int CELL_IDX = (row * NS_COLS) + col;
            localparam int EVENT_MSB = (NS_ROWS * NS_COLS * NS_EVT) - 1 - (CELL_IDX * NS_EVT);

            event_storage #(
                .NBW_STR(NBW_STR),
                .NS_EVT(NS_EVT),
                .NBW_EVT(NBW_EVT)
            ) u_event_storage (
                .clk(clk),
                .rst_async_n(rst_async_n),
                .i_en_overflow(i_en_overflow[CELL_IDX]),
                .i_event(i_event[EVENT_MSB-:NS_EVT]),
                .i_data(data_pipe[row][col]),
                .i_bypass(i_bypass[row]),
                .i_raddr(i_raddr),
                .o_data(data_pipe[row+1][col])
            );
        end
    end

    for (genvar col = 0; col < NS_COLS; col++) begin : output_pack
        assign data_col_sel[(NBW_STR*NS_COLS)-1-(col*NBW_STR)-:NBW_STR] = data_pipe[NS_ROWS][col];
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
