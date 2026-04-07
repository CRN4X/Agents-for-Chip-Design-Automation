module security_module #(
    parameter p_address_width = 8,
    parameter p_data_width    = 8,
    parameter p_unlock_code_0 = 8'hAB,
    parameter p_unlock_code_1 = 8'hCD
) (
    input  wire                           i_clk,
    input  wire                           i_rst,
    input  wire [p_address_width-1:0]     i_addr,
    input  wire [p_data_width-1:0]        i_data_in,
    input  wire                           i_read_write_enable,
    output reg                            o_secure_enable
);

localparam [1:0] LOCKED = 2'b00,
                 STAGE1 = 2'b01,
                 UNLOCK = 2'b10;

reg [1:0] state_ff;

always @(posedge i_clk or negedge i_rst) begin
    if (!i_rst) begin
        state_ff <= LOCKED;
        o_secure_enable <= 1'b0;
    end else begin
        if (!i_read_write_enable) begin
            case (state_ff)
                LOCKED: begin
                    if ((i_addr == {p_address_width{1'b0}}) && (i_data_in == p_unlock_code_0)) begin
                        state_ff <= STAGE1;
                        o_secure_enable <= 1'b0;
                    end else begin
                        state_ff <= LOCKED;
                        o_secure_enable <= 1'b0;
                    end
                end
                STAGE1: begin
                    if ((i_addr == {{(p_address_width-1){1'b0}},1'b1}) && (i_data_in == p_unlock_code_1)) begin
                        state_ff <= UNLOCK;
                        o_secure_enable <= 1'b1;
                    end else begin
                        state_ff <= LOCKED;
                        o_secure_enable <= 1'b0;
                    end
                end
                default: begin
                    if ((i_addr == {p_address_width{1'b0}}) && (i_data_in == p_unlock_code_0)) begin
                        state_ff <= STAGE1;
                        o_secure_enable <= 1'b0;
                    end else begin
                        state_ff <= LOCKED;
                        o_secure_enable <= 1'b0;
                    end
                end
            endcase
        end else begin
            o_secure_enable <= (state_ff == UNLOCK);
        end
    end
end

endmodule
