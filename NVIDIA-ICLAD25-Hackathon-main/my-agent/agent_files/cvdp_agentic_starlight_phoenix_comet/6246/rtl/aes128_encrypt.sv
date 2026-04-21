`timescale 1ns/1ns

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

localparam NBW_EX_KEY = 1408;

logic [NBW_EX_KEY-1:0] expanded_key_ff;
logic [NBW_EX_KEY-1:0] expanded_key_input;
logic [NBW_EX_KEY-1:0] expanded_key_sel;
logic [NBW_DATA-1:0]   cipher_next;
logic [NBW_DATA-1:0]   cipher_pending_ff;

function automatic [7:0] sbox_lookup(input [7:0] b);
    case (b)
        8'h00: sbox_lookup = 8'h63;
        8'h01: sbox_lookup = 8'h7C;
        8'h02: sbox_lookup = 8'h77;
        8'h03: sbox_lookup = 8'h7B;
        8'h04: sbox_lookup = 8'hF2;
        8'h05: sbox_lookup = 8'h6B;
        8'h06: sbox_lookup = 8'h6F;
        8'h07: sbox_lookup = 8'hC5;
        8'h08: sbox_lookup = 8'h30;
        8'h09: sbox_lookup = 8'h01;
        8'h0A: sbox_lookup = 8'h67;
        8'h0B: sbox_lookup = 8'h2B;
        8'h0C: sbox_lookup = 8'hFE;
        8'h0D: sbox_lookup = 8'hD7;
        8'h0E: sbox_lookup = 8'hAB;
        8'h0F: sbox_lookup = 8'h76;
        8'h10: sbox_lookup = 8'hCA;
        8'h11: sbox_lookup = 8'h82;
        8'h12: sbox_lookup = 8'hC9;
        8'h13: sbox_lookup = 8'h7D;
        8'h14: sbox_lookup = 8'hFA;
        8'h15: sbox_lookup = 8'h59;
        8'h16: sbox_lookup = 8'h47;
        8'h17: sbox_lookup = 8'hF0;
        8'h18: sbox_lookup = 8'hAD;
        8'h19: sbox_lookup = 8'hD4;
        8'h1A: sbox_lookup = 8'hA2;
        8'h1B: sbox_lookup = 8'hAF;
        8'h1C: sbox_lookup = 8'h9C;
        8'h1D: sbox_lookup = 8'hA4;
        8'h1E: sbox_lookup = 8'h72;
        8'h1F: sbox_lookup = 8'hC0;
        8'h20: sbox_lookup = 8'hB7;
        8'h21: sbox_lookup = 8'hFD;
        8'h22: sbox_lookup = 8'h93;
        8'h23: sbox_lookup = 8'h26;
        8'h24: sbox_lookup = 8'h36;
        8'h25: sbox_lookup = 8'h3F;
        8'h26: sbox_lookup = 8'hF7;
        8'h27: sbox_lookup = 8'hCC;
        8'h28: sbox_lookup = 8'h34;
        8'h29: sbox_lookup = 8'hA5;
        8'h2A: sbox_lookup = 8'hE5;
        8'h2B: sbox_lookup = 8'hF1;
        8'h2C: sbox_lookup = 8'h71;
        8'h2D: sbox_lookup = 8'hD8;
        8'h2E: sbox_lookup = 8'h31;
        8'h2F: sbox_lookup = 8'h15;
        8'h30: sbox_lookup = 8'h04;
        8'h31: sbox_lookup = 8'hC7;
        8'h32: sbox_lookup = 8'h23;
        8'h33: sbox_lookup = 8'hC3;
        8'h34: sbox_lookup = 8'h18;
        8'h35: sbox_lookup = 8'h96;
        8'h36: sbox_lookup = 8'h05;
        8'h37: sbox_lookup = 8'h9A;
        8'h38: sbox_lookup = 8'h07;
        8'h39: sbox_lookup = 8'h12;
        8'h3A: sbox_lookup = 8'h80;
        8'h3B: sbox_lookup = 8'hE2;
        8'h3C: sbox_lookup = 8'hEB;
        8'h3D: sbox_lookup = 8'h27;
        8'h3E: sbox_lookup = 8'hB2;
        8'h3F: sbox_lookup = 8'h75;
        8'h40: sbox_lookup = 8'h09;
        8'h41: sbox_lookup = 8'h83;
        8'h42: sbox_lookup = 8'h2C;
        8'h43: sbox_lookup = 8'h1A;
        8'h44: sbox_lookup = 8'h1B;
        8'h45: sbox_lookup = 8'h6E;
        8'h46: sbox_lookup = 8'h5A;
        8'h47: sbox_lookup = 8'hA0;
        8'h48: sbox_lookup = 8'h52;
        8'h49: sbox_lookup = 8'h3B;
        8'h4A: sbox_lookup = 8'hD6;
        8'h4B: sbox_lookup = 8'hB3;
        8'h4C: sbox_lookup = 8'h29;
        8'h4D: sbox_lookup = 8'hE3;
        8'h4E: sbox_lookup = 8'h2F;
        8'h4F: sbox_lookup = 8'h84;
        8'h50: sbox_lookup = 8'h53;
        8'h51: sbox_lookup = 8'hD1;
        8'h52: sbox_lookup = 8'h00;
        8'h53: sbox_lookup = 8'hED;
        8'h54: sbox_lookup = 8'h20;
        8'h55: sbox_lookup = 8'hFC;
        8'h56: sbox_lookup = 8'hB1;
        8'h57: sbox_lookup = 8'h5B;
        8'h58: sbox_lookup = 8'h6A;
        8'h59: sbox_lookup = 8'hCB;
        8'h5A: sbox_lookup = 8'hBE;
        8'h5B: sbox_lookup = 8'h39;
        8'h5C: sbox_lookup = 8'h4A;
        8'h5D: sbox_lookup = 8'h4C;
        8'h5E: sbox_lookup = 8'h58;
        8'h5F: sbox_lookup = 8'hCF;
        8'h60: sbox_lookup = 8'hD0;
        8'h61: sbox_lookup = 8'hEF;
        8'h62: sbox_lookup = 8'hAA;
        8'h63: sbox_lookup = 8'hFB;
        8'h64: sbox_lookup = 8'h43;
        8'h65: sbox_lookup = 8'h4D;
        8'h66: sbox_lookup = 8'h33;
        8'h67: sbox_lookup = 8'h85;
        8'h68: sbox_lookup = 8'h45;
        8'h69: sbox_lookup = 8'hF9;
        8'h6A: sbox_lookup = 8'h02;
        8'h6B: sbox_lookup = 8'h7F;
        8'h6C: sbox_lookup = 8'h50;
        8'h6D: sbox_lookup = 8'h3C;
        8'h6E: sbox_lookup = 8'h9F;
        8'h6F: sbox_lookup = 8'hA8;
        8'h70: sbox_lookup = 8'h51;
        8'h71: sbox_lookup = 8'hA3;
        8'h72: sbox_lookup = 8'h40;
        8'h73: sbox_lookup = 8'h8F;
        8'h74: sbox_lookup = 8'h92;
        8'h75: sbox_lookup = 8'h9D;
        8'h76: sbox_lookup = 8'h38;
        8'h77: sbox_lookup = 8'hF5;
        8'h78: sbox_lookup = 8'hBC;
        8'h79: sbox_lookup = 8'hB6;
        8'h7A: sbox_lookup = 8'hDA;
        8'h7B: sbox_lookup = 8'h21;
        8'h7C: sbox_lookup = 8'h10;
        8'h7D: sbox_lookup = 8'hFF;
        8'h7E: sbox_lookup = 8'hF3;
        8'h7F: sbox_lookup = 8'hD2;
        8'h80: sbox_lookup = 8'hCD;
        8'h81: sbox_lookup = 8'h0C;
        8'h82: sbox_lookup = 8'h13;
        8'h83: sbox_lookup = 8'hEC;
        8'h84: sbox_lookup = 8'h5F;
        8'h85: sbox_lookup = 8'h97;
        8'h86: sbox_lookup = 8'h44;
        8'h87: sbox_lookup = 8'h17;
        8'h88: sbox_lookup = 8'hC4;
        8'h89: sbox_lookup = 8'hA7;
        8'h8A: sbox_lookup = 8'h7E;
        8'h8B: sbox_lookup = 8'h3D;
        8'h8C: sbox_lookup = 8'h64;
        8'h8D: sbox_lookup = 8'h5D;
        8'h8E: sbox_lookup = 8'h19;
        8'h8F: sbox_lookup = 8'h73;
        8'h90: sbox_lookup = 8'h60;
        8'h91: sbox_lookup = 8'h81;
        8'h92: sbox_lookup = 8'h4F;
        8'h93: sbox_lookup = 8'hDC;
        8'h94: sbox_lookup = 8'h22;
        8'h95: sbox_lookup = 8'h2A;
        8'h96: sbox_lookup = 8'h90;
        8'h97: sbox_lookup = 8'h88;
        8'h98: sbox_lookup = 8'h46;
        8'h99: sbox_lookup = 8'hEE;
        8'h9A: sbox_lookup = 8'hB8;
        8'h9B: sbox_lookup = 8'h14;
        8'h9C: sbox_lookup = 8'hDE;
        8'h9D: sbox_lookup = 8'h5E;
        8'h9E: sbox_lookup = 8'h0B;
        8'h9F: sbox_lookup = 8'hDB;
        8'hA0: sbox_lookup = 8'hE0;
        8'hA1: sbox_lookup = 8'h32;
        8'hA2: sbox_lookup = 8'h3A;
        8'hA3: sbox_lookup = 8'h0A;
        8'hA4: sbox_lookup = 8'h49;
        8'hA5: sbox_lookup = 8'h06;
        8'hA6: sbox_lookup = 8'h24;
        8'hA7: sbox_lookup = 8'h5C;
        8'hA8: sbox_lookup = 8'hC2;
        8'hA9: sbox_lookup = 8'hD3;
        8'hAA: sbox_lookup = 8'hAC;
        8'hAB: sbox_lookup = 8'h62;
        8'hAC: sbox_lookup = 8'h91;
        8'hAD: sbox_lookup = 8'h95;
        8'hAE: sbox_lookup = 8'hE4;
        8'hAF: sbox_lookup = 8'h79;
        8'hB0: sbox_lookup = 8'hE7;
        8'hB1: sbox_lookup = 8'hC8;
        8'hB2: sbox_lookup = 8'h37;
        8'hB3: sbox_lookup = 8'h6D;
        8'hB4: sbox_lookup = 8'h8D;
        8'hB5: sbox_lookup = 8'hD5;
        8'hB6: sbox_lookup = 8'h4E;
        8'hB7: sbox_lookup = 8'hA9;
        8'hB8: sbox_lookup = 8'h6C;
        8'hB9: sbox_lookup = 8'h56;
        8'hBA: sbox_lookup = 8'hF4;
        8'hBB: sbox_lookup = 8'hEA;
        8'hBC: sbox_lookup = 8'h65;
        8'hBD: sbox_lookup = 8'h7A;
        8'hBE: sbox_lookup = 8'hAE;
        8'hBF: sbox_lookup = 8'h08;
        8'hC0: sbox_lookup = 8'hBA;
        8'hC1: sbox_lookup = 8'h78;
        8'hC2: sbox_lookup = 8'h25;
        8'hC3: sbox_lookup = 8'h2E;
        8'hC4: sbox_lookup = 8'h1C;
        8'hC5: sbox_lookup = 8'hA6;
        8'hC6: sbox_lookup = 8'hB4;
        8'hC7: sbox_lookup = 8'hC6;
        8'hC8: sbox_lookup = 8'hE8;
        8'hC9: sbox_lookup = 8'hDD;
        8'hCA: sbox_lookup = 8'h74;
        8'hCB: sbox_lookup = 8'h1F;
        8'hCC: sbox_lookup = 8'h4B;
        8'hCD: sbox_lookup = 8'hBD;
        8'hCE: sbox_lookup = 8'h8B;
        8'hCF: sbox_lookup = 8'h8A;
        8'hD0: sbox_lookup = 8'h70;
        8'hD1: sbox_lookup = 8'h3E;
        8'hD2: sbox_lookup = 8'hB5;
        8'hD3: sbox_lookup = 8'h66;
        8'hD4: sbox_lookup = 8'h48;
        8'hD5: sbox_lookup = 8'h03;
        8'hD6: sbox_lookup = 8'hF6;
        8'hD7: sbox_lookup = 8'h0E;
        8'hD8: sbox_lookup = 8'h61;
        8'hD9: sbox_lookup = 8'h35;
        8'hDA: sbox_lookup = 8'h57;
        8'hDB: sbox_lookup = 8'hB9;
        8'hDC: sbox_lookup = 8'h86;
        8'hDD: sbox_lookup = 8'hC1;
        8'hDE: sbox_lookup = 8'h1D;
        8'hDF: sbox_lookup = 8'h9E;
        8'hE0: sbox_lookup = 8'hE1;
        8'hE1: sbox_lookup = 8'hF8;
        8'hE2: sbox_lookup = 8'h98;
        8'hE3: sbox_lookup = 8'h11;
        8'hE4: sbox_lookup = 8'h69;
        8'hE5: sbox_lookup = 8'hD9;
        8'hE6: sbox_lookup = 8'h8E;
        8'hE7: sbox_lookup = 8'h94;
        8'hE8: sbox_lookup = 8'h9B;
        8'hE9: sbox_lookup = 8'h1E;
        8'hEA: sbox_lookup = 8'h87;
        8'hEB: sbox_lookup = 8'hE9;
        8'hEC: sbox_lookup = 8'hCE;
        8'hED: sbox_lookup = 8'h55;
        8'hEE: sbox_lookup = 8'h28;
        8'hEF: sbox_lookup = 8'hDF;
        8'hF0: sbox_lookup = 8'h8C;
        8'hF1: sbox_lookup = 8'hA1;
        8'hF2: sbox_lookup = 8'h89;
        8'hF3: sbox_lookup = 8'h0D;
        8'hF4: sbox_lookup = 8'hBF;
        8'hF5: sbox_lookup = 8'hE6;
        8'hF6: sbox_lookup = 8'h42;
        8'hF7: sbox_lookup = 8'h68;
        8'hF8: sbox_lookup = 8'h41;
        8'hF9: sbox_lookup = 8'h99;
        8'hFA: sbox_lookup = 8'h2D;
        8'hFB: sbox_lookup = 8'h0F;
        8'hFC: sbox_lookup = 8'hB0;
        8'hFD: sbox_lookup = 8'h54;
        8'hFE: sbox_lookup = 8'hBB;
        8'hFF: sbox_lookup = 8'h16;
    endcase
endfunction

function automatic [7:0] xtime(input [7:0] x);
    if (x[7]) begin
        xtime = {x[6:0], 1'b0} ^ 8'h1B;
    end else begin
        xtime = {x[6:0], 1'b0};
    end
endfunction

function automatic [31:0] rot_word(input [31:0] w);
    rot_word = {w[23:0], w[31:24]};
endfunction

function automatic [31:0] sub_word(input [31:0] w);
    sub_word = {
        sbox_lookup(w[31:24]),
        sbox_lookup(w[23:16]),
        sbox_lookup(w[15:8]),
        sbox_lookup(w[7:0])
    };
endfunction

function automatic [127:0] sub_bytes(input [127:0] s);
    integer idx;
    begin
        for (idx = 0; idx < 16; idx = idx + 1) begin
            sub_bytes[127-8*idx-:8] = sbox_lookup(s[127-8*idx-:8]);
        end
    end
endfunction

function automatic [127:0] shift_rows(input [127:0] s);
    integer r;
    integer c;
    integer src_c;
    begin
        for (r = 0; r < 4; r = r + 1) begin
            for (c = 0; c < 4; c = c + 1) begin
                src_c = (c + r) % 4;
                shift_rows[127-(4*c+r)*8-:8] = s[127-(4*src_c+r)*8-:8];
            end
        end
    end
endfunction

function automatic [127:0] mix_columns(input [127:0] s);
    integer c;
    logic [7:0] s0;
    logic [7:0] s1;
    logic [7:0] s2;
    logic [7:0] s3;
    begin
        for (c = 0; c < 4; c = c + 1) begin
            s0 = s[127-(4*c+0)*8-:8];
            s1 = s[127-(4*c+1)*8-:8];
            s2 = s[127-(4*c+2)*8-:8];
            s3 = s[127-(4*c+3)*8-:8];

            mix_columns[127-(4*c+0)*8-:8] = xtime(s0) ^ (xtime(s1) ^ s1) ^ s2 ^ s3;
            mix_columns[127-(4*c+1)*8-:8] = s0 ^ xtime(s1) ^ (xtime(s2) ^ s2) ^ s3;
            mix_columns[127-(4*c+2)*8-:8] = s0 ^ s1 ^ xtime(s2) ^ (xtime(s3) ^ s3);
            mix_columns[127-(4*c+3)*8-:8] = (xtime(s0) ^ s0) ^ s1 ^ s2 ^ xtime(s3);
        end
    end
endfunction

function automatic [1407:0] expand_key(input [127:0] key);
    logic [31:0] w[0:43];
    logic [31:0] temp;
    logic [7:0]  rcon[1:10];
    integer i;
    begin
        rcon[1]  = 8'h01;
        rcon[2]  = 8'h02;
        rcon[3]  = 8'h04;
        rcon[4]  = 8'h08;
        rcon[5]  = 8'h10;
        rcon[6]  = 8'h20;
        rcon[7]  = 8'h40;
        rcon[8]  = 8'h80;
        rcon[9]  = 8'h1B;
        rcon[10] = 8'h36;

        for (i = 0; i < 4; i = i + 1) begin
            w[i] = key[127-32*i-:32];
        end

        for (i = 4; i < 44; i = i + 1) begin
            temp = w[i-1];
            if ((i % 4) == 0) begin
                temp = sub_word(rot_word(temp)) ^ {rcon[i/4], 24'h0};
            end
            w[i] = w[i-4] ^ temp;
        end

        for (i = 0; i < 44; i = i + 1) begin
            expand_key[1407-32*i-:32] = w[i];
        end
    end
endfunction

function automatic [127:0] get_round_key(input [1407:0] ex_key, input integer round_idx);
    get_round_key = ex_key[1407-128*round_idx-:128];
endfunction

function automatic [127:0] encrypt_block(input [127:0] data, input [1407:0] ex_key);
    logic [127:0] state;
    integer round_idx;
    begin
        state = data ^ get_round_key(ex_key, 0);

        for (round_idx = 1; round_idx <= 9; round_idx = round_idx + 1) begin
            state = sub_bytes(state);
            state = shift_rows(state);
            state = mix_columns(state);
            state = state ^ get_round_key(ex_key, round_idx);
        end

        state = sub_bytes(state);
        state = shift_rows(state);
        state = state ^ get_round_key(ex_key, 10);

        encrypt_block = state;
    end
endfunction

assign expanded_key_input = expand_key(i_key);
assign expanded_key_sel   = (i_update_key & o_done) ? expanded_key_input : expanded_key_ff;
assign cipher_next        = encrypt_block(i_data, expanded_key_sel);

always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
        expanded_key_ff   <= {NBW_EX_KEY{1'b0}};
        cipher_pending_ff <= {NBW_DATA{1'b0}};
        o_data            <= {NBW_DATA{1'b0}};
        o_done            <= 1'b1;
    end else begin
        if (i_start & o_done) begin
            if (i_update_key) begin
                expanded_key_ff <= expanded_key_input;
            end
            cipher_pending_ff <= cipher_next;
            o_done <= 1'b0;
        end else if (!o_done) begin
            o_data <= cipher_pending_ff;
            o_done <= 1'b1;
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
