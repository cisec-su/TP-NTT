`ifndef TP_NTT_SVH
`define TP_NTT_SVH


`include "butterfly.svh"


typedef struct packed {
    int LOGN, LOGN1, LOGN2, LOGN3, LOGTP, LOGQ, LOGQH, NON_STD, MORE_DSP;
} tp_ntt_params_t;


typedef enum int {
    DIM_2D = 0,
    DIM_3D = 1,
    DIM_4D = 2
} tp_ntt_dim_t;


typedef enum logic [1:0] {
    OP_NTT          = 2'b00,
    OP_LOAD_TWIDDLE = 2'b01,
    OP_RFU          = 2'b10,
    OP_LOAD_Q       = 2'b11
} tp_ntt_op_t;


function int tp_ntt_logn4(input tp_ntt_params_t params);
    tp_ntt_logn4 = params.LOGN - params.LOGN1 - params.LOGN2 - params.LOGN3;
endfunction


function tp_ntt_dim_t tp_ntt_dim(input tp_ntt_params_t params);
    tp_ntt_dim = (tp_ntt_logn4(params) != 0) ? DIM_4D : (params.LOGN3 != 0) ? DIM_3D : DIM_2D;
endfunction


function butterfly_params_t tp_ntt_butterfly_params(input tp_ntt_params_t params);
    tp_ntt_butterfly_params = {params.LOGQ, params.LOGQH, params.NON_STD, params.MORE_DSP};
endfunction


function int tp_ntt_d(input tp_ntt_params_t params);
    int N  = 1 << params.LOGN;
    int TP = 1 << params.LOGTP;
    tp_ntt_d = N / TP;
endfunction


function int tp_ntt_d1(input tp_ntt_params_t params);
    int N1 = 1 << params.LOGN1;
    int N2 = 1 << params.LOGN2;
    int TP = 1 << params.LOGTP;
    tp_ntt_d1 = (N1 * N2) / TP;
endfunction


function int tp_ntt_d2(input tp_ntt_params_t params);
    int N3 = 1 << params.LOGN1;
    int N4 = 1 << tp_ntt_logn4(params);
    int TP = 1 << params.LOGTP;
    tp_ntt_d2 = (N3 * N4) / TP;
endfunction

/*
 * Latency refers to the number of clock cycles between the last input and first output (see tp_ntt_tb.sv)
 */
function int tp_ntt_lat(input tp_ntt_params_t params);
    int logn4 = tp_ntt_logn4(params);
    butterfly_params_t butterfly_params = tp_ntt_butterfly_params(params);
    int butterfly_lat_plus1 = butterfly_lat(butterfly_params) + 1;
    if (tp_ntt_dim(params) == DIM_2D)
        tp_ntt_lat = (butterfly_lat_plus1 * params.LOGN) + 9 + 2 + 3;
    else if (tp_ntt_dim(params) == DIM_3D)
        tp_ntt_lat = (butterfly_lat_plus1 * params.LOGN) + tp_ntt_d1(params) + 15 + 3 + 3;
    else
        tp_ntt_lat = (butterfly_lat_plus1 * params.LOGN) + tp_ntt_d1(params) + tp_ntt_d2(params) + 21 + 4 + 3;
endfunction


`endif