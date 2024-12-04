module automorphism_unit
   #(
        parameter  large_automorphism   = 0  ,  // 0 --> SMALL_ADDRESS_GENERATOR , 1 --> LARGE_ADDRESS_GENERATOR
        parameter  N            = 128,
        parameter  n1           = 8  ,
        parameter  n2           = 2  ,
        parameter  size0        = 16 ,
        parameter  size1        = 16 ,    
        parameter  TP           = 8  ,
        parameter  LOGQ         = 60 ,
        parameter  BTF_LAT      = 10 ,
        parameter  AU_ID        = 0
    )
    (
        input                               clk         ,
        input                               rst         ,
        input                               start       ,
        input           [LOGQ*TP-1:0]       input_data  ,
        output reg      [LOGQ*TP-1:0]       output_data     
    );


    
    
    localparam depth  = large_automorphism ? $rtoi($ceil(N/TP)) : $rtoi($ceil(size0/n1)) ;
    localparam size1_over_tp = size1/TP;
    localparam size1_over_tp_log2 = $rtoi($ceil($clog2(size1_over_tp)));
    localparam size0_over_tp = size0/TP;
    localparam log_size0_over_tp = $rtoi($ceil($clog2((size0)/TP)));
    localparam size0_over_tp_mult_size1_over_tp_log2 = $rtoi($ceil($clog2((size0/TP)*(size1_over_tp))));

    localparam reg_ctr = $clog2(size0_over_tp);

    localparam BRAM_size        = large_automorphism ? 2*depth : 2*size0_over_tp;
    localparam BRAM_log_size    = large_automorphism ? $rtoi($ceil($clog2(2*depth))) : log_size0_over_tp + 1;

    localparam log_depth  = large_automorphism ? $rtoi($ceil($clog2(depth))) : log_size0_over_tp;

    // states
    localparam OP_IDLE          = 1'd0;
    localparam OP_STARTED       = 1'd1;

    wire [log_depth:0] read_addr_int [0:TP-1];
    reg  [log_depth:0] ctr;
    wire [log_depth:0] ctr_shifted, ctr_out;
    reg  curr_state, next_state;

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
                    ctr <= ctr;
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
    if (AU_ID == 0) begin
        shiftreg #(.SHIFT(2),.DATA(1)) sre100(clk,rst,start_addr_gen,start_take_input);

        assign start_addr_sig = start_addr_gen;
    end else begin
        shiftreg #(.SHIFT(4),.DATA(1)) sre200(clk,rst,start_addr_gen,start_take_input);
        shiftreg #(.SHIFT(2),.DATA(1)) sre100(clk,rst,start_addr_gen,start_addr_gen_shifted);
        

        assign start_addr_sig = start_addr_gen_shifted;
    end
endgenerate

generate
    if (AU_ID == 0) begin
        shiftreg #(.SHIFT(2),.DATA(log_depth+1)) sre101(clk,rst,ctr,ctr_shifted);
    end else begin
        shiftreg #(.SHIFT(4),.DATA(log_depth+1)) sre101(clk,rst,ctr,ctr_shifted);
    end
endgenerate


generate
    if (AU_ID == 0) begin
        shiftreg #(.SHIFT(depth+5),.DATA(log_depth+1)) sre102(clk,rst,ctr,ctr_out);
    end else begin
        shiftreg #(.SHIFT(depth+7),.DATA(log_depth+1)) sre102(clk,rst,ctr,ctr_out);
    end
endgenerate


generate
    addr_gen #(.large_addr(large_automorphism),.N(N), .n1(n1), .size0(size0), .size1(size1), .TP(TP)) small_addr_gen_sm_unit (clk, rst, start_addr_sig, read_addr_res, write_addr_res);
endgenerate

generate
    if (large_automorphism) begin
        for (genvar rot = 0; rot < TP; rot = rot + 1 ) begin
            always @(posedge clk) begin
                input_data_shift[rot*LOGQ +: LOGQ] <= input_data[(((rot + (ctr_shifted>>size0_over_tp_mult_size1_over_tp_log2))&(TP-1)))*LOGQ +: LOGQ];
            end
        end
    end else begin
        for (genvar rot = 0; rot < TP; rot = rot + 1) begin
            always @(posedge clk) begin
                input_data_shift[(TP-rot)*LOGQ-1 -: LOGQ] <= input_data[(TP-((   ((((rot - (ctr_shifted&(size0/TP-1)))&(TP-1)))/n2) + (((rot - (ctr_shifted&(size0/TP-1)))&(n2-1))*(TP/n2)))&(TP-1)))*LOGQ-1 -: LOGQ];
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
                        if(start_take_input) begin
                            di00[k]       <= input_data_shift[(TP-k)*LOGQ-1-:LOGQ];
                            dr00[k]       <= read_addr_res[(TP-k)*(log_depth+1)-1-:log_depth+1];
                            dw00[k]       <= write_addr_res[(TP-k)*(log_depth+1)-1-:log_depth+1];
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

    for (genvar c2 = 0; c2 < TP; c2 = c2 + 1) begin: BRAM_GEN_BLOCK_NTT0 // BRAM for NTT
        BRAM #(LOGQ, BRAM_size, BRAM_log_size) bm000(clk,de00[1*c2+0],dw00[1*c2+0],di00[1*c2+0],dr00[1*c2+0],do00[1*c2+0]); // 64 BRAMs * 128 depth (2**7) * 32 bit
    end
endgenerate



generate
    
    if (large_automorphism) begin
        for (genvar i = 0; i < TP; i = i + 1) begin
            always @(posedge clk ) begin
                output_data[(TP-i)*LOGQ-1-:LOGQ] <= do00[(i + (((ctr_out>>size1_over_tp_log2)&(depth-1))))&(TP-1)];
            end
        end
    end else begin
        for (genvar i = 0; i < TP; i = i + 1) begin
            always @(posedge clk ) begin
                output_data[(TP-i)*LOGQ-1 -: LOGQ] <= do00[(i + (ctr_out&(size0_over_tp-1)))&(TP-1)];
            end
        end
    end
    
endgenerate







endmodule