module shuffle_post_process #(
        parameter LOGN          = 16,
        parameter LOGN1         = 6,
        parameter LOGN2         = 4,
        parameter LOGTP         = 6,
        parameter TP            = 1<<LOGTP,
        parameter LOGQ          = 60,
        parameter AU_ID         = 4
) (
        input                           clk,
        input                           rst,
        input                           start,
        input                           mod_op,
        input   [TP*LOGQ-1:0]           input_data,
        output reg [TP*LOGQ-1:0]        output_data
);


// states
localparam OP_IDLE                  = 2'd0;
localparam OP_SHUFFLE               = 2'd1;

localparam reg_ctr = $rtoi($ceil(LOGN-LOGTP));
localparam depth = 1<<reg_ctr;

localparam magic_num = LOGN2 - 1;
localparam N1 = 1<<LOGN1;

reg [1:0] OP_TYPE;

reg [1:0] curr_state, next_state;

reg [LOGQ-1:0]                  di00     [1*(TP)-1:0];
wire[LOGQ-1:0]                  do00     [1*(TP)-1:0];
reg [(reg_ctr+1)-1:0]           dw00     [1*(TP)-1:0];
reg [(reg_ctr+1)-1:0]           dr00     [1*(TP)-1:0];
reg                             de00     [1*(TP)-1:0];


reg [reg_ctr+1:0] ctr, ctr_d1, ctr_d2, ctr_d3;

reg [TP*LOGQ-1:0] NTT_core_in;
wire [TP*LOGQ-1:0] NTT_core_out;

wire [TP*LOGQ-1:0] NTT_core_out_shift_d2;



always @(posedge clk or posedge rst) begin
    if (rst) begin
        ctr <= 0;
        ctr_d1 <= 0;
        ctr_d2 <= 0;
        ctr_d3 <= 0;
    end else begin
        case (curr_state)
            OP_SHUFFLE: begin
                ctr <= ctr + 1;
                ctr_d1 <= ctr;
                ctr_d2 <= ctr_d1;
                ctr_d3 <= ctr_d2;
            end
            default: begin
                ctr <= 0;
                ctr_d1 <=0;
                ctr_d2 <= 0;
                ctr_d3 <= 0;
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


always @(*) begin
    next_state = curr_state;
    if (start) begin
        next_state = OP_SHUFFLE;
    end
    else if ((ctr[reg_ctr+1:0]) == (depth*2)) begin
        next_state = OP_IDLE;
    end
end

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
                    OP_SHUFFLE: begin
                        di00[k]       <= mod_op ? input_data[(TP-k)*LOGQ-1-:LOGQ] : input_data[(TP-((k-(ctr>>2))&(5'd31)))*LOGQ-1-:LOGQ];
                        dr00[k]       <= mod_op ? (((((ctr & (depth-1)) & 1'd1)         << ((reg_ctr >= 1)  * ((0 >  magic_num) * (reg_ctr - (0 - magic_num))  + (0 <= magic_num) * (magic_num - 0)))) +
((((ctr & (depth-1)) & 2'd3)  >> 1) << ((reg_ctr >= 2)  * ((1 >  magic_num) * (reg_ctr - (1 - magic_num))  + (1 <= magic_num) * (magic_num - 1)))) +
((((ctr & (depth-1)) & 3'd7)  >> 2) << ((reg_ctr >= 3)  * ((2 >  magic_num) * (reg_ctr - (2 - magic_num))  + (2 <= magic_num) * (magic_num - 2)))) +
((((ctr & (depth-1)) & 4'd15) >> 3) << ((reg_ctr >= 4)  * ((3 >  magic_num) * (reg_ctr - (3 - magic_num))  + (3 <= magic_num) * (magic_num - 3)))) +
((((ctr & (depth-1)) & 5'd31) >> 4) << ((reg_ctr >= 5)  * ((4 >  magic_num) * (reg_ctr - (4 - magic_num))  + (4 <= magic_num) * (magic_num - 4)))) +
((((ctr & (depth-1)) & 6'd63) >> 5) << ((reg_ctr >= 6)  * ((5 >  magic_num) * (reg_ctr - (5 - magic_num))  + (5 <= magic_num) * (magic_num - 5)))) +
((((ctr & (depth-1)) & 7'd127)>> 6) << ((reg_ctr >= 7)  * ((6 >  magic_num) * (reg_ctr - (6 - magic_num))  + (6 <= magic_num) * (magic_num - 6)))) +
((((ctr & (depth-1)) & 8'd255)>> 7) << ((reg_ctr >= 8)  * ((7 >  magic_num) * (reg_ctr - (7 - magic_num))  + (7 <= magic_num) * (magic_num - 7)))) +
((((ctr & (depth-1)) & 9'd511)>> 8) << ((reg_ctr >= 9)  * ((8 >  magic_num) * (reg_ctr - (8 - magic_num))  + (8 <= magic_num) * (magic_num - 8)))) +
((((ctr & (depth-1)) & 10'd1023)>>9)<< ((reg_ctr >= 10) * ((9 >  magic_num) * (reg_ctr - (9 - magic_num))  + (9 <= magic_num) * (magic_num - 9)))) +
((((ctr & (depth-1)) & 11'd2047)>>10)<< ((reg_ctr >= 11) * ((10 > magic_num) * (reg_ctr - (10 - magic_num)) + (10 <= magic_num) * (magic_num - 10)))) +
((((ctr & (depth-1)) & 12'd4095)>>11)<< ((reg_ctr >= 12) * ((11 > magic_num) * (reg_ctr - (11 - magic_num)) + (11 <= magic_num) * (magic_num - 11))))) & (depth-1)) + (ctr<depth)*depth : (((ctr & 2'd3) + ((k-((ctr&(depth-1))>>2))<<2))) & (depth-1) + (ctr<depth)*depth;
                        dw00[k]       <= ctr;
                        de00[k]       <= 1'b1;                        
            
                    end
                    default: begin
                        di00[k]       <= 0;
                        dr00[k]       <= 0;
                        dw00[k]       <= 0;
                        de00[k]       <= 0;
                    end
                endcase   
            end
        end
    end
endgenerate




generate  
    for (genvar b2 = 0; b2 < TP; b2 = b2 + 1) begin: BRAM_GEN_BLOCK_NTT // BRAM for TWIDDLE 
        BRAM #(LOGQ, depth<<1, reg_ctr+1) data00(clk,de00[1*b2+0],dw00[1*b2+0],di00[1*b2+0],dr00[1*b2+0],do00[1*b2+0]);
    end
endgenerate

// Output Rotaion for Next Block
generate
    
    for (genvar i = 0; i < TP; i = i + 1) begin
        always @(posedge clk) begin
            output_data[(TP-i)*LOGQ-1 -: LOGQ] <=  mod_op ? (ctr_d2 >= depth || ctr_d3 >= depth) ? do00[(i & 1'd1) * (N1 >> 1) +
                                                        ((i & 2'd3) >> 1) * (N1 >> 2) +
                                                        ((i & 3'd7) >> 2) * (N1 >> 3) +
                                                        ((i & 4'd15) >> 3) * (N1 >> 4) +
                                                        ((i & 5'd31) >> 4) * (N1 >> 5) +
                                                        ((i & 6'd63) >> 5) * (N1 >> 6) +
                                                        ((i & 7'd127) >> 6) * (N1 >> 7)
            ] : 0 
            : (ctr_d2 >= depth || ctr_d3 >= depth) ?  do00[
                (i + (ctr_d2>>2)) & (TP-1) 
            ] : 0;
        end
    end
endgenerate

    
endmodule