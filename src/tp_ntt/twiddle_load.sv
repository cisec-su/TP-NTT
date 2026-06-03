`include "tp_ntt.svh"

module twiddle_load
   #(
        parameter LOGN          = 16,
        parameter LOGN1         = 6 ,
        parameter LOGN2         = 4 ,
        parameter LOGN3         = 6 ,
        parameter LOGTP         = 6 ,
        parameter LOGQ          = 60,
        parameter LOGQH         = 17,
        parameter NON_STD       = 1 ,
        parameter MORE_DSP      = 0 ,
        parameter TP            = 1 << LOGTP
    )
    (
        input                               clk,
        input                               rst,
        input  tp_ntt_op_t                  op,
        input                               intt,
        input           [TP*LOGQ  -1:0]     psi,
        output          [(TP-1)*LOGQ  -1:0]     psi_out
    );

localparam N                        = 1 << LOGN;
localparam N1                       = 1 << LOGN1;
localparam N2                       = 1 << LOGN2;
localparam N3                       = 1 << LOGN3;
localparam N4                       = 1 << (LOGN-LOGN1-LOGN2-LOGN3);
localparam LOGN4                    = LOGN - LOGN1 - LOGN2 - LOGN3;
localparam SIZE0                    = N1 * N2;
localparam SIZE1                    = N / (SIZE0);
localparam DEPTH                    = N/TP ;
localparam DEPTH_LARGE              = N/TP;
localparam BRAM_SIZE                = DEPTH;
localparam BRAM_LOG_SIZE            = $clog2(BRAM_SIZE);
localparam LOG_DEPTH                = $clog2(DEPTH);
localparam DIM_NUM                  = (LOGN4 != 0) ? 4 : ((LOGN3 != 0) ? 3 : 2);
localparam TWID_FACTOR_N2           = (TP>>LOGN2) * ((N2)-1);
localparam CTR_READ_NUM             = DIM_NUM == 2 ? (DEPTH+1)-1 : DIM_NUM == 3 ? (1+(N2)+DEPTH)-1    : DIM_NUM == 4 ? (1+(N2)+DEPTH+DEPTH)-1 : 0;
localparam CTR_READ_NUM_INTT        = DIM_NUM == 2 ? (DEPTH+1)-1 : DIM_NUM == 3 ? (DEPTH+DEPTH+1)-1         : DIM_NUM == 4 ? (1+(1<<LOGN3)+DEPTH+DEPTH)-1 : 0;

localparam LOG_CTR = LOG_DEPTH+2;

localparam DIV          = (TP/(TP-TWID_FACTOR_N2));
localparam LOG_DIV      =  $clog2(DIV);

localparam FIXED_VAL_PRE =  ((TP-1)-((((N2-1)*(TP-TWID_FACTOR_N2)+1))));

localparam FIXED_VAL  =  FIXED_VAL_PRE < 0 ? 2 : (TP/N2)-FIXED_VAL_PRE;

localparam FIXED_VAL_2  =  FIXED_VAL_PRE < 0 ? 1 : (TP/N2)-FIXED_VAL_PRE;

localparam START_PARAM = FIXED_VAL_PRE < 0 ? FIXED_VAL_2: 0;

localparam END_PARAM = FIXED_VAL_PRE < 0 ? FIXED_VAL_2+1 : FIXED_VAL_2;

localparam MINUS_CHECK =  FIXED_VAL_PRE < 0 ? 1 : 0;

//localparam int GROUP = N2;

localparam TP_min_TWID_FACTOR_N2 = TP-TWID_FACTOR_N2;

localparam TP_min_TWID_FACTOR_N2_log2 = $clog2(TP_min_TWID_FACTOR_N2);
localparam SIZE1_OVER_TWID_FACTOR_N2 = (SIZE1)/TWID_FACTOR_N2;
localparam N3_times_tp_min_1 = N3*(TP-1);
localparam N2_min1_mul_tp_min_twid_factor_n2 = (N2-1)<<(TP_min_TWID_FACTOR_N2_log2);
localparam TP_over_n2_minus_1 = (TP/N2) - 1;

wire [4:0] MAP_LUT [0:TP-1];



if (TP == 32) begin
    if (DIM_NUM == 3) begin
        if (N2 == 4) begin
            assign MAP_LUT[0]=0;  assign MAP_LUT[1]=1;  assign MAP_LUT[2]=2;
            assign MAP_LUT[3]=0;  assign MAP_LUT[4]=1;  assign MAP_LUT[5]=2;
            assign MAP_LUT[6]=0;  assign MAP_LUT[7]=1;  assign MAP_LUT[8]=2;
            assign MAP_LUT[9]=0;  assign MAP_LUT[10]=1; assign MAP_LUT[11]=2;
            assign MAP_LUT[12]=0; assign MAP_LUT[13]=1; assign MAP_LUT[14]=2;
            assign MAP_LUT[15]=0; assign MAP_LUT[16]=1; assign MAP_LUT[17]=2;
            assign MAP_LUT[18]=0; assign MAP_LUT[19]=1; assign MAP_LUT[20]=2;
            assign MAP_LUT[21]=0; assign MAP_LUT[22]=1; assign MAP_LUT[23]=2;
        end
        else if (N2 == 8) begin
            assign MAP_LUT[0]=0;  assign MAP_LUT[1]=1;  assign MAP_LUT[2]=2;  assign MAP_LUT[3]=3;
            assign MAP_LUT[4]=4;  assign MAP_LUT[5]=5;  assign MAP_LUT[6]=6;

            assign MAP_LUT[7]=0;  assign MAP_LUT[8]=1;  assign MAP_LUT[9]=2;  assign MAP_LUT[10]=3;
            assign MAP_LUT[11]=4; assign MAP_LUT[12]=5; assign MAP_LUT[13]=6;

            assign MAP_LUT[14]=0; assign MAP_LUT[15]=1; assign MAP_LUT[16]=2; assign MAP_LUT[17]=3;
            assign MAP_LUT[18]=4; assign MAP_LUT[19]=5; assign MAP_LUT[20]=6;

            assign MAP_LUT[21]=0; assign MAP_LUT[22]=1; assign MAP_LUT[23]=2; assign MAP_LUT[24]=3;
            assign MAP_LUT[25]=4; assign MAP_LUT[26]=5; assign MAP_LUT[27]=6;
        end
        else if (N2 == 16) begin
            assign MAP_LUT[0]=0;  assign MAP_LUT[1]=1;  assign MAP_LUT[2]=2;  assign MAP_LUT[3]=3;
            assign MAP_LUT[4]=4;  assign MAP_LUT[5]=5;  assign MAP_LUT[6]=6;  assign MAP_LUT[7]=7;
            assign MAP_LUT[8]=8;  assign MAP_LUT[9]=9;  assign MAP_LUT[10]=10; assign MAP_LUT[11]=11;
            assign MAP_LUT[12]=12; assign MAP_LUT[13]=13; assign MAP_LUT[14]=14;

            assign MAP_LUT[15]=0; assign MAP_LUT[16]=1; assign MAP_LUT[17]=2; assign MAP_LUT[18]=3;
            assign MAP_LUT[19]=4; assign MAP_LUT[20]=5; assign MAP_LUT[21]=6; assign MAP_LUT[22]=7;
            assign MAP_LUT[23]=8; assign MAP_LUT[24]=9; assign MAP_LUT[25]=10; assign MAP_LUT[26]=11;
            assign MAP_LUT[27]=12; assign MAP_LUT[28]=13; assign MAP_LUT[29]=14;
        end
        else if (N2 == 32) begin
            assign MAP_LUT[0]=0;  assign MAP_LUT[1]=1;  assign MAP_LUT[2]=2;  assign MAP_LUT[3]=3;
            assign MAP_LUT[4]=4;  assign MAP_LUT[5]=5;  assign MAP_LUT[6]=6;  assign MAP_LUT[7]=7;
            assign MAP_LUT[8]=8;  assign MAP_LUT[9]=9;  assign MAP_LUT[10]=10; assign MAP_LUT[11]=11;
            assign MAP_LUT[12]=12; assign MAP_LUT[13]=13; assign MAP_LUT[14]=14; assign MAP_LUT[15]=15;
            assign MAP_LUT[16]=16; assign MAP_LUT[17]=17; assign MAP_LUT[18]=18; assign MAP_LUT[19]=19;
            assign MAP_LUT[20]=20; assign MAP_LUT[21]=21; assign MAP_LUT[22]=22; assign MAP_LUT[23]=23;
            assign MAP_LUT[24]=24; assign MAP_LUT[25]=25; assign MAP_LUT[26]=26; assign MAP_LUT[27]=27;
            assign MAP_LUT[28]=28; assign MAP_LUT[29]=29; assign MAP_LUT[30]=30;
        end
    end else if(DIM_NUM == 4) begin
        assign MAP_LUT[0] = 0;
        assign MAP_LUT[1] = 0;
        assign MAP_LUT[2] = 0;
        assign MAP_LUT[3] = 0;
        assign MAP_LUT[4] = 0;
        assign MAP_LUT[5] = 0;
        assign MAP_LUT[6] = 0;
        assign MAP_LUT[7] = 0;
        assign MAP_LUT[8] = 0;
        assign MAP_LUT[9] = 0;
        assign MAP_LUT[10] = 0;
        assign MAP_LUT[11] = 0;
        assign MAP_LUT[12] = 0;
        assign MAP_LUT[13] = 0;
        assign MAP_LUT[14] = 0;
        assign MAP_LUT[15] = 0;
    end    
end else if (TP == 64) begin
    if (N2 == 2) begin
        assign MAP_LUT[0]=0;  assign MAP_LUT[1]=0;  assign MAP_LUT[2]=0;  assign MAP_LUT[3]=0;
        assign MAP_LUT[4]=0;  assign MAP_LUT[5]=0;  assign MAP_LUT[6]=0;  assign MAP_LUT[7]=0;
        assign MAP_LUT[8]=0;  assign MAP_LUT[9]=0;  assign MAP_LUT[10]=0; assign MAP_LUT[11]=0;
        assign MAP_LUT[12]=0; assign MAP_LUT[13]=0; assign MAP_LUT[14]=0; assign MAP_LUT[15]=0;
        assign MAP_LUT[16]=0; assign MAP_LUT[17]=0; assign MAP_LUT[18]=0; assign MAP_LUT[19]=0;
        assign MAP_LUT[20]=0; assign MAP_LUT[21]=0; assign MAP_LUT[22]=0; assign MAP_LUT[23]=0;
        assign MAP_LUT[24]=0; assign MAP_LUT[25]=0; assign MAP_LUT[26]=0; assign MAP_LUT[27]=0;
        assign MAP_LUT[28]=0; assign MAP_LUT[29]=0; assign MAP_LUT[30]=0; assign MAP_LUT[31]=0;
        assign MAP_LUT[32]=0; assign MAP_LUT[33]=0; assign MAP_LUT[34]=0; assign MAP_LUT[35]=0;
        assign MAP_LUT[36]=0; assign MAP_LUT[37]=0; assign MAP_LUT[38]=0; assign MAP_LUT[39]=0;
        assign MAP_LUT[40]=0; assign MAP_LUT[41]=0; assign MAP_LUT[42]=0; assign MAP_LUT[43]=0;
        assign MAP_LUT[44]=0; assign MAP_LUT[45]=0; assign MAP_LUT[46]=0; assign MAP_LUT[47]=0;
        assign MAP_LUT[48]=0; assign MAP_LUT[49]=0; assign MAP_LUT[50]=0; assign MAP_LUT[51]=0;
        assign MAP_LUT[52]=0; assign MAP_LUT[53]=0; assign MAP_LUT[54]=0; assign MAP_LUT[55]=0;
        assign MAP_LUT[56]=0; assign MAP_LUT[57]=0; assign MAP_LUT[58]=0; assign MAP_LUT[59]=0;
        assign MAP_LUT[60]=0; assign MAP_LUT[61]=0; assign MAP_LUT[62]=0; assign MAP_LUT[63]=0;
    end
    else if (N2 == 4) begin
        assign MAP_LUT[0]=0;  assign MAP_LUT[1]=1;  assign MAP_LUT[2]=2;
        assign MAP_LUT[3]=0;  assign MAP_LUT[4]=1;  assign MAP_LUT[5]=2;
        assign MAP_LUT[6]=0;  assign MAP_LUT[7]=1;  assign MAP_LUT[8]=2;
        assign MAP_LUT[9]=0;  assign MAP_LUT[10]=1; assign MAP_LUT[11]=2;
        assign MAP_LUT[12]=0; assign MAP_LUT[13]=1; assign MAP_LUT[14]=2;
        assign MAP_LUT[15]=0; assign MAP_LUT[16]=1; assign MAP_LUT[17]=2;
        assign MAP_LUT[18]=0; assign MAP_LUT[19]=1; assign MAP_LUT[20]=2;
        assign MAP_LUT[21]=0; assign MAP_LUT[22]=1; assign MAP_LUT[23]=2;
        assign MAP_LUT[24]=0; assign MAP_LUT[25]=1; assign MAP_LUT[26]=2;
        assign MAP_LUT[27]=0; assign MAP_LUT[28]=1; assign MAP_LUT[29]=2;
        assign MAP_LUT[30]=0; assign MAP_LUT[31]=1; assign MAP_LUT[32]=2;
        assign MAP_LUT[33]=0; assign MAP_LUT[34]=1; assign MAP_LUT[35]=2;
        assign MAP_LUT[36]=0; assign MAP_LUT[37]=1; assign MAP_LUT[38]=2;
        assign MAP_LUT[39]=0; assign MAP_LUT[40]=1; assign MAP_LUT[41]=2;
        assign MAP_LUT[42]=0; assign MAP_LUT[43]=1; assign MAP_LUT[44]=2;
        assign MAP_LUT[45]=0; assign MAP_LUT[46]=1; assign MAP_LUT[47]=2;
        assign MAP_LUT[48]=0; assign MAP_LUT[49]=1; assign MAP_LUT[50]=2;
        assign MAP_LUT[51]=0; assign MAP_LUT[52]=1; assign MAP_LUT[53]=2;
        assign MAP_LUT[54]=0; assign MAP_LUT[55]=1; assign MAP_LUT[56]=2;
        assign MAP_LUT[57]=0; assign MAP_LUT[58]=1; assign MAP_LUT[59]=2;
        assign MAP_LUT[60]=0; assign MAP_LUT[61]=1; assign MAP_LUT[62]=2;
    end
    else if (N2 == 8) begin
        assign MAP_LUT[0]=0;  assign MAP_LUT[1]=1;  assign MAP_LUT[2]=2;  assign MAP_LUT[3]=3;
        assign MAP_LUT[4]=4;  assign MAP_LUT[5]=5;  assign MAP_LUT[6]=6;

        assign MAP_LUT[7]=0;  assign MAP_LUT[8]=1;  assign MAP_LUT[9]=2;  assign MAP_LUT[10]=3;
        assign MAP_LUT[11]=4; assign MAP_LUT[12]=5; assign MAP_LUT[13]=6;

        assign MAP_LUT[14]=0; assign MAP_LUT[15]=1; assign MAP_LUT[16]=2; assign MAP_LUT[17]=3;
        assign MAP_LUT[18]=4; assign MAP_LUT[19]=5; assign MAP_LUT[20]=6;

        assign MAP_LUT[21]=0; assign MAP_LUT[22]=1; assign MAP_LUT[23]=2; assign MAP_LUT[24]=3;
        assign MAP_LUT[25]=4; assign MAP_LUT[26]=5; assign MAP_LUT[27]=6;

        assign MAP_LUT[28]=0; assign MAP_LUT[29]=1; assign MAP_LUT[30]=2; assign MAP_LUT[31]=3;
        assign MAP_LUT[32]=4; assign MAP_LUT[33]=5; assign MAP_LUT[34]=6;

        assign MAP_LUT[35]=0; assign MAP_LUT[36]=1; assign MAP_LUT[37]=2; assign MAP_LUT[38]=3;
        assign MAP_LUT[39]=4; assign MAP_LUT[40]=5; assign MAP_LUT[41]=6;

        assign MAP_LUT[42]=0; assign MAP_LUT[43]=1; assign MAP_LUT[44]=2; assign MAP_LUT[45]=3;
        assign MAP_LUT[46]=4; assign MAP_LUT[47]=5; assign MAP_LUT[48]=6;

        assign MAP_LUT[49]=0; assign MAP_LUT[50]=1; assign MAP_LUT[51]=2; assign MAP_LUT[52]=3;
        assign MAP_LUT[53]=4; assign MAP_LUT[54]=5; assign MAP_LUT[55]=6;

        assign MAP_LUT[56]=0; assign MAP_LUT[57]=1; assign MAP_LUT[58]=2; assign MAP_LUT[59]=3;
        assign MAP_LUT[60]=4; assign MAP_LUT[61]=5; assign MAP_LUT[62]=6;
    end
    else if (N2 == 16) begin
        assign MAP_LUT[0]=0;  assign MAP_LUT[1]=1;  assign MAP_LUT[2]=2;  assign MAP_LUT[3]=3;
        assign MAP_LUT[4]=4;  assign MAP_LUT[5]=5;  assign MAP_LUT[6]=6;  assign MAP_LUT[7]=7;
        assign MAP_LUT[8]=8;  assign MAP_LUT[9]=9;  assign MAP_LUT[10]=10; assign MAP_LUT[11]=11;
        assign MAP_LUT[12]=12; assign MAP_LUT[13]=13; assign MAP_LUT[14]=14;

        assign MAP_LUT[15]=0; assign MAP_LUT[16]=1; assign MAP_LUT[17]=2; assign MAP_LUT[18]=3;
        assign MAP_LUT[19]=4; assign MAP_LUT[20]=5; assign MAP_LUT[21]=6; assign MAP_LUT[22]=7;
        assign MAP_LUT[23]=8; assign MAP_LUT[24]=9; assign MAP_LUT[25]=10; assign MAP_LUT[26]=11;
        assign MAP_LUT[27]=12; assign MAP_LUT[28]=13; assign MAP_LUT[29]=14;

        assign MAP_LUT[30]=0; assign MAP_LUT[31]=1; assign MAP_LUT[32]=2; assign MAP_LUT[33]=3;
        assign MAP_LUT[34]=4; assign MAP_LUT[35]=5; assign MAP_LUT[36]=6; assign MAP_LUT[37]=7;
        assign MAP_LUT[38]=8; assign MAP_LUT[39]=9; assign MAP_LUT[40]=10; assign MAP_LUT[41]=11;
        assign MAP_LUT[42]=12; assign MAP_LUT[43]=13; assign MAP_LUT[44]=14;

        assign MAP_LUT[45]=0; assign MAP_LUT[46]=1; assign MAP_LUT[47]=2; assign MAP_LUT[48]=3;
        assign MAP_LUT[49]=4; assign MAP_LUT[50]=5; assign MAP_LUT[51]=6; assign MAP_LUT[52]=7;
        assign MAP_LUT[53]=8; assign MAP_LUT[54]=9; assign MAP_LUT[55]=10; assign MAP_LUT[56]=11;
        assign MAP_LUT[57]=12; assign MAP_LUT[58]=13; assign MAP_LUT[59]=14;

        assign MAP_LUT[60]=0; assign MAP_LUT[61]=1; assign MAP_LUT[62]=2; assign MAP_LUT[63]=3;
    end
    
end
    

localparam BRAM_SIZE_2                = 256;
localparam BRAM_LOG_SIZE_2            = $clog2(BRAM_SIZE_2);


// states
localparam OP_IDLE                      = 1'd0;
localparam OP_TWIDDLE_LOAD              = 1'd1;

reg  [LOG_CTR-1:0] ctr, ctr_read;
wire [LOG_CTR-1:0] ctr_read_d1, ctr_read_d2, ctr_read_d3; 
reg  curr_state, next_state;

reg [1:0]              op_d;

reg start_addr_gen;

reg [LOGQ-1:0]                  bi00     [(TP-1)-1:0];
wire[LOGQ-1:0]                  bo00     [(TP-1)-1:0];
reg [LOG_DEPTH+2-1:0]             bw00     [(TP-1)-1:0];
reg [LOG_DEPTH+2-1:0]             br00     [(TP-1)-1:0];
reg                             be00     [(TP-1)-1:0];

reg [LOGQ-1:0]                  bi_new     [(TP-1)-1:0];
wire[LOGQ-1:0]                  bo_new     [(TP-1)-1:0];
reg [BRAM_LOG_SIZE_2-1:0]               bw_new     [(TP-1)-1:0];
reg [BRAM_LOG_SIZE_2-1:0]               br_new     [(TP-1)-1:0];
reg                             be_new     [(TP-1)-1:0];


reg [(TP-1)*LOGQ-1:0] twiddle_in_read;
reg [(TP-1)*LOGQ-1:0] twiddle_in_true;
wire [(TP-1)*LOGQ-1:0] psi_d;
wire [1:0] op_in_ntt;

reg [LOG_DEPTH:0] subctr, subctr2;  
reg [LOG_DEPTH:0] write_addr, write_addr2;

reg en2;

wire twid_load_started;

shiftreg #(
    .SHIFT (1),
    .DATA  (LOG_CTR)
) sre_ctr_read (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (ctr_read   ),
    .data_out (ctr_read_d1)
);

shiftreg #(
    .SHIFT (1),
    .DATA  (LOG_CTR)
) sre_ctr_read_d2 (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (ctr_read_d1   ),
    .data_out (ctr_read_d2)
);

shiftreg #(
    .SHIFT (2),
    .DATA  (LOG_CTR)
) sre_ctr_read_d3 (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (ctr_read_d2   ),
    .data_out (ctr_read_d3)
);

shiftreg #(
    .SHIFT (1),
    .DATA  (2)
) sre_op_in (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (op         ),
    .data_out (op_d       )
);


always @(posedge clk) 
begin
    if(rst)
        curr_state <= OP_IDLE;
    else
        curr_state <= next_state;
end


always @(*) begin
    next_state = curr_state;
    if (op == OP_TWIDDLE_LOAD) begin
        next_state = OP_TWIDDLE_LOAD;
    end
    else if ((ctr_read_d1 == CTR_READ_NUM && intt == 1'b0 ) || (ctr_read_d1 == CTR_READ_NUM_INTT && intt == 1'b1 ) ) begin
        next_state = OP_IDLE;
    end
end

always @(posedge clk) begin
    if (rst) begin
        subctr     <= 2;
        subctr2    <= 0;
        write_addr <= 1;
        write_addr2 <= SIZE1_OVER_TWID_FACTOR_N2;
        en <= 'd0;
        en2 <= 'd0;
    end
    else begin
        case (curr_state)
            OP_TWIDDLE_LOAD: begin
                if (en) begin
                    if (intt == 0) begin
                        if (subctr == (TP-1)-1) begin
                            subctr     <= 0;
                            write_addr <= write_addr + 1;
                        end
                        else begin
                            subctr <= subctr + 1;
                        end
                    end else begin
                        if (subctr == (TWID_FACTOR_N2)-1) begin
                            subctr     <= 0;
                            write_addr <= write_addr + 1;
                        end
                        else begin
                            subctr <= subctr + 1;
                        end
                        
                    end
                    
                end
                if (en2) begin
                    if (intt == 1'b1) begin
                        if (subctr2 == TP-2) begin
                            subctr2     <= 0;
                            write_addr2 <= write_addr2 + 1;
                        end
                        else begin
                            subctr2 <= subctr2 + 1;
                        end
                    end
                    
                end
                
            end 
            default: begin
                if (intt == 0) begin
                    write_addr <= 1;
                    subctr <= FIXED_VAL;

                    write_addr2 <= SIZE1_OVER_TWID_FACTOR_N2;
                    subctr2 <= 0;
                end else begin
                    write_addr <= 0;
                    subctr <= 0;

                    write_addr2 <= SIZE1_OVER_TWID_FACTOR_N2;
                    subctr2 <= 0;
                end
                
                
            end
        endcase

        if (DIM_NUM == 2 && twid_load_started) begin
            if (intt == 1'b0) begin
                if (ctr == (1 + (N2))-1) begin
                    en <= 1'd1;
                end
                else if (ctr == DEPTH_LARGE - 1 ) begin
                    en <= 1'd0;
                end
            end else begin
                if (ctr == 0 ) begin
                    en <= 1'd1;
                end
                else if (ctr == DEPTH_LARGE - 1 ) begin
                    en <= 1'd0;
                end
            end
            
        end

        if (DIM_NUM == 3 && twid_load_started) begin
            if (intt == 1'b0) begin
                if (ctr == (1 + (N2))-1) begin
                    en <= 1'd1;
                end
                else if (ctr == DEPTH_LARGE - 1 ) begin
                    en <= 1'd0;
                end
            end else begin
                if (ctr == 0 ) begin
                    en <= 1'd1;
                end
                else if (ctr == DEPTH_LARGE - 1 ) begin
                    en <= 1'd0;
                end
            end
            
        end
        if (DIM_NUM == 4 && twid_load_started) begin
            if (intt == 1'b0) begin
                if (ctr == (1 + (N2))-1 ) begin
                    en <= 1'd1;
                end
                else if (ctr == DEPTH_LARGE - 1 ) begin
                    en <= 1'd0;
                end
            end else begin
                if (ctr == 0 ) begin
                    en <= 1'd1;
                end
                else if (ctr == DEPTH_LARGE - 1 ) begin
                    en <= 1'd0;
                end
                if (ctr == (SIZE1)-1 ) begin
                    en2 <= 1'd1;
                end
                else if (ctr == DEPTH_LARGE - 1 ) begin
                    en2 <= 1'd0;
                end
            end
            
        end
    end

end

assign twid_load_started = (op == OP_TWIDDLE_LOAD || curr_state == OP_TWIDDLE_LOAD) ? 1'b1 : 1'b0;


always @(posedge clk) begin
    if (rst) begin
        ctr <= 0;
    end else begin
        case (curr_state)
            OP_TWIDDLE_LOAD: begin
                ctr <= ctr + 1;
            end 
            default: begin
                ctr <= 0;
            end
        endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        ctr_read <= 0;
    end else begin
        case (curr_state)
            OP_TWIDDLE_LOAD: begin
                ctr_read <= ctr_read + 1;
            end 
            default: begin
                ctr_read <= 0;
            end
        endcase
    end
end



always @(posedge clk ) begin
    if (rst) begin
        start_addr_gen <= 1'b0;
    end else begin
        case (curr_state)
            OP_TWIDDLE_LOAD: 
                start_addr_gen <= 1'b1; 
            default: begin
                start_addr_gen <= 1'b0;
            end
        endcase
    end
end

reg en;


for (genvar i = 0; i < TP-1; i = i + 1) begin: FIFO_LOOP // BRAM for NTT
    always @(posedge clk ) begin
        if (rst) begin
            br_new[i] <= 0;
        end else begin
            case (curr_state)
                OP_TWIDDLE_LOAD: begin
                    if (DIM_NUM == 2) begin
                        if (intt == 0) begin
                            if (ctr >= DEPTH_LARGE) begin
                                br_new[i] <= 0;
                            end
                        end else begin
                            if (ctr >= DEPTH_LARGE ) begin
                                br_new[i] <= ctr - (DEPTH_LARGE);
                            end
                            
                        end
                    end 
                    else if (DIM_NUM == 3) begin
                        if (intt == 0) begin
                            if (ctr >= DEPTH_LARGE-2) begin
                                br_new[i] <= ctr - (DEPTH_LARGE-2);
                            end
                        end else begin
                            if (ctr >= DEPTH-2 && ctr < DEPTH + (N2)-2) begin
                                br_new[i] <= ctr - (DEPTH-2);
                            end
                            else if (ctr >= DEPTH + (N2)-2) begin
                                br_new[i] <= (N2);
                            end
                            else begin
                                 br_new[i] <= 'd0;
                            end
                        end
                    end 
                    else if (DIM_NUM == 4) begin
                        if (intt == 0) begin
                            if (ctr >= DEPTH_LARGE-2) begin
                                br_new[i] <= ctr - (DEPTH_LARGE-2);
                            end
                        end else begin
                            if (ctr >= DEPTH-2 && ctr < DEPTH + SIZE1_OVER_TWID_FACTOR_N2 - 2) begin
                                br_new[i] <= ctr - (DEPTH-2);
                            end
                            else if (ctr >= DEPTH + SIZE1_OVER_TWID_FACTOR_N2 - 2   && ctr < DEPTH + SIZE1_OVER_TWID_FACTOR_N2 + (N3) - 2) begin
                                br_new[i] <=  (ctr - (DEPTH+SIZE1_OVER_TWID_FACTOR_N2-2)) + SIZE1_OVER_TWID_FACTOR_N2;
                            end
                            else if (ctr >=  DEPTH + SIZE1_OVER_TWID_FACTOR_N2 + N3 - 2) begin
                                br_new[i] <= SIZE1_OVER_TWID_FACTOR_N2 + N3;
                            end
                            else begin
                                 br_new[i] <= 'd0;
                            end
                        end
                    end 
                   
                end
                default: begin
                    br_new[i] <= 0;
                end
            endcase
        end
    end
end

for (genvar i = 0; i < TP-1; i = i + 1) begin: FIFO_LOOP22 // BRAM for NTT
    always @(posedge clk ) begin
        if (rst) begin
            bi_new[i] <= 'd0;
            be_new[i] <= 'd0;
            bw_new[i] <= 'd0;
        end else begin
            case (curr_state)
                OP_TWIDDLE_LOAD: begin
                    if (DIM_NUM == 2) begin
                        if (intt == 0) begin
                            if (ctr == i) begin
                                bi_new[i] <= psi[LOGQ*(1)-1-:LOGQ];
                                be_new[i] <= 1'b1;
                                bw_new[i] <= 'b0;
                            end
                        end else begin
                            if (ctr < DEPTH_LARGE ) begin
                                if (ctr == i) begin
                                    bi_new[i] <= psi[LOGQ*(1)-1-:LOGQ];
                                    be_new[i] <= 1'b1;
                                    bw_new[i] <= 'b0;
                                end
                            end
                            else begin
                                bi_new[i] <='d0;
                                be_new[i] <= 'd0;
                                bw_new[i] <= 'd0;
                            end
                        end 
                    end
                    else if (DIM_NUM == 3) begin
                        if (intt == 0) begin
                            if (ctr == 0) begin
                                if (i == 0) begin
                                    bi_new[i] <= psi[LOGQ*(1)-1-:LOGQ];
                                    be_new[i] <= 1'b1;
                                    bw_new[i] <= 'd0;
                                end
                                else begin
                                    bi_new[i] <= 'd0;
                                    be_new[i] <= 1'b0;
                                    bw_new[i] <= 'd0;
                                end
                                
                            end
                            else if (ctr >= 1 && ctr < 1 + (N2)) begin
                                if (ctr < (N2)) begin
                                    if (i < ((ctr<<(TP_min_TWID_FACTOR_N2_log2))+1) && i >= ((ctr-1)<<(TP_min_TWID_FACTOR_N2_log2))+1) begin
                                        bi_new[i] <= psi[LOGQ*((TP-(i-(((ctr[LOGN2-1:0]-1)<<(TP_min_TWID_FACTOR_N2_log2))+1)+TWID_FACTOR_N2)))-1-:LOGQ];
                                        be_new[i] <= 1'b1;
                                        bw_new[i] <= ((ctr-1)>>LOG_DIV) & (DIV-1);
                                    end
                                    else if (ctr == (N2)-1 && i == 0 && LOGN2 == LOGTP) begin
                                        bi_new[i] <= psi[LOGQ*((TP-(TP-1-i)))-1-:LOGQ];
                                        be_new[i] <= 1'b1;
                                        bw_new[i] <= 'b1;
                                    end
                                    else begin
                                        bi_new[i] <= 'd0;
                                        be_new[i] <= 'b0;
                                        bw_new[i] <= 'b0;
                                    end
                                end else begin
                                    if ((N2_min1_mul_tp_min_twid_factor_n2)+1 < TP-1 && i < TP-1 && i >= ((N2_min1_mul_tp_min_twid_factor_n2)+1)) begin
                                        bi_new[i] <= psi[LOGQ*(TP-(i-1))-1-:LOGQ];
                                        be_new[i] <= 1'b1;
                                        bw_new[i] <= 'd0; 
                                    end
                                    else if (i < END_PARAM && i >= START_PARAM) begin 
                                        bi_new[i] <= psi[LOGQ*((TP-(TP-FIXED_VAL_2))-(i-MINUS_CHECK))-1-:LOGQ];
                                        be_new[i] <= 1'b1;
                                        bw_new[i] <= 'd1; 
                                    end
                                    else begin
                                        bi_new[i] <= 'd0;
                                        be_new[i] <= 'b0;
                                        bw_new[i] <= 'b0;
                                    end
                                end
                            end
                            else begin
                                if (ctr < DEPTH_LARGE-1 && ctr >= 1 + (N2)) begin
                                    bi_new[i] <= (i == subctr) ? psi[LOGQ*(1)-1-:LOGQ]: 'd0;
                                    be_new[i] <= (i == subctr) ? 1'b1: 'd0;
                                    bw_new[i] <= (i == subctr) ? write_addr : 'd0;
                                end else begin
                                    bi_new[i] <= 'd0;
                                    be_new[i] <= 'd0;
                                    bw_new[i] <= 'd0;
                                end 
                            end
                        end else begin
                            if (ctr <= DEPTH_LARGE - (TP-1)) begin
                                bi_new[i] <= (i == subctr) ? psi[LOGQ*(1)-1-:LOGQ] : 'd0;
                                be_new[i] <= (i == subctr) ? 1'b1 : 'd0;
                                bw_new[i] <= (i == subctr) ? write_addr : 'd0;
                            end
                            else if (ctr >  DEPTH_LARGE - (TP-1)) begin
                                if (i == ctr - ( DEPTH_LARGE - (TP))) begin
                                    bi_new[i] <= psi[LOGQ*(1)-1-:LOGQ];
                                    be_new[i] <= 1'b1;
                                    bw_new[i] <= N2;
                                end else begin
                                    bi_new[i] <= 'd0;
                                    be_new[i] <= 'd0;
                                    bw_new[i] <= 'd0;
                                end
                                
                            end
                            else begin
                                bi_new[i] <='d0;
                                be_new[i] <= 'd0;
                                bw_new[i] <= 'd0;
                            end
                        end 
                    end
                    else if (DIM_NUM == 4) begin
                        if (intt == 0) begin
                            if (ctr == 0) begin
                                if (i == 0) begin
                                    bi_new[i] <= psi[LOGQ*(1)-1-:LOGQ];
                                    be_new[i] <= 1'b1;
                                    bw_new[i] <= 'd0;
                                end
                                else begin
                                   bi_new[i] <= 'd0;
                                   be_new[i] <= 1'b0;
                                   bw_new[i] <= 'd0;
                                end
                                
                            end
                            else if (ctr >= 1 && ctr < 1 + (1<<LOGN2)) begin
                                if (ctr < (1<<LOGN2)) begin
                                    if (i < ((ctr[1:0]<<(TP_min_TWID_FACTOR_N2_log2))+1) && i >= ((ctr[1:0]-1)<<(TP_min_TWID_FACTOR_N2_log2))+1) begin
                                        bi_new[i] <= psi[LOGQ*((TP-(i-(((ctr[1:0]-1)<<(TP_min_TWID_FACTOR_N2_log2))+1)+TWID_FACTOR_N2)))-1-:LOGQ];
                                        be_new[i] <= 1'b1;
                                        bw_new[i] <= ((ctr[1:0]-1)>>LOG_DIV) & (DIV-1);
                                    end
                                    else begin
                                        bi_new[i] <= 'd0;
                                        be_new[i] <= 'b0;
                                        bw_new[i] <= 'b0;
                                    end
                                end else begin
                                    if ((N2_min1_mul_tp_min_twid_factor_n2)+1 < TP-1 && i < TP-1 && i >= ((N2_min1_mul_tp_min_twid_factor_n2)+1)) begin 
                                        bi_new[i] <= psi[LOGQ*(TP-(i-1))-1-:LOGQ];
                                        be_new[i] <= 1'b1;
                                        bw_new[i] <= 'd0; 
                                    end
                                    else if (i < END_PARAM && i >= START_PARAM) begin 
                                        bi_new[i] <= psi[LOGQ*((TP-(TP-FIXED_VAL_2))-(i-MINUS_CHECK))-1-:LOGQ];
                                        be_new[i] <= 1'b1;
                                        bw_new[i] <= 'd1;
                                    end
                                    else begin
                                        bi_new[i] <= 'd0;
                                        be_new[i] <= 'b0;
                                        bw_new[i] <= 'b0;
                                    end
                                end
                            end
                            else begin
                                if (ctr < DEPTH_LARGE-1 && ctr >= 1 + (N2)) begin
                                    bi_new[i] <= (i == subctr) ? psi[LOGQ*(1)-1-:LOGQ]: 'd0;
                                    be_new[i] <= (i == subctr) ? 1'b1: 'd0;
                                    bw_new[i] <= (i == subctr) ? write_addr : 'd0;
                                end else begin
                                    bi_new[i] <= 'd0;
                                    be_new[i] <= 'd0;
                                    bw_new[i] <= 'd0;
                                end 
                            end
                        end else begin
                            if (ctr < (SIZE1)) begin
                                //fifo_reg[LOGQ*(ctr+1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                                bi_new[i] <= (i == subctr) ? psi[LOGQ*(1)-1-:LOGQ] : 'd0;
                                be_new[i] <= (i == subctr) ? 1'b1 : 'd0;
                                bw_new[i] <= (i == subctr) ? write_addr : 'd0;
                            end
                            else if (ctr >=  (SIZE1) && ctr < (SIZE1) + N3_times_tp_min_1) begin
                                    bi_new[i] <= (i == subctr2) ? psi[LOGQ*(1)-1-:LOGQ] : 'd0;
                                    be_new[i] <= (i == subctr2) ? 1'b1 : 'd0;
                                    bw_new[i] <= (i == subctr2) ? write_addr2 : 'd0;
                                
                            end
                            else if (ctr >=  (SIZE1) + N3_times_tp_min_1 && ctr < (SIZE1) + N3_times_tp_min_1 + (TP-1)) begin
                                    bi_new[i] <= (i == subctr2) ? psi[LOGQ*(1)-1-:LOGQ] : 'd0;
                                    be_new[i] <= (i == subctr2) ? 1'b1 : 'd0;
                                    bw_new[i] <= (i == subctr2) ? write_addr2 : 'd0;
                                
                            end
                            else begin
                                bi_new[i] <='d0;
                                be_new[i] <= 'd0;
                                bw_new[i] <= 'd0;
                            end
                        end 
                    end
                end 
                default: begin
                    bi_new[i] <= 'd0;
                    be_new[i] <= 'd0;
                    bw_new[i] <= 'd0;
                end
            endcase
        end
    end
end


for (genvar i = 0; i < TP-1; i = i + 1) begin: BRAM_TWIDDLE_LOAD_2 // BRAM for NTT
    always @(posedge clk) begin
        if (rst) begin
            bi00[i] <= 0;
            br00[i] <= 0;
            bw00[i] <= 0;
            be00[i] <= 0;
        end
        else begin
            case (curr_state)
                OP_TWIDDLE_LOAD: begin
                    if (DIM_NUM == 4) begin
                        if (intt == 0) begin
                            if (ctr == 0) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end else if (ctr >= 1 && ctr < 1 + (N2)) begin
                                if (i < TWID_FACTOR_N2) begin
                                    bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                                end
                                else begin 
                                    bi00[i] <= 0;
                                end
                            end
                            else if ( ctr >= 1 + (N2) && ctr < 1 + (N2) + (((1<<(LOGN-LOGTP))-1)>>LOGN3)) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end
                            else begin
                                if (ctr < DEPTH_LARGE) begin  
                                    bi00[i] <=  psi[(TP-i)*LOGQ-1-:LOGQ];
                                end else begin
                                    bi00[i] <= bo_new[i];
                                end
                            end
                            br00[i] <= ctr_read_d1 < (1) ? 1'd0 : ctr_read_d1 < (1 + (N2)) ? ((ctr_read_d1-1) & ((N2)-1)) + 1 : ctr_read_d1 < (1 + (N2) + (1<<(LOGN-LOGTP))) ? (((ctr_read_d1 - (1 + (N2))) & ((1<<(LOGN-LOGTP))-1))>>LOGN3) + (N2) + 1 : ((ctr_read_d1-( DEPTH +(N2) + 1)) & ((1<<(LOGN-LOGTP))-1)) + (DEPTH/N3) +  (N2) + 1;
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < (1 + (N2) + (DEPTH/N3) + (1<<(LOGN-LOGTP)))) ? 1'b1 : 1'b0;
                        end else begin
                            if (ctr < DEPTH) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end else if (ctr >= DEPTH && ctr < DEPTH + (DEPTH/TP) ) begin
                                if (i < TWID_FACTOR_N2) begin
                                    bi00[i] <= bo_new[i];
                                end
                                else begin 
                                    bi00[i] <= 'd0;
                                end
                            end
                            else if (ctr >= DEPTH + (DEPTH/TP) && ctr < DEPTH + (DEPTH/TP + (1<<LOGN3)) + 1) begin
                                bi00[i] <= bo_new[i];
                            end
                            br00[i] <= ctr_read_d1 < (DEPTH) ? ctr_read_d1 : ctr_read_d1 < (DEPTH + DEPTH) ? ((ctr_read_d1 & (DEPTH - 1)) >> LOGTP) + DEPTH : ctr_read_d1 < (DEPTH + DEPTH + (1<<LOGN3) ) ?  DEPTH + (DEPTH>>LOGTP) + ((ctr_read_d1 - (DEPTH + (DEPTH>>LOGTP))) & ((1<<LOGN3)-1)) : DEPTH + (DEPTH>>LOGTP) + (1<<LOGN3);
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < DEPTH + DEPTH/TP + (1<<LOGN3) + 1) ? 1'b1 : 1'b0;
                        end
                    end
                    else if (DIM_NUM == 3) begin
                        if (intt == 0) begin
                            if (ctr == 0) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end else if (ctr >= 1 && ctr < 1 + (N2)) begin
                                if (i < TWID_FACTOR_N2) begin
                                    bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                                end
                                else begin 
                                    bi00[i] <= 0;
                                end
                            end
                            else begin
                                if (ctr < DEPTH_LARGE) begin  
                                    bi00[i] <=  psi[(TP-i)*LOGQ-1-:LOGQ];
                                end else begin
                                    bi00[i] <= bo_new[i];
                                end
                            end
                            br00[i] <= ctr_read_d1 < (1) ? 1'd0 : ctr_read_d1 < (1 + (N2)) ? ((ctr_read_d1-1) & ((N2)-1)) + 1 : ((ctr_read_d1-(1+(N2))) & ((1<<(LOGN-LOGTP))-1)) + (N2) + 1;
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < (1 + (N2) + (1<<(LOGN-LOGTP)))) ? 1'b1 : 1'b0;
                        end else begin
                            if (ctr < DEPTH) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end else if (ctr >= DEPTH && ctr < DEPTH + (N2)) begin
                                if (i < TWID_FACTOR_N2) begin
                                    bi00[i] <= bo_new[i];
                                end
                                else begin 
                                    bi00[i] <= 0;
                                end
                            end else begin
                                    bi00[i] <= bo_new[i];
                                end
                            br00[i] <= ctr_read_d1 < (DEPTH) ? ctr_read_d1 : ctr_read_d1 < (DEPTH+DEPTH) ? ((ctr_read_d1 & (DEPTH - 1)) >> LOGTP) + DEPTH : DEPTH + (N2);                            
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < (1 + (N2) + (1<<(LOGN-LOGTP)))) ? 1'b1 : 1'b0;
                        end
                    end 
                    else if (DIM_NUM == 2) begin
                        if (intt == 1'b0) begin
                            if (ctr == 0) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end else begin
                                if (ctr < DEPTH_LARGE) begin  
                                    bi00[i] <=  psi[(TP-i)*LOGQ-1-:LOGQ];
                                end else begin
                                    bi00[i] <= (i < TP-2) ? bo_new[i] : bi_new[TP-2];
                                end
                            end
                            br00[i] <= ctr_read_d1 < (1) ? 1'd0 : ((ctr_read_d1-1) & ((1<<(LOGN-LOGTP))-1)) + 1;
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < (1 + (1<<(LOGN-LOGTP)))) ? 1'b1 : 1'b0;
                        end else begin
                            if (ctr < DEPTH) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end else begin
                                bi00[i] <=  (i < TP-2) ? bo_new[i] : bi_new[TP-2];
                            end
                            br00[i] <= ctr_read_d1 < (DEPTH_LARGE) ? ctr_read_d1 : DEPTH;
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < (1 + (1<<(LOGN-LOGTP)))) ? 1'b1 : 1'b0;
                        end
                        
                    end
                end 
                default: begin
                    bi00[i] <= 0;
                    br00[i] <= 0;
                    bw00[i] <= 0;
                    be00[i] <= 0;
                end
            endcase
           
        end
    end
end

for (genvar c2 = 0; c2 < TP-1; c2 = c2 + 1) begin: BRAM_GEN_BLOCK_NTT0 // BRAM for NTT
    BRAM #(
    .DSIZE (LOGQ         ),
    .MSIZE (BRAM_SIZE    ),
    .DEPTH (BRAM_LOG_SIZE)
) bm000 (
    .clk   (clk          ),
    .wen   (be00[c2]     ),
    .waddr (bw00[c2]     ),
    .din   (bi00[c2]     ),
    .raddr (br00[c2]     ),
    .dout  (bo00[c2]     )
);
end

for (genvar c2 = 0; c2 < TP-1; c2 = c2 + 1) begin: BRAM_GEN_BLOCK_NTT1 // BRAM for NTT
    BRAM #(
    .DSIZE (LOGQ         ),
    .MSIZE (BRAM_SIZE_2    ),
    .DEPTH (BRAM_LOG_SIZE_2)
) bm000 (
    .clk   (clk          ),
    .wen   (be_new[c2]     ),
    .waddr (bw_new[c2]     ),
    .din   (bi_new[c2]     ),
    .raddr (br_new[c2]     ),
    .dout  (bo_new[c2]     )
);
end


for (genvar loop_id = 0; loop_id < TP-1; loop_id = loop_id + 1) begin
    always @(posedge clk) begin
        if (rst) begin
            twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= 0; 
        end else begin
            if (intt == 1'b0) begin
                twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= bo00[loop_id];
            end else begin
                if (DIM_NUM == 3) begin
                    if (ctr_read_d2 >= DEPTH && ctr_read_d2 < DEPTH << 1) begin
                        twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= bo00[loop_id];
                    end
                    else begin
                        twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= bo00[loop_id];
                    end
                end else if (DIM_NUM == 2) begin
                    twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= bo00[loop_id];
                end else if (DIM_NUM == 4) begin
                    twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= bo00[loop_id];
                end
                
            end
             
        end
        
    end
end

integer loop_id;

for (genvar loop_id = 0; loop_id < TP-1; loop_id = loop_id + 1) begin
     always @(posedge clk) begin
        if (rst) begin
            twiddle_in_true[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= 0; 
        end else begin
            if (intt == 1'b0) begin
                twiddle_in_true[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ];
            end else begin
                if (DIM_NUM == 3) begin
                    if (ctr_read_d3 >= DEPTH && ctr_read_d3 < DEPTH << 1) begin
                            if (LOGQ == 60) begin
                                if (N2==32) begin
                                    twiddle_in_true[(TP-1-(loop_id))*LOGQ-1-:LOGQ] <= twiddle_in_read[((TP-1-MAP_LUT[loop_id])<<6) - ((TP-1-MAP_LUT[loop_id])<<2)-1-:(LOGQ)];            
                                end
                                else if (N2==16) begin
                                    twiddle_in_true[(TP-1-(loop_id))*LOGQ-1-:LOGQ] <= twiddle_in_read[((TP-1-(((ctr_read_d3[4:4] & 1'd1) << 4) - (ctr_read_d3[4:4] & 1'd1)+MAP_LUT[loop_id]))<<6) - ((TP-1-(((ctr_read_d3[4:4] & 1'd1) << 4) - (ctr_read_d3[4:4] & 1'd1)+MAP_LUT[loop_id]))<<2)-1-:(LOGQ)];  
                                    
                                end
                                else if (N2==8) begin
                                    twiddle_in_true[(TP-1-(loop_id))*LOGQ-1-:LOGQ] <= twiddle_in_read[((TP-1-(((ctr_read_d3[4:3]) << 3) - (ctr_read_d3[4:3])+MAP_LUT[loop_id]))<<6) - ((TP-1-(((ctr_read_d3[4:3]) << 3) - (ctr_read_d3[4:3])+MAP_LUT[loop_id]))<<2)-1-:(LOGQ)];  
                                    
                                end
                                else if (N2==4) begin
                                    twiddle_in_true[(TP-1-(loop_id))*LOGQ-1-:LOGQ] <= twiddle_in_read[((TP-1-(((ctr_read_d3[4:2]) << 2) - (ctr_read_d3[4:2])+MAP_LUT[loop_id]))<<6) - ((TP-1-(((ctr_read_d3[4:2]) << 2) - (ctr_read_d3[4:2])+MAP_LUT[loop_id]))<<2)-1-:(LOGQ)];  
                                    
                                end
                                else if (N2==2) begin
                                    twiddle_in_true[(TP-1-(loop_id))*LOGQ-1-:LOGQ] <= twiddle_in_read[((TP-1-(((ctr_read_d3[4:1]) << 1) - (ctr_read_d3[4:1])+MAP_LUT[loop_id]))<<6) - ((TP-1-(((ctr_read_d3[4:1]) << 1) - (ctr_read_d3[4:1])+MAP_LUT[loop_id]))<<2)-1-:(LOGQ)];  
                                    
                                end
                            end else if(LOGQ == 32) begin
                                if (N2 == 2) begin
                                    twiddle_in_true[(TP-1-(loop_id))*LOGQ-1-:LOGQ] <= twiddle_in_read[((TP-1-(((ctr_read_d3[5:1]) << 1) - (ctr_read_d3[5:1])+MAP_LUT[loop_id]))<<5)-1-:(LOGQ)];
                                end
                                else if (N2 == 4) begin
                                    twiddle_in_true[(TP-1-(loop_id))*LOGQ-1-:LOGQ] <= twiddle_in_read[((TP-1-(((ctr_read_d3[5:2]) << 2) - (ctr_read_d3[5:2])+MAP_LUT[loop_id]))<<5)-1-:(LOGQ)];
                                end
                                else if (N2 == 8) begin
                                    twiddle_in_true[(TP-1-(loop_id))*LOGQ-1-:LOGQ] <= twiddle_in_read[((TP-1-(((ctr_read_d3[5:3]) << 3) - (ctr_read_d3[5:3])+MAP_LUT[loop_id]))<<5)-1-:(LOGQ)];
                                end
                                else if (N2 == 16) begin
                                    twiddle_in_true[(TP-1-(loop_id))*LOGQ-1-:LOGQ] <= twiddle_in_read[((TP-1-(((ctr_read_d3[5:4]) << 4) - (ctr_read_d3[5:4])+MAP_LUT[loop_id]))<<5)-1-:(LOGQ)];
                                end
                            end
                            
                        //end
                    end
                    else begin
                        twiddle_in_true[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ];
                    end
                end 
                else if (DIM_NUM == 4) begin
                    if (ctr_read_d3 >= DEPTH && ctr_read_d3 < DEPTH << 1) begin
                        twiddle_in_true[(TP-1-(loop_id))*LOGQ-1-:LOGQ] <= twiddle_in_read[(TP-1-(ctr_read_d3[4:1]))*LOGQ-1-:(LOGQ)];

                    end
                    else begin
                        twiddle_in_true[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ];
                    end
                end else if (DIM_NUM == 2) begin
                    twiddle_in_true[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ];
                end
            end
        end
    end
end

assign psi_out        = twiddle_in_true;
    
endmodule