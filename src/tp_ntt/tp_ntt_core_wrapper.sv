`include "tp_ntt.svh"

module tp_ntt_core_wrapper#(
        parameter DIM           = 1,
        parameter LOGN          = 10,
        parameter LOGN1         = 6,
        parameter LOGN2         = 4,
        parameter LOG_GLOBAL_N2 = 6,
        parameter LOG_GLOBAL_N3 = 6,
        parameter LOGTP         = 6,
        parameter LOGQ          = 60,
        parameter LOGQH         = 17,
        parameter NON_STD       = 1 ,
        parameter MORE_DSP      = 0 ,
        parameter BLOCK_ID      = 0,
        parameter LARGE         = 0,
        parameter RW_DIS        = 0
    )
    (
        input                           clk,
        input                           rst,
        input                           start,
        input   [1:0]                   op,
        input                           intt,
        input   [LOGQH-1:0]             qH,
        input   [TP*LOGQ-1:0]           i_poly,
        input   [(TP-1)*LOGQ-1:0]       psi,
        output reg [TP*LOGQ-1:0]        o_poly
    );

localparam N                        = 1 << LOGN;
localparam N1                       = 1 << LOGN1;
localparam N2                       = 1 << LOGN2;
localparam TP                       = 1 << LOGTP;
localparam SIZE0                    = N1*N2;
localparam SIZE0_OVER_TP            = (SIZE0/TP);
localparam N_OVER_TP_LOG2           = $clog2(N/TP);
localparam DEPTH                    =  N/TP;
localparam DEPTH_LOG                =  $clog2(N/TP) + 1;
localparam REG_CTR                  = $clog2(SIZE0_OVER_TP) + 1;
localparam BRAM_REG_SIZE            =  (TP/N1)*(N1-1);
localparam ITER_PART_NUM_TOT        = (DIM == DIM_2D) ? 2 : ((DIM == DIM_3D) ? 3 : 4);
localparam LOG_NEEDED_GLOBAL_N2     = LOG_GLOBAL_N2;
localparam LOG_NEEDED_GLOBAL_N3     = LOG_GLOBAL_N3;
localparam TWID_LOAD_CTR            = (DIM == DIM_2D) ? (BLOCK_ID == 0) ? 1         : (BLOCK_ID == 1) ? DEPTH : 0 : (DIM == DIM_3D) ? (BLOCK_ID == 0) ? 1       : (BLOCK_ID == 1) ? 1<<LOG_NEEDED_GLOBAL_N2    : (BLOCK_ID == 2) ? DEPTH   : 0 : (DIM == DIM_4D) ? (BLOCK_ID == 0) ? 1       : (BLOCK_ID == 1) ? 1<<LOG_NEEDED_GLOBAL_N2 : (BLOCK_ID == 2) ? DEPTH                   :  (BLOCK_ID == 3) ? DEPTH  : 0 : 0;
localparam TWID_LOAD_INV_CTR        = (DIM == DIM_2D) ? (BLOCK_ID == 0) ? DEPTH     : (BLOCK_ID == 1) ? 1     : 0 : (DIM == DIM_3D) ? (BLOCK_ID == 0) ? DEPTH   : (BLOCK_ID == 1) ? DEPTH       : (BLOCK_ID == 2) ? 1       : 0 : (DIM == DIM_4D) ? (BLOCK_ID == 0) ? DEPTH   : (BLOCK_ID == 1) ? DEPTH                   : (BLOCK_ID == 2) ? 1<<LOG_NEEDED_GLOBAL_N3 :  (BLOCK_ID == 3) ? 1      : 0 : 0;
//localparam W_R_DEPTH                = (TWID_LOAD_CTR == 1) ? 1 : $clog2(TWID_LOAD_CTR);
localparam W_R_DEPTH                = DEPTH_LOG-1;
localparam BRAM_DEPTH_LOG2          = W_R_DEPTH;
localparam BRAM_DEPTH               = 1 << W_R_DEPTH;
localparam WRITE_TWIDDLE_START      = (DIM == DIM_2D) ? (BLOCK_ID == 0) ? 0         : (BLOCK_ID == 1) ? 1       : 0 : (DIM == DIM_3D) ? (BLOCK_ID == 0) ? 0         : (BLOCK_ID == 1) ? 1               : (BLOCK_ID == 2) ? 1+(1<<LOG_NEEDED_GLOBAL_N2)            : 0 : (DIM == DIM_4D) ? (BLOCK_ID == 0) ? 0     : (BLOCK_ID == 1) ? 1                               : (BLOCK_ID == 2) ? 1+(1<<LOG_NEEDED_GLOBAL_N2)                     : (BLOCK_ID == 3) ?  1+(1<<LOG_NEEDED_GLOBAL_N2)+DEPTH              : 0 : 0;
localparam WRITE_TWIDDLE_END        = (DIM == DIM_2D) ? (BLOCK_ID == 0) ? 1         : (BLOCK_ID == 1) ? DEPTH+1 : 0 : (DIM == DIM_3D) ? (BLOCK_ID == 0) ? 1         : (BLOCK_ID == 1) ? 1+(1<<LOG_NEEDED_GLOBAL_N2)    : (BLOCK_ID == 2) ? 1+(1<<LOG_NEEDED_GLOBAL_N2)+DEPTH      : 0 : (DIM == DIM_4D) ? (BLOCK_ID == 0) ? 1     : (BLOCK_ID == 1) ? 1+(1<<LOG_NEEDED_GLOBAL_N2)     : (BLOCK_ID == 2) ? 1+(1<<LOG_NEEDED_GLOBAL_N2)+DEPTH               : (BLOCK_ID == 3) ?  1+(1<<LOG_NEEDED_GLOBAL_N2)+DEPTH+DEPTH        : 0 : 0;
localparam WRITE_TWIDDLE_INV_START  = (DIM == DIM_2D) ? (BLOCK_ID == 0) ? 0         : (BLOCK_ID == 1) ? DEPTH   : 0 : (DIM == DIM_3D) ? (BLOCK_ID == 0) ? 0         : (BLOCK_ID == 1) ? DEPTH           : (BLOCK_ID == 2) ? DEPTH+DEPTH             : 0 : (DIM == DIM_4D) ? (BLOCK_ID == 0) ? 0     : (BLOCK_ID == 1) ? DEPTH                           : (BLOCK_ID == 2) ? DEPTH + DEPTH                                   : (BLOCK_ID == 3) ?  DEPTH + DEPTH + (1<<LOG_NEEDED_GLOBAL_N3)      : 0 : 0;
localparam WRITE_TWIDDLE_INV_END    = (DIM == DIM_2D) ? (BLOCK_ID == 0) ? DEPTH     : (BLOCK_ID == 1) ? DEPTH+1 : 0 : (DIM == DIM_3D) ? (BLOCK_ID == 0) ? DEPTH     : (BLOCK_ID == 1) ? DEPTH+DEPTH     : (BLOCK_ID == 2) ? DEPTH+DEPTH+1           : 0 : (DIM == DIM_4D) ? (BLOCK_ID == 0) ? DEPTH : (BLOCK_ID == 1) ? DEPTH+DEPTH                     : (BLOCK_ID == 2) ? DEPTH + DEPTH + (1<<LOG_NEEDED_GLOBAL_N3)       : (BLOCK_ID == 3) ?  DEPTH + DEPTH + (1<<LOG_NEEDED_GLOBAL_N3) + 1  : 0 : 0;
localparam TWID_TOTAL_CTR           = (DIM == DIM_2D) ? 1 + DEPTH : (DIM == DIM_3D) ? 1+(1<<LOG_NEEDED_GLOBAL_N2)+DEPTH : (DIM == DIM_4D) ? 1 + (1<<LOG_NEEDED_GLOBAL_N2) + DEPTH + DEPTH : 0;
localparam TWID_TOTAL_INV_CTR       = (DIM == DIM_2D) ? 1 + DEPTH : (DIM == DIM_3D) ? DEPTH+DEPTH+1                     : (DIM == DIM_4D) ? 1 + (1<<LOG_NEEDED_GLOBAL_N3) + DEPTH + DEPTH : 0;

// states
localparam OP_IDLE                  = 2'd0;
localparam OP_TWIDDLE_LOAD          = 2'd1;
localparam OP_STARTED               = 2'd2;
localparam OP_Q_LOAD                = 2'd3;



reg [1:0] OP_TYPE;

reg [1:0] curr_state, next_state;

reg [1:0] curr_state_twid, next_state_twid;

reg [LOGQ-1:0]                  di00     [TP-1:0];
wire[LOGQ-1:0]                  do00     [TP-1:0];
reg [REG_CTR-1:0]               dw00     [TP-1:0];
reg [REG_CTR-1:0]               dr00     [TP-1:0];
reg                             de00     [TP-1:0];


reg [LOGQ-1:0]                  bi0     [BRAM_REG_SIZE-1:0];
wire[LOGQ-1:0]                  bo0     [BRAM_REG_SIZE-1:0];
reg [W_R_DEPTH-1:0]             bw0     [BRAM_REG_SIZE-1:0];
reg [W_R_DEPTH-1:0]             br0     [BRAM_REG_SIZE-1:0];
reg                             be0     [BRAM_REG_SIZE-1:0];


reg [DEPTH_LOG:0] ctr, ctr_twid;

reg [TP*LOGQ-1:0] NTT_core_in;
wire [TP*LOGQ-1:0] NTT_core_out;
reg [BRAM_REG_SIZE*LOGQ-1:0] W_core_in;
reg [LOGQH-1:0] q_core_in;

wire [TP*LOGQ-1:0] NTT_core_out_shift_d2;

reg intt_q;



always @(posedge clk or posedge rst) begin
    if (rst) begin
        ctr <= 0;
    end else begin
        case (curr_state)
            OP_STARTED: begin
                ctr <= ctr + 1;
            end
            OP_Q_LOAD: begin
                ctr <= ctr + 1;
            end
            default: begin
                ctr <= 0;
            end
            
        endcase
        
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ctr_twid <= 0;
    end else begin
        case (curr_state_twid)
            OP_LOAD_TWIDDLE: begin
                ctr_twid <= ctr_twid + 1;
            end
            default: begin
                ctr_twid <= 0;
            end
            
        endcase
        
    end
end

always @(posedge clk) 
begin
    if(rst)
        curr_state <= OP_IDLE;
    else
        curr_state <= next_state;
end

always @(posedge clk) 
begin
    if(rst)
        curr_state_twid <= OP_IDLE;
    else
        curr_state_twid <= next_state_twid;
end


always @(posedge clk) begin
    if (rst) begin
        intt_q <= 0;
    end else if (start) begin
        intt_q <= intt;
    end
end


// New Next State Logic
always @(*) begin
    next_state = curr_state;
    case (curr_state)
        OP_IDLE: begin
            if (start) begin
                next_state = OP_STARTED;
            end 
            else begin
                case (op)
                    OP_LOAD_Q: begin
                        next_state = OP_Q_LOAD;
                    end
                    default: begin
                        next_state = OP_IDLE;
                    end
                endcase
            end
            
        end 
        OP_STARTED: begin
            next_state = ((ctr[DEPTH_LOG-2:0]) == (DEPTH-1)) ? OP_IDLE : OP_STARTED;
        end
        OP_Q_LOAD: begin
            next_state = (ctr == 1) ? OP_IDLE : OP_Q_LOAD;
        end
        default: begin
            next_state = OP_IDLE;
        end
    endcase
end


// New Next State Logic
always @(*) begin
    next_state_twid = curr_state_twid;
    case (curr_state_twid)
        OP_IDLE: begin
            case (op)
                OP_LOAD_TWIDDLE: begin
                    next_state_twid = OP_TWIDDLE_LOAD;
                end
                default: begin
                    next_state_twid = OP_IDLE;
                end
            endcase
        end 
        OP_TWIDDLE_LOAD: begin
            next_state_twid = (ctr_twid == TWID_TOTAL_CTR-1 && intt == 0) || (ctr_twid == TWID_TOTAL_INV_CTR-1 && intt == 1)  ? OP_IDLE : OP_TWIDDLE_LOAD;
        end
        default: begin
            next_state_twid = OP_IDLE;
        end
    endcase
end



always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_core_in <= 0;
    end else begin
        case (curr_state)
            OP_Q_LOAD: begin
                q_core_in <= qH;
            end 

            default: begin
                q_core_in <= q_core_in;
            end
        endcase
    end
end




for (genvar i = 0; i < BRAM_REG_SIZE; i = i + 1) begin

    always @(posedge clk) begin
        if (curr_state_twid == OP_TWIDDLE_LOAD && ((ctr_twid >= WRITE_TWIDDLE_START && ctr_twid < WRITE_TWIDDLE_END && intt == 0  ) || (ctr_twid >= WRITE_TWIDDLE_INV_START && ctr_twid < WRITE_TWIDDLE_INV_END && intt == 1) )) begin
            bi0[i]       <= psi[(TP-1-i)*LOGQ-1-:LOGQ];
            bw0[i]       <= (intt == 0) ? ((ctr_twid-WRITE_TWIDDLE_START) & (TWID_LOAD_CTR-1)) : ((ctr_twid-WRITE_TWIDDLE_INV_START) & (TWID_LOAD_INV_CTR-1)); 
        end
        else begin
            bi0[i]       <= 0;
            bw0[i]       <= 0;  
        end
        
        if (curr_state == OP_STARTED) begin
            br0[i]       <= (intt == 0) ? ((ctr) & (TWID_LOAD_CTR-1)) : ((ctr) & (TWID_LOAD_INV_CTR-1)); 
        end
        else begin
            br0[i]       <= 0;  
        end


        
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            be0[i]       <= 0;
        end else begin
            case (curr_state_twid)
                OP_TWIDDLE_LOAD: begin
                    if (((ctr_twid >= WRITE_TWIDDLE_START && ctr_twid < WRITE_TWIDDLE_END && intt == 0  ) || (ctr_twid >= WRITE_TWIDDLE_INV_START && ctr_twid < WRITE_TWIDDLE_INV_END && intt == 1) )) begin
                        be0[i]       <= 1'b1;
                    end
                    else begin
                        be0[i]       <= 0;
                    end
                end
                default: begin
                    be0[i]       <= 0;
                end
            endcase
        end
    end

end

for (genvar i = 0; i < BRAM_REG_SIZE; i = i + 1) begin
    always @(posedge clk) begin
        W_core_in[(BRAM_REG_SIZE-i)*LOGQ-1-:LOGQ] <= bo0[i];
    end
end


if (LARGE) begin
    for (genvar i = 0; i < TP; i = i + 1) begin
        always @(posedge clk) begin
            NTT_core_in[(TP-(((i & (1'd1)) + ((i&(N1-1))&(2'd3))/2*(N1/2) + ((i&(N1-1))&(3'D7))/4*(N1/4) + ((i&(N1-1))&4'd15)/8*(N1/8) + ((i&(N1-1))&5'd31)/16*(N1/16) + (((i%N1)&(6'd63))/32)*(N1/32) + (((i&(N1-1))&7'd127)/64)*(N1/64) + ((i&(N1-1))/128)*(N1/128) + (i/N1)*N1) & (TP-1)))*LOGQ-1-:LOGQ] <= i_poly[(TP - (i))*LOGQ-1-:LOGQ] ;
        end
    end
end else begin
    for (genvar i = 0; i < TP; i = i + 1) begin
        always @(posedge clk) begin
            if (RW_DIS) begin
                NTT_core_in[( TP - (((i & (1'd1)) + (i&(2'd3))/2*(TP/2) + (i&(3'd7))/4*(TP/4) + (i&4'd15)/8*(TP/8) + (i&5'd31)/16*(TP/16) + (i&6'd63)/32*(TP/32) + (i&7'd127)/64*(TP/64) + (i/128)*(TP/128)) & (TP-1)) )*LOGQ-1             -:LOGQ]    <= i_poly[(TP-i)*LOGQ-1-:LOGQ];
            end else begin
                NTT_core_in[( TP - (((i & (1'd1)) + (i&(2'd3))/2*(TP/2) + (i&(3'd7))/4*(TP/4) + (i&4'd15)/8*(TP/8) + (i&5'd31)/16*(TP/16) + (i&6'd63)/32*(TP/32) + (i&7'd127)/64*(TP/64) + (i/128)*(TP/128)) & (TP-1)) )*LOGQ-1-:LOGQ]    <= i_poly[(TP-i)*LOGQ-1-:LOGQ];
            end
        end
    end
end
    




for (genvar b2 = 0; b2 < BRAM_REG_SIZE; b2 = b2 + 1) begin: BRAM_GEN_BLOCK_TWIDDLE // BRAM for TWIDDLE
   BRAM #(
    .DSIZE (LOGQ                       ),
    .MSIZE (BRAM_DEPTH                 ),
    .DEPTH (BRAM_DEPTH_LOG2            )
) bt000 (
    .clk   (clk            ),
    .wen   (be0[b2]        ),
    .waddr (bw0[b2]        ),
    .din   (bi0[b2]        ),
    .raddr (br0[b2]        ),
    .dout  (bo0[b2]        )
);
end



for (genvar ntt_idx = 0; ntt_idx < (TP>>LOGN1) ; ntt_idx = ntt_idx + 1) begin
    tp_ntt_core #(  
        .LOGN       (LOGN1   ),
        .LOGQ       (LOGQ    ),
        .LOGQH      (LOGQH   ),
        .NON_STD    (NON_STD ),
        .MORE_DSP   (MORE_DSP)
    ) tp_ntt_core_inst (
        .clk        (clk      ),
        .intt       (intt_q   ),
        .qH         (q_core_in),
        .i_poly     (NTT_core_in[(TP-N1*ntt_idx)*LOGQ-1-:N1*LOGQ]),
        .psi        (W_core_in[(BRAM_REG_SIZE-(N1-1)*ntt_idx)*LOGQ-1-:(N1-1)*LOGQ]),
        .o_poly     (NTT_core_out[(TP-N1*ntt_idx)*LOGQ-1-:N1*LOGQ])
    );
end 


// Output Rotaion for Next Block    
for (genvar i = 0; i < TP; i = i + 1) begin
    always @(posedge clk) begin
        o_poly[(TP-i)*LOGQ-1 -: LOGQ] <= NTT_core_out[(TP-i)*LOGQ-1-:LOGQ];
    end
end


endmodule