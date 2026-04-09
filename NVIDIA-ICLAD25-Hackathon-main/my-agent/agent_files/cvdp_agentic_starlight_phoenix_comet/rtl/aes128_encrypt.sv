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

localparam int STEPS = 10;

logic [NBW_KEY-1:0] key_ff;
logic [NBW_DATA-1:0] data_ff;
logic [3:0] busy_ff;

function automatic [7:0] sbox_fn(input logic [7:0] x);
    begin
        case (x)
        8'h00: sbox_fn = 8'h63;
        8'h01: sbox_fn = 8'h7C;
        8'h02: sbox_fn = 8'h77;
        8'h03: sbox_fn = 8'h7B;
        8'h04: sbox_fn = 8'hF2;
        8'h05: sbox_fn = 8'h6B;
        8'h06: sbox_fn = 8'h6F;
        8'h07: sbox_fn = 8'hC5;
        8'h08: sbox_fn = 8'h30;
        8'h09: sbox_fn = 8'h01;
        8'h0A: sbox_fn = 8'h67;
        8'h0B: sbox_fn = 8'h2B;
        8'h0C: sbox_fn = 8'hFE;
        8'h0D: sbox_fn = 8'hD7;
        8'h0E: sbox_fn = 8'hAB;
        8'h0F: sbox_fn = 8'h76;
        8'h10: sbox_fn = 8'hCA;
        8'h11: sbox_fn = 8'h82;
        8'h12: sbox_fn = 8'hC9;
        8'h13: sbox_fn = 8'h7D;
        8'h14: sbox_fn = 8'hFA;
        8'h15: sbox_fn = 8'h59;
        8'h16: sbox_fn = 8'h47;
        8'h17: sbox_fn = 8'hF0;
        8'h18: sbox_fn = 8'hAD;
        8'h19: sbox_fn = 8'hD4;
        8'h1A: sbox_fn = 8'hA2;
        8'h1B: sbox_fn = 8'hAF;
        8'h1C: sbox_fn = 8'h9C;
        8'h1D: sbox_fn = 8'hA4;
        8'h1E: sbox_fn = 8'h72;
        8'h1F: sbox_fn = 8'hC0;
        8'h20: sbox_fn = 8'hB7;
        8'h21: sbox_fn = 8'hFD;
        8'h22: sbox_fn = 8'h93;
        8'h23: sbox_fn = 8'h26;
        8'h24: sbox_fn = 8'h36;
        8'h25: sbox_fn = 8'h3F;
        8'h26: sbox_fn = 8'hF7;
        8'h27: sbox_fn = 8'hCC;
        8'h28: sbox_fn = 8'h34;
        8'h29: sbox_fn = 8'hA5;
        8'h2A: sbox_fn = 8'hE5;
        8'h2B: sbox_fn = 8'hF1;
        8'h2C: sbox_fn = 8'h71;
        8'h2D: sbox_fn = 8'hD8;
        8'h2E: sbox_fn = 8'h31;
        8'h2F: sbox_fn = 8'h15;
        8'h30: sbox_fn = 8'h04;
        8'h31: sbox_fn = 8'hC7;
        8'h32: sbox_fn = 8'h23;
        8'h33: sbox_fn = 8'hC3;
        8'h34: sbox_fn = 8'h18;
        8'h35: sbox_fn = 8'h96;
        8'h36: sbox_fn = 8'h05;
        8'h37: sbox_fn = 8'h9A;
        8'h38: sbox_fn = 8'h07;
        8'h39: sbox_fn = 8'h12;
        8'h3A: sbox_fn = 8'h80;
        8'h3B: sbox_fn = 8'hE2;
        8'h3C: sbox_fn = 8'hEB;
        8'h3D: sbox_fn = 8'h27;
        8'h3E: sbox_fn = 8'hB2;
        8'h3F: sbox_fn = 8'h75;
        8'h40: sbox_fn = 8'h09;
        8'h41: sbox_fn = 8'h83;
        8'h42: sbox_fn = 8'h2C;
        8'h43: sbox_fn = 8'h1A;
        8'h44: sbox_fn = 8'h1B;
        8'h45: sbox_fn = 8'h6E;
        8'h46: sbox_fn = 8'h5A;
        8'h47: sbox_fn = 8'hA0;
        8'h48: sbox_fn = 8'h52;
        8'h49: sbox_fn = 8'h3B;
        8'h4A: sbox_fn = 8'hD6;
        8'h4B: sbox_fn = 8'hB3;
        8'h4C: sbox_fn = 8'h29;
        8'h4D: sbox_fn = 8'hE3;
        8'h4E: sbox_fn = 8'h2F;
        8'h4F: sbox_fn = 8'h84;
        8'h50: sbox_fn = 8'h53;
        8'h51: sbox_fn = 8'hD1;
        8'h52: sbox_fn = 8'h00;
        8'h53: sbox_fn = 8'hED;
        8'h54: sbox_fn = 8'h20;
        8'h55: sbox_fn = 8'hFC;
        8'h56: sbox_fn = 8'hB1;
        8'h57: sbox_fn = 8'h5B;
        8'h58: sbox_fn = 8'h6A;
        8'h59: sbox_fn = 8'hCB;
        8'h5A: sbox_fn = 8'hBE;
        8'h5B: sbox_fn = 8'h39;
        8'h5C: sbox_fn = 8'h4A;
        8'h5D: sbox_fn = 8'h4C;
        8'h5E: sbox_fn = 8'h58;
        8'h5F: sbox_fn = 8'hCF;
        8'h60: sbox_fn = 8'hD0;
        8'h61: sbox_fn = 8'hEF;
        8'h62: sbox_fn = 8'hAA;
        8'h63: sbox_fn = 8'hFB;
        8'h64: sbox_fn = 8'h43;
        8'h65: sbox_fn = 8'h4D;
        8'h66: sbox_fn = 8'h33;
        8'h67: sbox_fn = 8'h85;
        8'h68: sbox_fn = 8'h45;
        8'h69: sbox_fn = 8'hF9;
        8'h6A: sbox_fn = 8'h02;
        8'h6B: sbox_fn = 8'h7F;
        8'h6C: sbox_fn = 8'h50;
        8'h6D: sbox_fn = 8'h3C;
        8'h6E: sbox_fn = 8'h9F;
        8'h6F: sbox_fn = 8'hA8;
        8'h70: sbox_fn = 8'h51;
        8'h71: sbox_fn = 8'hA3;
        8'h72: sbox_fn = 8'h40;
        8'h73: sbox_fn = 8'h8F;
        8'h74: sbox_fn = 8'h92;
        8'h75: sbox_fn = 8'h9D;
        8'h76: sbox_fn = 8'h38;
        8'h77: sbox_fn = 8'hF5;
        8'h78: sbox_fn = 8'hBC;
        8'h79: sbox_fn = 8'hB6;
        8'h7A: sbox_fn = 8'hDA;
        8'h7B: sbox_fn = 8'h21;
        8'h7C: sbox_fn = 8'h10;
        8'h7D: sbox_fn = 8'hFF;
        8'h7E: sbox_fn = 8'hF3;
        8'h7F: sbox_fn = 8'hD2;
        8'h80: sbox_fn = 8'hCD;
        8'h81: sbox_fn = 8'h0C;
        8'h82: sbox_fn = 8'h13;
        8'h83: sbox_fn = 8'hEC;
        8'h84: sbox_fn = 8'h5F;
        8'h85: sbox_fn = 8'h97;
        8'h86: sbox_fn = 8'h44;
        8'h87: sbox_fn = 8'h17;
        8'h88: sbox_fn = 8'hC4;
        8'h89: sbox_fn = 8'hA7;
        8'h8A: sbox_fn = 8'h7E;
        8'h8B: sbox_fn = 8'h3D;
        8'h8C: sbox_fn = 8'h64;
        8'h8D: sbox_fn = 8'h5D;
        8'h8E: sbox_fn = 8'h19;
        8'h8F: sbox_fn = 8'h73;
        8'h90: sbox_fn = 8'h60;
        8'h91: sbox_fn = 8'h81;
        8'h92: sbox_fn = 8'h4F;
        8'h93: sbox_fn = 8'hDC;
        8'h94: sbox_fn = 8'h22;
        8'h95: sbox_fn = 8'h2A;
        8'h96: sbox_fn = 8'h90;
        8'h97: sbox_fn = 8'h88;
        8'h98: sbox_fn = 8'h46;
        8'h99: sbox_fn = 8'hEE;
        8'h9A: sbox_fn = 8'hB8;
        8'h9B: sbox_fn = 8'h14;
        8'h9C: sbox_fn = 8'hDE;
        8'h9D: sbox_fn = 8'h5E;
        8'h9E: sbox_fn = 8'h0B;
        8'h9F: sbox_fn = 8'hDB;
        8'hA0: sbox_fn = 8'hE0;
        8'hA1: sbox_fn = 8'h32;
        8'hA2: sbox_fn = 8'h3A;
        8'hA3: sbox_fn = 8'h0A;
        8'hA4: sbox_fn = 8'h49;
        8'hA5: sbox_fn = 8'h06;
        8'hA6: sbox_fn = 8'h24;
        8'hA7: sbox_fn = 8'h5C;
        8'hA8: sbox_fn = 8'hC2;
        8'hA9: sbox_fn = 8'hD3;
        8'hAA: sbox_fn = 8'hAC;
        8'hAB: sbox_fn = 8'h62;
        8'hAC: sbox_fn = 8'h91;
        8'hAD: sbox_fn = 8'h95;
        8'hAE: sbox_fn = 8'hE4;
        8'hAF: sbox_fn = 8'h79;
        8'hB0: sbox_fn = 8'hE7;
        8'hB1: sbox_fn = 8'hC8;
        8'hB2: sbox_fn = 8'h37;
        8'hB3: sbox_fn = 8'h6D;
        8'hB4: sbox_fn = 8'h8D;
        8'hB5: sbox_fn = 8'hD5;
        8'hB6: sbox_fn = 8'h4E;
        8'hB7: sbox_fn = 8'hA9;
        8'hB8: sbox_fn = 8'h6C;
        8'hB9: sbox_fn = 8'h56;
        8'hBA: sbox_fn = 8'hF4;
        8'hBB: sbox_fn = 8'hEA;
        8'hBC: sbox_fn = 8'h65;
        8'hBD: sbox_fn = 8'h7A;
        8'hBE: sbox_fn = 8'hAE;
        8'hBF: sbox_fn = 8'h08;
        8'hC0: sbox_fn = 8'hBA;
        8'hC1: sbox_fn = 8'h78;
        8'hC2: sbox_fn = 8'h25;
        8'hC3: sbox_fn = 8'h2E;
        8'hC4: sbox_fn = 8'h1C;
        8'hC5: sbox_fn = 8'hA6;
        8'hC6: sbox_fn = 8'hB4;
        8'hC7: sbox_fn = 8'hC6;
        8'hC8: sbox_fn = 8'hE8;
        8'hC9: sbox_fn = 8'hDD;
        8'hCA: sbox_fn = 8'h74;
        8'hCB: sbox_fn = 8'h1F;
        8'hCC: sbox_fn = 8'h4B;
        8'hCD: sbox_fn = 8'hBD;
        8'hCE: sbox_fn = 8'h8B;
        8'hCF: sbox_fn = 8'h8A;
        8'hD0: sbox_fn = 8'h70;
        8'hD1: sbox_fn = 8'h3E;
        8'hD2: sbox_fn = 8'hB5;
        8'hD3: sbox_fn = 8'h66;
        8'hD4: sbox_fn = 8'h48;
        8'hD5: sbox_fn = 8'h03;
        8'hD6: sbox_fn = 8'hF6;
        8'hD7: sbox_fn = 8'h0E;
        8'hD8: sbox_fn = 8'h61;
        8'hD9: sbox_fn = 8'h35;
        8'hDA: sbox_fn = 8'h57;
        8'hDB: sbox_fn = 8'hB9;
        8'hDC: sbox_fn = 8'h86;
        8'hDD: sbox_fn = 8'hC1;
        8'hDE: sbox_fn = 8'h1D;
        8'hDF: sbox_fn = 8'h9E;
        8'hE0: sbox_fn = 8'hE1;
        8'hE1: sbox_fn = 8'hF8;
        8'hE2: sbox_fn = 8'h98;
        8'hE3: sbox_fn = 8'h11;
        8'hE4: sbox_fn = 8'h69;
        8'hE5: sbox_fn = 8'hD9;
        8'hE6: sbox_fn = 8'h8E;
        8'hE7: sbox_fn = 8'h94;
        8'hE8: sbox_fn = 8'h9B;
        8'hE9: sbox_fn = 8'h1E;
        8'hEA: sbox_fn = 8'h87;
        8'hEB: sbox_fn = 8'hE9;
        8'hEC: sbox_fn = 8'hCE;
        8'hED: sbox_fn = 8'h55;
        8'hEE: sbox_fn = 8'h28;
        8'hEF: sbox_fn = 8'hDF;
        8'hF0: sbox_fn = 8'h8C;
        8'hF1: sbox_fn = 8'hA1;
        8'hF2: sbox_fn = 8'h89;
        8'hF3: sbox_fn = 8'h0D;
        8'hF4: sbox_fn = 8'hBF;
        8'hF5: sbox_fn = 8'hE6;
        8'hF6: sbox_fn = 8'h42;
        8'hF7: sbox_fn = 8'h68;
        8'hF8: sbox_fn = 8'h41;
        8'hF9: sbox_fn = 8'h99;
        8'hFA: sbox_fn = 8'h2D;
        8'hFB: sbox_fn = 8'h0F;
        8'hFC: sbox_fn = 8'hB0;
        8'hFD: sbox_fn = 8'h54;
        8'hFE: sbox_fn = 8'hBB;
        8'hFF: sbox_fn = 8'h16;
            default: sbox_fn = 8'h00;
        endcase
    end
endfunction

function automatic [7:0] xtime_fn(input logic [7:0] x);
    begin
        xtime_fn = x[7] ? ({x[6:0], 1'b0} ^ 8'h1B) : {x[6:0], 1'b0};
    end
endfunction

function automatic [31:0] rot_word_fn(input logic [31:0] w);
    begin
        rot_word_fn = {w[23:0], w[31:24]};
    end
endfunction

function automatic [31:0] sub_word_fn(input logic [31:0] w);
    begin
        sub_word_fn = {sbox_fn(w[31:24]), sbox_fn(w[23:16]), sbox_fn(w[15:8]), sbox_fn(w[7:0])};
    end
endfunction

function automatic [7:0] get_byte_fn(input logic [127:0] v, input int idx);
    begin
        get_byte_fn = v[127 - idx*8 -: 8];
    end
endfunction

function automatic [127:0] set_byte_fn(input logic [127:0] v, input int idx, input logic [7:0] b);
    logic [127:0] tmp;
    begin
        tmp = v;
        tmp[127 - idx*8 -: 8] = b;
        set_byte_fn = tmp;
    end
endfunction

function automatic [1407:0] expand_key_fn(input logic [127:0] key);
    logic [31:0] w [0:43];
    logic [31:0] temp;
    logic [1407:0] ex;
    logic [7:0] rcon [1:10];
    int i;
    begin
        rcon[1] = 8'h01; rcon[2] = 8'h02; rcon[3] = 8'h04; rcon[4] = 8'h08; rcon[5] = 8'h10;
        rcon[6] = 8'h20; rcon[7] = 8'h40; rcon[8] = 8'h80; rcon[9] = 8'h1B; rcon[10] = 8'h36;

        for (i = 0; i < 4; i++) begin
            w[i] = key[127 - i*32 -: 32];
        end

        for (i = 4; i < 44; i++) begin
            temp = w[i-1];
            if ((i % 4) == 0) begin
                temp = sub_word_fn(rot_word_fn(temp)) ^ {rcon[i/4], 24'h0};
            end
            w[i] = w[i-4] ^ temp;
        end

        ex = '0;
        for (i = 0; i < 44; i++) begin
            ex[1407 - i*32 -: 32] = w[i];
        end

        expand_key_fn = ex;
    end
endfunction

function automatic [127:0] add_round_key_fn(input logic [127:0] st, input logic [1407:0] ex, input int round);
    logic [127:0] out;
    logic [31:0] word;
    logic [7:0] sb;
    int i, j;
    begin
        out = st;
        for (j = 0; j < 4; j++) begin
            word = ex[1407 - (round*4 + j)*32 -: 32];
            for (i = 0; i < 4; i++) begin
                sb = word[31 - i*8 -: 8];
                out = set_byte_fn(out, i + 4*j, get_byte_fn(out, i + 4*j) ^ sb);
            end
        end
        add_round_key_fn = out;
    end
endfunction

function automatic [127:0] sub_bytes_fn(input logic [127:0] st);
    logic [127:0] out;
    int i;
    begin
        out = st;
        for (i = 0; i < 16; i++) begin
            out = set_byte_fn(out, i, sbox_fn(get_byte_fn(st, i)));
        end
        sub_bytes_fn = out;
    end
endfunction

function automatic [127:0] shift_rows_fn(input logic [127:0] st);
    logic [127:0] out;
    begin
        out = st;

        out = set_byte_fn(out, 1,  get_byte_fn(st, 5));
        out = set_byte_fn(out, 5,  get_byte_fn(st, 9));
        out = set_byte_fn(out, 9,  get_byte_fn(st, 13));
        out = set_byte_fn(out, 13, get_byte_fn(st, 1));

        out = set_byte_fn(out, 2,  get_byte_fn(st, 10));
        out = set_byte_fn(out, 6,  get_byte_fn(st, 14));
        out = set_byte_fn(out, 10, get_byte_fn(st, 2));
        out = set_byte_fn(out, 14, get_byte_fn(st, 6));

        out = set_byte_fn(out, 3,  get_byte_fn(st, 15));
        out = set_byte_fn(out, 7,  get_byte_fn(st, 3));
        out = set_byte_fn(out, 11, get_byte_fn(st, 7));
        out = set_byte_fn(out, 15, get_byte_fn(st, 11));

        shift_rows_fn = out;
    end
endfunction

function automatic [127:0] mix_columns_fn(input logic [127:0] st);
    logic [127:0] out;
    logic [7:0] a0, a1, a2, a3;
    logic [7:0] t, u;
    int j;
    begin
        out = st;
        for (j = 0; j < 4; j++) begin
            a0 = get_byte_fn(out, 4*j + 0);
            a1 = get_byte_fn(out, 4*j + 1);
            a2 = get_byte_fn(out, 4*j + 2);
            a3 = get_byte_fn(out, 4*j + 3);
            t  = a0 ^ a1 ^ a2 ^ a3;
            u  = a0;

            out = set_byte_fn(out, 4*j + 0, a0 ^ t ^ xtime_fn(a0 ^ a1));
            out = set_byte_fn(out, 4*j + 1, a1 ^ t ^ xtime_fn(a1 ^ a2));
            out = set_byte_fn(out, 4*j + 2, a2 ^ t ^ xtime_fn(a2 ^ a3));
            out = set_byte_fn(out, 4*j + 3, a3 ^ t ^ xtime_fn(a3 ^ u));
        end
        mix_columns_fn = out;
    end
endfunction

function automatic [127:0] encrypt_block_fn(input logic [127:0] pt, input logic [127:0] key);
    logic [127:0] st;
    logic [1407:0] ex;
    int round;
    begin
        ex = expand_key_fn(key);
        st = add_round_key_fn(pt, ex, 0);

        for (round = 1; round < 10; round++) begin
            st = sub_bytes_fn(st);
            st = shift_rows_fn(st);
            st = mix_columns_fn(st);
            st = add_round_key_fn(st, ex, round);
        end

        st = sub_bytes_fn(st);
        st = shift_rows_fn(st);
        st = add_round_key_fn(st, ex, 10);

        encrypt_block_fn = st;
    end
endfunction

assign o_done = (busy_ff == 4'd0);
assign o_data = data_ff;

always_ff @(posedge clk or negedge rst_async_n) begin
    logic [NBW_KEY-1:0] active_key;
    if (!rst_async_n) begin
        key_ff  <= '0;
        data_ff <= '0;
        busy_ff <= 4'd0;
    end else begin
        if (busy_ff != 4'd0) begin
            busy_ff <= busy_ff - 1'b1;
        end

        if (i_update_key && o_done) begin
            key_ff <= i_key;
        end

        if (i_start && o_done) begin
            active_key = i_update_key ? i_key : key_ff;
            data_ff <= encrypt_block_fn(i_data, active_key);
            busy_ff <= 4'd11;
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
