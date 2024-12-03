`include "bu_def.vh"
`include "tp_ntt.vh"

module tp_ntt_top
   #(
        parameter N             = 1<<7,
        parameter n1            = 1<<3,
        parameter n2            = 1<<1,
        parameter n3            = 1<<3,
        parameter TP            = 1<<3,
        parameter LOGQ          = 60
    )
    (
        input                           clk,
        input                           rst,
        input                           START_NTT_ALL,
        input       [            1:0]   OP_TYPE_INPUT,
        input       [LOGQ       -1:0]   Q_in,
        input       [TP*LOGQ    -1:0]   NTT_INPUT,
        input       [(TP-1)*LOGQ-1:0]   TWIDDLE_INPUT,
        output reg  [TP*LOGQ    -1:0]   NTT_OUTPUT
    );


localparam n4      = N / (n1*n2*n3);
localparam BTF_LAT = (LOGQ == 32) ? `BTRFLY_CC_32 + 1 : `BTRFLY_CC_60 + 1;
localparam DIM     = (n4 != 1) ? `DIM_4D : (n3 != 1) ? `DIM_3D : `DIM_2D;
localparam log_n1  = $rtoi($ceil($clog2(n1)));
localparam log_n2  = $rtoi($ceil($clog2(n2)));
localparam log_n3  = $rtoi($ceil($clog2(n3)));
localparam log_n4  = $rtoi($ceil($clog2(n4)));
localparam depth         =  $rtoi($ceil(N/TP));
localparam size0_over_tp =  $rtoi($ceil(n1*n2/TP));
localparam size1_over_tp =  $rtoi($ceil(n3*n4/TP));


wire START_NTT_2, START_NTT_3, START_NTT_4, START_NTT_AU1, START_NTT_AU2;
wire [TP*LOGQ-1:0] NTT_READ_STAGE0, NTT_READ_STAGE1, NTT_READ_STAGE2, NTT_READ_STAGE3, NTT_READ_AU1, NTT_READ_AU2;


generate
    if (DIM == `DIM_2D) begin
        //tp_ntt_block1#(.DIM(DIM), .N(N), .n1(n1), .n2(n2),    .TP(TP), .LOGQ(LOGQ), .BTF_LAT(BTF_LAT), .RW_DIS(0), .BLOCK_ID(0)) tp_ntt_d1 (clk, rst, START_NTT_ALL ,OP_TYPE_INPUT, Q_in, NTT_INPUT, TWIDDLE_INPUT, NTT_READ_STAGE0);
        //tp_ntt_block2#(.DIM(DIM), .N(N), .n2(n2), .size0(n1*n2), .TP(TP), .LOGQ(LOGQ), .BTF_LAT(BTF_LAT), .RW_DIS(1)              ) tp_ntt_d2 (clk, rst, START_NTT_2 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE0, TWIDDLE_INPUT, NTT_READ_STAGE1);
    end
    else if (DIM == `DIM_3D) begin
        //tp_ntt_block1#(.DIM(DIM), .N(N), .n1(n1), .n2(n2),    .TP(TP), .LOGQ(LOGQ), .BTF_LAT(BTF_LAT), .RW_DIS(0), .BLOCK_ID(0)) tp_ntt_d1 (clk, rst, START_NTT_ALL ,OP_TYPE_INPUT, Q_in, NTT_INPUT, TWIDDLE_INPUT, NTT_READ_STAGE0);
        //tp_ntt_block2#(.DIM(DIM), .N(N), .n2(n2), .size0(n1*n2), .TP(TP), .LOGQ(LOGQ), .BTF_LAT(BTF_LAT), .RW_DIS(0)              ) tp_ntt_d2 (clk, rst, START_NTT_2 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE0, TWIDDLE_INPUT, NTT_READ_STAGE1);
        //tp_ntt_block1#(.DIM(DIM), .N(N), .n1(n3), .n2(1),    .TP(TP), .LOGQ(LOGQ), .BTF_LAT(BTF_LAT), .RW_DIS(1), .BLOCK_ID(2)) tp_ntt_d3 (clk, rst, START_NTT_3 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE1, TWIDDLE_INPUT, NTT_READ_STAGE2);
        
        tp_ntt_core_wrapper#(
         .DIM(DIM),
         .N(N),
         .n1(n1),
         .n2(n2),
         .TP(TP),
         .LOGQ(LOGQ),         
         .BTF_LAT(BTF_LAT),       
         .BLOCK_ID(0),       
         .IS_LARGE(0),
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
            .large_automorphism(0),
            .N(N),            
            .n1(n1),
            .n2(n2),           
            .size0(n1*n2),        
            .size1(n3*n4),        
            .TP(TP),           
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
         .N(N),
         .n1(n2),
         .n2(n1),
         .TP(TP),
         .LOGQ(LOGQ),         
         .BTF_LAT(BTF_LAT),       
         .BLOCK_ID(1),       
         .IS_LARGE(1),
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
            .large_automorphism(1),
            .N(N),            
            .n1(n2),
            .n2(n1),           
            .size0(n1*n2),        
            .size1(n3*n4),        
            .TP(TP),           
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
         .N(N),
         .n1(n3),
         .n2(n4),
         .TP(TP),
         .LOGQ(LOGQ),         
         .BTF_LAT(BTF_LAT),       
         .BLOCK_ID(2),       
         .IS_LARGE(0),
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
        //tp_ntt_block1#(.DIM(DIM), .N(N), .n1(n1), .n2(n2),    .TP(TP), .LOGQ(LOGQ), .BTF_LAT(BTF_LAT), .RW_DIS(0), .BLOCK_ID(0)) tp_ntt_d1 (clk, rst, START_NTT_ALL ,OP_TYPE_INPUT, Q_in, NTT_INPUT, TWIDDLE_INPUT, NTT_READ_STAGE0);
        //tp_ntt_block2#(.DIM(DIM), .N(N), .n2(n2), .size0(n1*n2), .TP(TP), .LOGQ(LOGQ), .BTF_LAT(BTF_LAT), .RW_DIS(0)              ) tp_ntt_d2 (clk, rst, START_NTT_2 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE0, TWIDDLE_INPUT, NTT_READ_STAGE1);
        //tp_ntt_block1#(.DIM(DIM), .N(N), .n1(n3), .n2(n4),    .TP(TP), .LOGQ(LOGQ), .BTF_LAT(BTF_LAT), .RW_DIS(0), .BLOCK_ID(2)) tp_ntt_d3 (clk, rst, START_NTT_3 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE1, TWIDDLE_INPUT, NTT_READ_STAGE2);
        //tp_ntt_block1#(.DIM(DIM), .N(N), .n1(n4), .n2(n3),    .TP(TP), .LOGQ(LOGQ), .BTF_LAT(BTF_LAT), .RW_DIS(1), .BLOCK_ID(3)) tp_ntt_d4 (clk, rst, START_NTT_4 ,OP_TYPE_INPUT, Q_in, NTT_READ_STAGE2, TWIDDLE_INPUT, NTT_READ_STAGE3);
    end
endgenerate


shiftreg #(.SHIFT(BTF_LAT*log_n1),                      .DATA(1))   sre101(clk, rst, START_NTT_ALL, START_NTT_AU1);
shiftreg #(.SHIFT(size0_over_tp + 4),                   .DATA(1))   sre104(clk, rst, START_NTT_AU1, START_NTT_2);
shiftreg #(.SHIFT(BTF_LAT*log_n2),                      .DATA(1))   sre105(clk, rst, START_NTT_2,   START_NTT_AU2);
shiftreg #(.SHIFT(depth + 6),                           .DATA(1))   sre102(clk, rst, START_NTT_AU2, START_NTT_3);
shiftreg #(.SHIFT(BTF_LAT*log_n3+size1_over_tp+6),      .DATA(1))   sre103(clk, rst, START_NTT_3,   START_NTT_4);


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
