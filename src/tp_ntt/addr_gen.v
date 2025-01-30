module addr_gen
   #(
        parameter  large_addr   = 1  ,  // 0 --> SMALL_ADDRESS_GENERATOR , 1 --> LARGE_ADDRESS_GENERATOR
        parameter  LOGN         = 128,
        parameter  LOGN1        = 2  ,
        parameter  size0        = 16 ,
        parameter  size1        = 16 ,    
        parameter  LOGTP        = 8  
    )
    (
        input                             clk      ,
        input                             rst      ,
        input                             start    ,
        output reg [(log_depth+1)*TP-1:0] read_addr,
        output reg [(log_depth+1)*TP-1:0] write_addr     
    );

localparam N  = 1 << LOGN;
localparam N1 = 1 << LOGN1;
localparam TP = 1 << LOGTP;
localparam depth  = $rtoi($ceil(N/TP));
localparam log_depth  = large_addr ? $rtoi($ceil($clog2(depth))) : log_size0_over_tp;
localparam log_size1  = $rtoi($ceil($clog2(size1)));
localparam size1_over_tp = size1/TP;
localparam size1_over_tp_log2 = $rtoi($ceil($clog2(size1_over_tp)));
localparam size0_over_tp = size0/TP;
localparam log_size0_over_tp = $rtoi($ceil($clog2(size0_over_tp)));
localparam read_lat = (large_addr) ? depth : size0_over_tp;

// states
localparam OP_IDLE          = 1'd0;
localparam OP_STARTED       = 1'd1;


wire [log_depth:0] read_addr_int [0:TP-1];
reg  [log_depth:0] ctr;
wire [log_depth:0] ctr_d;
wire [log_depth:0] ctr_read;
reg  curr_state, next_state;

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
    if (large_addr) begin
        for (genvar i = 0; i < TP; i = i + 1) begin
            assign read_addr_int[i] = ((((size0_over_tp)<<(size1_over_tp_log2))*i + (size0_over_tp)*(ctr_read&(size1_over_tp-1)) + ((ctr_read&(depth-1))>>log_size1)) & (depth-1)) + ((ctr_read<depth)<<log_depth);
        end
    end else begin
        for (genvar i = 0; i < TP; i = i + 1) begin
            assign read_addr_int[i] = (i&(size0_over_tp-1)) + size0_over_tp*(ctr_read<size0_over_tp);
        end
    end
endgenerate


generate
    if (large_addr) begin
        for (genvar i = 0; i < TP; i = i + 1) begin
            always @(posedge clk) begin
                read_addr [((TP-i)*(log_depth+1))-1 -: log_depth+1] <= read_addr_int[((i + TP)- (ctr_read>>(size1_over_tp_log2))) & (TP-1)];
            end
            always @(posedge clk) begin
                write_addr[((TP-i)*(log_depth+1))-1 -: log_depth+1] <= ctr;
            end
        end
    end else begin
        for (genvar i = 0; i < TP; i = i + 1) begin
            always @(posedge clk) begin
                read_addr [((TP-i)*(log_size0_over_tp+1))-1 -: log_size0_over_tp+1] <= read_addr_int[((i + TP) - (ctr_read&((size0_over_tp)-1))) & (TP-1)];
            end
            always @(posedge clk) begin
                write_addr[((TP-i)*(log_size0_over_tp+1))-1 -: log_size0_over_tp+1] <= ctr;
            end
        end
    end
    
endgenerate



endmodule