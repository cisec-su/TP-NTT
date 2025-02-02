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
        input                           START_NTT_ALL,
        input       [            1:0]   OP_TYPE_INPUT,
        input       [LOGQH      -1:0]   Q_in,
        input       [TP*LOGQ    -1:0]   NTT_INPUT,
        input       [(TP-1)*LOGQ-1:0]   TWIDDLE_INPUT,
        output reg  [TP*LOGQ    -1:0]   NTT_OUTPUT
    );


localparam tp_ntt_params_t tp_ntt_params = {LOGN, LOGN1, LOGN2, LOGN3, LOGTP, LOGQ, LOGQH, NON_STD, MORE_DSP};
localparam tp_ntt_dim_t DIM = tp_ntt_dim(tp_ntt_params);
localparam butterfly_params_t butterfly_params = {LOGQ, LOGQH, NON_STD, MORE_DSP};
localparam LAT     = tp_ntt_lat(tp_ntt_params);
localparam BTF_LAT = butterfly_lat(butterfly_params);    
localparam LOGN4 = tp_ntt_logn4(tp_ntt_params);
localparam D   =  tp_ntt_d(tp_ntt_params);
localparam D1  =  tp_ntt_d1(tp_ntt_params);
localparam D2  =  tp_ntt_d2(tp_ntt_params);
localparam N  = 1 << LOGN;
localparam N1 = 1 << LOGN1;
localparam N2 = 1 << LOGN2;
localparam N3 = 1 << LOGN3;
localparam TP = 1 << LOGTP;
localparam N4 = 1 << LOGN4;


wire START_NTT_2, START_NTT_3, START_NTT_4, START_NTT_AU1, START_NTT_AU2, START_NTT_AU3;
wire [TP*LOGQ-1:0] NTT_READ_STAGE0, NTT_READ_STAGE1, NTT_READ_STAGE2, NTT_READ_STAGE3, NTT_READ_AU1, NTT_READ_AU2, NTT_READ_AU3;


generate
    if (DIM == DIM_2D) begin
        tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN1),
         .LOGN2(LOGN2),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),
         .LOGQH(LOGQH),
         .BLOCK_ID(0),       
         .LARGE(0),
         .RW_DIS(0))
         tp_ntt_d1 
         (
          .clk(clk), 
          .rst(rst), 
          .START_NTT(START_NTT_ALL),
          .OP_TYPE_INPUT(OP_TYPE_INPUT), 
          .Q_in(Q_in), 
          .NTT_INPUT(NTT_INPUT), 
          .TWIDDLE_INPUT(TWIDDLE_INPUT), 
          .NTT_OUTPUT(NTT_READ_STAGE0));
        automorphism_unit#(
            .LARGE(0),
            .LOGN(LOGN),            
            .LOGN1(LOGN1),
            .LOGN2(LOGN2),   
            .LOGTP(LOGTP),           
            .LOGQ(LOGQ),
            .AU_ID(0)         
          )
          AU1
          (
            .clk(clk),         
            .rst(rst),         
            .start(START_NTT_AU1),
            .input_data(NTT_READ_STAGE0),  
            .output_data(NTT_READ_AU1)    
          );
          tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN2),
         .LOGN2(LOGN1),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),
         .LOGQH(LOGQH),
         .BLOCK_ID(1),       
         .LARGE(1),
         .RW_DIS(1))
         tp_ntt_d2 
         (
          .clk(clk), 
          .rst(rst), 
          .START_NTT(START_NTT_2),
          .OP_TYPE_INPUT(OP_TYPE_INPUT), 
          .Q_in(Q_in), 
          .NTT_INPUT(NTT_READ_AU1), 
          .TWIDDLE_INPUT(TWIDDLE_INPUT), 
          .NTT_OUTPUT(NTT_READ_STAGE1));
    end
    else if (DIM == DIM_3D) begin        
        tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN1),
         .LOGN2(LOGN2),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),
         .LOGQH(LOGQH),
         .BLOCK_ID(0),       
         .LARGE(0),
         .RW_DIS(0))
         tp_ntt_d1 
         (
          .clk(clk), 
          .rst(rst), 
          .START_NTT(START_NTT_ALL),
          .OP_TYPE_INPUT(OP_TYPE_INPUT), 
          .Q_in(Q_in), 
          .NTT_INPUT(NTT_INPUT), 
          .TWIDDLE_INPUT(TWIDDLE_INPUT), 
          .NTT_OUTPUT(NTT_READ_STAGE0));

          automorphism_unit#(
            .LARGE(0),
            .LOGN(LOGN),            
            .LOGN1(LOGN1),
            .LOGN2(LOGN2),           
            .LOGTP(LOGTP),           
            .LOGQ(LOGQ),
            .AU_ID(0)         
          )
          AU1
          (
            .clk(clk),         
            .rst(rst),         
            .start(START_NTT_AU1),
            .input_data(NTT_READ_STAGE0),  
            .output_data(NTT_READ_AU1)    
          );

          tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN2),
         .LOGN2(LOGN1),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),         
         .LOGQH(LOGQH),
         .BLOCK_ID(1),       
         .LARGE(1),
         .RW_DIS(0))
         tp_ntt_d2 
         (
          .clk(clk), 
          .rst(rst), 
          .START_NTT(START_NTT_2),
          .OP_TYPE_INPUT(OP_TYPE_INPUT), 
          .Q_in(Q_in), 
          .NTT_INPUT(NTT_READ_AU1), 
          .TWIDDLE_INPUT(TWIDDLE_INPUT), 
          .NTT_OUTPUT(NTT_READ_STAGE1));

          automorphism_unit#(
            .LARGE(1),
            .LOGN(LOGN),            
            .LOGN1(LOGN2),
            .LOGN2(LOGN1),           
            .LOGTP(LOGTP),           
            .LOGQ(LOGQ),
            .AU_ID(1)         
          )
          AU2
          (
            .clk(clk),         
            .rst(rst),         
            .start(START_NTT_AU2),
            .input_data(NTT_READ_STAGE1),  
            .output_data(NTT_READ_AU2)    
          );

          tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN3),
         .LOGN2(LOGN4),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),         
         .LOGQH(LOGQH),
         .BLOCK_ID(2),       
         .LARGE(0),
         .RW_DIS(1))
         tp_ntt_d3 
         (
          .clk(clk), 
          .rst(rst), 
          .START_NTT(START_NTT_3),
          .OP_TYPE_INPUT(OP_TYPE_INPUT), 
          .Q_in(Q_in), 
          .NTT_INPUT(NTT_READ_AU2), 
          .TWIDDLE_INPUT(TWIDDLE_INPUT), 
          .NTT_OUTPUT(NTT_READ_STAGE2));
    end
    else if (DIM == DIM_4D) begin
        tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN1),
         .LOGN2(LOGN2),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),         
         .LOGQH(LOGQH),
         .BLOCK_ID(0),       
         .LARGE(0),
         .RW_DIS(0))
         tp_ntt_d1 
         (
          .clk(clk), 
          .rst(rst), 
          .START_NTT(START_NTT_ALL),
          .OP_TYPE_INPUT(OP_TYPE_INPUT), 
          .Q_in(Q_in), 
          .NTT_INPUT(NTT_INPUT), 
          .TWIDDLE_INPUT(TWIDDLE_INPUT), 
          .NTT_OUTPUT(NTT_READ_STAGE0));

          automorphism_unit#(
            .LARGE(0),
            .LOGN(LOGN),            
            .LOGN1(LOGN1),
            .LOGN2(LOGN2),           
            .LOGTP(LOGTP),           
            .LOGQ(LOGQ),
            .AU_ID(0)         
          )
          AU1
          (
            .clk(clk),         
            .rst(rst),         
            .start(START_NTT_AU1),
            .input_data(NTT_READ_STAGE0),  
            .output_data(NTT_READ_AU1)    
          );

          tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN2),
         .LOGN2(LOGN1),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),         
         .LOGQH(LOGQH),
         .BLOCK_ID(1),       
         .LARGE(1),
         .RW_DIS(0))
         tp_ntt_d2 
         (
          .clk(clk), 
          .rst(rst), 
          .START_NTT(START_NTT_2),
          .OP_TYPE_INPUT(OP_TYPE_INPUT), 
          .Q_in(Q_in), 
          .NTT_INPUT(NTT_READ_AU1), 
          .TWIDDLE_INPUT(TWIDDLE_INPUT), 
          .NTT_OUTPUT(NTT_READ_STAGE1));

          automorphism_unit#(
            .LARGE(1),
            .LOGN(LOGN),            
            .LOGN1(LOGN2),
            .LOGN2(LOGN1),        
            .LOGTP(LOGTP),           
            .LOGQ(LOGQ),
            .AU_ID(1)         
          )
          AU2
          (
            .clk(clk),         
            .rst(rst),         
            .start(START_NTT_AU2),
            .input_data(NTT_READ_STAGE1),  
            .output_data(NTT_READ_AU2)    
          );

          tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN3),
         .LOGN2(LOGN4),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),         
         .LOGQH(LOGQH),
         .BLOCK_ID(2),       
         .LARGE(0),
         .RW_DIS(0))
         tp_ntt_d3 
         (
          .clk(clk), 
          .rst(rst), 
          .START_NTT(START_NTT_3),
          .OP_TYPE_INPUT(OP_TYPE_INPUT), 
          .Q_in(Q_in), 
          .NTT_INPUT(NTT_READ_AU2), 
          .TWIDDLE_INPUT(TWIDDLE_INPUT), 
          .NTT_OUTPUT(NTT_READ_STAGE2));
        automorphism_unit#(
            .LARGE(0),
            .LOGN(LOGN),
            .LOGN1(LOGN3),
            .LOGN2(LOGN4),
            .LOGTP(LOGTP),
            .LOGQ(LOGQ),
            .AU_ID(2)
          )
          AU3
          (
            .clk(clk),         
            .rst(rst),         
            .start(START_NTT_AU3),
            .input_data(NTT_READ_STAGE2),  
            .output_data(NTT_READ_AU3)    
          );
          tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN4),
         .LOGN2(LOGN3),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),         
         .LOGQH(LOGQH),
         .BLOCK_ID(3),       
         .LARGE(0),
         .RW_DIS(1))
         tp_ntt_d4 
         (
          .clk(clk), 
          .rst(rst), 
          .START_NTT(START_NTT_4),
          .OP_TYPE_INPUT(OP_TYPE_INPUT), 
          .Q_in(Q_in), 
          .NTT_INPUT(NTT_READ_AU3), 
          .TWIDDLE_INPUT(TWIDDLE_INPUT), 
          .NTT_OUTPUT(NTT_READ_STAGE3));
    end
endgenerate


shiftreg #(.SHIFT((BTF_LAT + 1)*LOGN1),                      .DATA(1))   sre101(clk, rst, START_NTT_ALL, START_NTT_AU1);
shiftreg #(.SHIFT(D1 + 4),                   .DATA(1))   sre102(clk, rst, START_NTT_AU1, START_NTT_2);
shiftreg #(.SHIFT((BTF_LAT + 1)*LOGN2),                      .DATA(1))   sre103(clk, rst, START_NTT_2,   START_NTT_AU2);
shiftreg #(.SHIFT(D + 6),                           .DATA(1))   sre104(clk, rst, START_NTT_AU2, START_NTT_3);

shiftreg #(.SHIFT((BTF_LAT + 1)*LOGN3),                      .DATA(1))   sre105(clk, rst, START_NTT_3,   START_NTT_AU3);

shiftreg #(.SHIFT(D2 + 6),                     .DATA(1))   sre106(clk, rst, START_NTT_AU3,   START_NTT_4);


always @(posedge clk or posedge rst) begin
    if (rst) begin
        NTT_OUTPUT <= 0;
    end else begin
        if (DIM == DIM_2D) begin
            NTT_OUTPUT <= NTT_READ_STAGE1;
        end
        else if (DIM == DIM_3D) begin
            NTT_OUTPUT <= NTT_READ_STAGE2;
        end
        else begin
            NTT_OUTPUT <= NTT_READ_STAGE3;
        end
    end    
end


endmodule
