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
        output reg [(log_depth+1)*TP-1:0] read_addr,
        output reg [(log_depth+1)*TP-1:0] write_addr     
    );

localparam N  = 1 << LOGN;
localparam N1 = 1 << LOGN1;
localparam N2 = 1 << LOGN2;
localparam TP = 1 << LOGTP;
localparam depth  = $rtoi($ceil(N/TP));
localparam log_depth  = $rtoi($ceil($clog2(depth)));
localparam read_lat = depth ;

// states
localparam OP_IDLE          = 1'd0;
localparam OP_STARTED       = 1'd1;


wire [log_depth:0] read_addr_int [0:TP-1];
reg  [log_depth:0] ctr;
wire [log_depth:0] ctr_d;
wire [log_depth:0] ctr_read;
reg  curr_state, next_state;

localparam reg_ctr = $rtoi($ceil(LOGN-LOGTP));

localparam magic_num = LOGN2 - 1;

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


shiftreg #(.SHIFT(read_lat),.DATA(log_depth+1)) srctr(clk,rst,ctr,ctr_d);

assign ctr_read = ctr_d + read_lat;


generate
        for (genvar i = 0; i < TP; i = i + 1) begin
            assign read_addr_int[i] = mod_op ? (((((ctr_read & (depth-1)) & 1'd1)         << ((reg_ctr >= 1)  * ((0 >  magic_num) * (reg_ctr - (0 - magic_num))  + (0 <= magic_num) * (magic_num - 0)))) +
((((ctr_read & (depth-1)) & 2'd3)  >> 1) << ((reg_ctr >= 2)  * ((1 >  magic_num) * (reg_ctr - (1 - magic_num))  + (1 <= magic_num) * (magic_num - 1)))) +
((((ctr_read & (depth-1)) & 3'd7)  >> 2) << ((reg_ctr >= 3)  * ((2 >  magic_num) * (reg_ctr - (2 - magic_num))  + (2 <= magic_num) * (magic_num - 2)))) +
((((ctr_read & (depth-1)) & 4'd15) >> 3) << ((reg_ctr >= 4)  * ((3 >  magic_num) * (reg_ctr - (3 - magic_num))  + (3 <= magic_num) * (magic_num - 3)))) +
((((ctr_read & (depth-1)) & 5'd31) >> 4) << ((reg_ctr >= 5)  * ((4 >  magic_num) * (reg_ctr - (4 - magic_num))  + (4 <= magic_num) * (magic_num - 4)))) +
((((ctr_read & (depth-1)) & 6'd63) >> 5) << ((reg_ctr >= 6)  * ((5 >  magic_num) * (reg_ctr - (5 - magic_num))  + (5 <= magic_num) * (magic_num - 5)))) +
((((ctr_read & (depth-1)) & 7'd127)>> 6) << ((reg_ctr >= 7)  * ((6 >  magic_num) * (reg_ctr - (6 - magic_num))  + (6 <= magic_num) * (magic_num - 6)))) +
((((ctr_read & (depth-1)) & 8'd255)>> 7) << ((reg_ctr >= 8)  * ((7 >  magic_num) * (reg_ctr - (7 - magic_num))  + (7 <= magic_num) * (magic_num - 7)))) +
((((ctr_read & (depth-1)) & 9'd511)>> 8) << ((reg_ctr >= 9)  * ((8 >  magic_num) * (reg_ctr - (8 - magic_num))  + (8 <= magic_num) * (magic_num - 8)))) +
((((ctr_read & (depth-1)) & 10'd1023)>>9)<< ((reg_ctr >= 10) * ((9 >  magic_num) * (reg_ctr - (9 - magic_num))  + (9 <= magic_num) * (magic_num - 9)))) +
((((ctr_read & (depth-1)) & 11'd2047)>>10)<< ((reg_ctr >= 11) * ((10 > magic_num) * (reg_ctr - (10 - magic_num)) + (10 <= magic_num) * (magic_num - 10)))) +
((((ctr_read & (depth-1)) & 12'd4095)>>11)<< ((reg_ctr >= 12) * ((11 > magic_num) * (reg_ctr - (11 - magic_num)) + (11 <= magic_num) * (magic_num - 11))))) & (depth-1)) + (ctr_read<depth)*depth : ((((ctr_read & 2'd3) + ((i-((ctr_read&(depth-1))>>2))<<2))) & (depth-1)) + (ctr_read<depth)*depth;;
        end
endgenerate


generate
        for (genvar i = 0; i < TP; i = i + 1) begin
            always @(posedge clk) begin
                read_addr [((TP-i)*(log_depth+1))-1 -: log_depth+1] <= read_addr_int[((i)) & (TP-1)];
            end
            always @(posedge clk) begin
                write_addr[((TP-i)*(log_depth+1))-1 -: log_depth+1] <= ctr;
            end
        end
    
endgenerate



endmodule