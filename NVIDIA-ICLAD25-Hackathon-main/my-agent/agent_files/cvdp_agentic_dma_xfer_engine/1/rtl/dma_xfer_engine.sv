`timescale 1ns/1ns

module dma_xfer_engine (
    input  logic        clk,
    input  logic        rstn,
    input  logic [3:0]  addr,
    input  logic        we,
    input  logic [31:0] wd,
    output logic [31:0] rd,
    input  logic        dma_req,
    input  logic [1:0]  bus_grant,
    input  logic [31:0] rd_m,
    output logic [1:0]  bus_req,
    output logic [1:0]  bus_lock,
    output logic [31:0] addr_m,
    output logic        we_m,
    output logic [31:0] wd_m,
    output logic [1:0]  size_m
);

  localparam logic [1:0] DMA_B  = 2'b00;
  localparam logic [1:0] DMA_HW = 2'b01;
  localparam logic [1:0] DMA_W  = 2'b10;

  localparam logic [1:0] ST_IDLE = 2'b00;
  localparam logic [1:0] ST_WB   = 2'b01;
  localparam logic [1:0] ST_TR   = 2'b10;

  logic [1:0] state;

  logic [9:0]  dma_cr;
  logic [31:0] dma_src_adr;
  logic [31:0] dma_dst_adr;

  logic [31:0] src_cur;
  logic [31:0] dst_cur;
  logic [2:0]  tr_remaining;
  logic [1:0]  src_size_cfg;
  logic [1:0]  dst_size_cfg;
  logic        inc_src_cfg;
  logic        inc_dst_cfg;
  logic        phase_read;
  logic [31:0] rd_buf;

  function automatic [31:0] pick_from_bus(
      input [31:0] bus_data,
      input [1:0]  sz,
      input [1:0]  ofs
  );
    begin
      pick_from_bus = 32'h0;
      case (sz)
        DMA_B: begin
          case (ofs)
            2'd0: pick_from_bus[7:0]   = bus_data[7:0];
            2'd1: pick_from_bus[7:0]   = bus_data[15:8];
            2'd2: pick_from_bus[7:0]   = bus_data[23:16];
            default: pick_from_bus[7:0] = bus_data[31:24];
          endcase
        end
        DMA_HW: begin
          if (ofs[1] == 1'b0) begin
            pick_from_bus[15:0] = bus_data[15:0];
          end else begin
            pick_from_bus[15:0] = bus_data[31:16];
          end
        end
        default: pick_from_bus = bus_data;
      endcase
    end
  endfunction

  function automatic [31:0] place_to_bus(
      input [31:0] payload,
      input [1:0]  sz,
      input [1:0]  ofs
  );
    begin
      place_to_bus = 32'h0;
      case (sz)
        DMA_B: begin
          case (ofs)
            2'd0: place_to_bus[7:0]   = payload[7:0];
            2'd1: place_to_bus[15:8]  = payload[7:0];
            2'd2: place_to_bus[23:16] = payload[7:0];
            default: place_to_bus[31:24] = payload[7:0];
          endcase
        end
        DMA_HW: begin
          if (ofs[1] == 1'b0) begin
            place_to_bus[15:0] = payload[15:0];
          end else begin
            place_to_bus[31:16] = payload[15:0];
          end
        end
        default: place_to_bus = payload;
      endcase
    end
  endfunction

  function automatic [31:0] size_inc(input [1:0] sz);
    begin
      case (sz)
        DMA_B:  size_inc = 32'd1;
        DMA_HW: size_inc = 32'd2;
        default: size_inc = 32'd4;
      endcase
    end
  endfunction

  function automatic [2:0] decode_count(input [9:0] cr);
    begin
      if (cr[9:7] != 3'b000) begin
        decode_count = cr[9:7];
      end else if (cr[2:0] != 3'b000) begin
        decode_count = cr[2:0];
      end else begin
        decode_count = 3'd1;
      end
    end
  endfunction

  function automatic [1:0] decode_src_size(input [9:0] cr);
    begin
      if (cr[9:7] != 3'b000) begin
        decode_src_size = cr[6:5];
      end else begin
        decode_src_size = cr[4:3];
      end
    end
  endfunction

  function automatic [1:0] decode_dst_size(input [9:0] cr);
    begin
      if (cr[9:7] != 3'b000) begin
        decode_dst_size = cr[4:3];
      end else begin
        decode_dst_size = cr[6:5];
      end
    end
  endfunction

  always_comb begin
    rd = 32'h0;
    case (addr)
      4'h0: rd[9:0] = dma_cr;
      4'h4: rd = dma_src_adr;
      4'h8: rd = dma_dst_adr;
      default: rd = 32'h0;
    endcase
  end

  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      state         <= ST_IDLE;
      dma_cr        <= 10'h0;
      dma_src_adr   <= 32'h0;
      dma_dst_adr   <= 32'h0;
      src_cur       <= 32'h0;
      dst_cur       <= 32'h0;
      tr_remaining  <= 3'h0;
      src_size_cfg  <= DMA_W;
      dst_size_cfg  <= DMA_W;
      inc_src_cfg   <= 1'b0;
      inc_dst_cfg   <= 1'b0;
      phase_read    <= 1'b1;
      rd_buf        <= 32'h0;
      bus_req       <= 1'b0;
      bus_lock      <= 1'b0;
      addr_m        <= 32'h0;
      we_m          <= 1'b0;
      wd_m          <= 32'h0;
      size_m        <= DMA_W;
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
          bus_req    <= 1'b0;
          bus_lock   <= 1'b0;
          we_m       <= 1'b0;
          addr_m     <= 32'h0;
          wd_m       <= 32'h0;
          size_m     <= DMA_W;
          phase_read <= 1'b1;

          if (dma_req) begin
            src_cur       <= dma_src_adr;
            dst_cur       <= dma_dst_adr;
            tr_remaining  <= decode_count(dma_cr);
            src_size_cfg  <= decode_src_size(dma_cr);
            dst_size_cfg  <= decode_dst_size(dma_cr);
            inc_src_cfg   <= dma_cr[2] | dma_cr[7];
            inc_dst_cfg   <= dma_cr[1] | dma_cr[8];
            bus_req       <= 1'b1;
            bus_lock      <= 1'b1;
            state         <= ST_WB;
          end
        end

        ST_WB: begin
          bus_req  <= 1'b1;
          bus_lock <= 1'b1;
          we_m     <= 1'b0;
          if (bus_grant != 2'b00) begin
            state <= ST_TR;
          end
        end

        ST_TR: begin
          bus_req  <= 1'b1;
          bus_lock <= 1'b1;

          if (phase_read) begin
            we_m   <= 1'b0;
            addr_m <= src_cur;
            size_m <= src_size_cfg;
            rd_buf <= pick_from_bus(rd_m, src_size_cfg, src_cur[1:0]);

            if (inc_src_cfg) begin
              src_cur <= src_cur + size_inc(src_size_cfg);
            end
            phase_read <= 1'b0;
          end else begin
            we_m   <= 1'b1;
            addr_m <= dst_cur;
            size_m <= dst_size_cfg;
            wd_m   <= place_to_bus(rd_buf, dst_size_cfg, dst_cur[1:0]);

            if (inc_dst_cfg) begin
              dst_cur <= dst_cur + size_inc(dst_size_cfg);
            end

            if (tr_remaining <= 3'd1) begin
              tr_remaining <= 3'd0;
              phase_read   <= 1'b1;
              we_m         <= 1'b0;
              bus_req      <= 1'b0;
              bus_lock     <= 1'b0;
              state        <= ST_IDLE;
            end else begin
              tr_remaining <= tr_remaining - 3'd1;
              phase_read   <= 1'b1;
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
