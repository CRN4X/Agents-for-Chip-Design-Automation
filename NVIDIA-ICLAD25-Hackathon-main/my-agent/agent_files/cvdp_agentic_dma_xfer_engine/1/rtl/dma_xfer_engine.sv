module dma_xfer_engine (
    input  wire        clk,
    input  wire        rstn,
    input  wire [3:0]  addr,
    input  wire        we,
    input  wire [31:0] wd,
    output reg  [31:0] rd,
    input  wire        dma_req,
    input  wire [31:0] bus_grant,
    input  wire [31:0] rd_m,
    output reg  [31:0] bus_req,
    output reg  [31:0] bus_lock,
    output reg  [31:0] addr_m,
    output reg         we_m,
    output reg  [31:0] wd_m,
    output reg  [1:0]  size_m
);

localparam [1:0] DMA_B  = 2'b00;
localparam [1:0] DMA_HW = 2'b01;
localparam [1:0] DMA_W  = 2'b10;

localparam [1:0] ST_IDLE = 2'b00;
localparam [1:0] ST_WB   = 2'b01;
localparam [1:0] ST_TR   = 2'b10;

reg [9:0]  dma_cr;
reg [31:0] dma_src_adr;
reg [31:0] dma_dst_adr;

reg [1:0]  state;
reg        tr_phase;  // 0: read, 1: write
reg [2:0]  beats_left;
reg [31:0] src_cur;
reg [31:0] dst_cur;
reg [31:0] rd_buf;

wire [2:0] cnt_hi   = dma_cr[9:7];
wire [2:0] cnt_lo   = dma_cr[2:0];
wire [2:0] cfg_cnt  = (cnt_hi != 3'd0) ? cnt_hi : cnt_lo;

wire [1:0] cfg_src_size = (dma_cr[6:5] != 2'b00) ? dma_cr[6:5] : dma_cr[4:3];
wire [1:0] cfg_dst_size = (dma_cr[4:3] != 2'b00) ? dma_cr[4:3] : dma_cr[6:5];
wire       cfg_inc_src  = dma_cr[2] | dma_cr[7];
wire       cfg_inc_dst  = dma_cr[1] | dma_cr[8];

function [31:0] extract_data;
    input [31:0] din;
    input [1:0]  size_sel;
    input [1:0]  ofs;
    begin
        case (size_sel)
            DMA_B: begin
                case (ofs)
                    2'b00: extract_data = {24'd0, din[7:0]};
                    2'b01: extract_data = {24'd0, din[15:8]};
                    2'b10: extract_data = {24'd0, din[23:16]};
                    default: extract_data = {24'd0, din[31:24]};
                endcase
            end
            DMA_HW: begin
                if (ofs[1] == 1'b0) begin
                    extract_data = {16'd0, din[15:0]};
                end else begin
                    extract_data = {16'd0, din[31:16]};
                end
            end
            default: extract_data = din;
        endcase
    end
endfunction

function [31:0] pack_data;
    input [31:0] din;
    input [1:0]  size_sel;
    input [1:0]  ofs;
    begin
        case (size_sel)
            DMA_B: begin
                case (ofs)
                    2'b00: pack_data = {24'd0, din[7:0]};
                    2'b01: pack_data = {16'd0, din[7:0], 8'd0};
                    2'b10: pack_data = {8'd0, din[7:0], 16'd0};
                    default: pack_data = {din[7:0], 24'd0};
                endcase
            end
            DMA_HW: begin
                if (ofs[1] == 1'b0) begin
                    pack_data = {16'd0, din[15:0]};
                end else begin
                    pack_data = {din[15:0], 16'd0};
                end
            end
            default: pack_data = din;
        endcase
    end
endfunction

function [31:0] size_inc;
    input [1:0] size_sel;
    begin
        case (size_sel)
            DMA_B: size_inc = 32'd1;
            DMA_HW: size_inc = 32'd2;
            default: size_inc = 32'd4;
        endcase
    end
endfunction

always @(*) begin
    if (!we) begin
        case (addr)
            4'h0: rd = {22'd0, dma_cr};
            4'h4: rd = dma_src_adr;
            4'h8: rd = dma_dst_adr;
            default: rd = 32'd0;
        endcase
    end else begin
        rd = 32'd0;
    end
end

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        dma_cr      <= 10'd0;
        dma_src_adr <= 32'd0;
        dma_dst_adr <= 32'd0;

        state       <= ST_IDLE;
        tr_phase    <= 1'b0;
        beats_left  <= 3'd0;
        src_cur     <= 32'd0;
        dst_cur     <= 32'd0;
        rd_buf      <= 32'd0;

        bus_req     <= 1'b0;
        bus_lock    <= 1'b0;
        addr_m      <= 32'd0;
        we_m        <= 1'b0;
        wd_m        <= 32'd0;
        size_m      <= DMA_W;
    end else begin
        if (we) begin
            case (addr)
                4'h0: dma_cr      <= wd[9:0];
                4'h4: dma_src_adr <= wd;
                4'h8: dma_dst_adr <= wd;
                default: ;
            endcase
        end

        case (state)
            ST_IDLE: begin
                bus_req  <= 1'b0;
                bus_lock <= 1'b0;
                we_m     <= 1'b0;

                if (dma_req && (cfg_cnt != 3'd0)) begin
                    src_cur    <= dma_src_adr;
                    dst_cur    <= dma_dst_adr;
                    beats_left <= cfg_cnt;
                    tr_phase   <= 1'b0;
                    state      <= ST_WB;

                    bus_req    <= 1'b1;
                    bus_lock   <= 1'b1;
                end
            end

            ST_WB: begin
                bus_req  <= 1'b1;
                bus_lock <= 1'b1;
                we_m     <= 1'b0;
                if (bus_grant) begin
                    state <= ST_TR;
                end
            end

            ST_TR: begin
                bus_req  <= 1'b1;
                bus_lock <= 1'b1;

                if (tr_phase == 1'b0) begin
                    addr_m <= src_cur;
                    we_m   <= 1'b0;
                    size_m <= cfg_src_size;
                    rd_buf <= extract_data(rd_m, cfg_src_size, src_cur[1:0]);

                    if (cfg_inc_src) begin
                        src_cur <= src_cur + size_inc(cfg_src_size);
                    end
                    tr_phase <= 1'b1;
                end else begin
                    addr_m <= dst_cur;
                    we_m   <= 1'b1;
                    size_m <= cfg_dst_size;
                    wd_m   <= pack_data(rd_buf, cfg_dst_size, dst_cur[1:0]);

                    if (cfg_inc_dst) begin
                        dst_cur <= dst_cur + size_inc(cfg_dst_size);
                    end

                    if (beats_left == 3'd1) begin
                        beats_left <= 3'd0;
                        state      <= ST_IDLE;
                        tr_phase   <= 1'b0;
                        bus_req    <= 1'b0;
                        bus_lock   <= 1'b0;
                        we_m       <= 1'b0;
                    end else begin
                        beats_left <= beats_left - 3'd1;
                        tr_phase   <= 1'b0;
                    end
                end
            end

            default: begin
                state <= ST_IDLE;
            end
        endcase
    end
end

endmodule
