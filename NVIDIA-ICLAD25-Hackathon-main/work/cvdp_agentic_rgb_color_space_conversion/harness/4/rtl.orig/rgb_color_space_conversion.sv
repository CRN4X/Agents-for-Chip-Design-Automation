module rgb_color_space_conversion (
    input               clk,
    input               rst,

    // Memory ports to initialize (1/delta) values
    input               we,
    input       [7:0]   waddr,
    input      [24:0]   wdata,

    // Input data with valid.
    input               valid_in,
    input       [7:0]   r_component,
    input       [7:0]   g_component,
    input       [7:0]   b_component,

    // HSV Output values
    output reg [11:0]   hsv_channel_h,  // Output in fx10.2 format, degree value = (hsv_channel_h)/4
    output reg [12:0]   hsv_channel_s,  // Output in fx1.12 format. % value = (hsv_channel_s/4096)*100
    output reg [11:0]   hsv_channel_v,  // % value = (hsv_channel_v/255) * 100

    // HSL Output values
    output reg [11:0]   hsl_channel_h,  // Output in fx10.2 format, degree value = (hsl_channel_h)/4
    output reg [12:0]   hsl_channel_s,  // Output in fx1.12 format. % value = (hsl_channel_s/4096)*100
    output reg [11:0]   hsl_channel_l,  // % value = (hsl_channel_l/255) * 100

    output reg          valid_out
);

    reg      [7:0]    valid_in_shreg;
    reg signed [12:0] pre_hue;
    reg      [11:0]   i_max, i_min, stage1_max, stage1_min, stage1_b;
    reg       [8:0]   hue_degrees_offset;
    reg       [2:0]   i_max_r, i_max_g, i_max_b;

    reg      [12:0]   g_sub_b_shreg;
    reg      [12:0]   b_sub_r_shreg;
    reg      [12:0]   r_sub_g_shreg;
    reg      [11:0]   i_max_shreg;
    reg      [11:0]   i_min_shreg;

    wire     [12:0]   saturation_result;
    wire     [12:0]   hsl_saturation_result;
    wire     [24:0]   inv_i_max, inv_delta_i;
    wire     [11:0]   almost_hue;
    reg signed [11:0] hue;

    assign valid_out = valid_in_shreg[7];
    assign hsv_channel_h = hue;
    assign hsv_channel_s = saturation_result;
    assign hsv_channel_v = i_max;
    
    assign hsl_channel_h = hue;
    assign hsl_channel_s = hsl_saturation_result;

    reg signed [12:0] g_sub_b, b_sub_r, r_sub_g, delta_i, max_plus_min;

    // Internally upscaled 12-bit values for fixed point precision
    wire [11:0] r_scaled = {4'b0000, r_component}; // Scale 8-bit to 12-bit
    wire [11:0] g_scaled = {4'b0000, g_component}; // Scale 8-bit to 12-bit
    wire [11:0] b_scaled = {4'b0000, b_component}; // Scale 8-bit to 12-bit

    // Subtraction logic, to find difference of inputs and delta value
    // Calculate g-b, b-r, r-g and max-min values to be used in h calculation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            g_sub_b <= 13'd0;
            b_sub_r <= 13'd0;
            r_sub_g <= 13'd0;
            delta_i <= 13'd0;
            max_plus_min <= 13'd0;
        end else begin
            g_sub_b <= $signed(g_scaled) - $signed(b_scaled);
            b_sub_r <= $signed(b_scaled) - $signed(r_scaled);
            r_sub_g <= $signed(r_scaled) - $signed(g_scaled);
            delta_i <= $signed(i_max) - $signed(i_min);
            max_plus_min <= $signed(i_max) + $signed(i_min);
        end
    end

    ////////////////////////////// HSL Channel Calculations ///////
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hsl_channel_l <= 'd0;
        end else begin
            hsl_channel_l <= max_plus_min[12:1]; // Divide by 2.. ignoring fraction part.
        end
    end

    wire [8:0]  double_L;               // 9-bit to handle overflow (max 510)
    reg  [8:0]  abs_2L_255;             // Absolute difference result
    wire [8:0]  hsl_channel_s_denom;    // 1-|2L-1|. This is Denominator of s formula
    wire [24:0] inv_hsl_channel_s_denom;// inverse of (1-|2L-1|).

    assign double_L = max_plus_min[8:0]; // Equivalent to L * 2 = i_max+i_min

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            abs_2L_255 <= 'd0;
        end else begin
            if (double_L >= 9'd255)
                abs_2L_255 <= (double_L - 9'd255);
            else
                abs_2L_255 <= (9'd255 - double_L);
        end
    end
    
    assign hsl_channel_s_denom = 9'd255 - abs_2L_255;  // abs_2L_255 is always <= 254

    // Memory to store 1/delta values (256 values)
    // 0,1/1,1/2,1/3...1/255)
    // These values are used to multiply with (g-b)/(b-r)/(r-g) for calculation
    // h value. It is easy to store inverse values and do multiplication
    // than division.
    multi_port_ram inverse_component_inst (
        .clk(clk),
        .we(we),
        .waddr(waddr),
        .wdata(wdata),
        .raddr_a(i_max[7:0]),
        .rdata_a(inv_i_max),
        .raddr_b(delta_i[7:0]),
        .rdata_b(inv_delta_i),
        .raddr_c(hsl_channel_s_denom[7:0]),
        .rdata_c(inv_hsl_channel_s_denom)
    );

    // Pre hue constant multiplier for h calculation
    // Multiply with 60 degrees.
    // Used 2 stage pipeline
    localparam signed [6:0] CONST_60 = 7'd60;
    reg signed [18:0] pre_hue_prod;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pre_hue_prod <= 19'd0;
        end else begin
            pre_hue_prod <= pre_hue * CONST_60;
        end
    end

    // HSL Channel Saturation calculation multiplier
    saturation_mult hsl_saturation_mult_0 (
        .clk(clk),
        .rst(rst),
        .a(inv_hsl_channel_s_denom), // Read inverted value from memory port1
        .b(delta_i[7:0]),   // Delta value (max-min)
        .result(hsl_saturation_result)
    );

    // Saturation calculation multiplier
    saturation_mult hsv_saturation_mult_0 (
        .clk(clk),
        .rst(rst),
        .a(inv_i_max),               // Read inverted value from memory port1
        .b(delta_i[7:0]),  // Delta value (max-min)
        .result(saturation_result)
    );
   
    // h value calculation multiplier
    hue_mult hue_mult_inst (
        .clk(clk),
        .rst(rst),
        .dataa(pre_hue_prod),        // Product from constant 60 multiplication
        .datab(inv_delta_i),         // Read inverted data from memory port2
        .result(almost_hue)
    );

    // Final h value addition logic
    always @(posedge clk or posedge rst) begin
        if (rst)
            hue <= 'd0;
        else
            hue <= $signed(almost_hue) + $signed({1'b0, {hue_degrees_offset, 2'd0}});
    end

    // Pipelining registers to help in each stage of data processing
    // Help with multiplications and additions
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all registers and shift registers
            g_sub_b_shreg <= 0;
            b_sub_r_shreg <= 0;
            r_sub_g_shreg <= 0;
            i_max_shreg <= 0;
            i_min_shreg <= 0;
        end else begin
            // Normal operation when reset is not asserted
            g_sub_b_shreg <= g_sub_b;
            b_sub_r_shreg <= b_sub_r;
            r_sub_g_shreg <= r_sub_g;
            i_max_shreg <= i_max;
            i_min_shreg <= i_min;
        end
    end

    // Calculate max and min values
    // Shift valid in for total latency cycles
    // and assign to output valid when output data is ready
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_in_shreg <= 0;
            stage1_max <= 0;
            stage1_min <= 0;
            stage1_b <= 0;
            i_max_r <= 0;
            i_max_g <= 0;
            i_max_b <= 0;
            i_max <= 0;
            i_min <= 0;
        end else begin
            valid_in_shreg <= {valid_in_shreg[6:0], valid_in};
            i_max_r[2] <= i_max_r[1];
            i_max_g[2] <= i_max_g[1];
            i_max_b[2] <= i_max_b[1];

            if (valid_in) begin
                stage1_b <= b_component;
                if (r_component > g_component) begin
                    stage1_max <= r_component;
                    stage1_min <= g_component;
                    i_max_r[0] <= 1;
                    i_max_g[0] <= 0;
                    i_max_b[0] <= 0;
                end else begin
                    stage1_max <= g_component;
                    stage1_min <= r_component;
                    i_max_r[0] <= 0;
                    i_max_g[0] <= 1;
                    i_max_b[0] <= 0;
                end
            end

            if (valid_in_shreg[0]) begin
                if (stage1_max > stage1_b) begin
                    i_max      <= stage1_max;
                    i_max_r[1] <= i_max_r[0];
                    i_max_g[1] <= i_max_g[0];
                    i_max_b[1] <= i_max_b[0];
                end else begin
                    i_max      <= stage1_b;
                    i_max_r[1] <= 0;
                    i_max_g[1] <= 0;
                    i_max_b[1] <= 1;
                end

                if (stage1_min < stage1_b) i_min <= stage1_min;
                else                       i_min <= stage1_b;
            end
        end
    end

    // Select degree value to add for h calculation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pre_hue <= 'd0;
            hue_degrees_offset <= 'd0;
        end else begin
            if (valid_in_shreg[2]) begin
                if (i_max_shreg == i_min_shreg) begin
                    pre_hue <= 0;
                    hue_degrees_offset <= 9'd0;
                end else if ((i_max_r[2]) && (~g_sub_b_shreg[12])) begin
                    pre_hue <= g_sub_b_shreg;
                    hue_degrees_offset <= 9'd0;
                end else if ((i_max_r[2]) && (g_sub_b_shreg[12])) begin
                    pre_hue <= g_sub_b_shreg;
                    hue_degrees_offset <= 9'd360;
                end else if (i_max_g[2]) begin
                    pre_hue <= b_sub_r_shreg;
                    hue_degrees_offset <= 9'd120;
                end else if (i_max_b[2]) begin
                    pre_hue <= r_sub_g_shreg;
                    hue_degrees_offset <= 9'd240;
                end
            end
        end
    end
endmodule

// Write port to initialize 1/delta values, and two read ports.
// 1. Read port --> read 1/delta address
// 2. Read port --> read 1/max address
// 3. Read port --> read 1/hsl_channel_s_denom
// Memory is used to store inverted values (0 to 1/255) such that multiplication can be
// performed easily than division.
module multi_port_ram (
    input               clk,
    input               we,
    input       [7:0]   waddr,
    input      [24:0]   wdata,
    input       [7:0]   raddr_a,
    output reg [24:0]   rdata_a,
    input       [7:0]   raddr_b,
    output reg [24:0]   rdata_b,
    input       [7:0]   raddr_c,
    output reg [24:0]   rdata_c
);

    reg [24:0] ram [0:255];

    always @(posedge clk) begin
        if (we) begin
            ram[waddr] <= wdata;
        end
    end

    always @(posedge clk) begin
        rdata_a <= ram[raddr_a];
    end

    always @(posedge clk) begin
        rdata_b <= ram[raddr_b];
    end
   
    always @(posedge clk) begin
        rdata_c <= ram[raddr_c];
    end
endmodule

// This is used to multiply delta value with inverted cmax value from memory
// (used to calculate s, saturation)
module saturation_mult (
    input  wire         clk,
    input  wire         rst,
    input  wire [24:0]  a,
    input  wire [7:0]   b,
    output [12:0]       result
);

    reg [24:0] A_reg;
    reg [7:0] B_reg;
    reg [30:0] mult_result;
    reg [18:0] rounded_result;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            A_reg <= 25'd0;
            B_reg <= 8'd0;
        end else begin
            A_reg <= a;
            B_reg <= b;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mult_result <= 'd0;
        end else begin
            mult_result <= A_reg * B_reg;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rounded_result <= 'd0;
        end else begin
            rounded_result <= mult_result[30:12] + mult_result[11];
        end
    end

    assign result = rounded_result[12:0];
endmodule

//used for h, hue calculation
module hue_mult (
    input               clk,
    input               rst,
    input signed [18:0] dataa,
    input      [24:0]   datab,
    output reg signed [11:0] result
);

    reg signed [43:0] mult_stage1;

    always @(posedge clk or posedge rst) begin
        if (rst)
            mult_stage1 <= 44'd0;
        else
            mult_stage1 <= $signed(dataa) * $signed({1'b0, datab});
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            result <= 12'd0;
        else
            result <= mult_stage1[33:22];
    end
endmodule