`timescale 1ns/1ns

module security_module #(
    parameter p_address_width = 8,
    parameter p_data_width = 8,
    parameter p_unlock_code_0 = 8'hAB,
    parameter p_unlock_code_1 = 8'hCD
) (
    input wire i_capture_pulse,
    input wire i_rst,
    input wire [p_address_width-1:0] i_addr,
    input wire [p_data_width-1:0] i_data_in,
    input wire i_read_write_enable,
    output reg o_secure_enable
);

localparam [1:0] S_LOCKED = 2'b00,
                 S_STEP1_OK = 2'b01,
                 S_UNLOCKED = 2'b10;

reg [1:0] state;

wire write_en;
assign write_en = (i_read_write_enable == 1'b0);

always @(posedge i_capture_pulse or negedge i_rst) begin
    if (!i_rst) begin
        state <= S_LOCKED;
        o_secure_enable <= 1'b0;
    end else begin
        case (state)
            S_LOCKED: begin
                o_secure_enable <= 1'b0;
                if (write_en &&
                    (i_addr == { {(p_address_width-1){1'b0}}, 1'b0 }) &&
                    (i_data_in == p_unlock_code_0)) begin
                    state <= S_STEP1_OK;
                end else begin
                    state <= S_LOCKED;
                end
            end

            S_STEP1_OK: begin
                o_secure_enable <= 1'b0;
                if (write_en &&
                    (i_addr == { {(p_address_width-1){1'b0}}, 1'b1 }) &&
                    (i_data_in == p_unlock_code_1)) begin
                    state <= S_UNLOCKED;
                    o_secure_enable <= 1'b1;
                end else begin
                    state <= S_LOCKED;
                end
            end

            S_UNLOCKED: begin
                state <= S_UNLOCKED;
                o_secure_enable <= 1'b1;
            end

            default: begin
                state <= S_LOCKED;
                o_secure_enable <= 1'b0;
            end
        endcase
    end
end

endmodule
