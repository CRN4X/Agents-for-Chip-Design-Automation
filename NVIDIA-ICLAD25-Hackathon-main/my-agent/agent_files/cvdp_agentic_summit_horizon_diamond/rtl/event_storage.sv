module event_storage #(
    parameter NBW_STR = 'd4,
    parameter NS_EVT  = 'd4,
    parameter NBW_EVT = 'd2
) (
    input  logic                 clk,
    input  logic                 rst_async_n,
    input  logic                 i_en_overflow,
    input  logic [NS_EVT-1:0]    i_event,
    input  logic [NBW_STR-1:0]   i_data,
    input  logic                 i_bypass,
    input  logic [NBW_EVT-1:0]   i_raddr,
    output logic [NBW_STR-1:0]   o_data
);

logic [NBW_STR-1:0] reg_bank [0:NS_EVT-1];

generate
    for (genvar i = 0; i < NS_EVT; i++) begin : instantiate_regs
        always_ff @ (posedge clk or negedge rst_async_n) begin
            if(!rst_async_n) begin
                reg_bank[i] <= '0;
            end else begin
                if(i_en_overflow) begin
                    reg_bank[i] <= reg_bank[i] + i_event[i];
                end else begin
                    if(reg_bank[i] == {NBW_STR{1'b1}}) begin
                        reg_bank[i] <= reg_bank[i];
                    end else begin
                        reg_bank[i] <= reg_bank[i] + i_event[i];
                    end
                end
            end
        end
    end
endgenerate

always_comb begin : output_assignment
    if(i_bypass) begin
        o_data = i_data;
    end else begin
        o_data = reg_bank[i_raddr];
    end
end

endmodule : event_storage
