`timescale 1ns/1ps

module axi4lite_to_pcie_cfg_bridge #(
     
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32  
    )(
    // AXI4-Lite Interface
    input  logic        aclk,           
    input  logic        aresetn,        
    input  logic [ADDR_WIDTH-1:0] awaddr,         
    input  logic        awvalid,        
    output logic        awready,        
    input  logic [DATA_WIDTH-1:0] wdata,          
    input  logic [DATA_WIDTH/8-1:0]  wstrb,          
    input  logic        wvalid,         
    output logic        wready,         
    output logic [1:0]  bresp,          
    output logic        bvalid,         
    input  logic        bready,         
    input  logic [ADDR_WIDTH-1:0] araddr,
    input  logic        arvalid,
    output logic        arready,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic        rvalid,
    input  logic        rready,
    output logic [1:0]  rresp,

    // PCIe Configuration Space Interface
    output logic [ADDR_WIDTH-1:0]    pcie_cfg_addr,  
    output logic [DATA_WIDTH-1:0] pcie_cfg_wdata, 
    output logic        pcie_cfg_wr_en, 
    input  logic [DATA_WIDTH-1:0] pcie_cfg_rdata, 
    input  logic        pcie_cfg_rd_en  
);

    // FSM States
    typedef enum logic [1:0] {
        IDLE,
        WRITE_RESPONSE,
        READ_RESPONSE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    logic [ADDR_WIDTH-1:0] awaddr_reg;
    logic [ADDR_WIDTH-1:0] araddr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic [DATA_WIDTH/8-1:0] wstrb_reg;

    // FSM State Transition
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // FSM Next State Logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (awvalid && wvalid) begin
                    next_state = WRITE_RESPONSE;
                end else if (arvalid) begin
                    next_state = READ_RESPONSE;
                end
            end

            WRITE_RESPONSE: begin
                if (bready) begin
                    next_state = IDLE;
                end
            end

            READ_RESPONSE: begin
                if (rready) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // FSM Output Logic
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awready <= 1'b0;
            wready <= 1'b0;
            arready <= 1'b0;
            bvalid <= 1'b0;
            rvalid <= 1'b0;
            bresp <= 2'b00; // OKAY response
            rresp <= 2'b00; // OKAY response
            pcie_cfg_wr_en <= 1'b0;
            pcie_cfg_wdata <= '0;
            pcie_cfg_addr <= '0;
            rdata <= '0;
            awaddr_reg <= '0;
            araddr_reg <= '0;
            wdata_reg <= '0;
            wstrb_reg <= '0;
        end else begin
            // Defaults for one-cycle actions and handshake outputs.
            awready <= 1'b0;
            wready <= 1'b0;
            arready <= 1'b0;
            pcie_cfg_wr_en <= 1'b0;

            case (current_state)
                IDLE: begin
                    awready <= 1'b1;
                    wready <= 1'b1;
                    arready <= 1'b1;
                    bvalid <= 1'b0;
                    rvalid <= 1'b0;

                    if (awvalid && wvalid) begin
                        awaddr_reg <= awaddr;
                        wdata_reg <= wdata;
                        wstrb_reg <= wstrb;
                        pcie_cfg_addr <= awaddr;
                        bresp <= 2'b00;

                        // Apply strobe mask on written bytes.
                        for (int i = 0; i < (DATA_WIDTH/8); i++) begin
                            pcie_cfg_wdata[(i*8)+:8] <=
                                (wstrb[i]) ? wdata[(i*8)+:8] : pcie_cfg_rdata[(i*8)+:8];
                        end
                        pcie_cfg_wr_en <= 1'b1;
                    end else if (arvalid) begin
                        araddr_reg <= araddr;
                        pcie_cfg_addr <= araddr;
                        rdata <= pcie_cfg_rdata;
                        rresp <= 2'b00;
                    end
                end

                WRITE_RESPONSE: begin
                    bvalid <= 1'b1;
                    rvalid <= 1'b0;
                    // Keep address/data registers stable for observability.
                    awaddr_reg <= awaddr_reg;
                    wdata_reg <= wdata_reg;
                    wstrb_reg <= wstrb_reg;
                end

                READ_RESPONSE: begin
                    bvalid <= 1'b0;
                    rvalid <= 1'b1;
                    pcie_cfg_addr <= araddr_reg;
                    rdata <= pcie_cfg_rdata;
                end

                default: begin
                    bvalid <= 1'b0;
                    rvalid <= 1'b0;
                end
            endcase
        end
    end

endmodule
