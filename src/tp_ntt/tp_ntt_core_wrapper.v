`include "tp_ntt.vh"

module tp_ntt_core_wrapper#(
        parameter DIM           = 1,
        parameter N             = 1024,
        parameter n1            = 64,
        parameter n2            = 16,
        parameter TP            = 64,
        parameter LOGQ          = 60,
        parameter LOGQH         = 17,
        parameter BTF_LAT       = 16,
        parameter BLOCK_ID      = 0,
        parameter IS_LARGE      = 0,
        parameter RW_DIS        = 0
    )
    (
        input                           clk,
        input                           rst,
        input                           START_NTT,
        input   [1:0]                   OP_TYPE_INPUT,
        input   [LOGQH-1:0]             Q_in,
        input   [TP*LOGQ-1:0]           NTT_INPUT,
        input   [(TP-1)*LOGQ-1:0]       TWIDDLE_INPUT,
        output reg [TP*LOGQ-1:0]        NTT_OUTPUT
    );


localparam log_n1 = $rtoi($ceil($clog2(n1)));
localparam log_TP = $rtoi($ceil($clog2(TP)));
localparam size0 = n1*n2;
localparam size0_over_tp = $rtoi($ceil((size0/TP)));
localparam N_over_TP_log2 = $rtoi($ceil($clog2(N/TP)));
localparam depth         =  $rtoi($ceil(N/TP));
localparam depth_log         =  $rtoi($ceil($clog2(N/TP)));

localparam reg_ctr = $clog2(size0_over_tp);
localparam bram_reg_size =  (TP/n1)*(n1-1);

localparam iter_part_num_tot = DIM == `DIM_2D ? 2 : (DIM == `DIM_3D ? 3 : 4);

// states
localparam OP_IDLE                  = 2'd0;
localparam OP_TWIDDLE_LOAD          = 2'd1;
localparam OP_STARTED               = 2'd2;
localparam OP_Q_LOAD                = 2'd3;




reg start_addr_gen;
wire start_addr_gen_shifted, start_addr_gen_shifted_v2, start_addr_gen_shifted_v3;

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


reg [depth_log+1:0] twid_ctr;
reg [reg_ctr:0] ctr;
wire [reg_ctr:0] ctr_shifted;

reg [TP*LOGQ-1:0] NTT_core_in, NTT_core_out_reg;
wire [TP*LOGQ-1:0] NTT_core_out;
reg [(bram_reg_size)*LOGQ-1:0] W_core_in;
reg [LOGQH-1:0] q_core_in;

wire [TP*LOGQ-1:0] NTT_core_out_shift_d2;



always @(posedge clk or posedge rst) begin
    if (rst) begin
        twid_ctr <= 0;
    end else begin
        case (curr_state)
            OP_TWIDDLE_LOAD: begin
                twid_ctr <= twid_ctr + 1;
            end 
            OP_STARTED: begin
                twid_ctr <= twid_ctr + 1;
            end
            default: begin
                twid_ctr <= 0;
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
            case (OP_TYPE_INPUT)
                2'd0: begin
                    if (START_NTT) begin
                        next_state = OP_STARTED;
                    end else begin
                        next_state = OP_IDLE;
                    end
                    
                end 
                2'd1: begin
                    next_state = OP_TWIDDLE_LOAD;
                end
                2'd2: begin
                    next_state = OP_STARTED;
                end
                2'd3: begin
                    next_state = OP_Q_LOAD;
                end
                default: begin
                    next_state = OP_IDLE;
                end
            endcase
        end 
        OP_TWIDDLE_LOAD: begin
            next_state = (twid_ctr == (iter_part_num_tot)*depth-1) ? OP_IDLE : OP_TWIDDLE_LOAD;
        end
        OP_STARTED: begin
            next_state =  OP_STARTED;
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
        ctr <= 0;
    end else begin
        case (curr_state)
            OP_TWIDDLE_LOAD: begin
                ctr <= ctr + 1;
            end 
            OP_STARTED: begin
                if (start_addr_gen_shifted) begin
                    ctr <= ctr + 1;
                end else begin
                    ctr <= ctr;
                end
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
        q_core_in <= 0;
    end else begin
        case (curr_state)
            OP_Q_LOAD: begin
                q_core_in <= Q_in;
            end 

            default: begin
                q_core_in <= q_core_in;
            end
        endcase
    end
end


generate
    if (IS_LARGE) begin
        for (genvar i = 0; i < bram_reg_size; i = i + 1) begin
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    bi0[i]       <= 0;
                    br0[i]       <= 0;
                    bw0[i]       <= 0;
                    be0[i]       <= 0;
                end else begin
                    case (curr_state)
                        OP_TWIDDLE_LOAD: begin
                            if (twid_ctr >= (BLOCK_ID<<depth_log) && twid_ctr < (BLOCK_ID+1)<<depth_log) begin
                                bi0[i]       <= TWIDDLE_INPUT[(TP-1-i)*LOGQ-1-:LOGQ];
                                br0[i]       <= 0;
                                bw0[i]       <= (twid_ctr & (depth-1));
                                be0[i]       <= 1'b1;
                            end
                            else begin
                                bi0[i]       <= 0;
                                br0[i]       <= 0;
                                bw0[i]       <= 0;
                                be0[i]       <= 0;
                            end
                        end
                        OP_STARTED: begin
                            br0[i]       <= (twid_ctr & (depth-1));
                        end
                        default: begin
                            bi0[i]       <= 0;
                            br0[i]       <= 0;
                            bw0[i]       <= 0;
                            be0[i]       <= 0;
                        end
                    endcase
                end
            end
        end
    end else begin
        for (genvar i = 0; i < TP-1; i = i + 1) begin // DEGisecek
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    bi0[i]       <= 0;
                    br0[i]       <= 0;
                    bw0[i]       <= 0;
                    be0[i]       <= 0;
                end else begin
                    case (curr_state)
                        OP_TWIDDLE_LOAD: begin
                            if(twid_ctr >= (BLOCK_ID<<depth_log) && twid_ctr < (BLOCK_ID+1)<<depth_log) begin
                                bi0[i]       <= TWIDDLE_INPUT[(TP-1-i)*LOGQ-1-:LOGQ];
                                br0[i]       <= 0;
                                bw0[i]       <= (twid_ctr & (depth-1));
                                be0[i]       <= 1'b1;
                            end
                            else begin
                                bi0[i]       <= 0;
                                br0[i]       <= 0;
                                bw0[i]       <= 0;
                                be0[i]       <= 0;
                            end
                        end
                        OP_STARTED: begin
                            br0[i]       <= (twid_ctr & (depth-1));
                        end
                        default: begin
                            bi0[i]       <= 0;
                            br0[i]       <= 0;
                            bw0[i]       <= 0;
                            be0[i]       <= 0;
                        end
                    endcase
                end
            end
        end
    end
    
endgenerate



generate
    for (genvar i = 0; i < bram_reg_size; i = i + 1) begin
        always @(posedge clk) begin
            W_core_in[(bram_reg_size-i)*LOGQ-1-:LOGQ]      <= (OP_STARTED) ? bo0[i] : 0;
        end
    end
endgenerate


generate
    if (IS_LARGE) begin
        for (genvar i = 0; i < TP; i = i + 1) begin
            always @(posedge clk) begin
                NTT_core_in[(TP-i)*LOGQ-1-:LOGQ] <= NTT_INPUT[(TP - (((i/n1)*n1 + (i & 1'd1)*(n1/2) + (i & (n1-1))/2)  & (TP-1)))*LOGQ-1-:LOGQ] ;
            end
        end
    end else begin
        for (genvar i = 0; i < TP; i = i + 1) begin
            always @(posedge clk) begin
                //NTT_core_in[( TP - (((i & (n1/2-1))*2 + (i & (n1-1))/(n1/2) + (i/n1)*n1) & (TP-1)) )*LOGQ-1             -:LOGQ]    <= NTT_INPUT[(TP-i)*LOGQ-1-:LOGQ];
                //Buraya bir bakalim
                //NTT_core_in[( TP - ((((i & (n2-1))*n1) + (i/(TP>>1)) + ((i & ((TP>>1)-1))/(TP/n1))*2) & (TP-1)) )*LOGQ-1-:LOGQ]     <= NTT_INPUT[(TP-i)*LOGQ-1-:LOGQ];
                if (RW_DIS) begin
                    NTT_core_in[( TP - (((i & (n1/2-1))*2 + (i & (n1-1))/(n1/2) + (i/n1)*n1) & (TP-1)) )*LOGQ-1             -:LOGQ]    <= NTT_INPUT[(TP-i)*LOGQ-1-:LOGQ];
                end else begin
                    NTT_core_in[( TP - ((((i & (n2-1))*n1) + (i/(TP>>1)) + ((i & ((TP>>1)-1))/(TP/n1))*2) & (TP-1)) )*LOGQ-1-:LOGQ]    <= NTT_INPUT[(TP-i)*LOGQ-1-:LOGQ];
                end
            end
        end
    end
    
endgenerate


// generate
//     for (genvar rot = 0; rot < TP; rot = rot + 1) begin
//         always @(posedge clk) begin
//             NTT_core_out_reg[(TP-((rot/(TP/n1) + (rot&(TP/n1-1))*n1  )&(TP-1)))*LOGQ-1 -: LOGQ] <= NTT_core_out[(TP - (((rot - (ctr&(size0/TP-1))))&(TP-1)))*LOGQ-1 -: LOGQ];
//         end
//     end
// endgenerate

generate  
    for (genvar b2 = 0; b2 < bram_reg_size; b2 = b2 + 1) begin: BRAM_GEN_BLOCK_TWIDDLE // BRAM for TWIDDLE
        BRAM #(LOGQ, $rtoi($ceil(N>>log_TP)), $rtoi($ceil($clog2((N>>log_TP))))) bt000(clk,be0[1*b2+0],bw0[1*b2+0],bi0[1*b2+0],br0[1*b2+0],bo0[1*b2+0]); // 64 BRAMs * 128 depth (2**7) * 32 bit
    end
endgenerate

generate
    for (genvar ntt_idx = 0; ntt_idx < (TP>>log_n1) ; ntt_idx = ntt_idx + 1) begin
        tp_ntt_core #(n1, LOGQ, LOGQH, BTF_LAT) NTT_units_pipelined(clk,rst, q_core_in ,NTT_core_in[(TP-n1*ntt_idx)*LOGQ-1-:n1*LOGQ], W_core_in[(bram_reg_size-(n1-1)*ntt_idx)*LOGQ-1-:(n1-1)*LOGQ], NTT_core_out[(TP-n1*ntt_idx)*LOGQ-1-:n1*LOGQ]);
    end 
endgenerate

// Output Rotaion for Next Block
generate
    
    for (genvar i = 0; i < TP; i = i + 1) begin
        always @(posedge clk) begin
            NTT_OUTPUT[(TP-i)*LOGQ-1 -: LOGQ] <= NTT_core_out[(TP-i)*LOGQ-1-:LOGQ];
        end
    end
endgenerate



endmodule