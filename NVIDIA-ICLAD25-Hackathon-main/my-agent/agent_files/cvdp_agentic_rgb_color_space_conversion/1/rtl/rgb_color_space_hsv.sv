`timescale 1ns/1ns

module rgb_color_space_hsv (
    input               clk,
    input               rst,
    input               we,
    input       [7:0]   waddr,
    input      [24:0]   wdata,
    input               valid_in,
    input       [7:0]   r_component,
    input       [7:0]   g_component,
    input       [7:0]   b_component,
    output reg [11:0]   h_component,
    output reg [12:0]   s_component,
    output reg [11:0]   v_component,
    output reg          valid_out
);

    reg [24:0] inv_lut [0:255];
    integer i;
    integer r_i, g_i, b_i;
    integer cmax, cmin, delta;
    integer s_tmp;
    real r_p, g_p, b_p;
    real cmax_r, cmin_r, delta_r;
    real h_r;
    integer h_fx;

    reg valid_d;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_d     <= 1'b0;
            valid_out   <= 1'b0;
            h_component <= 12'd0;
            s_component <= 13'd0;
            v_component <= 12'd0;
            for (i = 0; i < 256; i = i + 1) begin
                inv_lut[i] <= 25'd0;
            end
        end else begin
            if (we) begin
                inv_lut[waddr] <= wdata;
            end

            valid_out <= valid_d;
            valid_d   <= valid_in;

            if (valid_in) begin
                r_i = r_component;
                g_i = g_component;
                b_i = b_component;

                cmax = r_i;
                if (g_i > cmax) cmax = g_i;
                if (b_i > cmax) cmax = b_i;

                cmin = r_i;
                if (g_i < cmin) cmin = g_i;
                if (b_i < cmin) cmin = b_i;

                delta = cmax - cmin;
                v_component <= cmax[11:0];

                if (cmax == 0) begin
                    s_component <= 13'd0;
                end else begin
                    s_tmp = ((delta * 4096) + (cmax / 2)) / cmax;
                    if (s_tmp < 0) s_tmp = 0;
                    if (s_tmp > 8191) s_tmp = 8191;
                    s_component <= s_tmp[12:0];
                end

                if (delta == 0) begin
                    h_component <= 12'd0;
                end else begin
                    r_p = r_i / 255.0;
                    g_p = g_i / 255.0;
                    b_p = b_i / 255.0;

                    cmax_r = r_p;
                    if (g_p > cmax_r) cmax_r = g_p;
                    if (b_p > cmax_r) cmax_r = b_p;

                    cmin_r = r_p;
                    if (g_p < cmin_r) cmin_r = g_p;
                    if (b_p < cmin_r) cmin_r = b_p;

                    delta_r = cmax_r - cmin_r;

                    if (delta_r == 0.0) begin
                        h_r = 0.0;
                    end else if (cmax_r == r_p) begin
                        h_r = 60.0 * ((g_p - b_p) / delta_r);
                        while (h_r < 0.0) h_r = h_r + 360.0;
                        while (h_r >= 360.0) h_r = h_r - 360.0;
                    end else if (cmax_r == g_p) begin
                        h_r = 60.0 * ((b_p - r_p) / delta_r) + 120.0;
                        while (h_r < 0.0) h_r = h_r + 360.0;
                        while (h_r >= 360.0) h_r = h_r - 360.0;
                    end else begin
                        h_r = 60.0 * ((r_p - g_p) / delta_r) + 240.0;
                        while (h_r < 0.0) h_r = h_r + 360.0;
                        while (h_r >= 360.0) h_r = h_r - 360.0;
                    end

                    h_fx = $rtoi((h_r * 4.0) + 0.5);
                    if (h_fx < 0) h_fx = 0;
                    if (h_fx > 1439) h_fx = h_fx % 1440;
                    h_component <= h_fx[11:0];
                end
            end
        end
    end

endmodule
