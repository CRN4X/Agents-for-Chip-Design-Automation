module csr_apb_interface(
    input  wire        pclk,
    input  wire        presetn,
    input  wire        pselx,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output reg         pslverr,
    output reg  [1:0]  dbg_state
);
    localparam IDLE       = 2'd0;
    localparam SETUP      = 2'd1;
    localparam READ_STATE = 2'd2;
    localparam WRITE_STATE= 2'd3;

    localparam DATA_REG      = 32'h10;
    localparam CONTROL_REG   = 32'h14;
    localparam INTERRUPT_REG = 32'h18;
    localparam ISR_REG       = 32'h1C;

    reg [31:0] data_reg;
    reg [31:0] control_reg;
    reg [31:0] interrupt_reg;
    reg [31:0] isr_reg;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            data_reg    <= 32'h0;
            control_reg <= 32'h0;
            interrupt_reg <= 32'h0;
            isr_reg     <= 32'h0;
            prdata      <= 32'h0;
            pslverr     <= 1'b0;
            dbg_state   <= IDLE;
        end else begin
            dbg_state <= IDLE;

            if (pselx && !penable) begin
                dbg_state <= SETUP;
            end

            if (pselx && penable) begin
                if (pwrite) begin
                    dbg_state <= WRITE_STATE;
                    case (paddr)
                        DATA_REG: data_reg <= pwdata;
                        CONTROL_REG: control_reg <= pwdata;
                        INTERRUPT_REG: begin
                            interrupt_reg <= pwdata;
                            isr_reg <= isr_reg & ~pwdata;
                        end
                        ISR_REG: pslverr <= 1'b1;  // write protected
                        default: begin
                        end
                    endcase
                end else begin
                    dbg_state <= READ_STATE;
                    case (paddr)
                        DATA_REG: prdata <= data_reg;
                        CONTROL_REG: prdata <= control_reg;
                        INTERRUPT_REG: prdata <= interrupt_reg;
                        ISR_REG: prdata <= isr_reg;
                        default: prdata <= 32'h0;
                    endcase
                end
            end
        end
    end
endmodule
