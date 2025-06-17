`include "butterfly.svh"

module tp_ntt_core 
   #(
        parameter LOGN         = 32,
        parameter LOGQ         = 32,
        parameter LOGQH        = 17,
        parameter NON_STD      = 1 ,
        parameter MORE_DSP     = 0
    )
    (
        input                        clk   , 
        input                        intt  ,
        input wire  [LOGQH     -1:0] qH    ,
        input wire  [LOGQ*N    -1:0] i_poly,
        input wire  [LOGQ*(N-1)-1:0] psi   ,
        output wire [LOGQ*N    -1:0] o_poly
    );

/////////////////////////// parameters //////////////////////////////////

localparam N = 1 << LOGN;
localparam butterfly_params_t butterfly_params = {LOGQ, LOGQH, NON_STD, MORE_DSP};
localparam BTF_LAT = butterfly_lat(butterfly_params);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// signals /////////////////////////////////////

wire [LOGQ - 1 : 0] stage_out [0 : LOGN - 1][0 : N - 1];
wire [LOGQ - 1 : 0] stage_in  [0 : LOGN - 1][0 : N - 1];

wire [LOGQ * (N - 1) - 1 : 0] psi_q  [0 : LOGN - 1];
wire [LOGQ * (N - 1) - 1 : 0] psi_mx [0 : LOGN - 1];
reg  [LOGQ           - 1 : 0] psi_st [0 : LOGN - 1][0 : (N >> 1) - 1];

reg                  CT   [0 : LOGN - 1][0 : (N >> 1) - 1];
reg  [LOGQ  - 1 : 0] A    [0 : LOGN - 1][0 : (N >> 1) - 1];
reg  [LOGQ  - 1 : 0] B    [0 : LOGN - 1][0 : (N >> 1) - 1];
reg  [LOGQH - 1 : 0] qH_q [0 : LOGN - 1][0 : (N >> 1) - 1];
wire [LOGQ  - 1 : 0] E    [0 : LOGN - 1][0 : (N >> 1) - 1];
wire [LOGQ  - 1 : 0] O    [0 : LOGN - 1][0 : (N >> 1) - 1];

reg  [LOGQ*N- 1  :0] i_poly_q;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// stage connections ///////////////////////////

generate
    for (genvar i = 0; i < LOGN; i = i + 1) begin 
        for (genvar j = 0; j < (N >> 1) ; j = j + 1) begin
            assign stage_out[i][(j << 1)    ] = E[i][j];
            assign stage_out[i][(j << 1) + 1] = O[i][j];
        end
    end
endgenerate


generate
    for (genvar j = 0; j < (LOGN - 1); j = j + 1) begin 
        for (genvar i = 0; i < (N >> 1); i = i + 1) begin
            assign stage_in[j + 1][(((i << 1) & ((N >> j) - 1)) / (N >> (j + 1))) + ((i << 1) & ((N >> (j + 1)) - 1)) + (((i << 1) / (N >> j)) * (N >> j))                 ] = stage_out[j][(i << 1)    ];
            assign stage_in[j + 1][(((i << 1) & ((N >> j) - 1)) / (N >> (j + 1))) + ((i << 1) & ((N >> (j + 1)) - 1)) + (((i << 1) / (N >> j)) * (N >> j)) + (N >> (j + 1))] = stage_out[j][(i << 1) + 1];
        end
    end
endgenerate


generate
    for (genvar j = 0; j < LOGN; j = j + 1) begin
        for (genvar i = 0; i < (N >> 1); i = i + 1) begin
            always @(posedge clk) begin
                if (intt) begin
                    psi_st[j][i] <= psi_q[j][((N - 1 - ((2 * ((1 << (LOGN - 1)) - (1 << (LOGN - j - 1)))) + (i&((1<<(LOGN-(j+1)))-1)))) * LOGQ) - 1 -: LOGQ];
                end else begin
                    psi_st[j][i] <= psi_q[j][((N - 1 - (((1 << j) - 1) + i / (N >> (j + 1)))) * LOGQ) - 1 -: LOGQ];   
                end
                             
            end
        end
    end
endgenerate

/////////////////////////////////////////////////////////////////////////




/////////////////////////// output //////////////////////////////////////

generate
    for (genvar i = 0; i < N; i = i + 1) begin 
        assign o_poly[(N - i) * LOGQ - 1 -: LOGQ] = stage_out[LOGN - 1][i];
    end
endgenerate

/////////////////////////////////////////////////////////////////////////




///////////////////// butterfly instantiations //////////////////////////

generate
    for (genvar j = 0; j < LOGN ; j = j + 1) begin
        for (genvar i = 0; i < (N >> 1); i = i + 1) begin: BTF_GEN_BLOCK
            butterfly #(
                .LOGQ    (LOGQ    ),
                .LOGQH   (LOGQH   ),
                .NON_STD (NON_STD ),
                .MORE_DSP(MORE_DSP)
            ) butterfly_inst (
                .clk(clk         ),
                .CT (CT    [j][i]),
                .A  (A     [j][i]),
                .B  (B     [j][i]),
                .psi(psi_st[j][i]),
                .qH (qH_q  [j][i]),
                .E  (E     [j][i]),
                .O  (O     [j][i])
            );
        end
    end
endgenerate

/////////////////////////////////////////////////////////////////////////




/////////////////// shift registers for twiddles ////////////////////////

generate
    for (genvar i = 0; i < LOGN; i = i + 1) begin
        localparam SHIFT = (i == 0) ? 1   : BTF_LAT + 1;
        assign psi_mx[i] = (i == 0) ? psi : psi_q[i - 1];
        shiftreg #(
            .SHIFT(SHIFT),
            .DATA((N - 1)*LOGQ)
        ) shiftreg_psi (
            .clk     (clk      ),
            .reset   (1'b0     ),
            .data_in (psi_mx[i]),
            .data_out(psi_q [i])
        );
    end
endgenerate

/////////////////////////////////////////////////////////////////////////




////////////////// sequential logic for butterfly input/output //////////

generate

    for (genvar i = 0; i < (N >> 1); i = i + 1) begin
        for (genvar j = 0; j < LOGN; j = j + 1) begin

            always @(posedge clk) begin
                CT  [j][i] <= (j == 0) ? ~intt : CT  [j - 1][i];
                qH_q[j][i] <= (j == 0) ?    qH : qH_q[j - 1][i];
            end       
     
            if (j == 0) begin
                always @(posedge clk) begin
                    A[0][i] <= i_poly_q[(N - (i << 1)    ) * LOGQ - 1 -: LOGQ];
                    B[0][i] <= i_poly_q[(N - (i << 1) - 1) * LOGQ - 1 -: LOGQ];
                end   
            end
            else begin
                always @(posedge clk) begin
                    A[j][i] <= stage_in[j][(i << 1)    ];
                    B[j][i] <= stage_in[j][(i << 1) + 1];
                end
            end

        end
    end

endgenerate

/////////////////////////////////////////////////////////////////////////




//////////////////////////// register input /////////////////////////////

always @(posedge clk) begin
    i_poly_q <= i_poly;
end


/////////////////////////////////////////////////////////////////////////
endmodule
