module shuffle_process_upd
   #(
        parameter  LARGE        = 1  ,  // 0 --> SMALL_ADDRESS_GENERATOR , 1 --> LARGE_ADDRESS_GENERATOR
        parameter  LOGN         = 15,
        parameter  LOGN1        = 6  ,
        parameter  LOGN2        = 3  ,
        parameter  LOGTP        = 6 ,
        parameter  LOGQ         = 60 ,
        parameter  AU_ID        = 7
    )
    (
        input                               clk         ,
        input                               rst         ,
        input                               start       ,
        input                               mod_op      ,
        input           [LOGQ*TP-1:0]       input_data  ,
        output reg      [LOGQ*TP-1:0]       output_data     
    );


    
localparam N                        = 1 << LOGN;
localparam N1                       = 1 << LOGN1;
localparam N2                       = 1 << LOGN2;
localparam TP                       = 1 << LOGTP;
localparam SIZE0                    = N1 * N2;
localparam SIZE1                    = N / (SIZE0);
localparam DEPTH                    = LARGE ? N/TP : SIZE0/TP ;
localparam DEPTH_NEW                 = N/TP ;
localparam DEPTH_LARGE              = N/TP;
localparam SIZE1_OVER_TP            = SIZE1/TP;
localparam SIZE0_OVER_TP            = SIZE0/TP;
localparam LOG_SIZE0_OVER_TP        = $clog2((SIZE0)/TP);
localparam BRAM_SIZE                = LARGE ? 2*DEPTH : 2*SIZE0_OVER_TP;
localparam BRAM_LOG_SIZE            = LARGE ? $clog2(2*DEPTH) : LOG_SIZE0_OVER_TP + 1;
localparam LOG_DEPTH                = LARGE ? $clog2(DEPTH) + 1 : LOG_SIZE0_OVER_TP + 1;
localparam LOG_DEPTH_LARGE          = $clog2(DEPTH_LARGE) + 1;

// states
localparam OP_IDLE                  = 1'd0;
localparam OP_STARTED               = 1'd1;

reg  [LOG_DEPTH-1:0] ctr;
wire [LOG_DEPTH-1:0] ctr_shifted, ctr_out;
reg  curr_state, next_state;

reg [LOG_DEPTH_LARGE+3:0] ctr_state;

reg start_addr_gen;
wire start_addr_gen_shifted;
wire start_addr_sig, start_take_input;

reg [LOGQ-1:0]                  di00     [TP-1:0];
wire[LOGQ-1:0]                  do00     [TP-1:0];
reg [LOG_DEPTH-1:0]             dw00     [TP-1:0];
reg [LOG_DEPTH-1:0]             dr00     [TP-1:0];
reg                             de00     [TP-1:0];



wire [LOG_DEPTH*TP-1:0] read_addr_res;
wire [LOG_DEPTH*TP-1:0] write_addr_res;

reg [TP*LOGQ-1:0] input_data_shift;

wire [LOGQ-1:0] input_data_int [TP-1:0];
wire [LOGQ-1:0] input_data_shift_int [TP-1:0];


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
    end
    else if ((ctr_state[LOG_DEPTH_LARGE-1:0]) == (DEPTH_LARGE-1)) begin
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

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ctr_state <= 0;
    end else begin
        case (curr_state)
            OP_STARTED: begin
                ctr_state <= ctr_state + 1;
            end 
            default: begin
                ctr_state <= 0;
            end
        endcase
        
    end
end

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

shiftreg #(
    .SHIFT (2),
    .DATA  (1)
) sre100 (
    .clk      (clk             ),
    .reset    (rst             ),
    .data_in  (start_addr_gen  ),
    .data_out (start_take_input)
);

assign start_addr_sig = start_addr_gen;

shiftreg #(
    .SHIFT (2),
    .DATA  (LOG_DEPTH)
) sre101 (
    .clk      (clk        ),
    .reset    (rst        ),
    .data_in  (ctr        ),
    .data_out (ctr_shifted)
);

shiftreg #(
    .SHIFT (DEPTH + 5),
    .DATA  (LOG_DEPTH)
) sre102 (
    .clk      (clk     ),
    .reset    (rst     ),
    .data_in  (ctr     ),
    .data_out (ctr_out )
);

shuffle_addr_gen #(
    .LOGN  (LOGN  ),
    .LOGN1 (LOGN1 ),
    .LOGN2 (LOGN2 ),
    .LOGTP (LOGTP )
) shuf_addr_gen_sm (
    .clk            (clk            ),
    .rst            (rst            ),
    .start          (start_addr_sig ),
    .mod_op         (mod_op         ),
    .read_addr      (read_addr_res  ),
    .write_addr     (write_addr_res )
);


for (genvar rot = 0; rot < TP; rot = rot + 1) begin
    assign input_data_int[rot] = input_data[rot*LOGQ +: LOGQ];
end


for (genvar rot = 0; rot < TP; rot = rot + 1 ) begin
    always @(posedge clk) begin
        input_data_shift[rot*LOGQ +: LOGQ] <=  input_data_int[((((rot+
                                                                    (
                                                                        ((ctr_shifted>>4)&1'd1)*2 + 
                                                                        ((ctr_shifted>>4)>>1)
                                                                    )
                                                                    ))&(2'd3)))];
    end
end


for (genvar rot = 0; rot < TP; rot = rot + 1) begin
    assign input_data_shift_int[rot] = input_data_shift[rot*LOGQ +: LOGQ];
end


for (genvar k = 0; k < TP; k = k + 1) begin
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            di00[k]       <= 0;
            dr00[k]       <= 0;
            dw00[k]       <= 0;
            de00[k]       <= 0;
        end else begin
            di00[k]       <= input_data_shift_int[(TP-k-1)];
            dr00[k]       <= read_addr_res[(TP-k)*(LOG_DEPTH)-1-:LOG_DEPTH];
            dw00[k]       <= write_addr_res[(TP-k)*(LOG_DEPTH)-1-:LOG_DEPTH];
            de00[k]       <= start_take_input;                        
        end
    end
end


for (genvar c2 = 0; c2 < TP; c2 = c2 + 1) begin: BRAM_GEN_BLOCK_NTT0 // BRAM for NTT
    BRAM #(
    .DSIZE (LOGQ         ),
    .MSIZE (BRAM_SIZE    ),
    .DEPTH (BRAM_LOG_SIZE)
) bm000 (
    .clk   (clk          ),
    .wen   (de00[c2]     ),
    .waddr (dw00[c2]     ),
    .din   (di00[c2]     ),
    .raddr (dr00[c2]     ),
    .dout  (do00[c2]     )
);
end



for (genvar i = 0; i < TP; i = i + 1) begin
    always @(posedge clk ) begin
        output_data[(TP-i)*LOGQ-1-:LOGQ] <= do00[(i + ((ctr_out/8)&1'd1)/1*4 +
                ((ctr_out/8) & 2'd3)/2*2 +
                (ctr_out/(DEPTH_NEW/2)) ) & (2'd3)
        ];
    end
end


endmodule