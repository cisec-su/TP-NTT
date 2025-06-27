module automorphism_addr_gen
   #(
        parameter  LARGE = 1  ,  // 0 --> SMALL_ADDRESS_GENERATOR , 1 --> LARGE_ADDRESS_GENERATOR
        parameter  LOGN  = 128,
        parameter  LOGN1 = 2  ,
        parameter  size0 = 16 ,
        parameter  size1 = 16 ,    
        parameter  LOGTP = 8  
    )
    (
        input                             clk      ,
        input                             rst      ,
        input                             start    ,
        output reg [(LOG_DEPTH)*TP-1:0] read_addr,
        output reg [(LOG_DEPTH)*TP-1:0] write_addr     
    );

localparam N                        = 1 << LOGN;
localparam N1                       = 1 << LOGN1;
localparam TP                       = 1 << LOGTP;
localparam DEPTH                    = N/TP;
localparam LOG_DEPTH                = LARGE ? $clog2(DEPTH) + 1 : LOG_SIZE0_OVER_TP + 1;
localparam LOG_SIZE1                = $clog2(size1);
localparam SIZE1_OVER_TP            = size1/TP;
localparam SIZE1_OVER_TP_LOG2       = $clog2(SIZE1_OVER_TP);
localparam SIZE0_OVER_TP            = size0/TP;
localparam LOG_SIZE0_OVER_TP        = $clog2(SIZE0_OVER_TP);
localparam READ_LAT                 = (LARGE) ? DEPTH : SIZE0_OVER_TP;

wire [LOG_DEPTH-1:0] read_addr_int [0:TP-1];
reg  [LOG_DEPTH-1:0] ctr;
wire [LOG_DEPTH-1:0] ctr_d;
wire [LOG_DEPTH-1:0] ctr_read;

reg start_d;


always @(posedge clk) begin
    if (rst) begin
        start_d <= 0;
    end
    else begin
        start_d <= start;
    end
end


always @(posedge clk) begin
    if (rst) begin
        ctr <= 0;
    end
    else if (start_d) begin
        ctr <= ctr + 1;
    end
end


shiftreg #(
    .SHIFT (READ_LAT  ),
    .DATA  (LOG_DEPTH )
) srctr (
    .clk      (clk   ),
    .reset    (1'b0  ),
    .data_in  (ctr   ),
    .data_out (ctr_d )
);

assign ctr_read = ctr_d + READ_LAT;


if (LARGE) begin
    for (genvar i = 0; i < TP; i = i + 1) begin
        assign read_addr_int[i] = ((((SIZE0_OVER_TP)<<(SIZE1_OVER_TP_LOG2))*i + (SIZE0_OVER_TP)*(ctr_read&(SIZE1_OVER_TP-1)) + ((ctr_read&(DEPTH-1))>>LOG_SIZE1)) & (DEPTH-1)) + ((ctr_read<DEPTH)<<(LOG_DEPTH-1));
    end
end else begin
    for (genvar i = 0; i < TP; i = i + 1) begin
        assign read_addr_int[i] = (i&(SIZE0_OVER_TP-1)) + SIZE0_OVER_TP*(ctr_read<SIZE0_OVER_TP);
    end
end


if (LARGE) begin
    for (genvar i = 0; i < TP; i = i + 1) begin
        always @(posedge clk) begin
            read_addr [((TP-i)*(LOG_DEPTH))-1 -: LOG_DEPTH] <= read_addr_int[((i + TP)- (ctr_read>>(SIZE1_OVER_TP_LOG2))) & (TP-1)];
        end
        always @(posedge clk) begin
            write_addr[((TP-i)*(LOG_DEPTH))-1 -: LOG_DEPTH] <= ctr;
        end
    end
end else begin
    for (genvar i = 0; i < TP; i = i + 1) begin
        always @(posedge clk) begin
            read_addr [((TP-i)*(LOG_SIZE0_OVER_TP+1))-1 -: LOG_SIZE0_OVER_TP+1] <= read_addr_int[((i + TP) - (ctr_read&((SIZE0_OVER_TP)-1))) & (TP-1)];
        end
        always @(posedge clk) begin
            write_addr[((TP-i)*(LOG_SIZE0_OVER_TP+1))-1 -: LOG_SIZE0_OVER_TP+1] <= ctr;
        end
    end
end



endmodule