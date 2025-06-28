`include "butterfly.svh"

// CT:0 -> GS-based butterfly (take input from A,B,psi -- output from E,O)
// CT:1 -> CT-based butterfly (take input from A,B,psi -- output from E,O)

module butterfly
   #(
        parameter LOGQ     = 60,
        parameter LOGQH    = 17,
        parameter NON_STD  = 1 ,
        parameter MORE_DSP = 0
    )
    (
        input               clk,
        input               CT ,
        input  [LOGQ -1:0]  A  ,
        input  [LOGQ -1:0]  B  ,
        input  [LOGQ -1:0]  psi,
        input  [LOGQH-1:0]  qH ,
        output [LOGQ -1:0]  E  ,
        output [LOGQ -1:0]  O
    );

/////////////////////////// parameters //////////////////////////////////

localparam butterfly_params_t butterfly_params = {LOGQ, LOGQH, NON_STD, MORE_DSP};
localparam modadd_params_t modadd_params = butterfly_modadd_params(butterfly_params);
localparam MODADD_LAT = modadd_lat(modadd_params);
localparam modmul_wlm_params_t modmul_wlm_params = butterfly_modmul_wlm_params(butterfly_params);
localparam MODMUL_LAT = modmul_wlm_lat(modmul_wlm_params);
localparam LAT = butterfly_lat(butterfly_params);

localparam W = LOGQ - LOGQH;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// signals /////////////////////////////////////

reg  [LOGQH - 1 : 0] q_add0;
reg  [LOGQH - 1 : 0] q_add1;
reg  [LOGQH - 1 : 0] q_sub; 

wire [LOGQ  - 1 : 0] modadd0_in_A;
wire [LOGQ  - 1 : 0] modadd0_in_B;
wire [LOGQ  - 1 : 0] modadd0_out;
wire [LOGQ  - 1 : 0] modadd1_in_A;
wire [LOGQ  - 1 : 0] modadd1_in_B;
wire [LOGQ  - 1 : 0] modadd1_out;
wire [LOGQ  - 1 : 0] modsub_in_A;
wire [LOGQ  - 1 : 0] modsub_in_B;
wire [LOGQ  - 1 : 0] modsub_out;
wire [LOGQ  - 1 : 0] modmul_in_A;
wire [LOGQ  - 1 : 0] modmul_in_B;
wire [LOGQ  - 1 : 0] modmul_out;
wire [LOGQ  - 1 : 0] A_d;
wire [LOGQ  - 1 : 0] psi_d;
wire [LOGQ  - 1 : 0] modadd0_out_d;
wire [LOGQ  - 1 : 0] modadd0_out_d1;
wire [LOGQ  - 1 : 0] mulinv2_out;

reg [LOGQ  - 1 : 0] E_q;
reg [LOGQ  - 1 : 0] O_q;



/////////////////////////////////////////////////////////////////////////




/////////////////////////// internal registering ////////////////////////

always @(posedge clk ) begin
    q_add0 <= qH;
    q_add1 <= qH;
    q_sub <= qH;
end


always @(posedge clk) begin
    E_q <= CT ? modadd0_out : mulinv2_out;
    O_q <= CT ? modsub_out  : modmul_out;
end


/////////////////////////////////////////////////////////////////////////

assign modadd0_in_A = CT ? A_d        : A;
assign modadd0_in_B = CT ? modmul_out : B;

assign modsub_in_A  = CT ? A_d        : A;
assign modsub_in_B  = CT ? modmul_out : B;

assign modmul_in_A  = CT ? B          : modsub_out;
assign modmul_in_B  = CT ? psi        : psi_d;

assign modadd1_in_A  = modadd0_out_d >> 1;
assign modadd1_in_B  = ({qH, {(W){1'b0}}} + 2'd2) >> 1;

assign mulinv2_out   = (modadd0_out_d1[0] == 1'b1) ? modadd1_out : modadd0_out_d1 >> 1;

assign E = E_q;
assign O = O_q;

/////////////////////////// modular arithmetic //////////////////////////

modadd #(
    .LOGQ  (modadd_params.LOGQ  ),
    .LOGQH (modadd_params.LOGQH ),
    .FF_IN (modadd_params.FF_IN ),
    .FF_ADD(modadd_params.FF_ADD),
    .FF_OUT(modadd_params.FF_OUT)
) ma0 (
    .A  (modadd0_in_A),
    .B  (modadd0_in_B),
    .clk(clk         ),
    .qH (q_add0      ),
    .C  (modadd0_out )
);

modadd #(
    .LOGQ  (modadd_params.LOGQ  ),
    .LOGQH (modadd_params.LOGQH ),
    .FF_IN (modadd_params.FF_IN ),
    .FF_ADD(modadd_params.FF_ADD),
    .FF_OUT(modadd_params.FF_OUT)
) ma1 (
    .A  (modadd1_in_A),
    .B  (modadd1_in_B),
    .clk(clk         ),
    .qH (q_add1      ),
    .C  (modadd1_out )
);


modsub #(
    .LOGQ  (modadd_params.LOGQ  ),
    .LOGQH (modadd_params.LOGQH ),
    .FF_IN (modadd_params.FF_IN ),
    .FF_SUB(modadd_params.FF_ADD),
    .FF_OUT(modadd_params.FF_OUT)
) ms0 (
    .A  (modsub_in_A),
    .B  (modsub_in_B),
    .clk(clk        ),
    .qH (q_sub      ),
    .C  (modsub_out )
);


modmul_wlm #(
        .LOGQ    (modmul_wlm_params.LOGQ    ),
        .LOGQH   (modmul_wlm_params.LOGQH   ),
        .CORRECT (modmul_wlm_params.CORRECT ),
        .FF_IN   (modmul_wlm_params.FF_IN   ),
        .FF_MUL  (modmul_wlm_params.FF_MUL  ),
        .FF_SUM  (modmul_wlm_params.FF_SUM  ),
        .FF_SUB  (modmul_wlm_params.FF_SUB  ),
        .FF_OUT  (modmul_wlm_params.FF_OUT  ),
        .USE_CSA (modmul_wlm_params.USE_CSA ),
        .FF_CSA  (modmul_wlm_params.FF_CSA  ),
        .MORE_DSP(modmul_wlm_params.MORE_DSP),
        .NON_STD (modmul_wlm_params.NON_STD )
) mm0 (
        .clk(clk        ),
        .A  (modmul_in_A),
        .B  (modmul_in_B),
        .qH (qH         ),
        .T  (modmul_out )
);


shiftreg #(
    .SHIFT(MODMUL_LAT),
    .DATA (LOGQ      )
) sre10 (
    .clk     (clk    ),
    .reset   (1'b0   ),
    .data_in (A      ),
    .data_out(A_d    )
);


shiftreg #(
    .SHIFT(MODADD_LAT),
    .DATA (LOGQ      )
) sre20 (
    .clk     (clk    ),
    .reset   (1'b0   ),
    .data_in (psi    ),
    .data_out(psi_d  )
);


shiftreg #(
    .SHIFT(MODMUL_LAT - MODADD_LAT),
    .DATA (LOGQ)
) sre30 (
    .clk     (clk          ),
    .reset   (1'b0         ),
    .data_in (modadd0_out  ),
    .data_out(modadd0_out_d)
);


shiftreg #(
    .SHIFT(MODADD_LAT),
    .DATA (LOGQ      )
) sre40 (
    .clk     (clk           ),
    .reset   (1'b0          ),
    .data_in (modadd0_out_d ),
    .data_out(modadd0_out_d1)
);

/////////////////////////////////////////////////////////////////////////

endmodule




