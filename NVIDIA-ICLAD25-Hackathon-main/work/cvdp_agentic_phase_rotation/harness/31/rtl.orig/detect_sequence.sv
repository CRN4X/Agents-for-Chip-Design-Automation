module detect_sequence #(
    parameter    NS              =  'd64      ,
    parameter    NBW_PILOT_POS   =  'd06      ,
    parameter    NBW_DATA_IN     =  'd08      ,
    parameter    NBI_DATA_IN     =  'd02      ,
    parameter    NBW_TH_PROC     =  'd10      ,
    parameter    NBW_ENERGY      =  'd10      ,
    parameter    NS_PROC         =  'd23      ,
    parameter    NS_PROC_OVERLAP =  NS_PROC - 1
)
(
    input  logic                                        clk               ,
    input  logic                                        rst_async_n       ,
    input  logic                                        i_valid           ,
    input  logic                                        i_enable          ,
    input  logic                                        i_proc_pol        ,
    input  logic [NBW_PILOT_POS-1:0]                    i_proc_pos        ,
    input  logic [NBW_TH_PROC-1:0]                      i_static_threshold,
    input  logic [NBW_DATA_IN*(NS+NS_PROC_OVERLAP)-1:0] i_data_i          ,
    input  logic [NBW_DATA_IN*(NS+NS_PROC_OVERLAP)-1:0] i_data_q          ,
    output logic                                        o_proc_detected    
);
localparam   PROC_CORR_ADDER_LEVELS   = $clog2(NS_PROC);
localparam   PROC_CORR_REG_LEVELS     = 8'b00000000;
localparam   PIPE_DEPTH              = 3;

logic [NS_PROC-1:0] conj_proc_h[2];
logic [NS_PROC-1:0] conj_proc_v[2];

assign conj_proc_h[1] = 23'b11011001100011010001110;
assign conj_proc_v[1] = 23'b10000101011110000101011;

assign conj_proc_h[0] = 23'b10101010111011101000000;
assign conj_proc_v[0] = 23'b11010110101100100001110;

logic signed [NBW_DATA_IN-1:0]  i_data_i_2d[(NS+NS_PROC_OVERLAP)];
logic signed [NBW_DATA_IN-1:0]  i_data_q_2d[(NS+NS_PROC_OVERLAP)];

always_comb begin
    for (int i=0; i<(NS+NS_PROC_OVERLAP); i++) begin
        i_data_i_2d[i] = $signed(i_data_i[(i+1)*NBW_DATA_IN-1-:NBW_DATA_IN]);
        i_data_q_2d[i] = $signed(i_data_q[(i+1)*NBW_DATA_IN-1-:NBW_DATA_IN]);
    end
end

logic  [PIPE_DEPTH-1:0] proc_enable_dff;

logic  proc_detected_dff;

logic  proc_pol_dff;

logic signed [NBW_DATA_IN-1:0] proc_buffer_i_dff[NS_PROC];
logic signed [NBW_DATA_IN-1:0] proc_buffer_q_dff[NS_PROC];
logic signed [NBW_DATA_IN*NS_PROC-1:0] proc_buffer_i_dff_1d;
logic signed [NBW_DATA_IN*NS_PROC-1:0] proc_buffer_q_dff_1d;
logic                     proc_enable;      
logic [NBW_ENERGY  -1 :0] proc_calc_energy; 
logic [       NS_PROC-1:0] conj_proc_seq[2];

assign proc_enable  = i_valid & i_enable;

always_ff @(posedge clk or negedge rst_async_n) begin : proc_proc_enable_dff
  if(~rst_async_n) 
    proc_enable_dff <= {PIPE_DEPTH{1'b0}};
  else begin
    proc_enable_dff[0] <= proc_enable;
    for(int i = 1 ; i < PIPE_DEPTH ; i++)
      proc_enable_dff[i] <= proc_enable_dff[i-1];
  end
end

always_ff @(posedge clk) begin
    if(proc_enable) begin
      for(int i = 0; i < NS_PROC; i++) begin
        proc_buffer_i_dff[i] <=  i_data_i_2d[i_proc_pos + i];
        proc_buffer_q_dff[i] <=  i_data_q_2d[i_proc_pos + i];
      end
    end
end

always_ff @(posedge clk or negedge rst_async_n) begin
    if(~rst_async_n)
        proc_pol_dff <= 1'b0;
    else      
      if(proc_enable)
        proc_pol_dff <=  i_proc_pol;
end

always_comb begin
  if(proc_pol_dff) begin
    conj_proc_seq[0] = conj_proc_v[0];
    conj_proc_seq[1] = conj_proc_v[1];
  end
  else begin
    conj_proc_seq[0] = conj_proc_h[0];
    conj_proc_seq[1] = conj_proc_h[1];    
  end
end

always_comb begin
  for (int i=0; i<NS_PROC; ++i) begin
    proc_buffer_i_dff_1d[(i+1)*NBW_DATA_IN-1-:NBW_DATA_IN] = proc_buffer_i_dff[i];
    proc_buffer_q_dff_1d[(i+1)*NBW_DATA_IN-1-:NBW_DATA_IN] = proc_buffer_q_dff[i];
  end
end

cross_correlation #(
        .NS_DATA_IN  (NS_PROC     ),
        .NBW_DATA_IN (NBW_DATA_IN ),
        .NBI_DATA_IN (NBI_DATA_IN ),
        .NBW_ENERGY  (NBW_ENERGY  )
  ) uu_cross_correlation(
     .clk         (clk                 ),
     .i_enable    (proc_enable_dff[0]  ),
     .i_data_i    (proc_buffer_i_dff_1d),
     .i_data_q    (proc_buffer_q_dff_1d),
     .i_conj_seq_i(conj_proc_seq[0]    ),
     .i_conj_seq_q(conj_proc_seq[1]    ),
     .o_energy    (proc_calc_energy    )
);

assign proc_detected  =   (proc_calc_energy >= i_static_threshold ) && proc_enable_dff[2]; 

always_ff @(posedge clk or negedge rst_async_n) begin : proc_proc_detected_dff
  if(~rst_async_n) 
     proc_detected_dff <= 1'b0;
  else
     proc_detected_dff <=  proc_detected;
end

assign o_proc_detected = proc_detected_dff;

endmodule