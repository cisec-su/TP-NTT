`include "tp_ntt.svh"

module tp_ntt_top_w_shuffle
   #(
        parameter LOGN          = 16,
        parameter LOGN1         = 6 ,
        parameter LOGN2         = 4 ,
        parameter LOGN3         = 6 ,
        parameter LOGTP         = 6 ,
        parameter LOGQ          = 60,
        parameter LOGQH         = 17,
        parameter NON_STD       = 1 ,
        parameter MORE_DSP      = 0
    )
    (
        input                           clk,
        input                           rst,
        input                           start,
        input  tp_ntt_op_t              op,
        input                           intt,
        input                           shuffle_mod,
        input       [LOGQH      -1:0]   qH,
        input       [TP*LOGQ    -1:0]   i_poly,
        input       [(TP-1)*LOGQ-1:0]   psi,
        output reg  [TP*LOGQ    -1:0]   o_poly
    );


localparam tp_ntt_params_t tp_ntt_params        = {LOGN, LOGN1, LOGN2, LOGN3, LOGTP, LOGQ, LOGQH, NON_STD, MORE_DSP};
localparam tp_ntt_dim_t DIM                     = tp_ntt_dim(tp_ntt_params);
localparam butterfly_params_t butterfly_params  = {LOGQ, LOGQH, NON_STD, MORE_DSP};
localparam LAT                                  = tp_ntt_lat(tp_ntt_params);
localparam BTF_LAT                              = butterfly_lat(butterfly_params);    
localparam LOGN4                                = tp_ntt_logn4(tp_ntt_params);
localparam D                                    =  tp_ntt_d(tp_ntt_params);
localparam D1                                   =  tp_ntt_d1(tp_ntt_params);
localparam D2                                   =  tp_ntt_d2(tp_ntt_params);
localparam N                                    = 1 << LOGN;
localparam N1                                   = 1 << LOGN1;
localparam N2                                   = 1 << LOGN2;
localparam N3                                   = 1 << LOGN3;
localparam TP                                   = 1 << LOGTP;
localparam N4                                   = 1 << LOGN4;




wire start_ntt2, start_ntt_top, start_ntt_top_d1, start_ntt_top_fn;
wire [TP*LOGQ-1:0] poly_ntt1, shuffle_out, poly_ntt_res;

reg [TP*LOGQ-1:0] poly_d1, poly_d2, poly_d3, shuffle_in;

always @(posedge clk) begin
    poly_d1 <= i_poly;
    poly_d2 <= poly_d1;
    shuffle_in <= poly_d2;
end

shiftreg #(
    .SHIFT (14'd128 + 7),
    .DATA  (1)
) sre101 (
    .clk      (clk           ),
    .reset    (rst           ),
    .data_in  (start         ),
    .data_out (start_ntt_top )
);

shiftreg #(
    .SHIFT (1),
    .DATA  (1)
) sre102 (
    .clk      (clk              ),
    .reset    (rst              ),
    .data_in  (start_ntt_top    ),
    .data_out (start_ntt_top_d1 )
);


assign start_ntt_top_fn = shuffle_mod ? start_ntt_top_d1 : start_ntt_top;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        o_poly <= 0;
    end else begin
        o_poly <= poly_ntt_res;
        
    end    
end

shuffle_process_upd #(
        .LOGN    (LOGN    ),
        .LOGN1   (LOGN1   ),
        .LOGN2   (LOGN2   ),
        .LOGTP   (LOGTP   ),
        .LOGQ    (LOGQ    )
    ) uut_shuf (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mod_op(shuffle_mod),
        .input_data(shuffle_in),
        .output_data(shuffle_out)
    );



tp_ntt_top #(
        .LOGN    (LOGN    ),
        .LOGN1   (LOGN1   ),
        .LOGN2   (LOGN2   ),
        .LOGN3   (LOGN3   ),
        .LOGTP   (LOGTP   ),
        .LOGQ    (LOGQ    ),
        .LOGQH   (LOGQH   ),
        .NON_STD (NON_STD ),
        .MORE_DSP(MORE_DSP)
    ) uut_top (
        .clk(clk),
        .rst(rst),
        .start(start_ntt_top_fn),
        .op(op),
        .shuffle_mod(shuffle_mod),
        .intt(intt),
        .qH(qH),
        .i_poly(shuffle_out),
        .psi(psi),
        .o_poly(poly_ntt_res)
    );



endmodule
