module csr_apb_interface (
    input  wire        pclk,
    input  wire        presetn,
    input  wire        pselx,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output reg         pslverr,
    output reg  [1:0]  fsm_state_dbg
);

    localparam [31:0] DATA_REG_ADDR      = 32'h10;
    localparam [31:0] CONTROL_REG_ADDR   = 32'h14;
    localparam [31:0] INTERRUPT_REG_ADDR = 32'h18;
    localparam [31:0] ISR_REG_ADDR       = 32'h1C;

    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] SETUP      = 2'd1;
    localparam [1:0] READ_STATE = 2'd2;
    localparam [1:0] WRITE_STATE= 2'd3;

    reg [1:0] state;
    reg [1:0] next_state;

    reg [31:0] data_reg;
    reg [31:0] control_reg;
    reg [31:0] interrupt_reg;
    reg [31:0] isr_reg;

    wire apb_setup;
    wire apb_access;

    assign apb_setup  = pselx & ~penable;
    assign apb_access = pselx & penable;

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (pselx) begin
                    next_state = SETUP;
                end
            end
            SETUP: begin
                if (apb_access) begin
                    if (pwrite) begin
                        next_state = WRITE_STATE;
                    end else begin
                        next_state = READ_STATE;
                    end
                end
            end
            READ_STATE: begin
                next_state = IDLE;
            end
            WRITE_STATE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            state          <= IDLE;
            fsm_state_dbg  <= IDLE;
            data_reg       <= 32'h0;
            control_reg    <= 32'h0;
            interrupt_reg  <= 32'h0;
            isr_reg        <= 32'h0;
            prdata         <= 32'h0;
            pslverr        <= 1'b0;
        end else begin
            state         <= next_state;
            fsm_state_dbg <= next_state;

            if (apb_access) begin
                if (pwrite) begin
                    case (paddr)
                        DATA_REG_ADDR: begin
                            data_reg <= pwdata;
                        end
                        CONTROL_REG_ADDR: begin
                            control_reg <= pwdata;
                        end
                        INTERRUPT_REG_ADDR: begin
                            interrupt_reg <= pwdata;
                            // Writing 1 clears corresponding ISR flag bits.
                            isr_reg[3:0] <= isr_reg[3:0] & ~pwdata[3:0];
                        end
                        ISR_REG_ADDR: begin
                            // Write-protected register.
                            pslverr <= 1'b1;
                        end
                        default: begin
                            // No action for undefined addresses.
                        end
                    endcase
                end else begin
                    case (paddr)
                        DATA_REG_ADDR: begin
                            prdata <= data_reg;
                        end
                        CONTROL_REG_ADDR: begin
                            prdata <= control_reg;
                        end
                        INTERRUPT_REG_ADDR: begin
                            prdata <= interrupt_reg;
                        end
                        ISR_REG_ADDR: begin
                            prdata <= isr_reg;
                        end
                        default: begin
                            prdata <= 32'h0;
                        end
                    endcase
                end
            end
        end
    end

endmodule
