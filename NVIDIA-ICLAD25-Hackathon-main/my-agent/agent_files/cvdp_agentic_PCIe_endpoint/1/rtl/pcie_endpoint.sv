`timescale 1ns/1ns

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
        RX_IDLE,
        RX_PROCESS,
        RX_SEND
    } rx_state_t;

    rx_state_t rx_state;

    logic [DATA_WIDTH-1:0] tlp_buffer;
    logic                  dma_pending;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state        <= RX_IDLE;
            pcie_rx_ready   <= 1'b1;
            pcie_tx_tlp     <= '0;
            pcie_tx_valid   <= 1'b0;
            tlp_buffer      <= '0;
            dma_pending     <= 1'b0;
            dma_complete    <= 1'b0;
            msix_interrupt  <= 1'b0;
        end else begin
            dma_complete   <= 1'b0;
            msix_interrupt <= 1'b0;

            case (rx_state)
                RX_IDLE: begin
                    pcie_rx_ready <= 1'b1;
                    pcie_tx_valid <= 1'b0;
                    if (pcie_rx_valid) begin
                        tlp_buffer    <= pcie_rx_tlp;
                        pcie_rx_ready <= 1'b0;
                        rx_state      <= RX_PROCESS;
                    end
                end

                RX_PROCESS: begin
                    pcie_tx_tlp   <= tlp_buffer;
                    pcie_tx_valid <= 1'b1;
                    rx_state      <= RX_SEND;
                end

                RX_SEND: begin
                    if (pcie_tx_valid && pcie_tx_ready) begin
                        pcie_tx_valid <= 1'b0;
                        pcie_rx_ready <= 1'b1;
                        rx_state      <= RX_IDLE;
                    end
                end

                default: begin
                    rx_state <= RX_IDLE;
                end
            endcase

            if (dma_request) begin
                dma_pending <= 1'b1;
            end

            if (dma_pending) begin
                dma_complete   <= 1'b1;
                msix_interrupt <= 1'b1;
                dma_pending    <= 1'b0;
            end
        end
    end

endmodule
