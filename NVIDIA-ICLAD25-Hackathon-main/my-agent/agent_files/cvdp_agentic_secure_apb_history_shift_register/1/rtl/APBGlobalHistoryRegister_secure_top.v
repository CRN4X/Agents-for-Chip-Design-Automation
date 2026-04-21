`timescale 1ns/1ns

module APBGlobalHistoryRegister_secure_top  #(
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

    wire sec_unlocked_capture;
    reg  sec_sync_ff1;
    reg  sec_sync_ff2;
    wire sec_unlocked_pclk;

    wire apb_pready;
    wire [7:0] apb_prdata;
    wire apb_pslverr;
    wire apb_history_full;
    wire apb_history_empty;
    wire apb_error_flag;
    wire apb_interrupt_full;
    wire apb_interrupt_error;

    security_module #(
        .p_unlock_code_0(p_unlock_code_0),
        .p_unlock_code_1(p_unlock_code_1)
    ) u_security_module (
        .i_capture_pulse(i_capture_pulse),
        .presetn(presetn),
        .paddr(paddr),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .o_secure_enable(sec_unlocked_capture)
    );

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            sec_sync_ff1 <= 1'b0;
            sec_sync_ff2 <= 1'b0;
        end else begin
            sec_sync_ff1 <= sec_unlocked_capture;
            sec_sync_ff2 <= sec_sync_ff1;
        end
    end

    assign sec_unlocked_pclk = sec_sync_ff2;

    APBGlobalHistoryRegister u_apb_ghsr (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .pselx(pselx),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .history_shift_valid(history_shift_valid),
        .clk_gate_en(clk_gate_en),
        .i_secure_enable(sec_unlocked_pclk),
        .pready(apb_pready),
        .prdata(apb_prdata),
        .pslverr(apb_pslverr),
        .history_full(apb_history_full),
        .history_empty(apb_history_empty),
        .error_flag(apb_error_flag),
        .interrupt_full(apb_interrupt_full),
        .interrupt_error(apb_interrupt_error)
    );

    always @(*) begin
        pready          = apb_pready;
        prdata          = apb_prdata;
        pslverr         = apb_pslverr;
        history_full    = apb_history_full;
        history_empty   = apb_history_empty;
        error_flag      = apb_error_flag;
        interrupt_full  = apb_interrupt_full;
        interrupt_error = apb_interrupt_error;
    end

endmodule
