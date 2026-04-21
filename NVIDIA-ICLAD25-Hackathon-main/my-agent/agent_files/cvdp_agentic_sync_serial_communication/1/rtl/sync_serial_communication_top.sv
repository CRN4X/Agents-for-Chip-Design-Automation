`timescale 1ns/1ns

module sync_serial_communication_tx_rx (
    input  logic        clk,
    input  logic        reset_n,
    input  logic [2:0]  sel,
    input  logic [63:0] data_in,
    output logic [63:0] data_out,
    output logic        done,
    output logic [63:0] gray_out
);
    logic serial_out;
    logic serial_clk;
    logic tx_active;

    tx_block u_tx_block (
        .clk       (clk),
        .reset_n   (reset_n),
        .sel       (sel),
        .data_in   (data_in),
        .serial_out(serial_out),
        .serial_clk(serial_clk),
        .tx_active (tx_active)
    );

    rx_block u_rx_block (
        .clk       (clk),
        .reset_n   (reset_n),
        .sel       (sel),
        .serial_in (serial_out),
        .serial_clk(serial_clk),
        .tx_active (tx_active),
        .data_out  (data_out),
        .done      (done)
    );

    binary_to_gray_conversion u_binary_to_gray_conversion (
        .data    (data_out),
        .gray_out(gray_out)
    );
endmodule

module tx_block (
    input  logic        clk,
    input  logic        reset_n,
    input  logic [2:0]  sel,
    input  logic [63:0] data_in,
    output logic        serial_out,
    output logic        serial_clk,
    output logic        tx_active
);
    logic [63:0] shift_reg;
    logic [6:0]  bits_remaining;

    function automatic logic [6:0] sel_to_width(input logic [2:0] sel_i);
        case (sel_i)
            3'b001: sel_to_width = 7'd8;
            3'b010: sel_to_width = 7'd16;
            3'b011: sel_to_width = 7'd32;
            3'b100: sel_to_width = 7'd64;
            default: sel_to_width = 7'd0;
        endcase
    endfunction

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            shift_reg       <= 64'd0;
            bits_remaining  <= 7'd0;
            serial_out      <= 1'b0;
            tx_active       <= 1'b0;
        end else begin
            if (!tx_active) begin
                serial_out <= 1'b0;
                if (sel_to_width(sel) != 7'd0) begin
                    shift_reg      <= data_in;
                    bits_remaining <= sel_to_width(sel);
                    tx_active      <= 1'b1;
                end
            end else begin
                serial_out <= shift_reg[0];
                shift_reg  <= {1'b0, shift_reg[63:1]};

                if (bits_remaining > 7'd1) begin
                    bits_remaining <= bits_remaining - 7'd1;
                end else begin
                    bits_remaining <= 7'd0;
                    tx_active      <= 1'b0;
                end
            end
        end
    end

    assign serial_clk = clk & tx_active;
endmodule

module rx_block (
    input  logic        clk,
    input  logic        reset_n,
    input  logic [2:0]  sel,
    input  logic        serial_in,
    input  logic        serial_clk,
    input  logic        tx_active,
    output logic [63:0] data_out,
    output logic        done
);
    logic [63:0] capture_reg;
    logic [6:0]  bit_count;
    logic [6:0]  target_width;
    logic        rx_active;

    function automatic logic [6:0] sel_to_width(input logic [2:0] sel_i);
        case (sel_i)
            3'b001: sel_to_width = 7'd8;
            3'b010: sel_to_width = 7'd16;
            3'b011: sel_to_width = 7'd32;
            3'b100: sel_to_width = 7'd64;
            default: sel_to_width = 7'd0;
        endcase
    endfunction

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            capture_reg  <= 64'd0;
            bit_count    <= 7'd0;
            target_width <= 7'd0;
            rx_active    <= 1'b0;
            data_out     <= 64'd0;
            done         <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!rx_active) begin
                if (tx_active && (sel_to_width(sel) != 7'd0)) begin
                    capture_reg  <= 64'd0;
                    bit_count    <= 7'd0;
                    target_width <= sel_to_width(sel);
                    rx_active    <= 1'b1;
                end
            end else begin
                if (serial_clk && (bit_count < target_width)) begin
                    capture_reg[bit_count] <= serial_in;
                    bit_count              <= bit_count + 7'd1;
                end else if (bit_count >= target_width) begin
                    data_out  <= capture_reg;
                    done      <= 1'b1;
                    rx_active <= 1'b0;
                end
            end
        end
    end
endmodule

module binary_to_gray_conversion (
    input  logic [63:0] data,
    output logic [63:0] gray_out
);
    always_comb begin
        gray_out = data ^ (data >> 1);
    end
endmodule
