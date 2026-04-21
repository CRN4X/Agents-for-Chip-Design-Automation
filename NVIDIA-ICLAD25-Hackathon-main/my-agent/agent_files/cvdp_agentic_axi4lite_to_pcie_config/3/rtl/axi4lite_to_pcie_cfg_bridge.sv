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
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready,

    // PCIe Configuration Space Interface
    output logic [ADDR_WIDTH-1:0]  pcie_cfg_addr,  
    output logic [DATA_WIDTH-1:0] pcie_cfg_wdata, 
    output logic        pcie_cfg_wr_en, 
    input  logic [DATA_WIDTH-1:0] pcie_cfg_rdata, 
    input  logic        pcie_cfg_rd_en  
);

    // FSM States
    typedef enum logic [1:0] {
        IDLE,
        WRITE_RESP,
        READ_RESP
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    logic [DATA_WIDTH-1:0] write_data_masked;
    integer i;

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
                    next_state = WRITE_RESP;
                end else if (arvalid) begin
                    next_state = READ_RESP;
                end
            end

            WRITE_RESP: begin
                if (bready) begin
                    next_state = IDLE;
                end
            end

            READ_RESP: begin
                if (rready) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // FSM output and datapath logic
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awready <= 1'b0;
            wready <= 1'b0;
            bvalid <= 1'b0;
            bresp <= 2'b00;
            arready <= 1'b0;
            rvalid <= 1'b0;
            rresp <= 2'b00;
            rdata <= {DATA_WIDTH{1'b0}};
            pcie_cfg_wr_en <= 1'b0;
            pcie_cfg_wdata <= {DATA_WIDTH{1'b0}};
            pcie_cfg_addr <= {ADDR_WIDTH{1'b0}};
        end else begin
            // Default deassertions for one-cycle handshake pulses
            awready <= 1'b0;
            wready <= 1'b0;
            arready <= 1'b0;
            pcie_cfg_wr_en <= 1'b0;

            case (current_state)
                IDLE: begin
                    bvalid <= 1'b0;
                    rvalid <= 1'b0;

                    if (awvalid && wvalid) begin
                        awready <= 1'b1;
                        wready <= 1'b1;
                        pcie_cfg_wr_en <= 1'b1;
                        pcie_cfg_addr <= awaddr;

                        write_data_masked = pcie_cfg_rdata;
                        for (i = 0; i < (DATA_WIDTH/8); i = i + 1) begin
                            if (wstrb[i]) begin
                                write_data_masked[(i*8)+:8] = wdata[(i*8)+:8];
                            end
                        end
                        pcie_cfg_wdata <= write_data_masked;
                    end else if (arvalid) begin
                        arready <= 1'b1;
                        pcie_cfg_addr <= araddr;
                    end
                end

                WRITE_RESP: begin
                    bvalid <= 1'b1;
                end

                READ_RESP: begin
                    rvalid <= 1'b1;
                    rresp <= 2'b00;
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
