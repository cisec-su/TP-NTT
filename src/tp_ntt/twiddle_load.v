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
        parameter MORE_DSP      = 0
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
localparam TP                       = 1 << LOGTP;
localparam LOGN4                    = LOGN - LOGN1 - LOGN2 - LOGN3;
localparam SIZE0                    = N1 * N2;
localparam SIZE1                    = N / (SIZE0);
localparam DEPTH                    = N/TP ;
localparam DEPTH_LARGE              = N/TP;
localparam SIZE1_OVER_TP            = SIZE1/TP;
localparam SIZE0_OVER_TP            = SIZE0/TP;
localparam LOG_SIZE0_OVER_TP        = $clog2((SIZE0)/TP);
localparam BRAM_SIZE                = 2*DEPTH;
localparam BRAM_LOG_SIZE            = $clog2(2*DEPTH);
localparam LOG_DEPTH                = $clog2(DEPTH) + 1;
localparam LOG_DEPTH_LARGE          = $clog2(DEPTH_LARGE) + 1;
localparam DIM_NUM                  = (LOGN4 != 0) ? 4 : ((LOGN3 != 0) ? 3 : 2);
localparam LAST_PARTITION_SIZE      = DIM_NUM == 4 ? (1 << LOGN4) - 1 :  DIM_NUM == 3 ? (1 << LOGN3) - 1 : DIM_NUM == 2 ? (1 << LOGN2) - 1 : 0;
localparam TWID_FACTOR_N2           = (TP>>LOGN2) * ((1<<LOGN2)-1);
localparam NEEDED_TWIDDLE           = DIM_NUM == 4 ? (N-1) - (1+((1<<(LOGTP-LOGN2))*(N2-1))+((DEPTH_LARGE/N3)*(TP-1))+((DEPTH_LARGE-1-(1<<(LOGTP-LOGN2))-(DEPTH_LARGE/N3))*(N4-1))) : DIM_NUM == 3 ? (1<<LOGN) - 1 - (TP-1)*(DEPTH_LARGE-N2) - (N2 * TWID_FACTOR_N2) : DIM_NUM == 2 ? N - 1 - (TP-1)*DEPTH_LARGE : 0;


// states
localparam OP_IDLE                      = 1'd0;
localparam OP_TWIDDLE_LOAD              = 1'd1;

reg  [LOG_DEPTH:0] ctr, ctr_read;
wire [LOG_DEPTH:0] ctr_read_d1, ctr_read_d2, ctr_read_d3; 
reg  curr_state, next_state;

reg [1:0]              op_d;

reg start_addr_gen;

reg [LOGQ-1:0]                  bi00     [(TP-1)-1:0];
wire[LOGQ-1:0]                  bo00     [(TP-1)-1:0];
reg [LOG_DEPTH:0]               bw00     [(TP-1)-1:0];
reg [LOG_DEPTH:0]               br00     [(TP-1)-1:0];
reg                             be00     [(TP-1)-1:0];


reg [NEEDED_TWIDDLE*LOGQ-1:0] fifo_reg;

reg [(TP-1)*LOGQ-1:0] twiddle_in_read;

reg [(TP-1)*LOGQ-1:0] twiddle_in_true;

wire [(TP-1)*LOGQ-1:0] psi_d;

wire [1:0] op_in_ntt;

shiftreg #(
    .SHIFT (1),
    .DATA  (LOG_DEPTH+1)
) sre_ctr_read (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (ctr_read   ),
    .data_out (ctr_read_d1)
);

shiftreg #(
    .SHIFT (1),
    .DATA  (LOG_DEPTH+1)
) sre_ctr_read_d2 (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (ctr_read_d1   ),
    .data_out (ctr_read_d2)
);

shiftreg #(
    .SHIFT (2),
    .DATA  (LOG_DEPTH+1)
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
    else if (ctr_read_d1 == DEPTH_LARGE*DIM_NUM-1) begin
        next_state = OP_IDLE;
    end
end


always @(posedge clk or posedge rst) begin
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

always @(posedge clk or posedge rst) begin
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



always @(posedge clk or posedge rst) begin
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

for (genvar i = 0; i < TP; i = i + 1) begin: FIFO_LOOP // BRAM for NTT
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fifo_reg <= 0;
        end else begin
            case (curr_state)
                OP_TWIDDLE_LOAD: begin
                    if (DIM_NUM == 4) begin
                        if (intt == 0) begin
                            if (ctr == 0) begin
                                fifo_reg[LOGQ*(1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            end
                            else if (ctr >= 1 && ctr < 1 + (1<<LOGN2)) begin
                                if (i >= TWID_FACTOR_N2) begin // take first (ctr-1)*4+1 (1-5-9-13)  elements from fifo 
                                    fifo_reg[LOGQ*((i-(TWID_FACTOR_N2-1))+(ctr-1)*(TP-TWID_FACTOR_N2)+1)-1-:LOGQ] <= psi[LOGQ*((TP-i))-1-:LOGQ];
                                end
                            end
                            else if (ctr >= (1 + (1<<LOGN2)) && ctr < (1 + (1<<LOGN2) + (1<<(LOGN-LOGN3)))) begin
                                fifo_reg[LOGQ*((ctr-(1 + (1<<LOGN2)) + (1 + (TP-TWID_FACTOR_N2)*(1<<LOGN2))) + 1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            end
                            else begin
                                fifo_reg[LOGQ*((ctr-(1 + (1<<LOGN2) + (1<<(LOGN-LOGN3))) + (1 + (TP-TWID_FACTOR_N2)*(1<<LOGN2) + (1)*(1<<(LOGN-LOGN3)))) + 1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            end
                        end else begin
                            if (ctr < DEPTH) begin
                                fifo_reg[LOGQ*(ctr+1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            end
                            // else if (ctr >= DEPTH && ctr < DEPTH + (DEPTH/N2)) begin
                            //     if (i >= TWID_FACTOR_N2) begin // take first (ctr-1)*4+1 (1-5-9-13)  elements from fifo 
                            //         fifo_reg[LOGQ*((i-(TWID_FACTOR_N2-1))+(ctr-DEPTH)*(TP-TWID_FACTOR_N2)+1)-1-:LOGQ] <= psi[LOGQ*((TP-i))-1-:LOGQ];
                            //     end
                            // end
                            // else begin
                            //     fifo_reg[LOGQ*(((ctr-(DEPTH + (DEPTH/N2))) + (1 + ((TP-TWID_FACTOR_N2)*(DEPTH/N2)))) + 1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            // end
                        end 
                    end else if (DIM_NUM == 3) begin
                        if (intt == 0) begin
                            if (ctr == 0) begin
                                fifo_reg[LOGQ*(1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            end
                            else if (ctr >= 1 && ctr < 1 + (1<<LOGN2)) begin
                                if (i >= TWID_FACTOR_N2) begin // take first (ctr-1)*4+1 (1-5-9-13)  elements from fifo 
                                    fifo_reg[LOGQ*((i-(TWID_FACTOR_N2-1))+(ctr-1)*(TP-TWID_FACTOR_N2)+1)-1-:LOGQ] <= psi[LOGQ*((TP-i))-1-:LOGQ];
                                end
                            end
                            else begin
                                fifo_reg[LOGQ*((ctr-(1 + (1<<LOGN2)) + (1 + (TP-TWID_FACTOR_N2)*(1<<LOGN2))) + 1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            end
                        end else begin
                            if (ctr < DEPTH_LARGE) begin
                                fifo_reg[LOGQ*(ctr+1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            end
                            else if (ctr >= DEPTH_LARGE && ctr < DEPTH_LARGE + (1<<LOGN2)) begin
                                if (i >= TWID_FACTOR_N2) begin // take first (ctr-1)*4+1 (1-5-9-13)  elements from fifo 
                                    fifo_reg[LOGQ*((i-(TWID_FACTOR_N2-1))+(ctr-DEPTH_LARGE)*(TP-TWID_FACTOR_N2)+1)-1-:LOGQ] <= psi[LOGQ*((TP-i))-1-:LOGQ];
                                end
                            end
                            else begin
                                fifo_reg[LOGQ*((ctr-(DEPTH_LARGE + (1<<LOGN2)) + (DEPTH_LARGE + (TP-TWID_FACTOR_N2)*(1<<LOGN2))) + 1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            end
                        end 
                    end else if (DIM_NUM == 2) begin
                        if (intt == 1'b0) begin
                            if (ctr == 0) begin
                                fifo_reg[LOGQ*(1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            end
                            else begin
                                fifo_reg[LOGQ*((ctr-(1) + (1)) + 1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            end
                        end else begin
                             if (ctr < DEPTH) begin
                                fifo_reg[LOGQ*(ctr+1)-1-:LOGQ] <= psi[LOGQ*(1)-1-:LOGQ];
                            end
                        end
                       
                    end else if (DIM_NUM == 4) begin
                        
                    end
                end 
                default: begin
                    fifo_reg <= 0;
                end
            endcase
        end
    end
end


for (genvar i = 0; i < TP-1; i = i + 1) begin: BRAM_TWIDDLE_LOAD_2 // BRAM for NTT
    always @(posedge clk or posedge rst) begin
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
                            end else if (ctr >= 1 && ctr < 1 + (1<<LOGN2)) begin
                                if (i < TWID_FACTOR_N2) begin
                                    bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                                end
                                else begin 
                                    bi00[i] <= 0;
                                end
                            end
                            else if ( ctr >= 1 + (1<<LOGN2) && ctr < 1 + (1<<LOGN2) + (((1<<(LOGN-LOGTP))-1)>>LOGN3)) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end
                            else begin
                                if (ctr < DEPTH_LARGE) begin  
                                    bi00[i] <=  psi[(TP-i)*LOGQ-1-:LOGQ];
                                end else begin
                                    bi00[i] <= fifo_reg[((LAST_PARTITION_SIZE)*(ctr-DEPTH_LARGE) + i + 1)*LOGQ-1-:LOGQ];
                                end
                            end
                            br00[i] <= ctr_read_d1 < (DEPTH_LARGE) ? 1'd0 : ctr_read_d1 < (DEPTH_LARGE * 2) ? (ctr_read_d1 & ((1<<LOGN2)-1)) + 1 : ctr_read_d1 < (DEPTH_LARGE*3) ? ((ctr_read_d1 & ((1<<(LOGN-LOGTP))-1))>>LOGN3) + (1<<LOGN2) + 1 : (ctr_read_d1 & ((1<<(LOGN-LOGTP))-1)) + (DEPTH/N3) +  (1<<LOGN2) + 1;
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < (1 + (1<<LOGN2) + (DEPTH/N3) + (1<<(LOGN-LOGTP)))) ? 1'b1 : 1'b0;
                        end else begin
                            if (ctr < DEPTH) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end else if (ctr >= DEPTH && ctr < DEPTH + (DEPTH/TP) ) begin
                                if (i < TWID_FACTOR_N2) begin
                                    bi00[i] <= fifo_reg[((TWID_FACTOR_N2)*(ctr-DEPTH_LARGE) + i + 1)*LOGQ-1-:LOGQ];
                                end
                                else begin 
                                    bi00[i] <= 0;
                                end
                            end
                            else if (ctr >= DEPTH + (DEPTH/TP) && ctr < DEPTH + (DEPTH/TP + (1<<LOGN3)) + 1) begin
                                bi00[i] <= fifo_reg[(TWID_FACTOR_N2 * DEPTH/TP + (ctr - (DEPTH + DEPTH/TP))*(N3-1) + i + 1)*LOGQ-1-:LOGQ];
                            end
                            else begin
                                //bi00[i] <= fifo_reg[(TWID_FACTOR_N2 * DEPTH/TP + (DEPTH/TP)*(N3-1) + i + 1)*LOGQ-1-:LOGQ];
                            end
                            br00[i] <= ctr_read_d1 < (DEPTH_LARGE) ? ctr_read_d1 : ctr_read_d1 < (DEPTH_LARGE * 2) ? ((ctr_read_d1 & (DEPTH - 1)) >> LOGTP) + DEPTH_LARGE : ctr_read_d1 < (DEPTH_LARGE * 3) ?  DEPTH_LARGE + (DEPTH_LARGE>>LOGTP) + ((ctr_read_d1 & (DEPTH - 1)) & ((1<<LOGN3)-1)) : DEPTH_LARGE + (DEPTH_LARGE>>LOGTP) + (1<<LOGN3);
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < DEPTH + DEPTH/TP + (1<<LOGN3) + 1) ? 1'b1 : 1'b0;
                        end
                    end
                    else if (DIM_NUM == 3) begin
                        if (intt == 0) begin
                            if (ctr == 0) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end else if (ctr >= 1 && ctr < 1 + (1<<LOGN2)) begin
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
                                    bi00[i] <= fifo_reg[((LAST_PARTITION_SIZE)*(ctr-DEPTH_LARGE) + i + 1)*LOGQ-1-:LOGQ];
                                end
                            end
                            br00[i] <= ctr_read_d1 < (DEPTH_LARGE) ? 1'd0 : ctr_read_d1 < (DEPTH_LARGE * 2) ? (ctr_read_d1 & ((1<<LOGN2)-1)) + 1 : (ctr_read_d1 & ((1<<(LOGN-LOGTP))-1)) + (1<<LOGN2) + 1;
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < (1 + (1<<LOGN2) + (1<<(LOGN-LOGTP)))) ? 1'b1 : 1'b0;
                        end else begin
                            if (ctr < DEPTH) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end else if (ctr >= DEPTH && ctr < DEPTH + (1<<LOGN2)) begin
                                if (i < TWID_FACTOR_N2) begin
                                    bi00[i] <= fifo_reg[((TWID_FACTOR_N2)*(ctr-DEPTH_LARGE) + i + 1)*LOGQ-1-:LOGQ];
                                end
                                else begin 
                                    bi00[i] <= 0;
                                end
                            end else begin
                                    bi00[i] <= fifo_reg[(TWID_FACTOR_N2 * N2 + i + 1)*LOGQ-1-:LOGQ];
                                end
                            br00[i] <= ctr_read_d1 < (DEPTH_LARGE) ? ctr_read_d1 : ctr_read_d1 < (DEPTH_LARGE * 2) ? ((ctr_read_d1 & (DEPTH - 1)) >> LOGTP) + DEPTH_LARGE : DEPTH_LARGE + (1<<LOGN2);
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < (1 + (1<<LOGN2) + (1<<(LOGN-LOGTP)))) ? 1'b1 : 1'b0;
                        end
                    end else if (DIM_NUM == 2) begin
                        if (intt == 1'b0) begin
                            if (ctr == 0) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end else begin
                                if (ctr < DEPTH_LARGE) begin  
                                    bi00[i] <=  psi[(TP-i)*LOGQ-1-:LOGQ];
                                end else begin
                                    bi00[i] <= fifo_reg[((LAST_PARTITION_SIZE)*(ctr-DEPTH_LARGE) + i + 1)*LOGQ-1-:LOGQ];
                                end
                            end
                            br00[i] <= ctr_read_d1 < (DEPTH_LARGE) ? 1'd0 : (ctr_read_d1 & ((1<<(LOGN-LOGTP))-1)) + 1;
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < (1 + (1<<(LOGN-LOGTP)))) ? 1'b1 : 1'b0;
                        end else begin
                            if (ctr < DEPTH) begin
                                bi00[i] <= psi[(TP-i)*LOGQ-1-:LOGQ];
                            end else begin
                                bi00[i] <= fifo_reg[((LAST_PARTITION_SIZE)*(ctr-DEPTH_LARGE) + i + 1)*LOGQ-1-:LOGQ];
                            end
                            br00[i] <= ctr_read_d1 < (DEPTH_LARGE) ? ctr_read_d1 : DEPTH;
                            bw00[i] <= ctr;
                            be00[i] <= (ctr < (1 + (1<<(LOGN-LOGTP)))) ? 1'b1 : 1'b0;
                        end
                        
                    end else if (DIM_NUM == 4) begin
                        
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


for (genvar loop_id = 0; loop_id < TP-1; loop_id = loop_id + 1) begin
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= 0; 
        end else begin
            if (intt == 1'b0) begin
                twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= bo00[loop_id];
            end else begin
                if (DIM_NUM == 3) begin
                    if (ctr_read_d2 >= DEPTH && ctr_read_d2 < DEPTH * 2) begin
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


for (genvar loop_id = 0; loop_id < TP-1; loop_id = loop_id + 1) begin
     always @(*) begin
        if (rst) begin
            twiddle_in_true[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= 0; 
        end else begin
            if (intt == 1'b0) begin
                twiddle_in_true[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ];
            end else begin
                if (DIM_NUM == 3) begin
                    if (ctr_read_d3 >= DEPTH && ctr_read_d3 < DEPTH * 2) begin
                        if (loop_id < TP/N2) begin
                            twiddle_in_true[(TP-1-((N2-1)*loop_id))*LOGQ-1-:(N2-1)*LOGQ] <= twiddle_in_read[(TP-1-((N2-1)*(((ctr_read_d3 & (DEPTH-1))>>LOGN2) & (TP/N2-1))))*LOGQ-1-:((N2-1)*LOGQ)];
                        end
                        
                        
                    end
                    else begin
                        twiddle_in_true[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ];
                    end
                end else if (DIM_NUM == 2) begin
                    twiddle_in_true[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ];
                end else if (DIM_NUM == 4) begin
                    //twiddle_in_true[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ];
                    if (ctr_read_d3 >= DEPTH && ctr_read_d3 < DEPTH * 2) begin
                        if (loop_id < TP/N2) begin
                            twiddle_in_true[(TP-1-((N2-1)*loop_id))*LOGQ-1-:(N2-1)*LOGQ] <= twiddle_in_read[(TP-1-((N2-1)*(((ctr_read_d3 & (DEPTH-1))>>LOGN2) & (TP/N2-1))))*LOGQ-1-:((N2-1)*LOGQ)];
                        end
                        
                    end
                    else begin
                        twiddle_in_true[(TP-1-loop_id)*LOGQ-1-:LOGQ] <= twiddle_in_read[(TP-1-loop_id)*LOGQ-1-:LOGQ];
                    end
                end
                
            end
             
        end
        
    end


end




assign psi_out        = twiddle_in_true;
    
endmodule