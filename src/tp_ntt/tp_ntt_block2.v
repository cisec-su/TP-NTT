`include "tp_ntt.vh"

module tp_ntt_block2#(
        parameter DIM           = 1,
        parameter N             = 4096,
        parameter n2            = 16,
        parameter size0         = 128,
        parameter TP            = 32,
        parameter LOGQ          = 32,
        parameter BTF_LAT       = 8,
        parameter RW_DIS        = 0
    )
    (
        input                           clk,
        input                           rst,
        input                           START_NTT,
        input   [1:0]                   OP_TYPE_INPUT,
        input   [LOGQ-1:0]              Q_in,
        input   [TP*LOGQ-1:0]           NTT_INPUT,
        input   [(TP-1)*LOGQ-1:0]       TWIDDLE_INPUT,
        output reg [TP*LOGQ-1:0]        NTT_OUTPUT
    );


localparam log_n2 = $rtoi($ceil($clog2(n2)));
localparam log_TP = $rtoi($ceil($clog2(TP)));
localparam log_N = $rtoi($ceil($clog2(N)));
localparam size1     = N / size0;    
localparam log_size1 = $rtoi($ceil($clog2(size1)));
localparam N_over_TP_log2 = $rtoi($ceil($clog2(N/TP)));
localparam LOG_LOG_Q = $rtoi($ceil($clog2(LOGQ)));
localparam depth         =  $rtoi($ceil(N/TP));
localparam depth_log         =  $rtoi($ceil($clog2(N/TP)));
localparam size1_over_tp = $rtoi($ceil(size1/TP));
localparam size1_over_tp_log2 = $rtoi($ceil($clog2(size1/TP)));
localparam reg_ctr = depth_log;
localparam bram_reg_size =  (TP/n2)*(n2-1);
localparam iter_part_num_tot = DIM == `DIM_2D ? 2 : (DIM == `DIM_3D ? 3 : 4);
localparam size0_over_tp_mult_size1_over_tp_log2 = $rtoi($ceil($clog2((size0/TP)*(size1_over_tp))));

// states
localparam OP_IDLE                  = 2'd0;
localparam OP_TWIDDLE_LOAD          = 2'd1;
localparam OP_STARTED               = 2'd2;
localparam OP_Q_LOAD                = 2'd3;




reg start_addr_gen;
wire start_addr_gen_shifted, start_addr_gen_shifted_v2, start_addr_gen_shifted_v3;

wire [(depth_log+1)*TP-1:0] read_addr_res;
wire [(depth_log+1)*TP-1:0] write_addr_res;

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
reg [reg_ctr:0] ctr_shifted;

reg        CT00         [(TP>>1)-1:0];
reg        MT00         [(TP>>1)-1:0];
reg [LOGQ-1:0] A00      [(TP>>1)-1:0];
reg [LOGQ-1:0] B00      [(TP>>1)-1:0];
reg [LOGQ-1:0] PSI00    [(TP>>1)-1:0];
reg [LOGQ-1:0] Q00      [(TP>>1)-1:0];
reg [5:0] K100          [(TP>>1)-1:0];
reg [5:0] K200          [(TP>>1)-1:0];
reg [5:0] M00           [(TP>>1)-1:0];
wire[LOGQ-1:0] E00      [(TP>>1)-1:0];
wire[LOGQ-1:0] O00      [(TP>>1)-1:0];
wire[LOGQ-1:0] MUL00    [(TP>>1)-1:0];
wire[LOGQ-1:0] M3200    [(TP>>1)-1:0];
wire[LOGQ-1:0] ADD00    [(TP>>1)-1:0];
wire[LOGQ-1:0] SUB00    [(TP>>1)-1:0];

reg [TP*LOGQ-1:0] NTT_core_in, NTT_core_out_reg;
wire [TP*LOGQ-1:0] NTT_core_out;
reg [LOGQ-1:0] q_core_in;
reg [bram_reg_size*LOGQ-1:0] W_core_in;

wire [TP*LOGQ-1:0] NTT_core_out_shift_d2;

reg [TP*LOGQ-1:0] NTT_core_out_shuffled;
    
    

always @(posedge clk or posedge rst) begin
    if (rst) begin
        start_addr_gen <= 1'b0;
    end else begin
        case (curr_state)
            OP_STARTED: 
                start_addr_gen <= 1'b1; 
            default: begin
                start_addr_gen <= 1'b0;
            end
        endcase
    end
end


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
    if (rst)
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
                        if (twid_ctr >= (1<<depth_log) && twid_ctr < (1+1)<<depth_log) begin
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
endgenerate

generate
    for (genvar k = 0; k < TP; k = k + 1) begin
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                di00[k]       <= 0;
                dr00[k]       <= 0;
                dw00[k]       <= 0;
                de00[k]       <= 0;
            end else begin
                case (curr_state)
                    OP_STARTED: begin
                        if (start_addr_gen_shifted_v2) begin
                            di00[k]       <= NTT_core_out_shuffled[(TP-k)*LOGQ-1-:LOGQ];
                            dr00[k]       <= read_addr_res[(TP-k)*(depth_log+1)-1-:(depth_log+1)];
                            dw00[k]       <= write_addr_res[(TP-k)*(depth_log+1)-1-:(depth_log+1)];
                            de00[k]       <= 1'b1;
                        end
                        else begin
                            di00[k]       <=    0;
                            dr00[k]       <=    0;
                            dw00[k]       <=    0;
                            de00[k]       <=    0;
                        end
                    end
                    default: begin
                        di00[k]       <=    0;
                        dr00[k]       <=    0;
                        dw00[k]       <=    0;
                        de00[k]       <=    0;
                    end
                endcase
            end
        end
    end
endgenerate


generate
    for (genvar i = 0; i < bram_reg_size; i = i + 1) begin
        always @(posedge clk) begin
             W_core_in[(bram_reg_size-i)*LOGQ-1-:LOGQ] <= (OP_STARTED) ? bo0[i] : 0 ;
        end
    end
endgenerate


generate
    for (genvar i = 0; i < TP; i = i + 1) begin
        always @(posedge clk) begin
            NTT_core_in[(TP-i)*LOGQ-1-:LOGQ] <= (OP_STARTED) ? NTT_INPUT[(TP - (((i/n2)*n2 + (i & 1'd1)*(n2/2) + (i & (n2-1))/2)  & (TP-1)))*LOGQ-1-:LOGQ] : 0 ;
        end
    end
endgenerate


generate
    for (genvar rot = 0; rot < TP; rot = rot + 1) begin
        always @(posedge clk) begin
            NTT_core_out_reg[(TP-((rot )&(TP-1)))*LOGQ-1-:LOGQ] <= NTT_core_out[(TP-((rot )&(TP-1)))*LOGQ-1-:LOGQ];
        end
    end
endgenerate


always @(posedge clk) begin
    NTT_core_out_shuffled <= (NTT_core_out_reg >> (((ctr-1)>>size0_over_tp_mult_size1_over_tp_log2)*LOGQ)) | (NTT_core_out_reg << (LOGQ*TP - ((ctr-1)>>size0_over_tp_mult_size1_over_tp_log2)*LOGQ));
end


generate
    if (RW_DIS == 0) begin
        addr_gen_large #(N, n2, size0, size1, TP) large_addr_gen_sm_unit(clk, rst, start_addr_gen_shifted, read_addr_res, write_addr_res);
    end
endgenerate


generate
    if (RW_DIS == 0) begin
        for (genvar c2 = 0; c2 < TP; c2 = c2 + 1) begin: BRAM_GEN_BLOCK_NTT0 // BRAM for NTT
            BRAM #(LOGQ, $rtoi($ceil(2*depth)), $rtoi($ceil($clog2(2*depth)))) bm000(clk,de00[1*c2+0],dw00[1*c2+0],di00[1*c2+0],dr00[1*c2+0],do00[1*c2+0]); // 64 BRAMs * 128 depth (2**7) * 32 bit
        end
    end     

    for (genvar b2 = 0; b2 < bram_reg_size; b2 = b2 + 1) begin: BRAM_GEN_BLOCK_TWIDDLE // BRAM for TWIDDLE
        BRAM #(LOGQ, $rtoi($ceil(N>>log_TP)), $rtoi($ceil($clog2((N>>log_TP))))) bt000(clk,be0[1*b2+0],bw0[1*b2+0],bi0[1*b2+0],br0[1*b2+0],bo0[1*b2+0]); // 64 BRAMs * 128 depth (2**7) * 32 bit
    end
endgenerate


generate
    for (genvar ntt_idx = 0; ntt_idx < (TP>>log_n2); ntt_idx = ntt_idx + 1) begin
        tp_ntt_core #(n2, LOGQ, BTF_LAT) NTT_units_pipelined(clk,rst, q_core_in, NTT_core_in[(TP-n2*ntt_idx)*LOGQ-1-:n2*LOGQ], W_core_in[(bram_reg_size-(n2-1)*ntt_idx)*LOGQ-1-:(n2-1)*LOGQ], NTT_core_out[(TP-n2*ntt_idx)*LOGQ-1-:n2*LOGQ]);
    end
endgenerate


shiftreg #(.SHIFT(log_n2*BTF_LAT+2),.DATA(1)) sre100(clk,rst,start_addr_gen,start_addr_gen_shifted);

shiftreg #(.SHIFT(log_n2*BTF_LAT+4),.DATA(1)) sre102(clk,rst,start_addr_gen,start_addr_gen_shifted_v2);


always @(posedge clk or posedge rst) begin
    if (rst) begin
        ctr_shifted <= 0;
    end else begin
        ctr_shifted <= ctr - (depth+3);
    end
end
    

generate
    for (genvar i = 0; i < TP; i = i + 1) begin
        always @(posedge clk) begin
            if (RW_DIS) begin
                NTT_OUTPUT[(TP-i)*LOGQ-1-:LOGQ] <= NTT_core_out[(TP-i)*LOGQ-1-:LOGQ];
            end
            else begin
                NTT_OUTPUT[(TP-i)*LOGQ-1-:LOGQ] <= do00[(i + (((ctr_shifted>>size1_over_tp_log2)&(depth-1))))&(TP-1)];
            end            
        end
    end
endgenerate


endmodule
