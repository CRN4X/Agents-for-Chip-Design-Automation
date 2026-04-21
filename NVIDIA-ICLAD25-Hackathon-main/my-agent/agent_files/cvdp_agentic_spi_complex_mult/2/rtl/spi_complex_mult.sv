`timescale 1ns/1ns

module spi_complex_mult #(
    parameter integer IN_WIDTH = 16,
    parameter integer OUT_WIDTH = 32
) (
    input  wire rst_async_n,
    input  wire spi_sck,
    input  wire spi_cs_n,
    input  wire spi_mosi,
    output reg  spi_miso
);

    reg [7:0] rx_shift;
    reg [2:0] rx_bit_cnt;
    reg [2:0] rx_byte_cnt;

    reg [7:0] msb_Ar, lsb_Ar;
    reg [7:0] msb_Ai, lsb_Ai;
    reg [7:0] msb_Br, lsb_Br;
    reg [7:0] msb_Bi, lsb_Bi;

    reg signed [OUT_WIDTH-1:0] result_real;
    reg signed [OUT_WIDTH-1:0] result_imag;

    reg [7:0] tx_shift;
    reg [2:0] tx_bit_cnt;
    reg [2:0] tx_byte_idx;
    reg [7:0] tx_byte_sel;

    reg [7:0] rx_byte;
    reg signed [IN_WIDTH-1:0] ar_v, ai_v, br_v, bi_v;

    always @(*) begin
        case (tx_byte_idx)
            3'd0: tx_byte_sel = result_real[31:24];
            3'd1: tx_byte_sel = result_real[23:16];
            3'd2: tx_byte_sel = result_real[15:8];
            3'd3: tx_byte_sel = result_real[7:0];
            3'd4: tx_byte_sel = result_imag[31:24];
            3'd5: tx_byte_sel = result_imag[23:16];
            3'd6: tx_byte_sel = result_imag[15:8];
            default: tx_byte_sel = result_imag[7:0];
        endcase
    end

    always @(negedge spi_cs_n or negedge rst_async_n) begin
        if (!rst_async_n) begin
            tx_shift   <= 8'd0;
            tx_bit_cnt <= 3'd0;
            spi_miso   <= 1'b0;
            rx_shift   <= 8'd0;
            rx_bit_cnt <= 3'd0;
        end else begin
            tx_shift   <= tx_byte_sel;
            tx_bit_cnt <= 3'd0;
            spi_miso   <= tx_byte_sel[7];
            rx_shift   <= 8'd0;
            rx_bit_cnt <= 3'd0;
        end
    end

    always @(posedge spi_sck or negedge rst_async_n) begin
        if (!rst_async_n) begin
            rx_shift    <= 8'd0;
            rx_bit_cnt  <= 3'd0;
            rx_byte_cnt <= 3'd0;

            msb_Ar <= 8'd0;
            lsb_Ar <= 8'd0;
            msb_Ai <= 8'd0;
            lsb_Ai <= 8'd0;
            msb_Br <= 8'd0;
            lsb_Br <= 8'd0;
            msb_Bi <= 8'd0;
            lsb_Bi <= 8'd0;

            result_real <= {OUT_WIDTH{1'b0}};
            result_imag <= {OUT_WIDTH{1'b0}};
            tx_byte_idx <= 3'd0;
        end else if (!spi_cs_n) begin
            rx_shift   <= {rx_shift[6:0], spi_mosi};
            rx_bit_cnt <= rx_bit_cnt + 3'd1;

            if (rx_bit_cnt == 3'd7) begin
                rx_byte = {rx_shift[6:0], spi_mosi};

                case (rx_byte_cnt)
                    3'd0: msb_Ar <= rx_byte;
                    3'd1: lsb_Ar <= rx_byte;
                    3'd2: msb_Ai <= rx_byte;
                    3'd3: lsb_Ai <= rx_byte;
                    3'd4: msb_Br <= rx_byte;
                    3'd5: lsb_Br <= rx_byte;
                    3'd6: msb_Bi <= rx_byte;
                    3'd7: lsb_Bi <= rx_byte;
                    default: ;
                endcase

                if (rx_byte_cnt == 3'd7) begin
                    ar_v = $signed({msb_Ar, lsb_Ar});
                    ai_v = $signed({msb_Ai, lsb_Ai});
                    br_v = $signed({msb_Br, lsb_Br});
                    bi_v = $signed({msb_Bi, rx_byte});

                    result_real <= (ar_v * br_v) - (ai_v * bi_v);
                    result_imag <= (ar_v * bi_v) + (ai_v * br_v);

                    rx_byte_cnt <= 3'd0;
                    tx_byte_idx <= 3'd0;
                end else begin
                    rx_byte_cnt <= rx_byte_cnt + 3'd1;
                    tx_byte_idx <= tx_byte_idx + 3'd1;
                end
            end
        end
    end

    always @(negedge spi_sck or negedge rst_async_n) begin
        if (!rst_async_n) begin
            tx_shift   <= 8'd0;
            tx_bit_cnt <= 3'd0;
            spi_miso   <= 1'b0;
        end else if (!spi_cs_n) begin
            tx_bit_cnt <= tx_bit_cnt + 3'd1;
            tx_shift   <= {tx_shift[6:0], 1'b0};
            spi_miso   <= tx_shift[6];
        end
    end

endmodule
