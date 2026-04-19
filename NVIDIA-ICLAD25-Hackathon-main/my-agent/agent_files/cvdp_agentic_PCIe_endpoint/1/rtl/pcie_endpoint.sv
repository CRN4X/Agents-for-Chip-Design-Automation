module pcie_endpoint #(
    parameter int ADDR_WIDTH = 64,
    parameter int DATA_WIDTH = 128
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [DATA_WIDTH-1:0] pcie_rx_tlp,
    input  logic                  pcie_rx_valid,
    output logic                  pcie_rx_ready,
    output logic [DATA_WIDTH-1:0] pcie_tx_tlp,
    output logic                  pcie_tx_valid,
    input  logic                  pcie_tx_ready,
    input  logic                  dma_request,
    output logic                  dma_complete,
    output logic                  msix_interrupt
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_PROCESS,
        ST_TX
    } pcie_state_t;

    pcie_state_t state_q, state_d;

    logic [DATA_WIDTH-1:0] tlp_data_q, tlp_data_d;
    logic                  dma_complete_d;
    logic                  msix_interrupt_d;

    always_comb begin
        state_d         = state_q;
        tlp_data_d      = tlp_data_q;
        dma_complete_d  = 1'b0;
        msix_interrupt_d = 1'b0;

        pcie_rx_ready   = 1'b0;
        pcie_tx_valid   = 1'b0;
        pcie_tx_tlp     = tlp_data_q;

        case (state_q)
            ST_IDLE: begin
                pcie_rx_ready = 1'b1;
                if (pcie_rx_valid) begin
                    tlp_data_d = pcie_rx_tlp;
                    state_d    = ST_PROCESS;
                end
            end

            ST_PROCESS: begin
                // Model a one-cycle processing stage before response transmit.
                state_d = ST_TX;
            end

            ST_TX: begin
                pcie_tx_valid = 1'b1;
                pcie_tx_tlp   = tlp_data_q;
                if (pcie_tx_ready) begin
                    state_d = ST_IDLE;
                end
            end

            default: begin
                state_d = ST_IDLE;
            end
        endcase

        // Simple DMA/MSI-X behavior matching the requested interface semantics.
        if (dma_request) begin
            dma_complete_d   = 1'b1;
            msix_interrupt_d = 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q         <= ST_IDLE;
            tlp_data_q      <= '0;
            dma_complete    <= 1'b0;
            msix_interrupt  <= 1'b0;
        end else begin
            state_q         <= state_d;
            tlp_data_q      <= tlp_data_d;
            dma_complete    <= dma_complete_d;
            msix_interrupt  <= msix_interrupt_d;
        end
    end

endmodule
