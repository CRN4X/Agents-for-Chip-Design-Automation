module aes_dec_top #(
    parameter NBW_KEY  = 'd256,
    parameter NBW_DATA = 'd128,
    parameter NBW_MODE = 'd3,
    parameter NBW_CNTR = 'd32
) (
    input  logic                clk,
    input  logic                rst_async_n,
    input  logic                i_reset_counter,
    input  logic                i_update_iv,
    input  logic [NBW_DATA-1:0] i_iv,
    input  logic                i_update_mode,
    input  logic [NBW_MODE-1:0] i_mode,
    input  logic                i_update_key,
    input  logic [NBW_KEY-1:0]  i_key,
    input  logic                i_start,
    input  logic [NBW_DATA-1:0] i_ciphertext,
    output logic                o_done,
    output logic [NBW_DATA-1:0] o_plaintext
);

// ----------------------------------------
// - Wires/Registers creation
// ----------------------------------------
logic [NBW_MODE-1:0] mode_ff;
logic [NBW_DATA-1:0] ciphertext_ff;
logic [NBW_DATA-1:0] iv_ff;
logic [NBW_DATA-1:0] iv_nx;
logic [NBW_DATA-1:0] plaintext;
logic [NBW_DATA-1:0] dec_in;
logic [NBW_DATA-1:0] dec_out;
logic                update_key_ff;
logic                start_dec_ff;
logic                start_enc_ff;
logic                dec_done;
logic [NBW_KEY-1:0]  key_ff;
logic [NBW_CNTR-1:0] counter_ff;
logic                dec_sel;
logic [NBW_DATA-1:0] enc_out;
logic                enc_done;

// Possible operation modes
localparam ECB  = 3'd0;
localparam CBC  = 3'd1;
localparam PCBC = 3'd2;
localparam CFB  = 3'd3;
localparam OFB  = 3'd4;
localparam CTR  = 3'd5;

// Operation modes logic
always_comb begin
    case(mode_ff)
        ECB: begin
            dec_in    = ciphertext_ff;
            iv_nx     = iv_ff;
            plaintext = dec_out;
            dec_sel   = 1'b1;
        end
        CBC: begin
            dec_in    = ciphertext_ff;
            iv_nx     = ciphertext_ff;
            plaintext = dec_out ^ iv_ff;
            dec_sel   = 1'b1;
        end
        PCBC: begin
            dec_in    = ciphertext_ff;
            iv_nx     = ciphertext_ff ^ dec_out ^ iv_ff;
            plaintext = dec_out ^ iv_ff;
            dec_sel   = 1'b1;
        end
        CFB: begin
            dec_in    = iv_ff;
            iv_nx     = ciphertext_ff;
            plaintext = ciphertext_ff ^ enc_out;
            dec_sel   = 1'b0;
        end
        OFB: begin
            dec_in    = iv_ff;
            iv_nx     = enc_out;
            plaintext = ciphertext_ff ^ enc_out;
            dec_sel   = 1'b0;
        end
        CTR: begin
            dec_in    = {iv_ff[NBW_DATA-1:NBW_CNTR], counter_ff};
            iv_nx     = iv_ff;
            plaintext = ciphertext_ff ^ enc_out;
            dec_sel   = 1'b0;
        end
        default: begin
            dec_in    = ciphertext_ff;
            iv_nx     = iv_ff;
            plaintext = dec_out;
            dec_sel   = 1'b1;
        end
    endcase
end

always_ff @ (posedge clk) begin : data_regs
    if(i_start & o_done) begin
        ciphertext_ff <= i_ciphertext;
    end
end

always_ff @ (posedge clk or negedge rst_async_n) begin : reset_regs
    if(!rst_async_n) begin
        iv_ff        <= 128'd0;
        mode_ff      <= 3'd0;
        o_done       <= 1'b1;
        o_plaintext  <= 128'd0;
        counter_ff   <= 0;
        start_enc_ff <= 1'b0;
        start_dec_ff <= 1'b0;
    end else begin
        if(i_update_iv) begin
            iv_ff <= i_iv;
        end else begin
            if(dec_done | enc_done) begin
                iv_ff <= iv_nx;
            end
        end

        if(i_update_mode) begin
            mode_ff <= i_mode;
        end

        if(dec_done | enc_done) begin
            o_done <= 1'b1;
        end else begin
            if(i_start & o_done) begin
                o_done <= 1'b0;
            end
        end

        if(dec_done | enc_done) begin
            o_plaintext <= plaintext;
        end

        if(i_reset_counter) begin
            counter_ff <= 0;
        end else if((dec_done | enc_done) & mode_ff == CTR) begin
            counter_ff <= counter_ff + 1'b1;
        end

        start_enc_ff  <= (i_start & o_done & (~dec_sel));
        start_dec_ff  <= (i_start & o_done & dec_sel);
        update_key_ff <= (i_start & i_update_key & o_done);
        if(i_start & i_update_key & o_done) begin
            key_ff <= i_key;
        end
    end
end

aes_decrypt #(
    .NBW_KEY (NBW_KEY ),
    .NBW_DATA(NBW_DATA)
) uu_aes256_decrypt (
    .clk         (clk          ),
    .rst_async_n (rst_async_n  ),
    .i_update_key(update_key_ff),
    .i_key       (key_ff       ),
    .i_start     (start_dec_ff ),
    .i_data      (dec_in       ),
    .o_done      (dec_done     ),
    .o_data      (dec_out      )
);

aes_encrypt #(
    .NBW_KEY (NBW_KEY ),
    .NBW_DATA(NBW_DATA)
) uu_aes_encrypt (
    .clk         (clk          ),
    .rst_async_n (rst_async_n  ),
    .i_update_key(update_key_ff),
    .i_key       (key_ff       ),
    .i_start     (start_enc_ff ),
    .i_data      (dec_in       ),
    .o_data      (enc_out      ),
    .o_done      (enc_done     )
);

endmodule : aes_dec_top