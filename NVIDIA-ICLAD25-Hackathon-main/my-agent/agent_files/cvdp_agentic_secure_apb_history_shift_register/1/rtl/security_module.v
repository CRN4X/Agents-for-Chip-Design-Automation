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

    localparam [1:0] S_LOCKED  = 2'b00;
    localparam [1:0] S_STEP1   = 2'b01;
    localparam [1:0] S_UNLOCK  = 2'b10;

    reg [1:0] state;

    always @(posedge i_capture_pulse or negedge presetn) begin
        if (!presetn) begin
            state <= S_LOCKED;
            secure_enable <= 1'b0;
        end else begin
            case (state)
                S_LOCKED: begin
                    if (pwrite && (paddr == 10'd0) && (pwdata == p_unlock_code_0)) begin
                        state <= S_STEP1;
                    end else begin
                        state <= S_LOCKED;
                    end
                    secure_enable <= 1'b0;
                end

                S_STEP1: begin
                    if (pwrite && (paddr == 10'd1) && (pwdata == p_unlock_code_1)) begin
                        state <= S_UNLOCK;
                        secure_enable <= 1'b1;
                    end else if (pwrite) begin
                        state <= S_LOCKED;
                        secure_enable <= 1'b0;
                    end else begin
                        state <= S_STEP1;
                        secure_enable <= 1'b0;
                    end
                end

                S_UNLOCK: begin
                    state <= S_UNLOCK;
                    secure_enable <= 1'b1;
                end

                default: begin
                    state <= S_LOCKED;
                    secure_enable <= 1'b0;
                end
            endcase
        end
    end

endmodule
