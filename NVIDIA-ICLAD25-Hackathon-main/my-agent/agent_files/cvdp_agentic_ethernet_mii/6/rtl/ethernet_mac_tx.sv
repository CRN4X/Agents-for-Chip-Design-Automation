`timescale 1ns/1ns

module ethernet_mac_tx
(
    input            clk_in,
    input            rst_in,
    input            cfg_wr_in,
    input  [31:0]    cfg_addr_in,
    input  [31:0]    cfg_data_wr_in,
    output reg [31:0] cfg_data_rd_out,
    output reg       interrupt_out,
    output reg       axis_tvalid_out,
    output reg [31:0] axis_tdata_out,
    output reg [3:0] axis_tstrb_out,
    output reg       axis_tlast_out,
    input            axis_tready_in
);

    localparam [15:0] ADDR_TX_LEN  = 16'h07F4;
    localparam [15:0] ADDR_IRQ_EN  = 16'h07F8;
    localparam [15:0] ADDR_TX_CTRL = 16'h07FC;

    localparam [2:0] ST_IDLE      = 3'd0;
    localparam [2:0] ST_READ_WAIT = 3'd1;
    localparam [2:0] ST_SEND      = 3'd2;
    localparam [2:0] ST_DONE      = 3'd3;

    reg [2:0]  state_q;
    reg [15:0] tx_len_cfg_q;
    reg        irq_en_q;
    reg [1:0]  tx_ctrl_q; // [0]=busy/start, [1]=program

    reg [9:0]  ram_addr0_q;
    wire [31:0] ram_data0;
    reg [9:0]  ram_addr1_q;
    wire [31:0] ram_data1;
    reg        ram_wr0_q;
    reg [31:0] ram_wdata0_q;

    reg        irq_pend_q;
    reg        prog_only_pend_q;

    reg [15:0] total_len_q;
    reg [15:0] bytes_left_q;
    reg [15:0] word_idx_q;

    wire [15:0] cfg_addr_lo_w = cfg_addr_in[15:0];
    wire        cfg_is_mem_w  = (cfg_addr_in[31:12] == 20'h0);

    wire [31:0] data_word_w;
    wire [3:0]  strb_word_w;
    wire [2:0]  send_bytes_w;

    ethernet_dp_ram #(
        .WIDTH(32),
        .ADDR_W(10)
    ) u_ram (
        .clk_in   (clk_in),
        .addr0_in (ram_addr0_q),
        .data0_in (ram_wdata0_q),
        .wr0_in   (ram_wr0_q),
        .data0_out(ram_data0),
        .addr1_in (ram_addr1_q),
        .data1_in (32'h0),
        .wr1_in   (1'b0),
        .data1_out(ram_data1)
    );

    assign send_bytes_w = (bytes_left_q >= 16'd4) ? 3'd4 : {1'b0, bytes_left_q[1:0]};

    assign strb_word_w = (send_bytes_w == 3'd4) ? 4'hF :
                         (send_bytes_w == 3'd3) ? 4'h7 :
                         (send_bytes_w == 3'd2) ? 4'h3 :
                         (send_bytes_w == 3'd1) ? 4'h1 : 4'h0;

    assign data_word_w[7:0]   = (((word_idx_q << 2) + 16'd0) < tx_len_cfg_q) ? ram_data1[7:0]   : 8'h00;
    assign data_word_w[15:8]  = (((word_idx_q << 2) + 16'd1) < tx_len_cfg_q) ? ram_data1[15:8]  : 8'h00;
    assign data_word_w[23:16] = (((word_idx_q << 2) + 16'd2) < tx_len_cfg_q) ? ram_data1[23:16] : 8'h00;
    assign data_word_w[31:24] = (((word_idx_q << 2) + 16'd3) < tx_len_cfg_q) ? ram_data1[31:24] : 8'h00;

    always @(*) begin
        if (!cfg_wr_in) begin
            case (cfg_addr_lo_w)
                ADDR_TX_LEN:  cfg_data_rd_out = {16'h0, tx_len_cfg_q};
                ADDR_IRQ_EN:  cfg_data_rd_out = {31'h0, irq_en_q};
                ADDR_TX_CTRL: cfg_data_rd_out = {30'h0, tx_ctrl_q};
                default:      cfg_data_rd_out = ram_data0;
            endcase
        end else begin
            cfg_data_rd_out = 32'h0;
        end
    end

    always @(posedge clk_in or posedge rst_in) begin
        if (rst_in) begin
            state_q          <= ST_IDLE;
            tx_len_cfg_q     <= 16'd64;
            irq_en_q         <= 1'b0;
            tx_ctrl_q        <= 2'b00;
            ram_addr0_q      <= 10'd0;
            ram_addr1_q      <= 10'd0;
            ram_wr0_q        <= 1'b0;
            ram_wdata0_q     <= 32'h0;
            irq_pend_q       <= 1'b0;
            prog_only_pend_q <= 1'b0;
            total_len_q      <= 16'd0;
            bytes_left_q     <= 16'd0;
            word_idx_q       <= 16'd0;
            interrupt_out    <= 1'b0;
            axis_tvalid_out  <= 1'b0;
            axis_tdata_out   <= 32'h0;
            axis_tstrb_out   <= 4'h0;
            axis_tlast_out   <= 1'b0;
        end else begin
            ram_wr0_q       <= 1'b0;
            interrupt_out   <= 1'b0;

            if (irq_pend_q) begin
                interrupt_out <= irq_en_q;
                irq_pend_q    <= 1'b0;
            end

            if (cfg_wr_in) begin
                if ((cfg_addr_lo_w == ADDR_TX_LEN) ||
                    (cfg_addr_lo_w == ADDR_IRQ_EN) ||
                    (cfg_addr_lo_w == ADDR_TX_CTRL)) begin
                    case (cfg_addr_lo_w)
                        ADDR_TX_LEN: begin
                            tx_len_cfg_q <= cfg_data_wr_in[15:0];
                        end
                        ADDR_IRQ_EN: begin
                            irq_en_q <= cfg_data_wr_in[0];
                        end
                        ADDR_TX_CTRL: begin
                            tx_ctrl_q <= cfg_data_wr_in[1:0];
                            if (state_q == ST_IDLE && cfg_data_wr_in[0] && cfg_data_wr_in[1]) begin
                                prog_only_pend_q <= 1'b1;
                            end
                        end
                        default: begin
                        end
                    endcase
                end else if (cfg_is_mem_w && (cfg_addr_lo_w < 16'h1000)) begin
                    ram_addr0_q  <= cfg_addr_in[11:2];
                    ram_wdata0_q <= cfg_data_wr_in;
                    ram_wr0_q    <= 1'b1;
                end
            end else begin
                ram_addr0_q <= cfg_addr_in[11:2];
            end

            case (state_q)
                ST_IDLE: begin
                    axis_tvalid_out <= 1'b0;
                    axis_tlast_out  <= 1'b0;
                    axis_tstrb_out  <= 4'h0;

                    if (prog_only_pend_q) begin
                        prog_only_pend_q <= 1'b0;
                        tx_ctrl_q        <= 2'b00;
                        irq_pend_q       <= 1'b1;
                    end else if (tx_ctrl_q[0] && !tx_ctrl_q[1]) begin
                        total_len_q  <= (tx_len_cfg_q < 16'd64) ? 16'd64 : tx_len_cfg_q;
                        bytes_left_q <= (tx_len_cfg_q < 16'd64) ? 16'd64 : tx_len_cfg_q;
                        word_idx_q   <= 16'd0;
                        ram_addr1_q  <= 10'd0;
                        state_q      <= ST_READ_WAIT;
                    end
                end

                ST_READ_WAIT: begin
                    axis_tvalid_out <= 1'b0;
                    axis_tlast_out  <= 1'b0;
                    axis_tstrb_out  <= 4'h0;
                    state_q         <= ST_SEND;
                end

                ST_SEND: begin
                    axis_tvalid_out <= 1'b1;
                    axis_tdata_out  <= data_word_w;
                    axis_tstrb_out  <= strb_word_w;
                    axis_tlast_out  <= (bytes_left_q <= 16'd4);

                    if (axis_tready_in) begin
                        if (bytes_left_q <= 16'd4) begin
                            state_q         <= ST_DONE;
                        end else begin
                            bytes_left_q <= bytes_left_q - 16'd4;
                            word_idx_q   <= word_idx_q + 16'd1;
                            ram_addr1_q  <= ram_addr1_q + 10'd1;
                            state_q      <= ST_READ_WAIT;
                        end
                    end
                end

                ST_DONE: begin
                    axis_tvalid_out <= 1'b0;
                    axis_tlast_out  <= 1'b0;
                    axis_tstrb_out  <= 4'h0;
                    tx_ctrl_q       <= 2'b00;
                    irq_pend_q      <= 1'b1;
                    state_q         <= ST_IDLE;
                end

                default: begin
                    state_q <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
