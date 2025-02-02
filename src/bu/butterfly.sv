`include "butterfly.svh"

// CT:0 -> GS-based butterfly (take input from A,B,PSI -- output from E,O)
// CT:1 -> CT-based butterfly (take input from A,B,PSI -- output from E,O)
// CT:0 -> Mod Add/Sub (take input from A,B   -- output from ADD/SUB)
// CT:1 -> Mod Mult    (take input from B,PSI -- output from MUL    )

module butterfly
   #(
        parameter LOGQ     = 60,
        parameter LOGQH    = 17,
        parameter NON_STD  = 1 ,
        parameter MORE_DSP = 0
    )
    (
        input               clk,
        input               rst,
        input               CT ,
        input               MT ,
        input  [LOGQ -1:0]  A  ,
        input  [LOGQ -1:0]  B  ,
        input  [LOGQ -1:0]  PSI,
        input  [LOGQH-1:0]  qH ,
        output [LOGQ -1:0]  E  ,
        output [LOGQ -1:0]  O  ,
        output [LOGQ -1:0]  MUL,
        output [LOGQ -1:0]  ADD,
        output [LOGQ -1:0]  SUB
    );

/////////////////////////// parameters //////////////////////////////////

localparam butterfly_params_t butterfly_params = {LOGQ, LOGQH, NON_STD, MORE_DSP};
localparam modadd_params_t modadd_params = butterfly_modadd_params(butterfly_params);
localparam modmul_wlm_params_t modmul_wlm_params = butterfly_modmul_wlm_params(butterfly_params);
localparam MODMUL_LAT = modmul_wlm_lat(modmul_wlm_params);
localparam LAT = butterfly_lat(butterfly_params);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// signals /////////////////////////////////////

reg [LOGQH-1:0] q_add;
reg [LOGQH-1:0] q_sub;

wire [LOGQ-1:0] A_d;
wire [LOGQ-1:0] modadd_res;
wire [LOGQ-1:0] modsub_res;
wire [LOGQ-1:0] modmul_res;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// internal registering ////////////////////////

always @(posedge clk ) begin
    q_add <= qH;
    q_sub <= qH;
end

/////////////////////////////////////////////////////////////////////////




/////////////////////////// modular arithmetic //////////////////////////

modadd #(
    .LOGQ  (modadd_params.LOGQ  ),
    .LOGQH (modadd_params.LOGQH ),
    .FF_IN (modadd_params.FF_IN ),
    .FF_ADD(modadd_params.FF_ADD),
    .FF_OUT(modadd_params.FF_OUT)
) ma0 (
    .A  (A_d       ),
    .B  (modmul_res),
    .qH (q_add     ),
    .C  (modadd_res)
);


modsub #(
    .LOGQ  (modadd_params.LOGQ  ),
    .LOGQH (modadd_params.LOGQH ),
    .FF_IN (modadd_params.FF_IN ),
    .FF_SUB(modadd_params.FF_ADD),
    .FF_OUT(modadd_params.FF_OUT)
) ms0 (
    .A  (A_d   ),
    .B  (modmul_res),
    .qH (q_sub     ),
    .C  (modsub_res)
);


shiftreg #(
    .SHIFT(MODMUL_LAT),
    .DATA (LOGQ      )
) sre10 (
    .clk     (clk    ),
    .reset   (rst    ),
    .data_in (A      ),
    .data_out(A_d    )
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
        .clk(clk       ),
        .A  (B         ),
        .B  (PSI       ),
        .qH (qH        ),
        .T  (modmul_res)
);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// output //////////////////////////////////////

assign E = modadd_res;
assign O = modsub_res;

assign MUL = modmul_res;

assign ADD = modadd_res;
assign SUB = modsub_res;

/////////////////////////////////////////////////////////////////////////

endmodule




