module shuffle_addr_gen
   #(
        parameter  LOGN         = 128,
        parameter  LOGN1        = 2  ,
        parameter  LOGN2        = 2  ,
        parameter  SIZE1        = 4  ,
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
localparam magical          = (N/(N1*TP));
localparam magical2         = (N2*SIZE1/TP);

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
    .reset    (rst   ),
    .data_in  (ctr   ),
    .data_out (ctr_d )
);

assign ctr_read = ctr_d + READ_LAT;

for (genvar j = 0; j < TP; j = j + 1) begin
    assign read_addr_int[j] =           (((j & 1'd1) * magical * (N1 >> 1) +
                ((j & 2'd3) / 2) * magical * (N1 >> 2) +
                ((j & 3'd7) / 4) * magical * (N1 >> 3) +
                ((j & 4'd15) / 8) * magical * (N1 >> 4) +
                ((j & 5'd31) / 16) * magical *  (N1 >> 5) +
                ((j & 6'd63) / 32) * magical * (N1 >> 6) +
                ((j & 7'd127) / 64) * magical * (N1 >> 7) + 
                (ctr_read & 1'd1)/1 * (magical/2) + 
                (ctr_read & 2'd3)/2 * (magical/4) + 
                (ctr_read & 3'd7)/4 * (magical/8) + 
                (ctr_read & 4'd15)/8 * (magical/16) + 
                (ctr_read & 5'd31)/16 * (magical/32) + 
                (ctr_read & 6'd63)/32 * (magical/64)) & (DEPTH-1)) + (ctr_read<DEPTH)*DEPTH;
end




for (genvar i = 0; i < TP; i = i + 1) begin
    always @(posedge clk) begin
        read_addr [((TP-i)*(LOG_DEPTH))-1 -: LOG_DEPTH] <= read_addr_int[((i - 
        (
            (((ctr_read & (DEPTH-1))/magical2)&1'd1)/1*(TP/2) +
            (((ctr_read & (DEPTH-1))/magical2)&2'd3)/2*(TP/4) +
            (((ctr_read & (DEPTH-1))/magical2)&3'd7)/4*(TP/8) +
            (((ctr_read & (DEPTH-1))/magical2)&4'd15)/8*(TP/16) +
            (((ctr_read & (DEPTH-1))/magical2)&5'd31)/16*(TP/32) +
            (((ctr_read & (DEPTH-1))/magical2)&6'd63)/32*(TP/64) 
        ))) & (TP-1)];
    end
    always @(posedge clk) begin
        write_addr[((TP-i)*(LOG_DEPTH))-1 -: LOG_DEPTH] <= ctr;
    end
end




endmodule