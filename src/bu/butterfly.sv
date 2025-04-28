`include "butterfly.svh"

// CT:0 -> GS-based butterfly (take input from A,B,psi -- output from E,O)
// CT:1 -> CT-based butterfly (take input from A,B,psi -- output from E,O)
// CT:0 -> Mod Add/Sub (take input from A,B   -- output from add/sub)
// CT:1 -> Mod Mult    (take input from B,psi -- output from mul    )

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
        input               MT ,
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
localparam modmul_wlm_params_t modmul_wlm_params = butterfly_modmul_wlm_params(butterfly_params);
localparam MODMUL_LAT = modmul_wlm_lat(modmul_wlm_params);
localparam LAT = butterfly_lat(butterfly_params);

localparam W = LOGQ - LOGQH;

/////////////////////////////////////////////////////////////////////////




/////////////////////////// signals /////////////////////////////////////

reg  [LOGQH - 1 : 0] q_add;
reg  [LOGQH - 1 : 0] q_sub; 
reg [LOGQ-1:0] modadd_res_intt_reg, mod_second_in, mod_second_in_b, modadd_res_reg;
 
wire [LOGQ  - 1 : 0] A_q;
wire [LOGQ  - 1 : 0] modadd_res, modadd_res_intt, modadd_res_del, modadd_res_del_d1, modadd_res_intt_del, res_anan, mod_second_in_b;
wire [LOGQ  - 1 : 0] modsub_res;
wire [LOGQ  - 1 : 0] modmul_res;
wire [LOGQ  - 1 : 0] modadd_B_in;
wire [LOGQ  - 1 : 0] modsub_B_in;
wire [LOGQ  - 1 : 0] modmul_A_in;
wire [LOGQ  - 1 : 0] A_q_mx, A_q_mad;
wire [LOGQ  - 1 : 0] B_d;
wire [LOGQ  - 1 : 0] modadd_res_d1;


/////////////////////////////////////////////////////////////////////////




/////////////////////////// internal registering ////////////////////////

always @(posedge clk ) begin
    q_add <= qH;
    q_sub <= qH;
end

/////////////////////////////////////////////////////////////////////////



assign modadd_B_in = CT ? modmul_res :  B;
assign modsub_B_in = CT ? modmul_res :  B;

assign modmul_A_in = CT ? B     : modsub_res;
assign A_q_mx      = CT ? A_q   : A;

assign A_q_mad      = CT ? A_q   : A;


/////////////////////////// modular arithmetic //////////////////////////

modadd #(
    .LOGQ  (modadd_params.LOGQ  ),
    .LOGQH (modadd_params.LOGQH ),
    .FF_IN (modadd_params.FF_IN ),
    .FF_ADD(modadd_params.FF_ADD),
    .FF_OUT(modadd_params.FF_OUT)
) ma0 (
    .A  (A_q_mad       ),
    .B  (modadd_B_in),
    .qH (q_add     ),
    .C  (modadd_res)
);

modadd #(
    .LOGQ  (modadd_params.LOGQ  ),
    .LOGQH (modadd_params.LOGQH ),
    .FF_IN (modadd_params.FF_IN ),
    .FF_ADD(modadd_params.FF_ADD),
    .FF_OUT(modadd_params.FF_OUT)
) ma1 (
    .A  (mod_second_in     ),
    .B  (mod_second_in_b),
    .qH (q_add     ),
    .C  (modadd_res_intt)
);



always @(posedge clk ) begin
    //mod_second_in_b <=({qH, {(W){1'b0}}} + 2)>>1;
    //mod_second_in <= modadd_res>>1;  
    modadd_res_intt_reg <= modadd_res_intt;
end

always@(*) begin
    assign mod_second_in =  modadd_res>>1;
    
    assign mod_second_in_b = ({qH, {(W){1'b0}}} + 2)>>1;

    assign modadd_res_reg = modadd_res;
end

modsub #(
    .LOGQ  (modadd_params.LOGQ  ),
    .LOGQH (modadd_params.LOGQH ),
    .FF_IN (modadd_params.FF_IN ),
    .FF_SUB(modadd_params.FF_ADD),
    .FF_OUT(modadd_params.FF_OUT)
) ms0 (
    .A  (A_q_mx   ),
    .B  (modsub_B_in),
    .qH (q_sub     ),
    .C  (modsub_res)
);


shiftreg #(
    .SHIFT(MODMUL_LAT),
    .DATA (LOGQ      )
) sre10 (
    .clk     (clk    ),
    .reset   (1'b0   ),
    .data_in (A      ),
    .data_out(A_q    )
);

shiftreg #(
    .SHIFT(MODMUL_LAT),
    .DATA (LOGQ      )
) sre20 (
    .clk     (clk    ),
    .reset   (1'b0   ),
    .data_in (B      ),
    .data_out(B_d    )
);

shiftreg #(
    .SHIFT(MODMUL_LAT-1),
    .DATA (LOGQ      )
) sre30 (
    .clk     (clk    ),
    .reset   (1'b0   ),
    .data_in (modadd_res_reg      ),
    .data_out(modadd_res_del    )
);

shiftreg #(
    .SHIFT(1),
    .DATA (LOGQ      )
) sre40 (
    .clk     (clk    ),
    .reset   (1'b0   ),
    .data_in (modadd_res_del      ),
    .data_out(modadd_res_del_d1    )
);


shiftreg #(
    .SHIFT(MODMUL_LAT-1),
    .DATA (LOGQ      )
) sre50 (
    .clk     (clk    ),
    .reset   (1'b0   ),
    .data_in (modadd_res_intt_reg      ),
    .data_out(modadd_res_intt_del    )
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
        .A  (modmul_A_in         ),
        .B  (psi       ),
        .qH (qH        ),
        .T  (modmul_res)
);

/////////////////////////////////////////////////////////////////////////




/////////////////////////// output //////////////////////////////////////

assign E = CT ? modadd_res : (modadd_res_del_d1[0] == 1'b1 ? modadd_res_intt_del : modadd_res_del_d1>>1);
assign O = CT ? modsub_res : modmul_res;

/////////////////////////////////////////////////////////////////////////

endmodule




