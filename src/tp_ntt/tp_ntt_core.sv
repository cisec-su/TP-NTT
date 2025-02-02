`include "butterfly.svh"

module tp_ntt_core 
   #(
        parameter N           = 32,
        parameter LOGQ         = 32,
        parameter LOGQH        = 17,
        parameter NON_STD      = 1 ,
        parameter MORE_DSP     = 0
    )
    (
        input                        clk   , 
        input                        rst   ,
        input wire  [LOGQH     -1:0] q_in  ,
        input wire  [LOGQ*N    -1:0] NTT_in,
        input wire  [LOGQ*(N-1)-1:0] W_in  ,
        output wire [LOGQ*N    -1:0] NTT_out
    );

localparam butterfly_params_t butterfly_params = {LOGQ, LOGQH, NON_STD, MORE_DSP};
localparam BTF_LAT = butterfly_lat(butterfly_params);
localparam stage_nums =  $rtoi($ceil($clog2(N)));

wire [LOGQ-1:0] NTT_results       [stage_nums-1:0][N-1:0];
wire [LOGQ-1:0] NTT_results_after [stage_nums-1:0][N-1:0];

reg            CT00 [stage_nums-1:0][(N>>1)-1:0];
reg            MT00 [stage_nums-1:0][(N>>1)-1:0];
reg [LOGQ-1:0] A00  [stage_nums-1:0][(N>>1)-1:0];
reg [LOGQ-1:0] B00  [stage_nums-1:0][(N>>1)-1:0];
reg [LOGQ-1:0] PSI00[stage_nums-1:0][(N>>1)-1:0];
reg [LOGQH-1:0] Q00  [stage_nums-1:0][(N>>1)-1:0];
wire[LOGQ-1:0] E00  [stage_nums-1:0][(N>>1)-1:0];
wire[LOGQ-1:0] O00  [stage_nums-1:0][(N>>1)-1:0];
wire[LOGQ-1:0] MUL00[stage_nums-1:0][(N>>1)-1:0];
wire[LOGQ-1:0] ADD00[stage_nums-1:0][(N>>1)-1:0];
wire[LOGQ-1:0] SUB00[stage_nums-1:0][(N>>1)-1:0];

wire [LOGQ*(N-1)-1:0] W_in_shifted [stage_nums-1:0] ;


generate
for (genvar i = 0; i < N>>1 ; i = i + 1 ) begin
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            {A00[0][i],B00[0][i],PSI00[0][i],CT00[0][i],MT00[0][i],Q00[0][i]} <= 0;
        end
        else begin
            {A00[0][i],B00[0][i],PSI00[0][i],CT00[0][i],MT00[0][i],Q00[0][i]} <= {NTT_in[(N-2*i)*LOGQ-1-:LOGQ],NTT_in[(N-(2*i+1))*LOGQ-1-:LOGQ],W_in[((N-1)*LOGQ)-1-:LOGQ],1'b1,1'b0, q_in};
        end
    end
    
end
endgenerate


generate
for (genvar i = 0; i < stage_nums; i = i + 1) begin 
    for (genvar j = 0; j < N>>1 ; j = j + 1) begin
        assign NTT_results[i][2*j] = E00[i][j];
        assign NTT_results[i][2*j+1] = O00[i][j];

    end
end
endgenerate


generate
    for (genvar j = 0; j < stage_nums-1; j = j + 1) begin 
        for (genvar i = 0; i < N>>1 ; i = i + 1) begin
            assign NTT_results_after[j+1][(((2*i)&((N>>j)-1))/(N>>(j+1))) + ((2*i) & ((N>>(j+1))-1)) + (((2*i)/(N>>(j)))*(N>>(j)))] = NTT_results[j][2*i];
            assign NTT_results_after[j+1][(((2*i)&((N>>j)-1))/(N>>(j+1))) + ((2*i) & ((N>>(j+1))-1)) + (((2*i)/(N>>(j)))*(N>>(j))) + ((N>>(j+1))*1)] = NTT_results[j][2*i+1];
        end
    end
endgenerate


generate
    for (genvar j = 1; j < stage_nums; j = j + 1) begin // For every stage
        for (genvar i = 0; i < (N>>1); i = i + 1) begin // For every butterfly
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    {A00[j][i],B00[j][i],PSI00[j][i],CT00[j][i],MT00[j][i],Q00[j][i]} <= 0;
                end
                else begin
                    {A00[j][i],B00[j][i],PSI00[j][i],CT00[j][i],MT00[j][i],Q00[j][i]} <= {NTT_results_after[j][2*i],NTT_results_after[j][2*i+1],W_in_shifted[j][((N-1-(((1<<j)-1)+i/(N>>(j+1))))*LOGQ)-1-:LOGQ],1'b1,1'b0,q_in};
                end
                    
            end
        end
    end
endgenerate


generate
    for (genvar k = 0; k < stage_nums ; k = k + 1) begin
        for (genvar m = 0; m < (N>>1); m = m + 1) begin: BTF_GEN_BLOCK
            butterfly #(
                .LOGQ    (LOGQ    ),
                .LOGQH   (LOGQH   ),
                .NON_STD (NON_STD ),
                .MORE_DSP(MORE_DSP)
            ) btfu00 (clk,rst,CT00[k][m],MT00[k][m],A00[k][m],B00[k][m],PSI00[k][m],Q00[k][m],E00[k][m],O00[k][m],MUL00[k][m],ADD00[k][m],SUB00[k][m]);
        end
    end
endgenerate


generate
    for (genvar i = 0; i < N; i = i + 1) begin // For every stage
        assign NTT_out[(N-(i))*LOGQ-1-:LOGQ] = {NTT_results[stage_nums-1][i]};
    end
endgenerate

//todo: remove redundant register usage
generate
    for (genvar b = 1; b < stage_nums; b = b + 1) begin
        shiftreg #(.SHIFT(b*(BTF_LAT + 1)),.DATA((N-1)*LOGQ)) sre100(clk,rst,W_in,W_in_shifted[b]);
    end
endgenerate


endmodule
