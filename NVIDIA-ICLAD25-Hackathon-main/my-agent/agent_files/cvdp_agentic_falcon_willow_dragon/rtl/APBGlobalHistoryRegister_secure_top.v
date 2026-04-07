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

    wire apb_pready;
    wire [7:0] apb_prdata;
    wire apb_pslverr;
    wire apb_history_full;
    wire apb_history_empty;
    wire apb_error_flag;
    wire apb_interrupt_full;
    wire apb_interrupt_error;

    wire secure_enable_raw;
    reg secure_enable_sync1;
    reg secure_enable_sync2;

    wire history_shift_valid_secure;

    security_module #(
        .p_unlock_code_0(p_unlock_code_0),
        .p_unlock_code_1(p_unlock_code_1)
    ) u_security_module (
        .i_capture_pulse(i_capture_pulse),
        .presetn(presetn),
        .paddr(paddr),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .o_secure_enable(secure_enable_raw)
    );

    // Synchronize unlock status from capture-pulse domain into APB/control domain.
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            secure_enable_sync1 <= 1'b0;
            secure_enable_sync2 <= 1'b0;
        end else begin
            secure_enable_sync1 <= secure_enable_raw;
            secure_enable_sync2 <= secure_enable_sync1;
        end
    end

    assign history_shift_valid_secure = history_shift_valid & secure_enable_sync2;

    APBGlobalHistoryRegister u_apb_global_history_register (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .pselx(pselx),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .history_shift_valid(history_shift_valid_secure),
        .clk_gate_en(clk_gate_en),
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
        pready = apb_pready;
        prdata = apb_prdata;
        pslverr = apb_pslverr;
        history_full = apb_history_full;
        history_empty = apb_history_empty;
        error_flag = apb_error_flag;
        interrupt_full = apb_interrupt_full;
        interrupt_error = apb_interrupt_error;
    end

endmodule
