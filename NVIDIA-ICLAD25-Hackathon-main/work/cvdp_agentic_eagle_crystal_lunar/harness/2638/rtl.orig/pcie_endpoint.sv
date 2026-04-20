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
        PCIE_IDLE,
        PCIE_RECEIVE,
        PCIE_PROCESS,
        PCIE_SEND_RESPONSE
    } pcie_state_t;

    typedef enum logic [1:0] {
        DLL_IDLE,
        DLL_TRANSMIT,
        DLL_WAIT_ACK,
        DLL_RETRY
    } dll_state_t;

    typedef enum logic [1:0] {
        DMA_IDLE,
        DMA_READ_DESC,
        DMA_FETCH_DATA,
        DMA_WRITE_DMA
    } dma_state_t;

    typedef enum logic {
        MSIX_IDLE,
        MSIX_GENERATE_INT
    } msix_state_t;

    pcie_state_t pcie_state;
    dll_state_t  dll_state;
    dma_state_t  dma_state;
    msix_state_t msix_state;

    logic [DATA_WIDTH-1:0] tlp_decoded_data;
    logic                  tlp_valid;
    logic [ADDR_WIDTH-1:0] dma_address;
    logic [DATA_WIDTH-1:0] dma_data;
    logic                  dma_start;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pcie_state       <= PCIE_IDLE;
            dll_state        <= DLL_IDLE;
            dma_state        <= DMA_IDLE;
            msix_state       <= MSIX_IDLE;
            pcie_rx_ready    <= 1'b1;
            pcie_tx_tlp      <= '0;
            pcie_tx_valid    <= 1'b0;
            dma_complete     <= 1'b0;
            msix_interrupt   <= 1'b0;
            tlp_decoded_data <= '0;
            tlp_valid        <= 1'b0;
            dma_address      <= '0;
            dma_data         <= '0;
            dma_start        <= 1'b0;
        end else begin
            // Default single-cycle pulses
            dma_complete   <= 1'b0;
            msix_interrupt <= 1'b0;
            dma_start      <= 1'b0;

            // PCIe transaction FSM
            case (pcie_state)
                PCIE_IDLE: begin
                    pcie_rx_ready <= 1'b1;
                    if (pcie_rx_valid) begin
                        pcie_state    <= PCIE_RECEIVE;
                        pcie_rx_ready <= 1'b0;
                    end
                end

                PCIE_RECEIVE: begin
                    tlp_decoded_data <= pcie_rx_tlp;
                    tlp_valid        <= 1'b1;
                    dma_address      <= pcie_rx_tlp[ADDR_WIDTH-1:0];
                    dma_data         <= pcie_rx_tlp;
                    pcie_state       <= PCIE_PROCESS;
                end

                PCIE_PROCESS: begin
                    pcie_state <= PCIE_SEND_RESPONSE;
                    if (dma_request) begin
                        dma_start <= 1'b1;
                    end
                end

                PCIE_SEND_RESPONSE: begin
                    if (dll_state == DLL_IDLE && tlp_valid) begin
                        pcie_tx_tlp <= tlp_decoded_data;
                        dll_state   <= DLL_TRANSMIT;
                    end
                    tlp_valid     <= 1'b0;
                    pcie_rx_ready <= 1'b1;
                    pcie_state    <= PCIE_IDLE;
                end

                default: pcie_state <= PCIE_IDLE;
            endcase

            // PCIe data-link FSM
            case (dll_state)
                DLL_IDLE: begin
                    pcie_tx_valid <= 1'b0;
                end

                DLL_TRANSMIT: begin
                    pcie_tx_valid <= 1'b1;
                    if (pcie_tx_ready) begin
                        dll_state <= DLL_WAIT_ACK;
                    end
                end

                DLL_WAIT_ACK: begin
                    pcie_tx_valid <= 1'b0;
                    dll_state     <= DLL_IDLE;
                end

                DLL_RETRY: begin
                    pcie_tx_valid <= 1'b1;
                    if (pcie_tx_ready) begin
                        dll_state <= DLL_WAIT_ACK;
                    end
                end

                default: dll_state <= DLL_IDLE;
            endcase

            // DMA FSM
            case (dma_state)
                DMA_IDLE: begin
                    if (dma_request || dma_start) begin
                        dma_state <= DMA_READ_DESC;
                    end
                end

                DMA_READ_DESC: begin
                    dma_state <= DMA_FETCH_DATA;
                end

                DMA_FETCH_DATA: begin
                    dma_state <= DMA_WRITE_DMA;
                end

                DMA_WRITE_DMA: begin
                    dma_complete <= 1'b1;
                    dma_state    <= DMA_IDLE;
                end

                default: dma_state <= DMA_IDLE;
            endcase

            // MSI-X FSM
            case (msix_state)
                MSIX_IDLE: begin
                    if (dma_complete) begin
                        msix_state <= MSIX_GENERATE_INT;
                    end
                end

                MSIX_GENERATE_INT: begin
                    msix_interrupt <= 1'b1;
                    msix_state     <= MSIX_IDLE;
                end

                default: msix_state <= MSIX_IDLE;
            endcase
        end
    end

endmodule
