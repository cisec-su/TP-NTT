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
        input       [LOGQH      -1:0]   qH,
        input       [TP*LOGQ    -1:0]   i_poly,
        input       [(TP-1)*LOGQ-1:0]   psi,
        output reg  [TP*LOGQ    -1:0]   o_poly
    );


localparam tp_ntt_params_t tp_ntt_params = {LOGN, LOGN1, LOGN2, LOGN3, LOGTP, LOGQ, LOGQH, NON_STD, MORE_DSP};
localparam tp_ntt_dim_t DIM = tp_ntt_dim(tp_ntt_params);
localparam butterfly_params_t butterfly_params = {LOGQ, LOGQH, NON_STD, MORE_DSP};
localparam LAT     = tp_ntt_lat(tp_ntt_params);
localparam BTF_LAT = butterfly_lat(butterfly_params);    
localparam LOGN4   = tp_ntt_logn4(tp_ntt_params);
localparam D   =  tp_ntt_d(tp_ntt_params);
localparam D1  =  tp_ntt_d1(tp_ntt_params);
localparam D2  =  tp_ntt_d2(tp_ntt_params);
localparam N  = 1 << LOGN;
localparam N1 = 1 << LOGN1;
localparam N2 = 1 << LOGN2;
localparam N3 = 1 << LOGN3;
localparam TP = 1 << LOGTP;
localparam N4 = 1 << LOGN4;


wire start_ntt2, start_ntt3, start_ntt4, start_au1, start_au2, start_au3;
wire [TP*LOGQ-1:0] poly_ntt1, poly_ntt2, poly_ntt3, poly_ntt4, poly_au1, poly_au2, poly_au3;


generate
    if (DIM == DIM_2D) begin
        tp_ntt_core_wrapper #(
            .DIM(DIM),
            .LOGN(LOGN),
            .LOGN1(LOGN1),
            .LOGN2(LOGN2),
            .LOGTP(LOGTP),
            .LOGQ(LOGQ),
            .LOGQH(LOGQH),
            .BLOCK_ID(0),       
            .LARGE(0),
            .RW_DIS(0)
        ) tp_ntt_d1 (
            .clk(clk), 
            .rst(rst), 
            .start(start),
            .op(op), 
            .qH(qH), 
            .i_poly(i_poly), 
            .psi(psi), 
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
          .op(op), 
          .qH(qH), 
          .i_poly(poly_au1), 
          .psi(psi), 
          .o_poly(poly_ntt2)
        );
    end
    else if (DIM == DIM_3D) begin        
        tp_ntt_core_wrapper #(
            .DIM(DIM),
            .LOGN(LOGN),
            .LOGN1(LOGN1),
            .LOGN2(LOGN2),
            .LOGTP(LOGTP),
            .LOGQ(LOGQ),
            .LOGQH(LOGQH),
            .BLOCK_ID(0),       
            .LARGE(0),
            .RW_DIS(0)
        ) tp_ntt_d1 (
            .clk(clk), 
            .rst(rst), 
            .start(start),
            .op(op), 
            .qH(qH), 
            .i_poly(i_poly), 
            .psi(psi), 
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
            .op(op), 
            .qH(qH), 
            .i_poly(poly_au1), 
            .psi(psi), 
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
            .op(op), 
            .qH(qH), 
            .i_poly(poly_au2), 
            .psi(psi), 
            .o_poly(poly_ntt3)
        );
    end
    else if (DIM == DIM_4D) begin
        tp_ntt_core_wrapper #(
            .DIM(DIM),
            .LOGN(LOGN),
            .LOGN1(LOGN1),
            .LOGN2(LOGN2),
            .LOGTP(LOGTP),
            .LOGQ(LOGQ),         
            .LOGQH(LOGQH),
            .BLOCK_ID(0),       
            .LARGE(0),
            .RW_DIS(0)
        ) tp_ntt_d1 (
            .clk(clk), 
            .rst(rst), 
            .start(start),
            .op(op), 
            .qH(qH), 
            .i_poly(i_poly), 
            .psi(psi), 
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
            .op(op), 
            .qH(qH), 
            .i_poly(poly_au1), 
            .psi(psi), 
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
            .op(op), 
            .qH(qH), 
            .i_poly(poly_au2), 
            .psi(psi), 
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
            .op(op), 
            .qH(qH), 
            .i_poly(poly_au3), 
            .psi(psi), 
            .o_poly(poly_ntt4)
        );
    end
endgenerate


shiftreg #(.SHIFT((BTF_LAT + 1)*LOGN1 + 1), .DATA(1)) sre101(clk, rst, start     , start_au1 );
shiftreg #(.SHIFT( D1 + 4                ), .DATA(1)) sre102(clk, rst, start_au1 , start_ntt2);
shiftreg #(.SHIFT((BTF_LAT + 1)*LOGN2 + 1), .DATA(1)) sre103(clk, rst, start_ntt2, start_au2 );
shiftreg #(.SHIFT( D + 6                 ), .DATA(1)) sre104(clk, rst, start_au2 , start_ntt3);
shiftreg #(.SHIFT((BTF_LAT + 1)*LOGN3 + 1), .DATA(1)) sre105(clk, rst, start_ntt3, start_au3 );
shiftreg #(.SHIFT( D2 + 6                ), .DATA(1)) sre106(clk, rst, start_au3 , start_ntt4);


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


endmodule
