module saturation #(
   parameter NBW_IN  = 8,
   parameter NBW_OUT = 6
)
(
   input  logic [NBW_IN-1:0]  i_data,
   output logic [NBW_OUT-1:0] o_data
);

localparam NB_TRIM = NBW_IN - NBW_OUT;
localparam NB_REPL = NBW_OUT - 1;

    generate
        if (NB_TRIM == 1) begin
            always_comb begin : trim
                if (i_data[NBW_IN-1] == i_data[NBW_OUT-1]) begin //sat
                    o_data = $signed(i_data[NBW_OUT-1:0]);
                end else begin
                    o_data = $signed({i_data[NBW_IN-1],{NB_REPL{!i_data[NBW_IN-1]}}});
                end
            end

        end else if (NB_TRIM > 1) begin

            always_comb begin : trim
                if ({(NB_TRIM){i_data[NBW_IN-1]}} == i_data[NBW_IN-2:NBW_OUT-1]) begin //sat
                    o_data = $signed(i_data[NBW_OUT-1:0]);
                end else begin
                    o_data = $signed({i_data[NBW_IN-1],{NB_REPL{!i_data[NBW_IN-1]}}});
                end
            end

        end
    endgenerate


endmodule