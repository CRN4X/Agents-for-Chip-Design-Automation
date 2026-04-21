`timescale 1ns/1ns

module csr_apb_interface (
    input  logic        pclk,
    input  logic        presetn,
    input  logic        pselx,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic        overflow_is,
    input  logic        sign_is,
    input  logic        parity_is,
    input  logic        zero_is,
    output logic [31:0] prdata,
    output logic        pslverr,
    output logic [1:0]  fsm_state_dbg
);

    localparam logic [31:0] DATA_REG_ADDR      = 32'h10;
    localparam logic [31:0] CONTROL_REG_ADDR   = 32'h14;
    localparam logic [31:0] INTERRUPT_REG_ADDR = 32'h18;
    localparam logic [31:0] ISR_REG_ADDR       = 32'h1C;

    typedef enum logic [1:0] {
        IDLE        = 2'd0,
        SETUP       = 2'd1,
        READ_STATE  = 2'd2,
        WRITE_STATE = 2'd3
    } state_t;

    state_t state;

    logic [31:0] data_reg;
    logic [31:0] control_reg;
    logic [31:0] interrupt_reg;
    logic [31:0] isr_reg;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            state         <= IDLE;
            data_reg      <= 32'd0;
            control_reg   <= 32'd0;
            interrupt_reg <= 32'd0;
            isr_reg       <= 32'd0;
            prdata        <= 32'd0;
            pslverr       <= 1'b0;
        end else begin
            // Latch incoming status flags, but ignore X/Z inputs.
            if (overflow_is === 1'b1) isr_reg[0] <= 1'b1;
            if (sign_is     === 1'b1) isr_reg[1] <= 1'b1;
            if (parity_is   === 1'b1) isr_reg[2] <= 1'b1;
            if (zero_is     === 1'b1) isr_reg[3] <= 1'b1;

            // FSM progression for debug/observability.
            case (state)
                IDLE: begin
                    if (pselx && !penable) begin
                        state <= SETUP;
                    end
                end
                SETUP: begin
                    if (pselx && penable) begin
                        if (pwrite) begin
                            state <= WRITE_STATE;
                        end else begin
                            state <= READ_STATE;
                        end
                    end else if (!pselx) begin
                        state <= IDLE;
                    end
                end
                READ_STATE,
                WRITE_STATE: begin
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase

            // APB ACCESS phase action.
            if (pselx && penable) begin
                if (pwrite) begin
                    unique case (paddr)
                        DATA_REG_ADDR: begin
                            data_reg <= pwdata;
                        end
                        CONTROL_REG_ADDR: begin
                            control_reg <= pwdata;
                        end
                        INTERRUPT_REG_ADDR: begin
                            interrupt_reg <= pwdata;
                            isr_reg[3:0] <= isr_reg[3:0] & ~pwdata[3:0];
                        end
                        ISR_REG_ADDR: begin
                            pslverr <= 1'b1;
                        end
                        default: begin
                            pslverr <= 1'b1;
                        end
                    endcase
                end else begin
                    unique case (paddr)
                        DATA_REG_ADDR:      prdata <= data_reg;
                        CONTROL_REG_ADDR:   prdata <= control_reg;
                        INTERRUPT_REG_ADDR: prdata <= interrupt_reg;
                        ISR_REG_ADDR:       prdata <= isr_reg;
                        default: begin
                            prdata  <= 32'd0;
                            pslverr <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end

    assign fsm_state_dbg = state;

endmodule
