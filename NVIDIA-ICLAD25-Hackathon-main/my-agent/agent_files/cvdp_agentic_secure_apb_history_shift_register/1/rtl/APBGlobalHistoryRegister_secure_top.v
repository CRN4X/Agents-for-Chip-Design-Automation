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

    wire secure_enable_async;
    reg  secure_sync_ff1;
    reg  secure_sync_ff2;

    wire         core_pready;
    wire [7:0]   core_prdata;
    wire         core_pslverr;
    wire         core_history_full;
    wire         core_history_empty;
    wire         core_error_flag;
    wire         core_interrupt_full;
    wire         core_interrupt_error;

    security_module #(
        .p_unlock_code_0(p_unlock_code_0),
        .p_unlock_code_1(p_unlock_code_1)
    ) u_security_module (
        .i_capture_pulse(i_capture_pulse),
        .presetn(presetn),
        .paddr(paddr),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .secure_enable(secure_enable_async)
    );

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            secure_sync_ff1 <= 1'b0;
            secure_sync_ff2 <= 1'b0;
        end else begin
            secure_sync_ff1 <= secure_enable_async;
            secure_sync_ff2 <= secure_sync_ff1;
        end
    end

    APBGlobalHistoryRegister u_global_history (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .pselx(pselx),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .history_shift_valid(history_shift_valid),
        .clk_gate_en(clk_gate_en),
        .secure_enable(secure_sync_ff2),
        .pready(core_pready),
        .prdata(core_prdata),
        .pslverr(core_pslverr),
        .history_full(core_history_full),
        .history_empty(core_history_empty),
        .error_flag(core_error_flag),
        .interrupt_full(core_interrupt_full),
        .interrupt_error(core_interrupt_error)
    );

    always @(*) begin
        pready = core_pready;
        prdata = core_prdata;
        pslverr = core_pslverr;
        history_full = core_history_full;
        history_empty = core_history_empty;
        error_flag = core_error_flag;
        interrupt_full = core_interrupt_full;
        interrupt_error = core_interrupt_error;
    end

endmodule
