`timescale 1ns/1ns

module ethernet_mii_tx (
    input               clk_in,
    input               rst_in,

    output reg [3:0]    mii_txd_out,
    output reg          mii_tx_en_out,

    input               axis_clk_in,
    input               axis_rst_in,
    input               axis_valid_in,
    input  [31:0]       axis_data_in,
    input  [3:0]        axis_strb_in,
    input               axis_last_in,
    output              axis_ready_out
);

    localparam ST_IDLE         = 3'd0;
    localparam ST_PREAMBLE     = 3'd1;
    localparam ST_PAYLOAD_FETCH= 3'd2;
    localparam ST_PAYLOAD      = 3'd3;
    localparam ST_CRC          = 3'd4;

    reg  [2:0]  tx_state_q;
    reg         nibble_phase_q;
    reg  [3:0]  preamble_idx_q;

    reg  [31:0] crc_q;
    reg  [31:0] crc_shift_q;
    reg  [2:0]  crc_nibble_idx_q;

    reg         fetch_wait_q;
    reg  [37:0] payload_word_q;
    reg  [2:0]  payload_valid_count_q;
    reg  [1:0]  payload_byte_idx_q;
    reg         payload_last_q;

    wire [37:0] fifo_rd_data_w;
    wire        fifo_rd_empty_w;
    wire        fifo_wr_full_w;

    wire        fifo_rd_pop_w;

    assign axis_ready_out = ~fifo_wr_full_w;

    ethernet_fifo_cdc #(
        .WIDTH(38),
        .DEPTH(512)
    ) u_fifo (
        .wr_clk_i   (axis_clk_in),
        .wr_rst_i   (axis_rst_in),
        .wr_push_i  (axis_valid_in & axis_ready_out),
        .wr_data_i  ({1'b0, axis_last_in, axis_strb_in, axis_data_in}),
        .wr_full_o  (fifo_wr_full_w),

        .rd_clk_i   (clk_in),
        .rd_rst_i   (rst_in),
        .rd_pop_i   (fifo_rd_pop_w),
        .rd_data_o  (fifo_rd_data_w),
        .rd_empty_o (fifo_rd_empty_w)
    );

    assign fifo_rd_pop_w = (tx_state_q == ST_PAYLOAD_FETCH) && !fetch_wait_q && !fifo_rd_empty_w;

    function [2:0] popcount4;
        input [3:0] v;
        begin
            popcount4 = v[0] + v[1] + v[2] + v[3];
        end
    endfunction

    function [7:0] byte_at_idx;
        input [31:0] word;
        input [1:0]  idx;
        begin
            case (idx)
                2'd0: byte_at_idx = word[7:0];
                2'd1: byte_at_idx = word[15:8];
                2'd2: byte_at_idx = word[23:16];
                default: byte_at_idx = word[31:24];
            endcase
        end
    endfunction

    function [31:0] crc32_next;
        input [31:0] crc_in;
        input [7:0]  data;
        reg   [31:0] c;
        reg          fb;
        integer      i;
        begin
            c = crc_in;
            for (i = 0; i < 8; i = i + 1) begin
                fb = c[0] ^ data[i];
                c  = {1'b0, c[31:1]};
                if (fb)
                    c = c ^ 32'hEDB88320;
            end
            crc32_next = c;
        end
    endfunction

    reg [7:0] tx_byte;
    reg [31:0] crc_next_v;

    always @(posedge clk_in or posedge rst_in) begin
        if (rst_in) begin
            tx_state_q           <= ST_IDLE;
            nibble_phase_q       <= 1'b0;
            preamble_idx_q       <= 4'd0;
            crc_q                <= 32'hFFFFFFFF;
            crc_shift_q          <= 32'd0;
            crc_nibble_idx_q     <= 3'd0;
            fetch_wait_q         <= 1'b0;
            payload_word_q       <= 38'd0;
            payload_valid_count_q<= 3'd0;
            payload_byte_idx_q   <= 2'd0;
            payload_last_q       <= 1'b0;
            mii_txd_out          <= 4'd0;
            mii_tx_en_out        <= 1'b0;
        end else begin
            case (tx_state_q)
                ST_IDLE: begin
                    mii_txd_out    <= 4'd0;
                    mii_tx_en_out        <= 1'b0;
                    nibble_phase_q <= 1'b0;
                    fetch_wait_q   <= 1'b0;

                    if (!fifo_rd_empty_w) begin
                        tx_state_q      <= ST_PREAMBLE;
                        preamble_idx_q  <= 4'd0;
                        crc_q           <= 32'hFFFFFFFF;
                    end
                end

                ST_PREAMBLE: begin
                    mii_tx_en_out        <= 1'b1;
                    tx_byte = (preamble_idx_q == 4'd7) ? 8'hD5 : 8'h55;

                    if (!nibble_phase_q) begin
                        mii_txd_out    <= tx_byte[3:0];
                        nibble_phase_q <= 1'b1;
                    end else begin
                        mii_txd_out    <= tx_byte[7:4];
                        nibble_phase_q <= 1'b0;

                        if (preamble_idx_q == 4'd7) begin
                            tx_state_q <= ST_PAYLOAD_FETCH;
                        end
                        preamble_idx_q <= preamble_idx_q + 4'd1;
                    end
                end

                ST_PAYLOAD_FETCH: begin
                    mii_tx_en_out        <= 1'b0;
                    mii_txd_out   <= 4'd0;

                    if (!fetch_wait_q) begin
                        if (!fifo_rd_empty_w) begin
                            fetch_wait_q  <= 1'b1;
                        end
                    end else begin
                        fetch_wait_q          <= 1'b0;
                        payload_word_q        <= fifo_rd_data_w;
                        payload_last_q        <= fifo_rd_data_w[36];
                        payload_valid_count_q <= popcount4(fifo_rd_data_w[35:32]);
                        payload_byte_idx_q    <= 2'd0;
                        nibble_phase_q        <= 1'b0;
                        tx_state_q            <= ST_PAYLOAD;
                    end
                end

                ST_PAYLOAD: begin
                    mii_tx_en_out        <= 1'b1;
                    tx_byte = byte_at_idx(payload_word_q[31:0], payload_byte_idx_q);

                    if (!nibble_phase_q) begin
                        mii_txd_out    <= tx_byte[3:0];
                        nibble_phase_q <= 1'b1;
                    end else begin
                        mii_txd_out    <= tx_byte[7:4];
                        nibble_phase_q <= 1'b0;

                        crc_next_v = crc32_next(crc_q, tx_byte);
                        crc_q      <= crc_next_v;

                        if ({1'b0, payload_byte_idx_q} + 3'd1 < payload_valid_count_q) begin
                            payload_byte_idx_q <= payload_byte_idx_q + 2'd1;
                        end else if (payload_last_q) begin
                            crc_shift_q      <= ~crc_next_v;
                            crc_nibble_idx_q <= 3'd0;
                            tx_state_q       <= ST_CRC;
                        end else begin
                            tx_state_q <= ST_PAYLOAD_FETCH;
                        end
                    end
                end

                ST_CRC: begin
                    mii_tx_en_out        <= 1'b1;
                    mii_txd_out     <= crc_shift_q[3:0];
                    crc_shift_q     <= {4'h0, crc_shift_q[31:4]};

                    if (crc_nibble_idx_q == 3'd7) begin
                        tx_state_q    <= ST_IDLE;
                    end else begin
                        crc_nibble_idx_q <= crc_nibble_idx_q + 3'd1;
                    end
                end

                default: begin
                    tx_state_q <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
