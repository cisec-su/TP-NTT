`include "tp_ntt.svh"

module tp_ntt_core_wrapper#(
        parameter DIM           = 1,
        parameter LOGN          = 10,
        parameter LOGN1         = 6,
        parameter LOGN2         = 4,
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

localparam N  = 1 << LOGN;
localparam N1 = 1 << LOGN1;
localparam N2 = 1 << LOGN2;
localparam TP = 1 << LOGTP;
localparam size0 = N1*N2;
localparam size0_over_tp = $rtoi($ceil((size0/TP)));
localparam N_over_TP_log2 = $rtoi($ceil($clog2(N/TP)));
localparam depth         =  $rtoi($ceil(N/TP));
localparam depth_log         =  $rtoi($ceil($clog2(N/TP)));

localparam reg_ctr = $clog2(size0_over_tp);
localparam bram_reg_size =  (TP/N1)*(N1-1);

localparam iter_part_num_tot = (DIM == DIM_2D) ? 2 : ((DIM == DIM_3D) ? 3 : 4);

// states
localparam OP_IDLE                  = 2'd0;
localparam OP_TWIDDLE_LOAD          = 2'd1;
localparam OP_STARTED               = 2'd2;
localparam OP_Q_LOAD                = 2'd3;



reg [1:0] OP_TYPE;

reg [1:0] curr_state, next_state;

reg [LOGQ-1:0]                  di00     [1*(TP)-1:0];
wire[LOGQ-1:0]                  do00     [1*(TP)-1:0];
reg [(reg_ctr+1)-1:0]           dw00     [1*(TP)-1:0];
reg [(reg_ctr+1)-1:0]           dr00     [1*(TP)-1:0];
reg                             de00     [1*(TP)-1:0];


reg [LOGQ-1:0]              bi0     [1*(bram_reg_size)-1:0];
wire[LOGQ-1:0]              bo0     [1*(bram_reg_size)-1:0];
reg [N_over_TP_log2-1:0]    bw0     [1*(bram_reg_size)-1:0];
reg [N_over_TP_log2-1:0]    br0     [1*(bram_reg_size)-1:0];
reg                         be0     [1*(bram_reg_size)-1:0];


reg [depth_log+3:0] ctr;

reg [TP*LOGQ-1:0] NTT_core_in;
wire [TP*LOGQ-1:0] NTT_core_out;
reg [(bram_reg_size)*LOGQ-1:0] W_core_in;
reg [LOGQH-1:0] q_core_in;

wire [TP*LOGQ-1:0] NTT_core_out_shift_d2;



always @(posedge clk or posedge rst) begin
    if (rst) begin
        ctr <= 0;
    end else begin
        case (curr_state)
            OP_TWIDDLE_LOAD: begin
                ctr <= ctr + 1;
            end 
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

always @(posedge clk) 
begin
    if(rst)
        curr_state <= OP_IDLE;
    else
        curr_state <= next_state;
end


// New Next State Logic
always @(*) begin
    next_state = curr_state;
    case (curr_state)
        OP_IDLE: begin
            case (op)
                OP_NTT: begin
                    if (start) begin
                        next_state = OP_STARTED;
                    end else begin
                        next_state = OP_IDLE;
                    end
                    
                end 
                OP_LOAD_TWIDDLE: begin
                    next_state = OP_TWIDDLE_LOAD;
                end
                OP_LOAD_Q: begin
                    next_state = OP_Q_LOAD;
                end
                default: begin
                    next_state = OP_IDLE;
                end
            endcase
        end 
        OP_TWIDDLE_LOAD: begin
            next_state = (ctr == (iter_part_num_tot)*depth-1) ? OP_IDLE : OP_TWIDDLE_LOAD;
        end
        OP_STARTED: begin
            next_state = ((ctr[depth_log+3:0]) == (4'd10*depth-1)) ? OP_IDLE : OP_STARTED;
        end
        OP_Q_LOAD: begin
            next_state = (ctr == 1) ? OP_IDLE : OP_Q_LOAD;
        end
        default: begin
            next_state = OP_IDLE;
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


generate

    for (genvar i = 0; i < bram_reg_size; i = i + 1) begin

        always @(posedge clk) begin
            if (curr_state == OP_STARTED) begin
                bi0[i]       <= 0;
                bw0[i]       <= 0;
                br0[i]       <= (ctr & (depth-1));  
            end
            else if (curr_state == OP_TWIDDLE_LOAD) begin
                bi0[i]       <= psi[(TP-1-i)*LOGQ-1-:LOGQ];
                bw0[i]       <= (ctr & (depth-1));
                br0[i]       <= 0;  
            end
            
        end

        always @(posedge clk or posedge rst) begin
            if (rst) begin
                be0[i]       <= 0;
            end else begin
                case (curr_state)
                    OP_TWIDDLE_LOAD: begin
                        if ((ctr >= (BLOCK_ID << depth_log)) && (ctr < (BLOCK_ID + 1) << depth_log)) begin
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

endgenerate



generate
    for (genvar i = 0; i < bram_reg_size; i = i + 1) begin
        always @(posedge clk) begin
            W_core_in[(bram_reg_size-i)*LOGQ-1-:LOGQ] <= bo0[i];
        end
    end
endgenerate


generate
    if (LARGE) begin
        for (genvar i = 0; i < TP; i = i + 1) begin
            always @(posedge clk) begin
                NTT_core_in[(TP-i)*LOGQ-1-:LOGQ] <= i_poly[(TP - (((i/N1)*N1 + (i & 1'd1)*(N1/2) + (i & (N1-1))/2)  & (TP-1)))*LOGQ-1-:LOGQ] ;
            end
        end
    end else begin
        for (genvar i = 0; i < TP; i = i + 1) begin
            always @(posedge clk) begin
                if (RW_DIS) begin
                    NTT_core_in[( TP - (((i & (N1/2-1))*2 + (i & (N1-1))/(N1/2) + (i/N1)*N1) & (TP-1)) )*LOGQ-1             -:LOGQ]    <= i_poly[(TP-i)*LOGQ-1-:LOGQ];
                end else begin
                    NTT_core_in[( TP - ((((i & (N2-1))*N1) + (i/(TP>>1)) + ((i & ((TP>>1)-1))/(TP/N1))*2) & (TP-1)) )*LOGQ-1-:LOGQ]    <= i_poly[(TP-i)*LOGQ-1-:LOGQ];
                end
            end
        end
    end
    
endgenerate


generate  
    for (genvar b2 = 0; b2 < bram_reg_size; b2 = b2 + 1) begin: BRAM_GEN_BLOCK_TWIDDLE // BRAM for TWIDDLE
        // if (BLOCK_ID == 0) begin : BRAM_GEN_BLOCK_0
        //     BRAM #(LOGQ, 1, 1) bt000(clk,be0[1*b2+0],1'b0,bi0[1*b2+0],1'b0,bo0[1*b2+0]);
        // end
        // else begin : BRAM_GEN_BLOCK_1
        //     BRAM #(LOGQ, $rtoi($ceil(N>>LOGTP)), $rtoi($ceil($clog2((N>>LOGTP))))) bt000(clk,be0[1*b2+0],bw0[1*b2+0],bi0[1*b2+0],br0[1*b2+0],bo0[1*b2+0]); // 64 BRAMs * 128 depth (2**7) * 32 bit                        
        // end
        BRAM #(LOGQ, $rtoi($ceil(N>>LOGTP)), $rtoi($ceil($clog2((N>>LOGTP))))) bt000(clk,be0[1*b2+0],bw0[1*b2+0],bi0[1*b2+0],br0[1*b2+0],bo0[1*b2+0]); // 64 BRAMs * 128 depth (2**7) * 32 bit                        
    end
endgenerate

generate
    for (genvar ntt_idx = 0; ntt_idx < (TP>>LOGN1) ; ntt_idx = ntt_idx + 1) begin
        tp_ntt_core #(.LOGN    (LOGN1   ),
                      .LOGQ    (LOGQ    ),
                      .LOGQH   (LOGQH   ),
                      .NON_STD (NON_STD ),
                      .MORE_DSP(MORE_DSP)
        ) tp_ntt_core_inst (
            .clk    (clk      ),
            .intt   (intt)     ,
            .qH     (q_core_in),
            .i_poly (NTT_core_in[(TP-N1*ntt_idx)*LOGQ-1-:N1*LOGQ]),
            .psi    (W_core_in[(bram_reg_size-(N1-1)*ntt_idx)*LOGQ-1-:(N1-1)*LOGQ]),
            .o_poly (NTT_core_out[(TP-N1*ntt_idx)*LOGQ-1-:N1*LOGQ])
        );
    end 
endgenerate

// Output Rotaion for Next Block
generate
    
    for (genvar i = 0; i < TP; i = i + 1) begin
        always @(posedge clk) begin
            o_poly[(TP-i)*LOGQ-1 -: LOGQ] <= NTT_core_out[(TP-i)*LOGQ-1-:LOGQ];
        end
    end
endgenerate



endmodule