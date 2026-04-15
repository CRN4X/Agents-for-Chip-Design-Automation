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

    // PCIe Configuration Space Interface
    output logic [ADDR_WIDTH/4-1:0]  pcie_cfg_addr,  
    output logic [DATA_WIDTH-1:0] pcie_cfg_wdata, 
    output logic        pcie_cfg_wr_en, 
    input  logic [DATA_WIDTH-1:0] pcie_cfg_rdata, 
    input  logic        pcie_cfg_rd_en  
);

    // FSM States
    typedef enum logic [2:0] {
        IDLE,           
        ADDR_CAPTURE,  
        DATA_CAPTURE,  
        PCIE_WRITE,    
        SEND_RESPONSE  
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    logic [ADDR_WIDTH-1:0] awaddr_reg;  
    logic [DATA_WIDTH-1:0] wdata_reg;   
    logic [DATA_WIDTH/8-1:0]  wstrb_reg;   

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
                    next_state = ADDR_CAPTURE;
                end
            end

            ADDR_CAPTURE: begin
                next_state = DATA_CAPTURE;
            end

            DATA_CAPTURE: begin
                next_state = PCIE_WRITE;
            end

            PCIE_WRITE: begin
                next_state = SEND_RESPONSE;
            end

            SEND_RESPONSE: begin
                if (bready) begin
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
            bvalid <= 1'b0;
            bresp <= 2'b00; // OKAY response
            pcie_cfg_wr_en <= 1'b0;
            pcie_cfg_wdata <= 32'h0;
            pcie_cfg_addr <= 8'h0;
            awaddr_reg <= 32'h0;
            wdata_reg <= 32'h0;
            wstrb_reg <= 4'h0;
        end else begin
            case (current_state)
                IDLE: begin
                    awready <= 1'b0;
                    wready <= 1'b0;
                    bvalid <= 1'b0;
                    pcie_cfg_wr_en <= 1'b0;
                end

                ADDR_CAPTURE: begin
                    awready <= 1'b1;
                    awaddr_reg <= awaddr;
                end

                DATA_CAPTURE: begin
                    wready <= 1'b1;
                    wdata_reg <= wdata;
                    wstrb_reg <= wstrb;
                end

                PCIE_WRITE: begin
                    pcie_cfg_wr_en <= 1'b1;
                    pcie_cfg_addr <= awaddr_reg[7:0]; // 8-bit PCIe address

                    // Apply wstrb to write only the selected bytes
                    for (int i = 0; i < (DATA_WIDTH/8); i++) begin
                        pcie_cfg_wdata[(i*8)+:8] <= (wstrb_reg[i]) ? wdata_reg[(i*8)+:8] : pcie_cfg_rdata[(i*8)+:8];
                    end
                end
                
                SEND_RESPONSE: begin
                    pcie_cfg_wr_en <= 1'b0;
                    bvalid <= 1'b1;
                end

                default: begin
                    // Default outputs
                end
            endcase
        end
    end

endmodule