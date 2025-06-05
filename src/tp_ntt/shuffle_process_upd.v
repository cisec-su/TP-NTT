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


    
    localparam N  = 1 << LOGN;
    localparam N1 = 1 << LOGN1;
    localparam N2 = 1 << LOGN2;
    localparam TP = 1 << LOGTP;
    localparam size0 = N1 * N2;
    localparam size1 = N / (size0);
    localparam depth  = LARGE ? $rtoi($ceil(N/TP)) : $rtoi($ceil(size0/TP)) ;
    localparam depth_large = $rtoi($ceil(N/TP));
    localparam size1_over_tp = size1/TP;
    localparam size1_over_tp_log2 = $rtoi($ceil($clog2(size1_over_tp)));
    localparam size0_over_tp = size0/TP;
    localparam log_size0_over_tp = $rtoi($ceil($clog2((size0)/TP)));
    localparam size0_over_tp_mult_size1_over_tp_log2 = $rtoi($ceil($clog2((size0/TP)*(size1_over_tp))));
    localparam reg_ctr = $clog2(size0_over_tp);

    localparam BRAM_size        = LARGE ? 2*depth : 2*size0_over_tp;
    localparam BRAM_log_size    = LARGE ? $rtoi($ceil($clog2(2*depth))) : log_size0_over_tp + 1;

    localparam log_depth  = LARGE ? $rtoi($ceil($clog2(depth))) : log_size0_over_tp;
    localparam log_depth_large = $rtoi($ceil($clog2(depth_large)));

    // states
    localparam OP_IDLE          = 1'd0;
    localparam OP_STARTED       = 1'd1;

    reg  [log_depth:0] ctr;
    wire [log_depth:0] ctr_shifted, ctr_out;
    reg  curr_state, next_state;

    reg [log_depth_large+4:0] ctr_state;

    reg start_addr_gen;
    wire start_addr_gen_shifted;
    wire start_addr_sig, start_take_input;

    reg [LOGQ-1:0]                  di00     [1*(TP)-1:0];
    wire[LOGQ-1:0]                  do00     [1*(TP)-1:0];
    reg [(log_depth+1)-1:0]           dw00     [1*(TP)-1:0];
    reg [(log_depth+1)-1:0]           dr00     [1*(TP)-1:0];
    reg                             de00     [1*(TP)-1:0];

    

    wire [(log_depth+1)*TP-1:0] read_addr_res;
    wire [(log_depth+1)*TP-1:0] write_addr_res;

    reg [TP*LOGQ-1:0] input_data_shift;

    wire [LOGQ-1:0] input_data_int [TP-1:0];
    wire [LOGQ-1:0] input_data_shift_int [TP-1:0];

    localparam TEMP = LARGE ? depth_large + 6 : depth_large + 4;

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
        else if ((ctr_state[log_depth_large+4:0]) == (4'd10*depth_large-1)) begin
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

generate
        shiftreg #(.SHIFT(2),.DATA(1)) sre100(clk,rst,start_addr_gen,start_take_input);

        assign start_addr_sig = start_addr_gen;

endgenerate

generate
        shiftreg #(.SHIFT(2),.DATA(log_depth+1)) sre101(clk,rst,ctr,ctr_shifted);
endgenerate


generate
    shiftreg #(.SHIFT(depth+5),.DATA(log_depth+1)) sre102(clk,rst,ctr,ctr_out);

endgenerate


generate
    shuffle_addr_gen #(.large_addr(LARGE), .LOGN(LOGN), .LOGN1(LOGN1), .LOGN2(LOGN2), .LOGTP(LOGTP)) shuf_addr_gen_unit (clk, rst, start_addr_sig, mod_op, read_addr_res, write_addr_res);
endgenerate


generate
    for (genvar rot = 0; rot < TP; rot = rot + 1) begin
        assign input_data_int[rot] = input_data[rot*LOGQ +: LOGQ];
    end
endgenerate

generate
    for (genvar rot = 0; rot < TP; rot = rot + 1 ) begin
        always @(posedge clk) begin
            input_data_shift[rot*LOGQ +: LOGQ] <= mod_op ? input_data_int[rot] : input_data_int[(((rot+(ctr_shifted>>2))&(5'd31)))];;
        end
    end
endgenerate


generate
    for (genvar rot = 0; rot < TP; rot = rot + 1) begin
        assign input_data_shift_int[rot] = input_data_shift[rot*LOGQ +: LOGQ];
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
                di00[k]       <= input_data_shift_int[(TP-k-1)];
                dr00[k]       <= read_addr_res[(TP-k)*(log_depth+1)-1-:log_depth+1];
                dw00[k]       <= write_addr_res[(TP-k)*(log_depth+1)-1-:log_depth+1];
                de00[k]       <= start_take_input;                        
            end
        end
    end
endgenerate

generate

    for (genvar c2 = 0; c2 < TP; c2 = c2 + 1) begin: BRAM_GEN_BLOCK_NTT0 // BRAM for NTT
        BRAM #(LOGQ, BRAM_size, BRAM_log_size) bm000(clk,de00[1*c2+0],dw00[1*c2+0],di00[1*c2+0],dr00[1*c2+0],do00[1*c2+0]); // 64 BRAMs * 128 depth (2**7) * 32 bit
    end
endgenerate



generate

    for (genvar i = 0; i < TP; i = i + 1) begin
        always @(posedge clk ) begin
            output_data[(TP-i)*LOGQ-1-:LOGQ] <= mod_op ? do00[(i & 1'd1) * (N1 >> 1) +
                                                        ((i & 2'd3) >> 1) * (N1 >> 2) +
                                                        ((i & 3'd7) >> 2) * (N1 >> 3) +
                                                        ((i & 4'd15) >> 3) * (N1 >> 4) +
                                                        ((i & 5'd31) >> 4) * (N1 >> 5) +
                                                        ((i & 6'd63) >> 5) * (N1 >> 6) +
                                                        ((i & 7'd127) >> 6) * (N1 >> 7)
            ] 
            :  do00[(i + (ctr_out>>2)) & (TP-1)] ;
        end
    end
    
endgenerate







endmodule