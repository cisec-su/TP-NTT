`ifndef BUTTERFLY_SVH
`define BUTTERFLY_SVH

`include "wlm_mixed.svh"
`include "modmul_wlm.svh"
`include "modadd.svh"


typedef struct packed {
    int LOGQ, LOGQH, NON_STD, MORE_DSP;
} butterfly_params_t;


function modmul_wlm_params_t butterfly_modmul_wlm_params(input butterfly_params_t params);
    butterfly_modmul_wlm_params = '{LOGQ   : params.LOGQ, LOGQH    : params.LOGQH   , CORRECT : 1             ,
                                    FF_IN  : 1          , FF_MUL   : 1              , FF_SUM  : 0             ,
                                    FF_SUB : 0          , FF_OUT   : 1              , USE_CSA : 0             ,
                                    FF_CSA : 0          , MORE_DSP : params.MORE_DSP, NON_STD : params.NON_STD};
endfunction


function modadd_params_t butterfly_modadd_params(input butterfly_params_t params);
    butterfly_modadd_params = '{LOGQ : params.LOGQ, LOGQH : params.LOGQH, FF_IN : 0, FF_ADD : 0, FF_OUT : 0};
endfunction


function int butterfly_lat(input butterfly_params_t params);
    modmul_wlm_params_t modmul_wlm_params = butterfly_modmul_wlm_params(params);
    modadd_params_t modadd_params = butterfly_modadd_params(params);
    butterfly_lat =  modmul_wlm_lat(modmul_wlm_params) + modadd_lat(modadd_params) + 1;
endfunction


`endif