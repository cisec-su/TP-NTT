`include "bu_def.vh"
`include "tp_ntt.vh"

module tp_ntt_top
   #(
        parameter LOGN          = 16,
        parameter LOGN1         = 6 ,
        parameter LOGN2         = 4 ,
        parameter LOGN3         = 6 ,
        parameter LOGTP         = 6 ,
        parameter LOGQ          = 60,
        parameter LOGQH         = 17
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

localparam N  = 1 << LOGN;
localparam N1 = 1 << LOGN1;
localparam N2 = 1 << LOGN2;
localparam N3 = 1 << LOGN3;
localparam TP = 1 << LOGTP;
localparam LOGN4 = LOGN - LOGN1 - LOGN2 - LOGN3;
localparam N4 = 1 << LOGN4;
localparam BTF_LAT = (LOGQ == 32) ? `BTRFLY_CC_32 + 1 : `BTRFLY_CC_60 + 1;
localparam DIM     = (N4 != 1) ? `DIM_4D : (N3 != 1) ? `DIM_3D : `DIM_2D;
localparam D  =  N / TP;
localparam D1 =  (N1 * N2) / TP;
localparam D2 =  (N3 * N4) / TP;


wire START_NTT_2, START_NTT_3, START_NTT_4, START_NTT_AU1, START_NTT_AU2, START_NTT_AU3;
wire [TP*LOGQ-1:0] NTT_READ_STAGE0, NTT_READ_STAGE1, NTT_READ_STAGE2, NTT_READ_STAGE3, NTT_READ_AU1, NTT_READ_AU2, NTT_READ_AU3;


generate
    if (DIM == `DIM_2D) begin
        tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN1),
         .LOGN2(LOGN2),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),
         .LOGQH(LOGQH),
         .BTF_LAT(BTF_LAT),       
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
            .BTF_LAT(BTF_LAT),
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
         .BTF_LAT(BTF_LAT),       
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
    else if (DIM == `DIM_3D) begin        
        tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN1),
         .LOGN2(LOGN2),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),
         .LOGQH(LOGQH),
         .BTF_LAT(BTF_LAT),       
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
            .BTF_LAT(BTF_LAT),
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
         .BTF_LAT(BTF_LAT),       
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
            .BTF_LAT(BTF_LAT),
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
         .BTF_LAT(BTF_LAT),       
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
    else if (DIM == `DIM_4D) begin
        tp_ntt_core_wrapper#(
         .DIM(DIM),
         .LOGN(LOGN),
         .LOGN1(LOGN1),
         .LOGN2(LOGN2),
         .LOGTP(LOGTP),
         .LOGQ(LOGQ),         
         .LOGQH(LOGQH),
         .BTF_LAT(BTF_LAT),       
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
            .BTF_LAT(BTF_LAT),
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
         .BTF_LAT(BTF_LAT),       
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
            .BTF_LAT(BTF_LAT),
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
         .BTF_LAT(BTF_LAT),       
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
            .BTF_LAT(BTF_LAT),
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
         .BTF_LAT(BTF_LAT),       
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


shiftreg #(.SHIFT(BTF_LAT*LOGN1),                      .DATA(1))   sre101(clk, rst, START_NTT_ALL, START_NTT_AU1);
shiftreg #(.SHIFT(D1 + 4),                   .DATA(1))   sre102(clk, rst, START_NTT_AU1, START_NTT_2);
shiftreg #(.SHIFT(BTF_LAT*LOGN2),                      .DATA(1))   sre103(clk, rst, START_NTT_2,   START_NTT_AU2);
shiftreg #(.SHIFT(D + 6),                           .DATA(1))   sre104(clk, rst, START_NTT_AU2, START_NTT_3);

shiftreg #(.SHIFT(BTF_LAT*LOGN3),                      .DATA(1))   sre105(clk, rst, START_NTT_3,   START_NTT_AU3);

shiftreg #(.SHIFT(D2 + 6),                     .DATA(1))   sre106(clk, rst, START_NTT_AU3,   START_NTT_4);


always @(posedge clk or posedge rst) begin
    if (rst) begin
        NTT_OUTPUT <= 0;
    end else begin
        if (DIM == `DIM_2D) begin
            NTT_OUTPUT <= NTT_READ_STAGE1;
        end
        else if (DIM == `DIM_3D) begin
            NTT_OUTPUT <= NTT_READ_STAGE2;
        end
        else begin
            NTT_OUTPUT <= NTT_READ_STAGE3;
        end
    end    
end


endmodule
