module aes128_encrypt #(
    parameter NBW_KEY  = 'd128,
    parameter NBW_DATA = 'd128
) (
    input  logic                clk,
    input  logic                rst_async_n,
    input  logic                i_update_key,
    input  logic [NBW_KEY-1:0]  i_key,
    input  logic                i_start,
    input  logic [NBW_DATA-1:0] i_data,
    output logic                o_done,
    output logic [NBW_DATA-1:0] o_data
);


logic [NBW_KEY-1:0] key_ff;

function automatic logic [7:0] sbox(input logic [7:0] x);
    case (x)
        8'h00: sbox = 8'h63;
        8'h01: sbox = 8'h7C;
        8'h02: sbox = 8'h77;
        8'h03: sbox = 8'h7B;
        8'h04: sbox = 8'hF2;
        8'h05: sbox = 8'h6B;
        8'h06: sbox = 8'h6F;
        8'h07: sbox = 8'hC5;
        8'h08: sbox = 8'h30;
        8'h09: sbox = 8'h01;
        8'h0A: sbox = 8'h67;
        8'h0B: sbox = 8'h2B;
        8'h0C: sbox = 8'hFE;
        8'h0D: sbox = 8'hD7;
        8'h0E: sbox = 8'hAB;
        8'h0F: sbox = 8'h76;
        8'h10: sbox = 8'hCA;
        8'h11: sbox = 8'h82;
        8'h12: sbox = 8'hC9;
        8'h13: sbox = 8'h7D;
        8'h14: sbox = 8'hFA;
        8'h15: sbox = 8'h59;
        8'h16: sbox = 8'h47;
        8'h17: sbox = 8'hF0;
        8'h18: sbox = 8'hAD;
        8'h19: sbox = 8'hD4;
        8'h1A: sbox = 8'hA2;
        8'h1B: sbox = 8'hAF;
        8'h1C: sbox = 8'h9C;
        8'h1D: sbox = 8'hA4;
        8'h1E: sbox = 8'h72;
        8'h1F: sbox = 8'hC0;
        8'h20: sbox = 8'hB7;
        8'h21: sbox = 8'hFD;
        8'h22: sbox = 8'h93;
        8'h23: sbox = 8'h26;
        8'h24: sbox = 8'h36;
        8'h25: sbox = 8'h3F;
        8'h26: sbox = 8'hF7;
        8'h27: sbox = 8'hCC;
        8'h28: sbox = 8'h34;
        8'h29: sbox = 8'hA5;
        8'h2A: sbox = 8'hE5;
        8'h2B: sbox = 8'hF1;
        8'h2C: sbox = 8'h71;
        8'h2D: sbox = 8'hD8;
        8'h2E: sbox = 8'h31;
        8'h2F: sbox = 8'h15;
        8'h30: sbox = 8'h04;
        8'h31: sbox = 8'hC7;
        8'h32: sbox = 8'h23;
        8'h33: sbox = 8'hC3;
        8'h34: sbox = 8'h18;
        8'h35: sbox = 8'h96;
        8'h36: sbox = 8'h05;
        8'h37: sbox = 8'h9A;
        8'h38: sbox = 8'h07;
        8'h39: sbox = 8'h12;
        8'h3A: sbox = 8'h80;
        8'h3B: sbox = 8'hE2;
        8'h3C: sbox = 8'hEB;
        8'h3D: sbox = 8'h27;
        8'h3E: sbox = 8'hB2;
        8'h3F: sbox = 8'h75;
        8'h40: sbox = 8'h09;
        8'h41: sbox = 8'h83;
        8'h42: sbox = 8'h2C;
        8'h43: sbox = 8'h1A;
        8'h44: sbox = 8'h1B;
        8'h45: sbox = 8'h6E;
        8'h46: sbox = 8'h5A;
        8'h47: sbox = 8'hA0;
        8'h48: sbox = 8'h52;
        8'h49: sbox = 8'h3B;
        8'h4A: sbox = 8'hD6;
        8'h4B: sbox = 8'hB3;
        8'h4C: sbox = 8'h29;
        8'h4D: sbox = 8'hE3;
        8'h4E: sbox = 8'h2F;
        8'h4F: sbox = 8'h84;
        8'h50: sbox = 8'h53;
        8'h51: sbox = 8'hD1;
        8'h52: sbox = 8'h00;
        8'h53: sbox = 8'hED;
        8'h54: sbox = 8'h20;
        8'h55: sbox = 8'hFC;
        8'h56: sbox = 8'hB1;
        8'h57: sbox = 8'h5B;
        8'h58: sbox = 8'h6A;
        8'h59: sbox = 8'hCB;
        8'h5A: sbox = 8'hBE;
        8'h5B: sbox = 8'h39;
        8'h5C: sbox = 8'h4A;
        8'h5D: sbox = 8'h4C;
        8'h5E: sbox = 8'h58;
        8'h5F: sbox = 8'hCF;
        8'h60: sbox = 8'hD0;
        8'h61: sbox = 8'hEF;
        8'h62: sbox = 8'hAA;
        8'h63: sbox = 8'hFB;
        8'h64: sbox = 8'h43;
        8'h65: sbox = 8'h4D;
        8'h66: sbox = 8'h33;
        8'h67: sbox = 8'h85;
        8'h68: sbox = 8'h45;
        8'h69: sbox = 8'hF9;
        8'h6A: sbox = 8'h02;
        8'h6B: sbox = 8'h7F;
        8'h6C: sbox = 8'h50;
        8'h6D: sbox = 8'h3C;
        8'h6E: sbox = 8'h9F;
        8'h6F: sbox = 8'hA8;
        8'h70: sbox = 8'h51;
        8'h71: sbox = 8'hA3;
        8'h72: sbox = 8'h40;
        8'h73: sbox = 8'h8F;
        8'h74: sbox = 8'h92;
        8'h75: sbox = 8'h9D;
        8'h76: sbox = 8'h38;
        8'h77: sbox = 8'hF5;
        8'h78: sbox = 8'hBC;
        8'h79: sbox = 8'hB6;
        8'h7A: sbox = 8'hDA;
        8'h7B: sbox = 8'h21;
        8'h7C: sbox = 8'h10;
        8'h7D: sbox = 8'hFF;
        8'h7E: sbox = 8'hF3;
        8'h7F: sbox = 8'hD2;
        8'h80: sbox = 8'hCD;
        8'h81: sbox = 8'h0C;
        8'h82: sbox = 8'h13;
        8'h83: sbox = 8'hEC;
        8'h84: sbox = 8'h5F;
        8'h85: sbox = 8'h97;
        8'h86: sbox = 8'h44;
        8'h87: sbox = 8'h17;
        8'h88: sbox = 8'hC4;
        8'h89: sbox = 8'hA7;
        8'h8A: sbox = 8'h7E;
        8'h8B: sbox = 8'h3D;
        8'h8C: sbox = 8'h64;
        8'h8D: sbox = 8'h5D;
        8'h8E: sbox = 8'h19;
        8'h8F: sbox = 8'h73;
        8'h90: sbox = 8'h60;
        8'h91: sbox = 8'h81;
        8'h92: sbox = 8'h4F;
        8'h93: sbox = 8'hDC;
        8'h94: sbox = 8'h22;
        8'h95: sbox = 8'h2A;
        8'h96: sbox = 8'h90;
        8'h97: sbox = 8'h88;
        8'h98: sbox = 8'h46;
        8'h99: sbox = 8'hEE;
        8'h9A: sbox = 8'hB8;
        8'h9B: sbox = 8'h14;
        8'h9C: sbox = 8'hDE;
        8'h9D: sbox = 8'h5E;
        8'h9E: sbox = 8'h0B;
        8'h9F: sbox = 8'hDB;
        8'hA0: sbox = 8'hE0;
        8'hA1: sbox = 8'h32;
        8'hA2: sbox = 8'h3A;
        8'hA3: sbox = 8'h0A;
        8'hA4: sbox = 8'h49;
        8'hA5: sbox = 8'h06;
        8'hA6: sbox = 8'h24;
        8'hA7: sbox = 8'h5C;
        8'hA8: sbox = 8'hC2;
        8'hA9: sbox = 8'hD3;
        8'hAA: sbox = 8'hAC;
        8'hAB: sbox = 8'h62;
        8'hAC: sbox = 8'h91;
        8'hAD: sbox = 8'h95;
        8'hAE: sbox = 8'hE4;
        8'hAF: sbox = 8'h79;
        8'hB0: sbox = 8'hE7;
        8'hB1: sbox = 8'hC8;
        8'hB2: sbox = 8'h37;
        8'hB3: sbox = 8'h6D;
        8'hB4: sbox = 8'h8D;
        8'hB5: sbox = 8'hD5;
        8'hB6: sbox = 8'h4E;
        8'hB7: sbox = 8'hA9;
        8'hB8: sbox = 8'h6C;
        8'hB9: sbox = 8'h56;
        8'hBA: sbox = 8'hF4;
        8'hBB: sbox = 8'hEA;
        8'hBC: sbox = 8'h65;
        8'hBD: sbox = 8'h7A;
        8'hBE: sbox = 8'hAE;
        8'hBF: sbox = 8'h08;
        8'hC0: sbox = 8'hBA;
        8'hC1: sbox = 8'h78;
        8'hC2: sbox = 8'h25;
        8'hC3: sbox = 8'h2E;
        8'hC4: sbox = 8'h1C;
        8'hC5: sbox = 8'hA6;
        8'hC6: sbox = 8'hB4;
        8'hC7: sbox = 8'hC6;
        8'hC8: sbox = 8'hE8;
        8'hC9: sbox = 8'hDD;
        8'hCA: sbox = 8'h74;
        8'hCB: sbox = 8'h1F;
        8'hCC: sbox = 8'h4B;
        8'hCD: sbox = 8'hBD;
        8'hCE: sbox = 8'h8B;
        8'hCF: sbox = 8'h8A;
        8'hD0: sbox = 8'h70;
        8'hD1: sbox = 8'h3E;
        8'hD2: sbox = 8'hB5;
        8'hD3: sbox = 8'h66;
        8'hD4: sbox = 8'h48;
        8'hD5: sbox = 8'h03;
        8'hD6: sbox = 8'hF6;
        8'hD7: sbox = 8'h0E;
        8'hD8: sbox = 8'h61;
        8'hD9: sbox = 8'h35;
        8'hDA: sbox = 8'h57;
        8'hDB: sbox = 8'hB9;
        8'hDC: sbox = 8'h86;
        8'hDD: sbox = 8'hC1;
        8'hDE: sbox = 8'h1D;
        8'hDF: sbox = 8'h9E;
        8'hE0: sbox = 8'hE1;
        8'hE1: sbox = 8'hF8;
        8'hE2: sbox = 8'h98;
        8'hE3: sbox = 8'h11;
        8'hE4: sbox = 8'h69;
        8'hE5: sbox = 8'hD9;
        8'hE6: sbox = 8'h8E;
        8'hE7: sbox = 8'h94;
        8'hE8: sbox = 8'h9B;
        8'hE9: sbox = 8'h1E;
        8'hEA: sbox = 8'h87;
        8'hEB: sbox = 8'hE9;
        8'hEC: sbox = 8'hCE;
        8'hED: sbox = 8'h55;
        8'hEE: sbox = 8'h28;
        8'hEF: sbox = 8'hDF;
        8'hF0: sbox = 8'h8C;
        8'hF1: sbox = 8'hA1;
        8'hF2: sbox = 8'h89;
        8'hF3: sbox = 8'h0D;
        8'hF4: sbox = 8'hBF;
        8'hF5: sbox = 8'hE6;
        8'hF6: sbox = 8'h42;
        8'hF7: sbox = 8'h68;
        8'hF8: sbox = 8'h41;
        8'hF9: sbox = 8'h99;
        8'hFA: sbox = 8'h2D;
        8'hFB: sbox = 8'h0F;
        8'hFC: sbox = 8'hB0;
        8'hFD: sbox = 8'h54;
        8'hFE: sbox = 8'hBB;
        8'hFF: sbox = 8'h16;
        default: sbox = 8'h00;
    endcase
endfunction

function automatic logic [7:0] xtime(input logic [7:0] x);
    if (x[7]) begin
        xtime = {x[6:0], 1'b0} ^ 8'h1B;
    end else begin
        xtime = {x[6:0], 1'b0};
    end
endfunction

function automatic logic [31:0] rot_word(input logic [31:0] w);
    rot_word = {w[23:0], w[31:24]};
endfunction

function automatic logic [31:0] sub_word(input logic [31:0] w);
    sub_word = {sbox(w[31:24]), sbox(w[23:16]), sbox(w[15:8]), sbox(w[7:0])};
endfunction

function automatic logic [NBW_DATA-1:0] aes_encrypt_block(
    input logic [NBW_DATA-1:0] data,
    input logic [NBW_KEY-1:0]  key
);
    logic [31:0] w [0:43];
    logic [7:0] state [0:3][0:3];
    logic [7:0] sh [0:3][0:3];
    logic [7:0] tmp0;
    logic [7:0] tmp1;
    logic [7:0] tmp2;
    logic [7:0] tmp3;
    logic [7:0] rcon [0:9];
    integer i;
    integer j;
    integer round;

    rcon[0] = 8'h01;
    rcon[1] = 8'h02;
    rcon[2] = 8'h04;
    rcon[3] = 8'h08;
    rcon[4] = 8'h10;
    rcon[5] = 8'h20;
    rcon[6] = 8'h40;
    rcon[7] = 8'h80;
    rcon[8] = 8'h1B;
    rcon[9] = 8'h36;

    w[0] = key[127:96];
    w[1] = key[95:64];
    w[2] = key[63:32];
    w[3] = key[31:0];

    for (i = 4; i < 44; i = i + 1) begin
        logic [31:0] temp;
        temp = w[i-1];
        if ((i % 4) == 0) begin
            temp = sub_word(rot_word(temp)) ^ {rcon[(i/4)-1], 24'h0};
        end
        w[i] = w[i-4] ^ temp;
    end

    for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
            state[i][j] = data[NBW_DATA-(4*j+i)*8-1 -: 8] ^ w[j][31-8*i -: 8];
        end
    end

    for (round = 1; round < 10; round = round + 1) begin
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                sh[i][j] = sbox(state[i][j]);
            end
        end

        tmp0 = sh[1][0];
        sh[1][0] = sh[1][1];
        sh[1][1] = sh[1][2];
        sh[1][2] = sh[1][3];
        sh[1][3] = tmp0;

        tmp0 = sh[2][0];
        tmp1 = sh[2][1];
        sh[2][0] = sh[2][2];
        sh[2][1] = sh[2][3];
        sh[2][2] = tmp0;
        sh[2][3] = tmp1;

        tmp0 = sh[3][0];
        sh[3][0] = sh[3][3];
        sh[3][3] = sh[3][2];
        sh[3][2] = sh[3][1];
        sh[3][1] = tmp0;

        for (j = 0; j < 4; j = j + 1) begin
            logic [7:0] a0;
            logic [7:0] a1;
            logic [7:0] a2;
            logic [7:0] a3;
            logic [7:0] t;
            a0 = sh[0][j];
            a1 = sh[1][j];
            a2 = sh[2][j];
            a3 = sh[3][j];
            t = a0 ^ a1 ^ a2 ^ a3;
            state[0][j] = a0 ^ t ^ xtime(a0 ^ a1);
            state[1][j] = a1 ^ t ^ xtime(a1 ^ a2);
            state[2][j] = a2 ^ t ^ xtime(a2 ^ a3);
            state[3][j] = a3 ^ t ^ xtime(a3 ^ a0);
        end

        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                state[i][j] = state[i][j] ^ w[round*4 + j][31-8*i -: 8];
            end
        end
    end

    for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
            sh[i][j] = sbox(state[i][j]);
        end
    end

    tmp0 = sh[1][0];
    sh[1][0] = sh[1][1];
    sh[1][1] = sh[1][2];
    sh[1][2] = sh[1][3];
    sh[1][3] = tmp0;

    tmp0 = sh[2][0];
    tmp1 = sh[2][1];
    sh[2][0] = sh[2][2];
    sh[2][1] = sh[2][3];
    sh[2][2] = tmp0;
    sh[2][3] = tmp1;

    tmp0 = sh[3][0];
    sh[3][0] = sh[3][3];
    sh[3][3] = sh[3][2];
    sh[3][2] = sh[3][1];
    sh[3][1] = tmp0;

    for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
            state[i][j] = sh[i][j] ^ w[40 + j][31-8*i -: 8];
            aes_encrypt_block[NBW_DATA-(4*j+i)*8-1 -: 8] = state[i][j];
        end
    end
endfunction

assign o_done = 1'b1;

always_ff @(posedge clk or negedge rst_async_n) begin
    logic [NBW_KEY-1:0] key_use;
    if (!rst_async_n) begin
        key_ff <= {NBW_KEY{1'b0}};
        o_data <= {NBW_DATA{1'b0}};
    end else begin
        if (i_update_key) begin
            key_ff <= i_key;
        end

        if (i_start) begin
            if (i_update_key) begin
                key_use = i_key;
            end else begin
                key_use = key_ff;
            end
            o_data <= aes_encrypt_block(i_data, key_use);
        end
    end
end

endmodule : aes128_encrypt

module sbox_enc (
    input  logic [7:0] i_data,
    output logic [7:0] o_data
);

always_comb begin
    case (i_data)
        8'h00: o_data = 8'h63;
        8'h01: o_data = 8'h7C;
        8'h02: o_data = 8'h77;
        8'h03: o_data = 8'h7B;
        8'h04: o_data = 8'hF2;
        8'h05: o_data = 8'h6B;
        8'h06: o_data = 8'h6F;
        8'h07: o_data = 8'hC5;
        8'h08: o_data = 8'h30;
        8'h09: o_data = 8'h01;
        8'h0A: o_data = 8'h67;
        8'h0B: o_data = 8'h2B;
        8'h0C: o_data = 8'hFE;
        8'h0D: o_data = 8'hD7;
        8'h0E: o_data = 8'hAB;
        8'h0F: o_data = 8'h76;
        8'h10: o_data = 8'hCA;
        8'h11: o_data = 8'h82;
        8'h12: o_data = 8'hC9;
        8'h13: o_data = 8'h7D;
        8'h14: o_data = 8'hFA;
        8'h15: o_data = 8'h59;
        8'h16: o_data = 8'h47;
        8'h17: o_data = 8'hF0;
        8'h18: o_data = 8'hAD;
        8'h19: o_data = 8'hD4;
        8'h1A: o_data = 8'hA2;
        8'h1B: o_data = 8'hAF;
        8'h1C: o_data = 8'h9C;
        8'h1D: o_data = 8'hA4;
        8'h1E: o_data = 8'h72;
        8'h1F: o_data = 8'hC0;
        8'h20: o_data = 8'hB7;
        8'h21: o_data = 8'hFD;
        8'h22: o_data = 8'h93;
        8'h23: o_data = 8'h26;
        8'h24: o_data = 8'h36;
        8'h25: o_data = 8'h3F;
        8'h26: o_data = 8'hF7;
        8'h27: o_data = 8'hCC;
        8'h28: o_data = 8'h34;
        8'h29: o_data = 8'hA5;
        8'h2A: o_data = 8'hE5;
        8'h2B: o_data = 8'hF1;
        8'h2C: o_data = 8'h71;
        8'h2D: o_data = 8'hD8;
        8'h2E: o_data = 8'h31;
        8'h2F: o_data = 8'h15;
        8'h30: o_data = 8'h04;
        8'h31: o_data = 8'hC7;
        8'h32: o_data = 8'h23;
        8'h33: o_data = 8'hC3;
        8'h34: o_data = 8'h18;
        8'h35: o_data = 8'h96;
        8'h36: o_data = 8'h05;
        8'h37: o_data = 8'h9A;
        8'h38: o_data = 8'h07;
        8'h39: o_data = 8'h12;
        8'h3A: o_data = 8'h80;
        8'h3B: o_data = 8'hE2;
        8'h3C: o_data = 8'hEB;
        8'h3D: o_data = 8'h27;
        8'h3E: o_data = 8'hB2;
        8'h3F: o_data = 8'h75;
        8'h40: o_data = 8'h09;
        8'h41: o_data = 8'h83;
        8'h42: o_data = 8'h2C;
        8'h43: o_data = 8'h1A;
        8'h44: o_data = 8'h1B;
        8'h45: o_data = 8'h6E;
        8'h46: o_data = 8'h5A;
        8'h47: o_data = 8'hA0;
        8'h48: o_data = 8'h52;
        8'h49: o_data = 8'h3B;
        8'h4A: o_data = 8'hD6;
        8'h4B: o_data = 8'hB3;
        8'h4C: o_data = 8'h29;
        8'h4D: o_data = 8'hE3;
        8'h4E: o_data = 8'h2F;
        8'h4F: o_data = 8'h84;
        8'h50: o_data = 8'h53;
        8'h51: o_data = 8'hD1;
        8'h52: o_data = 8'h00;
        8'h53: o_data = 8'hED;
        8'h54: o_data = 8'h20;
        8'h55: o_data = 8'hFC;
        8'h56: o_data = 8'hB1;
        8'h57: o_data = 8'h5B;
        8'h58: o_data = 8'h6A;
        8'h59: o_data = 8'hCB;
        8'h5A: o_data = 8'hBE;
        8'h5B: o_data = 8'h39;
        8'h5C: o_data = 8'h4A;
        8'h5D: o_data = 8'h4C;
        8'h5E: o_data = 8'h58;
        8'h5F: o_data = 8'hCF;
        8'h60: o_data = 8'hD0;
        8'h61: o_data = 8'hEF;
        8'h62: o_data = 8'hAA;
        8'h63: o_data = 8'hFB;
        8'h64: o_data = 8'h43;
        8'h65: o_data = 8'h4D;
        8'h66: o_data = 8'h33;
        8'h67: o_data = 8'h85;
        8'h68: o_data = 8'h45;
        8'h69: o_data = 8'hF9;
        8'h6A: o_data = 8'h02;
        8'h6B: o_data = 8'h7F;
        8'h6C: o_data = 8'h50;
        8'h6D: o_data = 8'h3C;
        8'h6E: o_data = 8'h9F;
        8'h6F: o_data = 8'hA8;
        8'h70: o_data = 8'h51;
        8'h71: o_data = 8'hA3;
        8'h72: o_data = 8'h40;
        8'h73: o_data = 8'h8F;
        8'h74: o_data = 8'h92;
        8'h75: o_data = 8'h9D;
        8'h76: o_data = 8'h38;
        8'h77: o_data = 8'hF5;
        8'h78: o_data = 8'hBC;
        8'h79: o_data = 8'hB6;
        8'h7A: o_data = 8'hDA;
        8'h7B: o_data = 8'h21;
        8'h7C: o_data = 8'h10;
        8'h7D: o_data = 8'hFF;
        8'h7E: o_data = 8'hF3;
        8'h7F: o_data = 8'hD2;
        8'h80: o_data = 8'hCD;
        8'h81: o_data = 8'h0C;
        8'h82: o_data = 8'h13;
        8'h83: o_data = 8'hEC;
        8'h84: o_data = 8'h5F;
        8'h85: o_data = 8'h97;
        8'h86: o_data = 8'h44;
        8'h87: o_data = 8'h17;
        8'h88: o_data = 8'hC4;
        8'h89: o_data = 8'hA7;
        8'h8A: o_data = 8'h7E;
        8'h8B: o_data = 8'h3D;
        8'h8C: o_data = 8'h64;
        8'h8D: o_data = 8'h5D;
        8'h8E: o_data = 8'h19;
        8'h8F: o_data = 8'h73;
        8'h90: o_data = 8'h60;
        8'h91: o_data = 8'h81;
        8'h92: o_data = 8'h4F;
        8'h93: o_data = 8'hDC;
        8'h94: o_data = 8'h22;
        8'h95: o_data = 8'h2A;
        8'h96: o_data = 8'h90;
        8'h97: o_data = 8'h88;
        8'h98: o_data = 8'h46;
        8'h99: o_data = 8'hEE;
        8'h9A: o_data = 8'hB8;
        8'h9B: o_data = 8'h14;
        8'h9C: o_data = 8'hDE;
        8'h9D: o_data = 8'h5E;
        8'h9E: o_data = 8'h0B;
        8'h9F: o_data = 8'hDB;
        8'hA0: o_data = 8'hE0;
        8'hA1: o_data = 8'h32;
        8'hA2: o_data = 8'h3A;
        8'hA3: o_data = 8'h0A;
        8'hA4: o_data = 8'h49;
        8'hA5: o_data = 8'h06;
        8'hA6: o_data = 8'h24;
        8'hA7: o_data = 8'h5C;
        8'hA8: o_data = 8'hC2;
        8'hA9: o_data = 8'hD3;
        8'hAA: o_data = 8'hAC;
        8'hAB: o_data = 8'h62;
        8'hAC: o_data = 8'h91;
        8'hAD: o_data = 8'h95;
        8'hAE: o_data = 8'hE4;
        8'hAF: o_data = 8'h79;
        8'hB0: o_data = 8'hE7;
        8'hB1: o_data = 8'hC8;
        8'hB2: o_data = 8'h37;
        8'hB3: o_data = 8'h6D;
        8'hB4: o_data = 8'h8D;
        8'hB5: o_data = 8'hD5;
        8'hB6: o_data = 8'h4E;
        8'hB7: o_data = 8'hA9;
        8'hB8: o_data = 8'h6C;
        8'hB9: o_data = 8'h56;
        8'hBA: o_data = 8'hF4;
        8'hBB: o_data = 8'hEA;
        8'hBC: o_data = 8'h65;
        8'hBD: o_data = 8'h7A;
        8'hBE: o_data = 8'hAE;
        8'hBF: o_data = 8'h08;
        8'hC0: o_data = 8'hBA;
        8'hC1: o_data = 8'h78;
        8'hC2: o_data = 8'h25;
        8'hC3: o_data = 8'h2E;
        8'hC4: o_data = 8'h1C;
        8'hC5: o_data = 8'hA6;
        8'hC6: o_data = 8'hB4;
        8'hC7: o_data = 8'hC6;
        8'hC8: o_data = 8'hE8;
        8'hC9: o_data = 8'hDD;
        8'hCA: o_data = 8'h74;
        8'hCB: o_data = 8'h1F;
        8'hCC: o_data = 8'h4B;
        8'hCD: o_data = 8'hBD;
        8'hCE: o_data = 8'h8B;
        8'hCF: o_data = 8'h8A;
        8'hD0: o_data = 8'h70;
        8'hD1: o_data = 8'h3E;
        8'hD2: o_data = 8'hB5;
        8'hD3: o_data = 8'h66;
        8'hD4: o_data = 8'h48;
        8'hD5: o_data = 8'h03;
        8'hD6: o_data = 8'hF6;
        8'hD7: o_data = 8'h0E;
        8'hD8: o_data = 8'h61;
        8'hD9: o_data = 8'h35;
        8'hDA: o_data = 8'h57;
        8'hDB: o_data = 8'hB9;
        8'hDC: o_data = 8'h86;
        8'hDD: o_data = 8'hC1;
        8'hDE: o_data = 8'h1D;
        8'hDF: o_data = 8'h9E;
        8'hE0: o_data = 8'hE1;
        8'hE1: o_data = 8'hF8;
        8'hE2: o_data = 8'h98;
        8'hE3: o_data = 8'h11;
        8'hE4: o_data = 8'h69;
        8'hE5: o_data = 8'hD9;
        8'hE6: o_data = 8'h8E;
        8'hE7: o_data = 8'h94;
        8'hE8: o_data = 8'h9B;
        8'hE9: o_data = 8'h1E;
        8'hEA: o_data = 8'h87;
        8'hEB: o_data = 8'hE9;
        8'hEC: o_data = 8'hCE;
        8'hED: o_data = 8'h55;
        8'hEE: o_data = 8'h28;
        8'hEF: o_data = 8'hDF;
        8'hF0: o_data = 8'h8C;
        8'hF1: o_data = 8'hA1;
        8'hF2: o_data = 8'h89;
        8'hF3: o_data = 8'h0D;
        8'hF4: o_data = 8'hBF;
        8'hF5: o_data = 8'hE6;
        8'hF6: o_data = 8'h42;
        8'hF7: o_data = 8'h68;
        8'hF8: o_data = 8'h41;
        8'hF9: o_data = 8'h99;
        8'hFA: o_data = 8'h2D;
        8'hFB: o_data = 8'h0F;
        8'hFC: o_data = 8'hB0;
        8'hFD: o_data = 8'h54;
        8'hFE: o_data = 8'hBB;
        8'hFF: o_data = 8'h16;
        default: o_data = 8'h00;
    endcase
end

endmodule : sbox_enc
