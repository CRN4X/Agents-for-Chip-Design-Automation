module tb_padding_top;

// Interface parameters
localparam NBW_KEY  = 'd256;
localparam NBW_DATA = 'd128;
localparam NBW_MODE = 'd3;
localparam NBW_CNTR = 'd32;
localparam NBW_PADD = 'd4;
localparam NBW_PMOD = 'd2;
localparam W3C_BYTE = 8'hAF;

// Possible operation modes
localparam ECB  = 3'd0;
localparam CBC  = 3'd1;
localparam PCBC = 3'd2;
localparam CFB  = 3'd3;
localparam OFB  = 3'd4;
localparam CTR  = 3'd5;

// Interface signals
logic                clk;
logic                rst_async_n;
logic                i_encrypt;
logic                i_update_padding_mode;
logic [NBW_PMOD-1:0] i_padding_mode;
logic [NBW_PADD-1:0] i_padding_bytes;
logic                i_reset_counter;
logic                i_update_iv;
logic [NBW_DATA-1:0] i_iv;
logic                i_update_mode;
logic [NBW_MODE-1:0] i_mode;
logic                i_update_key;
logic [NBW_KEY-1:0]  i_key;
logic                i_start;
logic [NBW_DATA-1:0] i_data;
logic                o_done;
logic [NBW_DATA-1:0] o_data;

// Module instantiation
padding_top #(
    .NBW_KEY (NBW_KEY ),
    .NBW_DATA(NBW_DATA),
    .NBW_MODE(NBW_MODE),
    .NBW_CNTR(NBW_CNTR),
    .NBW_PADD(NBW_PADD),
    .NBW_PMOD(NBW_PMOD),
    .W3C_BYTE(W3C_BYTE)
) uu_padding_top (
    .clk                  (clk                  ),
    .rst_async_n          (rst_async_n          ),
    .i_encrypt            (i_encrypt            ),
    .i_update_padding_mode(i_update_padding_mode),
    .i_padding_mode       (i_padding_mode       ),
    .i_padding_bytes      (i_padding_bytes      ),
    .i_reset_counter      (i_reset_counter      ),
    .i_update_iv          (i_update_iv          ),
    .i_iv                 (i_iv                 ),
    .i_update_mode        (i_update_mode        ),
    .i_mode               (i_mode               ),
    .i_update_key         (i_update_key         ),
    .i_key                (i_key                ),
    .i_start              (i_start              ),
    .i_data               (i_data               ),
    .o_done               (o_done               ),
    .o_data               (o_data               )
);

initial begin
    $dumpfile("test.vcd");
    $dumpvars(0,tb_padding_top);
end

task Compare (logic [NBW_DATA-1:0] compare_value);
    if(o_data == compare_value) begin
        $display("PASS");
    end else begin
        $display("\nFAIL:");
        $display(" - Expected output: %h", compare_value);
        $display(" - Observed output: %h", o_data);
    end
endtask

task DriveInputs(logic update_key, logic [NBW_PADD-1:0] padding_bytes, logic [NBW_DATA-1:0] expected_output);
    @(negedge clk);
    i_key           = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    i_data          = 128'h00112233445566778899aabbccddeeff;
    i_reset_counter = 0;
    i_iv            = 0;
    i_update_iv     = 0;
    i_update_mode   = 0;
    i_mode          = 0;
    i_update_key    = update_key;
    i_start         = 1;

    i_padding_bytes = padding_bytes;

    @(negedge clk);
    i_start = 0;
    i_update_key = 0;
    i_key = 0;
    i_data = 0;
    i_padding_bytes = 0;

    @(posedge o_done);
    @(negedge clk);

    Compare(expected_output);
endtask

always #5 clk = ~clk;

initial begin
    clk = 0;
    i_update_padding_mode = 0;
    i_start = 0;
    i_update_iv = 0;
    i_update_key = 0;
    i_update_mode = 0;
    i_reset_counter = 0;
    rst_async_n = 1;
    #1;
    rst_async_n = 0;
    #2;
    rst_async_n = 1;
    @(negedge clk);

    // Udpate mode to CTR
    i_update_mode = 1;
    i_mode        = CTR;
    // Add a "random" IV
    i_update_iv   = 1;
    i_iv          = 128'hffffffff_00000000_00000000_ffffffff;
    // Set to encrypt
    i_encrypt = 1;
    $display("\n================");
    $display("=   Encrypt    =");
    $display("================");

    // Set padding mode to PKCS
    i_update_padding_mode = 1;
    i_padding_mode = 2'b00;
    @(negedge clk);

    $display("\n================");
    $display("=     PKCS     =");
    $display("================");
    
    // Try all paddings for the PKCS mode
    DriveInputs(1'b1, 4'h0, 128'hf1fa832efe2cceee4f06eda80718af1b);
    DriveInputs(1'b0, 4'h1, 128'h9c9a150012f05c1db68aa6de49bc56f0);
    DriveInputs(1'b0, 4'h2, 128'h7736fbfaeb7a413495e65b8a70779392);
    DriveInputs(1'b0, 4'h3, 128'h85f263da7dea8bcc3883f2c312bccabb);
    DriveInputs(1'b0, 4'h4, 128'h2c84695b539826d43818daddb1359610);
    DriveInputs(1'b0, 4'h5, 128'h74b38b042a70078444e45c6cd62fe09f);
    DriveInputs(1'b0, 4'h6, 128'h049d2c451606113d5c597fd47ed2ddc7);
    DriveInputs(1'b0, 4'h7, 128'h58d05e0c92b12118eaf2ca738d2c7f06);
    DriveInputs(1'b0, 4'h8, 128'h4e1d3f0d7dd4b629e291de8eb7520781);
    DriveInputs(1'b0, 4'h9, 128'h7a3b7f71319b895fadc2c8cadbf3f511);
    DriveInputs(1'b0, 4'ha, 128'h283873c17d3fac7e9057748dc5a0dc9a);
    DriveInputs(1'b0, 4'hb, 128'hf1d4ec0c04533fb438681a866d6ceba2);
    DriveInputs(1'b0, 4'hc, 128'h9e6a83f1871445ba974d9ea24deb2497);
    DriveInputs(1'b0, 4'hd, 128'h3786b6f975e68cf93eb043f73b0930ec);
    DriveInputs(1'b0, 4'he, 128'h7e9d6b0ad94e7cccda9b35c383f7639e);
    DriveInputs(1'b0, 4'hf, 128'h9f6e010a5e695b284e5a8c4d8e8de1c5);

    // Reset the counter
    i_reset_counter = 1;

    // Set padding mode to OneAndZeroes
    i_update_padding_mode = 1;
    i_padding_mode = 2'b01;
    @(negedge clk);

    $display("\n================");
    $display("= OneAndZeroes =");
    $display("================");
    
    // Try all paddings for the OneAndZeroes mode
    DriveInputs(1'b0, 4'h0, 128'hf1fa832efe2cceee4f06eda80718af1b);
    DriveInputs(1'b0, 4'h1, 128'h9c9a150012f05c1db68aa6de49bc5671);
    DriveInputs(1'b0, 4'h2, 128'h7736fbfaeb7a413495e65b8a70771190);
    DriveInputs(1'b0, 4'h3, 128'h85f263da7dea8bcc3883f2c3123fc9b8);
    DriveInputs(1'b0, 4'h4, 128'h2c84695b539826d43818dadd35319214);
    DriveInputs(1'b0, 4'h5, 128'h74b38b042a70078444e45ce9d32ae59a);
    DriveInputs(1'b0, 4'h6, 128'h049d2c451606113d5c59f9d278d4dbc1);
    DriveInputs(1'b0, 4'h7, 128'h58d05e0c92b12118ea75cd748a2b7801);
    DriveInputs(1'b0, 4'h8, 128'h4e1d3f0d7dd4b6296a99d686bf5a0f89);
    DriveInputs(1'b0, 4'h9, 128'h7a3b7f71319b89d6a4cbc1c3d2fafc18);
    DriveInputs(1'b0, 4'ha, 128'h283873c17d3f26749a5d7e87cfaad690);
    DriveInputs(1'b0, 4'hb, 128'hf1d4ec0c04d834bf3363118d6667e0a9);
    DriveInputs(1'b0, 4'hc, 128'h9e6a83f10b1849b69b4192ae41e7289b);
    DriveInputs(1'b0, 4'hd, 128'h3786b67478eb81f433bd4efa36043de1);
    DriveInputs(1'b0, 4'he, 128'h7e9de504d74072c2d4953bcd8df96d90);
    DriveInputs(1'b0, 4'hf, 128'h9fe10e0551665427415583428182eeca);

    // Reset the counter
    i_reset_counter = 1;

    // Set padding mode to ANSIX923
    i_update_padding_mode = 1;
    i_padding_mode = 2'b10;
    @(negedge clk);

    $display("\n================");
    $display("=   ANSIX923   =");
    $display("================");
    
    // Try all paddings for the ANSIX923 mode
    DriveInputs(1'b0, 4'h0, 128'hf1fa832efe2cceee4f06eda80718af1b);
    DriveInputs(1'b0, 4'h1, 128'h9c9a150012f05c1db68aa6de49bc56f0);
    DriveInputs(1'b0, 4'h2, 128'h7736fbfaeb7a413495e65b8a70779192);
    DriveInputs(1'b0, 4'h3, 128'h85f263da7dea8bcc3883f2c312bfc9bb);
    DriveInputs(1'b0, 4'h4, 128'h2c84695b539826d43818daddb5319210);
    DriveInputs(1'b0, 4'h5, 128'h74b38b042a70078444e45c69d32ae59f);
    DriveInputs(1'b0, 4'h6, 128'h049d2c451606113d5c5979d278d4dbc7);
    DriveInputs(1'b0, 4'h7, 128'h58d05e0c92b12118eaf5cd748a2b7806);
    DriveInputs(1'b0, 4'h8, 128'h4e1d3f0d7dd4b629ea99d686bf5a0f81);
    DriveInputs(1'b0, 4'h9, 128'h7a3b7f71319b8956a4cbc1c3d2fafc11);
    DriveInputs(1'b0, 4'ha, 128'h283873c17d3fa6749a5d7e87cfaad69a);
    DriveInputs(1'b0, 4'hb, 128'hf1d4ec0c045834bf3363118d6667e0a2);
    DriveInputs(1'b0, 4'hc, 128'h9e6a83f18b1849b69b4192ae41e72897);
    DriveInputs(1'b0, 4'hd, 128'h3786b6f478eb81f433bd4efa36043dec);
    DriveInputs(1'b0, 4'he, 128'h7e9d6504d74072c2d4953bcd8df96d9e);
    DriveInputs(1'b0, 4'hf, 128'h9f610e0551665427415583428182eec5);

    // Reset the counter
    i_reset_counter = 1;

    // Set padding mode to W3C
    i_update_padding_mode = 1;
    i_padding_mode = 2'b11;
    @(negedge clk);

    $display("\n================");
    $display("=     W3C      =");
    $display("================");
    
    // Try all paddings for the W3C mode
    DriveInputs(1'b0, 4'h0, 128'hf1fa832efe2cceee4f06eda80718af1b);
    DriveInputs(1'b0, 4'h1, 128'h9c9a150012f05c1db68aa6de49bc56f0);
    DriveInputs(1'b0, 4'h2, 128'h7736fbfaeb7a413495e65b8a70773e92);
    DriveInputs(1'b0, 4'h3, 128'h85f263da7dea8bcc3883f2c3121066bb);
    DriveInputs(1'b0, 4'h4, 128'h2c84695b539826d43818dadd1a9e3d10);
    DriveInputs(1'b0, 4'h5, 128'h74b38b042a70078444e45cc67c854a9f);
    DriveInputs(1'b0, 4'h6, 128'h049d2c451606113d5c59d67dd77b74c7);
    DriveInputs(1'b0, 4'h7, 128'h58d05e0c92b12118ea5a62db2584d706);
    DriveInputs(1'b0, 4'h8, 128'h4e1d3f0d7dd4b6294536792910f5a081);
    DriveInputs(1'b0, 4'h9, 128'h7a3b7f71319b89f90b646e6c7d555311);
    DriveInputs(1'b0, 4'ha, 128'h283873c17d3f09db35f2d1286005799a);
    DriveInputs(1'b0, 4'hb, 128'hf1d4ec0c04f79b109cccbe22c9c84fa2);
    DriveInputs(1'b0, 4'hc, 128'h9e6a83f124b7e61934ee3d01ee488797);
    DriveInputs(1'b0, 4'hd, 128'h3786b65bd7442e5b9c12e15599ab92ec);
    DriveInputs(1'b0, 4'he, 128'h7e9dcaab78efdd6d7b3a94622256c29e);
    DriveInputs(1'b0, 4'hf, 128'h9fcea1aafec9fb88eefa2ced2e2d41c5);

    // Set to decrypt
    i_encrypt = 0;

    $display("\n================");
    $display("=   Decrypt    =");
    $display("================");

    // Set padding mode to PKCS
    i_update_padding_mode = 1;
    i_padding_mode = 2'b00;
    @(negedge clk);

    $display("\n================");
    $display("=     PKCS     =");
    $display("================");
    
    // Try all paddings for the PKCS mode
    DriveInputs(1'b1, 4'h0, 128'heab487e68ec92db4ac288a24757b0262);
    DriveInputs(1'b0, 4'h1, 128'hf64d8192e294917701d3d70da384c8e0);
    DriveInputs(1'b0, 4'h2, 128'h6ef961d86bfde1b7d9d37020f206f105);
    DriveInputs(1'b0, 4'h3, 128'hb22dc55b0054fd0ad709cec19d083750);
    DriveInputs(1'b0, 4'h4, 128'h95e72e8457f2a58a96b41bbccb6e0660);
    DriveInputs(1'b0, 4'h5, 128'hdd67798259aa234a12d3b764459bfef2);
    DriveInputs(1'b0, 4'h6, 128'hb98acf0a984284ae96b8bd07cc810ae4);
    DriveInputs(1'b0, 4'h7, 128'h8265365ce045f9789243ce7b53188570);
    DriveInputs(1'b0, 4'h8, 128'hee14dc243cab56a63ee686058db3a46d);
    DriveInputs(1'b0, 4'h9, 128'h1e32eebda4b7878a8a36cb04c11b1983);
    DriveInputs(1'b0, 4'ha, 128'h0b4dcae2cd918bafbb8bf32f8b05a9e0);
    DriveInputs(1'b0, 4'hb, 128'hc4067f695b84b0c36c8b2a2ac39347ef);
    DriveInputs(1'b0, 4'hc, 128'hf8d01782c0031d7555f230f917508c93);
    DriveInputs(1'b0, 4'hd, 128'ha8a93b08d5b93ae809b78365a31dd1a8);
    DriveInputs(1'b0, 4'he, 128'hac0cebdf2fae979c490695b48a33d1d5);
    DriveInputs(1'b0, 4'hf, 128'h22619dbea37c0527210568174c69f3ad);

    // Reset the counter
    i_reset_counter = 1;

    // Set padding mode to OneAndZeroes
    i_update_padding_mode = 1;
    i_padding_mode = 2'b01;
    @(negedge clk);

    $display("\n================");
    $display("= OneAndZeroes =");
    $display("================");
    
    // Try all paddings for the OneAndZeroes mode
    DriveInputs(1'b0, 4'h0, 128'heab487e68ec92db4ac288a24757b0262);
    DriveInputs(1'b0, 4'h1, 128'hc54a83e25ca56799a14ffd4bcaf3d1f5);
    DriveInputs(1'b0, 4'h2, 128'h9f52e86b3dd2996b4ca0cc97d58b71d6);
    DriveInputs(1'b0, 4'h3, 128'h2b66be0bf9e98b1cec49147b99b088e0);
    DriveInputs(1'b0, 4'h4, 128'h577530ee4c2a45cb8a5e97d879468047);
    DriveInputs(1'b0, 4'h5, 128'ha77b9e5ffc79e5e930495192f3242255);
    DriveInputs(1'b0, 4'h6, 128'ha3a023dfdd23fc0410b7694c1b679046);
    DriveInputs(1'b0, 4'h7, 128'h88f9321e73e273599a4d07874bd666a1);
    DriveInputs(1'b0, 4'h8, 128'h74c452ff371e6849d6ed5d5335505e45);
    DriveInputs(1'b0, 4'h9, 128'h0d169882051c4787e25a44b9f0628fd6);
    DriveInputs(1'b0, 4'ha, 128'hae93a046915f6a4b08868fc5613dff94);
    DriveInputs(1'b0, 4'hb, 128'hbc554067455fa678d3303a28f0a19cfa);
    DriveInputs(1'b0, 4'hc, 128'hb7fb754b48f60052e0b10d2f8b32275c);
    DriveInputs(1'b0, 4'hd, 128'h3f3aa4a7f7aa8342e474a34c5abe3f1a);
    DriveInputs(1'b0, 4'he, 128'h5694bc221034dfc53b5ac47ee17fc98c);
    DriveInputs(1'b0, 4'hf, 128'h4e6821cc1b5bc620050e2a6a40a605f6);

    // Reset the counter
    i_reset_counter = 1;

    // Set padding mode to ANSIX923
    i_update_padding_mode = 1;
    i_padding_mode = 2'b10;
    @(negedge clk);

    $display("\n================");
    $display("=   ANSIX923   =");
    $display("================");
    
    // Try all paddings for the ANSIX923 mode
    DriveInputs(1'b0, 4'h0, 128'heab487e68ec92db4ac288a24757b0262);
    DriveInputs(1'b0, 4'h1, 128'hf64d8192e294917701d3d70da384c8e0);
    DriveInputs(1'b0, 4'h2, 128'h1fd077ebf6416f3c40bbed158ab717bc);
    DriveInputs(1'b0, 4'h3, 128'h8479c1c2b5e323f09a8c6d24a123e877);
    DriveInputs(1'b0, 4'h4, 128'h95dd5b8ea8eb4102cf0c3c7b3355b074);
    DriveInputs(1'b0, 4'h5, 128'h853d05d712ab8e1122aef182fc9a6d0b);
    DriveInputs(1'b0, 4'h6, 128'h5e3e77097905251a05af46092bddc94d);
    DriveInputs(1'b0, 4'h7, 128'h6ac5d4bb95a0bb686f6fa70527030e62);
    DriveInputs(1'b0, 4'h8, 128'h05474c6d864611bff5152b02bae22577);
    DriveInputs(1'b0, 4'h9, 128'h1405a02698df01f1ea7c6df42ca32884);
    DriveInputs(1'b0, 4'ha, 128'h6e088002346334f80f2f129a1d547aaa);
    DriveInputs(1'b0, 4'hb, 128'h0a980602ad8dad88d6b00c713abea53b);
    DriveInputs(1'b0, 4'hc, 128'hcd0c9deab70fd5328970a76fa0d1dc48);
    DriveInputs(1'b0, 4'hd, 128'h9a25537211c82a59b7bdf9a1fbac1f98);
    DriveInputs(1'b0, 4'he, 128'h195b50b81173a575df5ee29817936c81);
    DriveInputs(1'b0, 4'hf, 128'h342e5b8715bbb0cc481365f92724c1ed);

    // Reset the counter
    i_reset_counter = 1;

    // Set padding mode to W3C
    i_update_padding_mode = 1;
    i_padding_mode = 2'b11;
    @(negedge clk);

    $display("\n================");
    $display("=     W3C      =");
    $display("================");
    
    // Try all paddings for the W3C mode
    DriveInputs(1'b0, 4'h0, 128'heab487e68ec92db4ac288a24757b0262);
    DriveInputs(1'b0, 4'h1, 128'hf64d8192e294917701d3d70da384c8e0);
    DriveInputs(1'b0, 4'h2, 128'he1b1ea612690eb1620ed797170814e60);
    DriveInputs(1'b0, 4'h3, 128'h98b896945ce882123e56e787f95857af);
    DriveInputs(1'b0, 4'h4, 128'h1c4874b8899b6a08c8d6ba8a7c56af36);
    DriveInputs(1'b0, 4'h5, 128'hdd573152aa7456e418848171a5a36917);
    DriveInputs(1'b0, 4'h6, 128'h437a94424a9234574e880ded69169a89);
    DriveInputs(1'b0, 4'h7, 128'h5ee7b24ddcd74217e700cfc4804d1d4f);
    DriveInputs(1'b0, 4'h8, 128'hf97a9831c2690f65f60bfef87a095127);
    DriveInputs(1'b0, 4'h9, 128'h7e00f194cdf6e8cea0673e04b679f596);
    DriveInputs(1'b0, 4'ha, 128'h464bb36d1646eccb390c2697dbe980f4);
    DriveInputs(1'b0, 4'hb, 128'h2f7eb1363120ab53ff3682cb37ca006b);
    DriveInputs(1'b0, 4'hc, 128'h77e987e8bdb2a56cd90481a1f2232f4b);
    DriveInputs(1'b0, 4'hd, 128'h70b8b2de66377852c1fa6090ffa5199a);
    DriveInputs(1'b0, 4'he, 128'h9fcb5342ceeda9eb119a749e828953ac);
    DriveInputs(1'b0, 4'hf, 128'h70063b648ddd4ec7ae5bfa7baae10919);

    $finish();
end

endmodule