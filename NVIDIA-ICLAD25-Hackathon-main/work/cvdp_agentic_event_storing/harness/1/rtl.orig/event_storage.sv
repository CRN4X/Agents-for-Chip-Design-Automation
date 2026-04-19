module event_storage #(
    parameter NBW_STR = 'd4,
    parameter NS_EVT  = 'd4,
    parameter NBW_EVT = 'd2
) (
    input  logic       clk,
    input  logic       rst_async_n,
    input  logic       i_en_overflow,
    input  logic [3:0] i_event,
    input  logic [3:0] i_data,
    input  logic       i_bypass,
    input  logic [1:0] i_raddr,
    output logic [3:0] o_data
);

// ----------------------------------------
// - Wires/Registers creation
// ----------------------------------------
logic [3:0] reg_bank [0:3];

// ----------------------------------------
// - Block logic
// ----------------------------------------
generate
    for (genvar i = 0; i < 4; i++) begin : instantiate_regs
        always_ff @ (posedge clk or negedge rst_async_n) begin
            if(!rst_async_n) begin
                reg_bank[i] <= 0;
            end else begin
                if(i_en_overflow) begin
                    reg_bank[i] <= reg_bank[i] + i_event[i];
                end else begin
                    if(reg_bank[i] == 4'd15) begin
                        reg_bank[i] <= reg_bank[i];
                    end else begin
                        reg_bank[i] <= reg_bank[i] + i_event[i];
                    end
                end
            end
        end
    end
endgenerate

// ----------------------------------------
// - Output assignment
// ----------------------------------------
always_comb begin : output_assignment
    if(i_bypass) begin
        o_data = i_data;
    end else begin
        o_data = reg_bank[i_raddr];
    end
end

endmodule : event_storage