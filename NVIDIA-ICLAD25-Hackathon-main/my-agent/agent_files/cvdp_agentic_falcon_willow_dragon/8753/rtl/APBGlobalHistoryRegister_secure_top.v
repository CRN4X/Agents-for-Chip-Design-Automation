module APBGlobalHistoryRegister_secure_top #(
    parameter p_unlock_code_0 = 8'hAB,
    parameter p_unlock_code_1 = 8'hCD
) (
    input  wire       pclk,
    input  wire       presetn,
    input  wire [9:0] paddr,
    input  wire       pselx,
    input  wire       penable,
    input  wire       pwrite,
    input  wire [7:0] pwdata,
    input  wire       history_shift_valid,
    input  wire       clk_gate_en,
    input  wire       i_capture_pulse,
    output reg        pready,
    output reg [7:0]  prdata,
    output reg        pslverr,
    output reg        history_full,
    output reg        history_empty,
    output reg        error_flag,
    output reg        interrupt_full,
    output reg        interrupt_error
);

    wire secure_enable_capture;
    reg  secure_sync_ff1;
    reg  secure_sync_ff2;
    wire secure_enable_pclk;

    wire apb_pready;
    wire [7:0] apb_prdata;
    wire apb_pslverr;
    wire apb_history_full;
    wire apb_history_empty;
    wire apb_error_flag;
    wire apb_interrupt_full;
    wire apb_interrupt_error;

    wire pselx_secure;
    wire penable_secure;
    wire history_shift_valid_secure;

    assign secure_enable_pclk       = secure_sync_ff2;
    assign pselx_secure             = pselx & secure_enable_pclk;
    assign penable_secure           = penable & secure_enable_pclk;
    assign history_shift_valid_secure = history_shift_valid & secure_enable_pclk;

    security_module #(
        .p_unlock_code_0(p_unlock_code_0),
        .p_unlock_code_1(p_unlock_code_1)
    ) u_security_module (
        .i_capture_pulse(i_capture_pulse),
        .presetn(presetn),
        .paddr(paddr),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .secure_enable(secure_enable_capture)
    );

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            secure_sync_ff1 <= 1'b0;
            secure_sync_ff2 <= 1'b0;
        end else begin
            secure_sync_ff1 <= secure_enable_capture;
            secure_sync_ff2 <= secure_sync_ff1;
        end
    end

    APBGlobalHistoryRegister u_apb_global_history_register (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .pselx(pselx_secure),
        .penable(penable_secure),
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
