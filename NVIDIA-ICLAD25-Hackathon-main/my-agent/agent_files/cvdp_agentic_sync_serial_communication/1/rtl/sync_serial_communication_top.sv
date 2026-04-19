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
    logic tx_done;
    logic [6:0] tx_total_bits;
    logic rx_done;

    tx_block u_tx_block (
        .clk(clk),
        .reset_n(reset_n),
        .sel(sel),
        .data_in(data_in),
        .serial_out(serial_out),
        .serial_clk(serial_clk),
        .active(tx_active),
        .done(tx_done),
        .total_bits(tx_total_bits)
    );

    rx_block u_rx_block (
        .clk(clk),
        .reset_n(reset_n),
        .serial_in(serial_out),
        .serial_clk(serial_clk),
        .tx_active(tx_active),
        .total_bits(tx_total_bits),
        .done(rx_done),
        .data_out(data_out)
    );

    binary_to_gray_conversion u_binary_to_gray_conversion (
        .data(data_out),
        .gray_out(gray_out)
    );

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            done <= 1'b0;
        end else begin
            done <= rx_done;
        end
    end

endmodule

module tx_block (
    input  logic        clk,
    input  logic        reset_n,
    input  logic [2:0]  sel,
    input  logic [63:0] data_in,
    output logic        serial_out,
    output logic        serial_clk,
    output logic        active,
    output logic        done,
    output logic [6:0]  total_bits
);
    logic [63:0] shift_reg;
    logic [6:0] bits_remaining;

    function automatic [6:0] sel_to_width(input logic [2:0] s);
        begin
            case (s)
                3'b001: sel_to_width = 7'd8;
                3'b010: sel_to_width = 7'd16;
                3'b011: sel_to_width = 7'd32;
                3'b100: sel_to_width = 7'd64;
                default: sel_to_width = 7'd0;
            endcase
        end
    endfunction

    function automatic [63:0] mask_data(input logic [63:0] d, input logic [2:0] s);
        begin
            case (s)
                3'b001: mask_data = {56'd0, d[7:0]};
                3'b010: mask_data = {48'd0, d[15:0]};
                3'b011: mask_data = {32'd0, d[31:0]};
                3'b100: mask_data = d;
                default: mask_data = 64'd0;
            endcase
        end
    endfunction

    assign serial_clk = clk & active;
    assign serial_out = shift_reg[0];

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            shift_reg <= 64'd0;
            bits_remaining <= 7'd0;
            total_bits <= 7'd0;
            active <= 1'b0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!active) begin
                if (sel_to_width(sel) != 7'd0) begin
                    shift_reg <= mask_data(data_in, sel);
                    bits_remaining <= sel_to_width(sel);
                    total_bits <= sel_to_width(sel);
                    active <= 1'b1;
                end
            end else begin
                shift_reg <= {1'b0, shift_reg[63:1]};
                bits_remaining <= bits_remaining - 7'd1;

                if (bits_remaining == 7'd1) begin
                    active <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end

endmodule

module rx_block (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        serial_in,
    input  logic        serial_clk,
    input  logic        tx_active,
    input  logic [6:0]  total_bits,
    output logic        done,
    output logic [63:0] data_out
);
    logic [63:0] rx_shift;
    logic [6:0]  rx_count;
    logic [6:0]  rx_target;
    logic receiving;
    logic done_pending;

    always_ff @(posedge serial_clk or negedge reset_n) begin
        if (!reset_n) begin
            rx_shift <= 64'd0;
            rx_count <= 7'd0;
            rx_target <= 7'd0;
            receiving <= 1'b0;
            done <= 1'b0;
            done_pending <= 1'b0;
            data_out <= 64'd0;
        end else begin
            done <= 1'b0;

            if (!receiving && tx_active) begin
                receiving <= 1'b1;
                rx_count <= 7'd0;
                rx_target <= total_bits;
                rx_shift <= 64'd0;
            end

            if (receiving) begin
                rx_shift[rx_count] <= serial_in;
                rx_count <= rx_count + 7'd1;

                if ((rx_count + 7'd1) >= rx_target) begin
                    receiving <= 1'b0;
                    done_pending <= 1'b1;
                end
            end

            if (done_pending) begin
                done_pending <= 1'b0;
                done <= 1'b1;
                data_out <= rx_shift;
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
