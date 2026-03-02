`include "tp_ntt.svh"

module tp_ntt_top
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
        input       [TP*LOGQ    -1:0]   psi,
        output reg  [TP*LOGQ    -1:0]   o_poly
    );


localparam tp_ntt_params_t TP_NTT_PARAMS        = {LOGN, LOGN1, LOGN2, LOGN3, LOGTP, LOGQ, LOGQH, NON_STD, MORE_DSP};
// if (tp_ntt_is_not_valid_partition(TP_NTT_PARAMS)) begin
//     partitioning_is_NOT_supported();
// end

// assert instead of fake module
// initial begin
//     if (tp_ntt_is_not_valid_partition(TP_NTT_PARAMS)) begin
//         $error("Invalid NTT partitioning");
//     end
// end

localparam tp_ntt_dim_t DIM                     = tp_ntt_dim(TP_NTT_PARAMS);
localparam butterfly_params_t BUTTERFLY_PARAMS  = {LOGQ, LOGQH, NON_STD, MORE_DSP};
localparam LAT                                  = tp_ntt_lat(TP_NTT_PARAMS);
localparam BTF_LAT                              = butterfly_lat(BUTTERFLY_PARAMS);    
localparam LOGN4                                = tp_ntt_logn4(TP_NTT_PARAMS);
localparam D                                    = tp_ntt_d(TP_NTT_PARAMS);
localparam D1                                   = tp_ntt_d1(TP_NTT_PARAMS);
localparam D2                                   = tp_ntt_d2(TP_NTT_PARAMS);
localparam N                                    = 1 << LOGN;
localparam N1                                   = 1 << LOGN1;
localparam N2                                   = 1 << LOGN2;
localparam N3                                   = 1 << LOGN3;
localparam TP                                   = 1 << LOGTP;
localparam N4                                   = 1 << LOGN4;
localparam DEPTH                                = N/TP;

localparam OP_IDLE                      = 1'd0;
localparam OP_TWIDDLE_LOAD              = 1'd1;




wire start_ntt2, start_ntt3, start_ntt4, start_au1, start_au2, start_au3, start_sig1;
wire intt_au1, intt_au2, intt_au3, intt_ntt2, intt_ntt3, intt_ntt4, intt_d1;

wire [TP*LOGQ-1:0] poly_ntt1, poly_ntt2, poly_ntt3, poly_ntt4, poly_au1, poly_au1_d2, poly_au2, poly_au3, poly_in_ntt1, poly_au2_d3, poly_au3_d4;

reg [TP*LOGQ-1:0] poly_d1, poly_d2, poly_d3, poly_d4;

wire       [LOGQH      -1:0]    qH_d1, qH_d2, qH_d3, qH_d4;
wire       [1:0]                op_code_d1, op_code_d2, op_code_d3, op_code_d4;

reg start_d1;


wire [(TP-1)*LOGQ-1:0] psi_out, psi_out_d1, psi_out_d2, psi_out_d3, psi_out_d4;








always @(posedge clk) begin
    poly_d1 <= i_poly;
    poly_d2 <= poly_d1;
    poly_d3 <= poly_d2;
    poly_d4 <= poly_d3;

    start_d1 <= start;
end





if (DIM == DIM_2D) begin
    tp_ntt_core_wrapper #(
        .DIM(DIM),
        .LOGN(LOGN),
        .LOGN1(LOGN1),
        .LOGN2(LOGN2),
        .LOG_GLOBAL_N2(LOGN2),
        .LOG_GLOBAL_N3(LOGN3),
        .LOGTP(LOGTP),
        .LOGQ(LOGQ),
        .LOGQH(LOGQH),
        .BLOCK_ID(0),       
        .LARGE(0),
        .RW_DIS(0)
    ) tp_ntt_d1 (
        .clk(clk), 
        .rst(rst), 
        .start(start_sig1),
        .op(op_code_d1), 
        .intt(intt_d1),
        .qH(qH_d1), 
        .i_poly(poly_in_ntt1), 
        .psi(psi_out_d1), 
        .o_poly(poly_ntt1)
    );

    automorphism_unit#(
        .LARGE(0),
        .LOGN(LOGN),            
        .LOGN1(LOGN1),
        .LOGN2(LOGN2),   
        .LOGTP(LOGTP),           
        .LOGQ(LOGQ),
        .AU_ID(0)         
    ) AU1 (
        .clk(clk),         
        .rst(rst),         
        .start(start_au1),
        .input_data(poly_ntt1),  
        .output_data(poly_au1)    
    );

    tp_ntt_core_wrapper #(
        .DIM(DIM),
        .LOGN(LOGN),
        .LOGN1(LOGN2),
        .LOGN2(LOGN1),
        .LOG_GLOBAL_N2(LOGN2),
        .LOG_GLOBAL_N3(LOGN3),
        .LOGTP(LOGTP),
        .LOGQ(LOGQ),
        .LOGQH(LOGQH),
        .BLOCK_ID(1),       
        .LARGE(1),
        .RW_DIS(1)
    ) tp_ntt_d2 (
        .clk(clk), 
        .rst(rst), 
        .start(start_ntt2),
        .op(op_code_d2), 
        .intt(intt_ntt2),
        .qH(qH_d2), 
        .i_poly(poly_au1_d2), 
        .psi(psi_out_d2), 
        .o_poly(poly_ntt2)
    );
end
else if (DIM == DIM_3D) begin        
    tp_ntt_core_wrapper #(
        .DIM(DIM),
        .LOGN(LOGN),
        .LOGN1(LOGN1),
        .LOGN2(LOGN2),
        .LOG_GLOBAL_N2(LOGN2),
        .LOG_GLOBAL_N3(LOGN3),
        .LOGTP(LOGTP),
        .LOGQ(LOGQ),
        .LOGQH(LOGQH),
        .BLOCK_ID(0),       
        .LARGE(0),
        .RW_DIS(0)
    ) tp_ntt_d1 (
        .clk(clk), 
        .rst(rst), 
        .start(start_sig1),
        .op(op_code_d1), 
        .intt(intt_d1),
        .qH(qH_d1), 
        .i_poly(poly_in_ntt1), 
        .psi(psi_out_d1), 
        .o_poly(poly_ntt1)
    );

    automorphism_unit #(
        .LARGE(0),
        .LOGN(LOGN),            
        .LOGN1(LOGN1),
        .LOGN2(LOGN2),           
        .LOGTP(LOGTP),           
        .LOGQ(LOGQ),
        .AU_ID(0)         
    ) AU1 (
        .clk(clk),         
        .rst(rst),         
        .start(start_au1),
        .input_data(poly_ntt1),  
        .output_data(poly_au1)    
    );

    tp_ntt_core_wrapper #(
        .DIM(DIM),
        .LOGN(LOGN),
        .LOGN1(LOGN2),
        .LOGN2(LOGN1),
        .LOG_GLOBAL_N2(LOGN2),
        .LOG_GLOBAL_N3(LOGN3),
        .LOGTP(LOGTP),
        .LOGQ(LOGQ),         
        .LOGQH(LOGQH),
        .BLOCK_ID(1),       
        .LARGE(1),
        .RW_DIS(0)
    ) tp_ntt_d2 (
        .clk(clk), 
        .rst(rst), 
        .start(start_ntt2),
        .op(op_code_d2), 
        .intt(intt_ntt2),
        .qH(qH_d2), 
        .i_poly(poly_au1_d2), 
        .psi(psi_out_d2), 
        .o_poly(poly_ntt2)
    );

    automorphism_unit #(
        .LARGE(1),
        .LOGN(LOGN),            
        .LOGN1(LOGN2),
        .LOGN2(LOGN1),           
        .LOGTP(LOGTP),           
        .LOGQ(LOGQ),
        .AU_ID(1)         
    ) AU2 (
        .clk(clk),         
        .rst(rst),         
        .start(start_au2),
        .input_data(poly_ntt2),  
        .output_data(poly_au2)    
    );

    tp_ntt_core_wrapper #(
        .DIM(DIM),
        .LOGN(LOGN),
        .LOGN1(LOGN3),
        .LOGN2(LOGN4),
        .LOG_GLOBAL_N2(LOGN2),
        .LOG_GLOBAL_N3(LOGN3),
        .LOGTP(LOGTP),
        .LOGQ(LOGQ),         
        .LOGQH(LOGQH),
        .BLOCK_ID(2),       
        .LARGE(0),
        .RW_DIS(1)
    ) tp_ntt_d3 (
        .clk(clk), 
        .rst(rst), 
        .start(start_ntt3),
        .op(op_code_d3), 
        .intt(intt_ntt3),
        .qH(qH_d3), 
        .i_poly(poly_au2_d3), 
        .psi(psi_out_d3), 
        .o_poly(poly_ntt3)
    );
end
else if (DIM == DIM_4D) begin
    tp_ntt_core_wrapper #(
        .DIM(DIM),
        .LOGN(LOGN),
        .LOGN1(LOGN1),
        .LOGN2(LOGN2),
        .LOG_GLOBAL_N2(LOGN2),
        .LOG_GLOBAL_N3(LOGN3),
        .LOGTP(LOGTP),
        .LOGQ(LOGQ),         
        .LOGQH(LOGQH),
        .BLOCK_ID(0),       
        .LARGE(0),
        .RW_DIS(0)
    ) tp_ntt_d1 (
        .clk(clk), 
        .rst(rst), 
        .start(start_sig1),
        .op(op_code_d1), 
        .intt(intt_d1),
        .qH(qH_d1), 
        .i_poly(poly_in_ntt1), 
        .psi(psi_out_d1), 
        .o_poly(poly_ntt1)
    );

    automorphism_unit #(
        .LARGE(0),
        .LOGN(LOGN),            
        .LOGN1(LOGN1),
        .LOGN2(LOGN2),           
        .LOGTP(LOGTP),           
        .LOGQ(LOGQ),
        .AU_ID(0)         
    ) AU1 (
        .clk(clk),         
        .rst(rst),         
        .start(start_au1),
        .input_data(poly_ntt1),  
        .output_data(poly_au1)    
    );

    tp_ntt_core_wrapper #(
        .DIM(DIM),
        .LOGN(LOGN),
        .LOGN1(LOGN2),
        .LOGN2(LOGN1),
        .LOG_GLOBAL_N2(LOGN2),
        .LOG_GLOBAL_N3(LOGN3),
        .LOGTP(LOGTP),
        .LOGQ(LOGQ),         
        .LOGQH(LOGQH),
        .BLOCK_ID(1),       
        .LARGE(1),
        .RW_DIS(0)
    ) tp_ntt_d2 (
        .clk(clk), 
        .rst(rst), 
        .start(start_ntt2),
        .op(op_code_d2), 
        .intt(intt_ntt2),
        .qH(qH_d2), 
        .i_poly(poly_au1_d2), 
        .psi(psi_out_d2), 
        .o_poly(poly_ntt2)
    );

    automorphism_unit #(
        .LARGE(1),
        .LOGN(LOGN),            
        .LOGN1(LOGN2),
        .LOGN2(LOGN1),        
        .LOGTP(LOGTP),           
        .LOGQ(LOGQ),
        .AU_ID(1)         
    ) AU2 (
        .clk(clk),         
        .rst(rst),         
        .start(start_au2),
        .input_data(poly_ntt2),  
        .output_data(poly_au2)    
    );

    tp_ntt_core_wrapper #(
        .DIM(DIM),
        .LOGN(LOGN),
        .LOGN1(LOGN3),
        .LOGN2(LOGN4),
        .LOG_GLOBAL_N2(LOGN2),
        .LOG_GLOBAL_N3(LOGN3),
        .LOGTP(LOGTP),
        .LOGQ(LOGQ),         
        .LOGQH(LOGQH),
        .BLOCK_ID(2),       
        .LARGE(0),
        .RW_DIS(0)
    ) tp_ntt_d3 (
        .clk(clk), 
        .rst(rst), 
        .start(start_ntt3),
        .op(op_code_d3), 
        .intt(intt_ntt3),
        .qH(qH_d3), 
        .i_poly(poly_au2_d3), 
        .psi(psi_out_d3), 
        .o_poly(poly_ntt3)
    );

    automorphism_unit #(
        .LARGE(0),
        .LOGN(LOGN),
        .LOGN1(LOGN3),
        .LOGN2(LOGN4),
        .LOGTP(LOGTP),
        .LOGQ(LOGQ),
        .AU_ID(2)
    ) AU3 (
        .clk(clk),         
        .rst(rst),         
        .start(start_au3),
        .input_data(poly_ntt3),  
        .output_data(poly_au3)    
    );

    tp_ntt_core_wrapper #(
        .DIM(DIM),
        .LOGN(LOGN),
        .LOGN1(LOGN4),
        .LOGN2(LOGN3),
        .LOG_GLOBAL_N2(LOGN2),
        .LOG_GLOBAL_N3(LOGN3),
        .LOGTP(LOGTP),
        .LOGQ(LOGQ),         
        .LOGQH(LOGQH),
        .BLOCK_ID(3),       
        .LARGE(0),
        .RW_DIS(1)
    ) tp_ntt_d4 (
        .clk(clk), 
        .rst(rst), 
        .start(start_ntt4),
        .op(op_code_d4), 
        .intt(intt_ntt4),
        .qH(qH_d4), 
        .i_poly(poly_au3_d4), 
        .psi(psi_out_d4), 
        .o_poly(poly_ntt4)
    );
end


// POLYNOMIAL DELAYS //

shiftreg #(
    .SHIFT (LAT0),
    .DATA  (TP*LOGQ)
) sre_poly_1 (
    .clk      (clk         ),
    .reset    (rst         ),
    .data_in  (poly_d3     ),
    .data_out (poly_in_ntt1 )
);

shiftreg #(
    .SHIFT (LAT1),
    .DATA  (TP*LOGQ)
) sre_poly_2 (
    .clk      (clk         ),
    .reset    (rst         ),
    .data_in  (poly_au1     ),
    .data_out (poly_au1_d2 )
);

shiftreg #(
    .SHIFT (LAT2),
    .DATA  (TP*LOGQ)
) sre_poly_3 (
    .clk      (clk         ),
    .reset    (rst         ),
    .data_in  (poly_au2    ),
    .data_out (poly_au2_d3 )
);

shiftreg #(
    .SHIFT (LAT3),
    .DATA  (TP*LOGQ)
) sre_poly_4 (
    .clk      (clk         ),
    .reset    (rst         ),
    .data_in  (poly_au3    ),
    .data_out (poly_au3_d4 )
);

// POLYNOMIAL DELAYS //


shiftreg #(
    .SHIFT (LAT0),
    .DATA  (1)
) sre112 (
    .clk      (clk         ),
    .reset    (rst         ),
    .data_in  (start_d1    ),
    .data_out (start_sig1  )
);

shiftreg #(
    .SHIFT ((BTF_LAT + 1) * LOGN1 + 3),
    .DATA  (1)
) sre107 (
    .clk      (clk         ),
    .reset    (rst         ),
    .data_in  (start_sig1    ),
    .data_out (start_au1)
);

shiftreg #(
    .SHIFT (D1 + 4 + LAT1),
    .DATA  (1)
) sre102 (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (start_au1  ),
    .data_out (start_ntt2 )
);

shiftreg #(
    .SHIFT ((BTF_LAT + 1) * LOGN2 + 1),
    .DATA  (1)
) sre103 (
    .clk      (clk       ),
    .reset    (rst       ),
    .data_in  (start_ntt2),
    .data_out (start_au2 )
);

shiftreg #(
    .SHIFT (D + 6 + LAT2),
    .DATA  (1)
) sre104 (
    .clk      (clk       ),
    .reset    (rst       ),
    .data_in  (start_au2 ),
    .data_out (start_ntt3)
);

shiftreg #(
    .SHIFT ((BTF_LAT + 1) * LOGN3 + 1),
    .DATA  (1)
) sre105 (
    .clk      (clk       ),
    .reset    (rst       ),
    .data_in  (start_ntt3),
    .data_out (start_au3 )
);

shiftreg #(
    .SHIFT (D2 + 6 + LAT3),
    .DATA  (1)
) sre106 (
    .clk      (clk       ),
    .reset    (rst       ),
    .data_in  (start_au3 ),
    .data_out (start_ntt4)
);

shiftreg #(
    .SHIFT (LAT0),
    .DATA  (1)
) sre210 (
    .clk      (clk     ),
    .reset    (rst     ),
    .data_in  (intt    ),
    .data_out (intt_d1 )
);

shiftreg #(
    .SHIFT (1),
    .DATA  (1)
) sre201 (
    .clk      (clk     ),
    .reset    (rst     ),
    .data_in  (intt_d1 ),
    .data_out (intt_au1)
);

shiftreg #(
    .SHIFT (LAT1),
    .DATA  (1)
) sre202 (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (intt_au1   ),
    .data_out (intt_ntt2  )
);

shiftreg #(
    .SHIFT (1),
    .DATA  (1)
) sre203 (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (intt_ntt2  ),
    .data_out (intt_au2   )
);

shiftreg #(
    .SHIFT (LAT2),
    .DATA  (1)
) sre204 (
    .clk      (clk       ),
    .reset    (rst       ),
    .data_in  (intt_au2  ),
    .data_out (intt_ntt3 )
);

shiftreg #(
    .SHIFT (1),
    .DATA  (1)
) sre205 (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (intt_ntt3  ),
    .data_out (intt_au3   )
);

shiftreg #(
    .SHIFT (LAT3),
    .DATA  (1)
) sre206 (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (intt_au3   ),
    .data_out (intt_ntt4  )
);




shiftreg #(
    .SHIFT (4 + LAT0),
    .DATA  (2)
) sre300 (
    .clk      (clk          ),
    .reset    (rst          ),
    .data_in  (op           ),
    .data_out (op_code_d1   )
);

shiftreg #(
    .SHIFT (LAT1),
    .DATA  (2)
) sre301 (
    .clk      (clk          ),
    .reset    (rst          ),
    .data_in  (op_code_d1   ),
    .data_out (op_code_d2   )
);

shiftreg #(
    .SHIFT (LAT2),
    .DATA  (2)
) sre302 (
    .clk      (clk          ),
    .reset    (rst          ),
    .data_in  (op_code_d2   ),
    .data_out (op_code_d3   )
);


shiftreg #(
    .SHIFT (LAT3),
    .DATA  (2)
) sre303 (
    .clk      (clk          ),
    .reset    (rst          ),
    .data_in  (op_code_d3   ),
    .data_out (op_code_d4   )
);



shiftreg #(
    .SHIFT (4 + LAT0),
    .DATA  (LOGQH)
) sre400 (
    .clk      (clk      ),
    .reset    (rst      ),
    .data_in  (qH       ),
    .data_out (qH_d1    )
);

shiftreg #(
    .SHIFT (LAT1),
    .DATA  (LOGQH)
) sre401 (
    .clk      (clk      ),
    .reset    (rst      ),
    .data_in  (qH_d1    ),
    .data_out (qH_d2    )
);

shiftreg #(
    .SHIFT (LAT2),
    .DATA  (LOGQH)
) sre402 (
    .clk      (clk      ),
    .reset    (rst      ),
    .data_in  (qH_d2    ),
    .data_out (qH_d3    )
);

shiftreg #(
    .SHIFT (LAT3),
    .DATA  (LOGQH)
) sre403 (
    .clk      (clk      ),
    .reset    (rst      ),
    .data_in  (qH_d3    ),
    .data_out (qH_d4    )
);


shiftreg #(
    .SHIFT (LAT0),
    .DATA  ((TP-1)*LOGQ)
) sre500 (
    .clk      (clk          ),
    .reset    (rst          ),
    .data_in  (psi_out      ),
    .data_out (psi_out_d1   )
);

shiftreg #(
    .SHIFT (LAT1),
    .DATA  ((TP-1)*LOGQ)
) sre501 (
    .clk      (clk          ),
    .reset    (rst          ),
    .data_in  (psi_out_d1   ),
    .data_out (psi_out_d2   )
);

shiftreg #(
    .SHIFT (LAT2),
    .DATA  ((TP-1)*LOGQ)
) sre502 (
    .clk      (clk          ),
    .reset    (rst          ),
    .data_in  (psi_out_d2   ),
    .data_out (psi_out_d3   )
);

shiftreg #(
    .SHIFT (LAT3),
    .DATA  ((TP-1)*LOGQ)
) sre503 (
    .clk      (clk          ),
    .reset    (rst          ),
    .data_in  (psi_out_d3   ),
    .data_out (psi_out_d4   )
);


always @(posedge clk or posedge rst) begin
    if (rst) begin
        o_poly <= 0;
    end else begin
        if (DIM == DIM_2D) begin
            o_poly <= poly_ntt2;
        end
        else if (DIM == DIM_3D) begin
            o_poly <= poly_ntt3;
        end
        else begin
            o_poly <= poly_ntt4;
        end
    end    
end


reg [20:0] ctr2;

always @(posedge clk ) begin
    if (rst) begin
        ctr2 <= 'd0;
    end
    else begin
        if (ctr2 == DEPTH*DIM-1) begin
            ctr2 <= 'd0;
        end else if(twiddle_load_started) begin
            ctr2 <= ctr2 + 'd1;
        end
    end
    
end

reg twiddle_load_started;

always @(posedge clk) begin
    if (rst) begin
        twiddle_load_started <= 0;
    end
    else begin
        if (op == OP_TWIDDLE_LOAD) begin
            twiddle_load_started <= 1;
        end
        else if (ctr2 == DEPTH*DIM-1) begin
            twiddle_load_started <= 0;
        end
    end
    
end

wire new_intt_flag;

assign new_intt_flag = (twiddle_load_started || op == OP_TWIDDLE_LOAD)  ? intt : 0;



twiddle_load #(
    .LOGN    (LOGN    ),
    .LOGN1   (LOGN1   ),
    .LOGN2   (LOGN2   ),
    .LOGN3   (LOGN3   ),
    .LOGTP   (LOGTP   ),
    .LOGQ    (LOGQ    ),
    .LOGQH   (LOGQH   ),
    .NON_STD (NON_STD ),
    .MORE_DSP(MORE_DSP)
) uut_twid (
    .clk(clk),
    .rst(rst),
    .op(op),
    .intt(intt),
    .psi(psi),
    .psi_out(psi_out)
);



endmodule
