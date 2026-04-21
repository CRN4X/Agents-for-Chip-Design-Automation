`timescale 1ns/1ns

module security_module #(
    parameter p_unlock_code_0 = 8'hAB,
    parameter p_unlock_code_1 = 8'hCD
) (
    input  wire       i_capture_pulse,
    input  wire       presetn,
    input  wire [9:0] paddr,
    input  wire       pwrite,
    input  wire [7:0] pwdata,
    output reg        o_secure_enable
);

    localparam ST_LOCKED   = 2'd0;
    localparam ST_STAGE1   = 2'd1;
    localparam ST_UNLOCKED = 2'd2;

    reg [1:0] r_state;

    always @(posedge i_capture_pulse or negedge presetn) begin
        if (!presetn) begin
            r_state          <= ST_LOCKED;
            o_secure_enable  <= 1'b0;
        end else begin
            case (r_state)
                ST_LOCKED: begin
                    if (pwrite && (paddr == 10'd0) && (pwdata == p_unlock_code_0)) begin
                        r_state <= ST_STAGE1;
                    end else begin
                        r_state <= ST_LOCKED;
                    end
                    o_secure_enable <= 1'b0;
                end

                ST_STAGE1: begin
                    if (pwrite && (paddr == 10'd1) && (pwdata == p_unlock_code_1)) begin
                        r_state <= ST_UNLOCKED;
                        o_secure_enable <= 1'b1;
                    end else begin
                        r_state <= ST_LOCKED;
                        o_secure_enable <= 1'b0;
                    end
                end

                default: begin
                    r_state <= ST_UNLOCKED;
                    o_secure_enable <= 1'b1;
                end
            endcase
        end
    end

endmodule
