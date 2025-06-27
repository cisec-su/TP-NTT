module shuffle_addr_gen
   #(
        parameter  LOGN         = 128,
        parameter  LOGN1        = 2  ,
        parameter  LOGN2        = 2  ,
        parameter  LOGTP        = 8  
    )
    (
        input                             clk      ,
        input                             rst      ,
        input                             start    ,
        input                             mod_op   ,
        output reg [(LOG_DEPTH)*TP-1:0] read_addr,
        output reg [(LOG_DEPTH)*TP-1:0] write_addr     
    );

localparam N                = 1 << LOGN;
localparam N1               = 1 << LOGN1;
localparam N2               = 1 << LOGN2;
localparam TP               = 1 << LOGTP;
localparam DEPTH            = N/TP;
localparam LOG_DEPTH        = $clog2(DEPTH)+1;
localparam READ_LAT         = DEPTH ;

// states
localparam OP_IDLE          = 1'd0;
localparam OP_STARTED       = 1'd1;


wire [LOG_DEPTH-1:0] read_addr_int [0:TP-1];
reg  [LOG_DEPTH-1:0] ctr;
wire [LOG_DEPTH-1:0] ctr_d;
wire [LOG_DEPTH-1:0] ctr_read;
reg  curr_state, next_state;

localparam REG_CTR = LOGN-LOGTP;

localparam MAGIC_NUM = LOGN2 - 1;

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
        next_state = OP_STARTED;
    end else begin
        next_state = OP_IDLE;
    end
end


always @(posedge clk or posedge rst) begin
    if (rst) begin
        ctr <= 0;
    end else begin
        case (curr_state)
            OP_STARTED: begin
                ctr <= ctr + 1;
            end 
            default: begin
                ctr <= 0;
            end
        endcase
        
    end
end


shiftreg #(
    .SHIFT (READ_LAT  ),
    .DATA  (LOG_DEPTH )
) srctr (
    .clk      (clk   ),
    .reset    (rst   ),
    .data_in  (ctr   ),
    .data_out (ctr_d )
);

assign ctr_read = ctr_d + READ_LAT;

for (genvar i = 0; i < TP; i = i + 1) begin
    assign read_addr_int[i] = mod_op ? (((((ctr_read & (DEPTH-1)) & 1'd1)         << ((REG_CTR >= 1)  * ((0 >  MAGIC_NUM) * (REG_CTR - (0 - MAGIC_NUM))  + (0 <= MAGIC_NUM) * (MAGIC_NUM - 0)))) +
                                        ((((ctr_read & (DEPTH-1)) & 2'd3)  >> 1) << ((REG_CTR >= 2)  * ((1 >  MAGIC_NUM) * (REG_CTR - (1 - MAGIC_NUM))  + (1 <= MAGIC_NUM) * (MAGIC_NUM - 1)))) +
                                        ((((ctr_read & (DEPTH-1)) & 3'd7)  >> 2) << ((REG_CTR >= 3)  * ((2 >  MAGIC_NUM) * (REG_CTR - (2 - MAGIC_NUM))  + (2 <= MAGIC_NUM) * (MAGIC_NUM - 2)))) +
                                        ((((ctr_read & (DEPTH-1)) & 4'd15) >> 3) << ((REG_CTR >= 4)  * ((3 >  MAGIC_NUM) * (REG_CTR - (3 - MAGIC_NUM))  + (3 <= MAGIC_NUM) * (MAGIC_NUM - 3)))) +
                                        ((((ctr_read & (DEPTH-1)) & 5'd31) >> 4) << ((REG_CTR >= 5)  * ((4 >  MAGIC_NUM) * (REG_CTR - (4 - MAGIC_NUM))  + (4 <= MAGIC_NUM) * (MAGIC_NUM - 4)))) +
                                        ((((ctr_read & (DEPTH-1)) & 6'd63) >> 5) << ((REG_CTR >= 6)  * ((5 >  MAGIC_NUM) * (REG_CTR - (5 - MAGIC_NUM))  + (5 <= MAGIC_NUM) * (MAGIC_NUM - 5)))) +
                                        ((((ctr_read & (DEPTH-1)) & 7'd127)>> 6) << ((REG_CTR >= 7)  * ((6 >  MAGIC_NUM) * (REG_CTR - (6 - MAGIC_NUM))  + (6 <= MAGIC_NUM) * (MAGIC_NUM - 6)))) +
                                        ((((ctr_read & (DEPTH-1)) & 8'd255)>> 7) << ((REG_CTR >= 8)  * ((7 >  MAGIC_NUM) * (REG_CTR - (7 - MAGIC_NUM))  + (7 <= MAGIC_NUM) * (MAGIC_NUM - 7)))) +
                                        ((((ctr_read & (DEPTH-1)) & 9'd511)>> 8) << ((REG_CTR >= 9)  * ((8 >  MAGIC_NUM) * (REG_CTR - (8 - MAGIC_NUM))  + (8 <= MAGIC_NUM) * (MAGIC_NUM - 8)))) +
                                        ((((ctr_read & (DEPTH-1)) & 10'd1023)>>9)<< ((REG_CTR >= 10) * ((9 >  MAGIC_NUM) * (REG_CTR - (9 - MAGIC_NUM))  + (9 <= MAGIC_NUM) * (MAGIC_NUM - 9)))) +
                                        ((((ctr_read & (DEPTH-1)) & 11'd2047)>>10)<< ((REG_CTR >= 11) * ((10 > MAGIC_NUM) * (REG_CTR - (10 - MAGIC_NUM)) + (10 <= MAGIC_NUM) * (MAGIC_NUM - 10)))) +
                                        ((((ctr_read & (DEPTH-1)) & 12'd4095)>>11)<< ((REG_CTR >= 12) * ((11 > MAGIC_NUM) * (REG_CTR - (11 - MAGIC_NUM)) + (11 <= MAGIC_NUM) * (MAGIC_NUM - 11))))) & (DEPTH-1)) + (ctr_read<DEPTH)*DEPTH : ((((ctr_read & 2'd3) + ((i-((ctr_read&(DEPTH-1))>>2))<<2))) & (DEPTH-1)) + (ctr_read<DEPTH)*DEPTH;
end




for (genvar i = 0; i < TP; i = i + 1) begin
    always @(posedge clk) begin
        read_addr [((TP-i)*(LOG_DEPTH))-1 -: LOG_DEPTH] <= read_addr_int[((i)) & (TP-1)];
    end
    always @(posedge clk) begin
        write_addr[((TP-i)*(LOG_DEPTH))-1 -: LOG_DEPTH] <= ctr;
    end
end




endmodule