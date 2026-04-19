module security_module #(
    parameter p_unlock_code_0 = 8'hAB,
    parameter p_unlock_code_1 = 8'hCD
) (
    input  wire       i_capture_pulse,
    input  wire       presetn,
    input  wire [9:0] paddr,
    input  wire       pwrite,
    input  wire [7:0] pwdata,
    output reg        secure_enable
);

    localparam [1:0] ST_LOCKED   = 2'b00;
    localparam [1:0] ST_STAGE1   = 2'b01;
    localparam [1:0] ST_UNLOCKED = 2'b10;

    reg [1:0] state_d;
    reg [1:0] state_q;

    always @(*) begin
        state_d = state_q;
        case (state_q)
            ST_LOCKED: begin
                if (pwrite) begin
                    if ((paddr == 10'd0) && (pwdata == p_unlock_code_0)) begin
                        state_d = ST_STAGE1;
                    end else begin
                        state_d = ST_LOCKED;
                    end
                end
            end

            ST_STAGE1: begin
                if (pwrite) begin
                    if ((paddr == 10'd1) && (pwdata == p_unlock_code_1)) begin
                        state_d = ST_UNLOCKED;
                    end else begin
                        state_d = ST_LOCKED;
                    end
                end
            end

            ST_UNLOCKED: begin
                state_d = ST_UNLOCKED;
            end

            default: begin
                state_d = ST_LOCKED;
            end
        endcase
    end

    always @(posedge i_capture_pulse or negedge presetn) begin
        if (!presetn) begin
            state_q <= ST_LOCKED;
        end else begin
            state_q <= state_d;
        end
    end

    always @(*) begin
        secure_enable = (state_q == ST_UNLOCKED);
    end

endmodule
