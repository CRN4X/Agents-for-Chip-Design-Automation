`timescale 1ns/1ns

module APBGlobalHistoryRegister_secure_top #(
    parameter p_unlock_code_0 = 8'hAB,
    parameter p_unlock_code_1 = 8'hCD
) (
    input  wire         pclk,
    input  wire         presetn,
    input  wire [9:0]   paddr,
    input  wire         pselx,
    input  wire         penable,
    input  wire         pwrite,
    input  wire [7:0]   pwdata,
    input  wire         history_shift_valid,
    input  wire         clk_gate_en,
    input  wire         i_capture_pulse,
    output reg          pready,
    output reg  [7:0]   prdata,
    output reg          pslverr,
    output reg          history_full,
    output reg          history_empty,
    output reg          error_flag,
    output reg          interrupt_full,
    output reg          interrupt_error
);

    wire security_unlocked_capture;
    reg  security_sync_ff1;
    reg  security_sync_ff2;

    wire        pready_w;
    wire [7:0]  prdata_w;
    wire        pslverr_w;
    wire        history_full_w;
    wire        history_empty_w;
    wire        error_flag_w;
    wire        interrupt_full_w;
    wire        interrupt_error_w;

    security_module #(
        .p_unlock_code_0(p_unlock_code_0),
        .p_unlock_code_1(p_unlock_code_1)
    ) u_security_module (
        .i_capture_pulse(i_capture_pulse),
        .presetn(presetn),
        .paddr(paddr),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .o_secure_enable(security_unlocked_capture)
    );

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            security_sync_ff1 <= 1'b0;
            security_sync_ff2 <= 1'b0;
        end else begin
            security_sync_ff1 <= security_unlocked_capture;
            security_sync_ff2 <= security_sync_ff1;
        end
    end

    APBGlobalHistoryRegister u_history_reg (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .pselx(pselx),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .history_shift_valid(history_shift_valid),
        .clk_gate_en(clk_gate_en),
        .secure_enable(security_sync_ff2),
        .pready(pready_w),
        .prdata(prdata_w),
        .pslverr(pslverr_w),
        .history_full(history_full_w),
        .history_empty(history_empty_w),
        .error_flag(error_flag_w),
        .interrupt_full(interrupt_full_w),
        .interrupt_error(interrupt_error_w)
    );

    always @(*) begin
        pready          = pready_w;
        prdata          = prdata_w;
        pslverr         = pslverr_w;
        history_full    = history_full_w;
        history_empty   = history_empty_w;
        error_flag      = error_flag_w;
        interrupt_full  = interrupt_full_w;
        interrupt_error = interrupt_error_w;
    end

endmodule
