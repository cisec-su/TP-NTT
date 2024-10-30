// top_module.v
module iterative_tp_cons_file #(
        parameter iter_choice   = 2,
        parameter N             = 1<<16,
        parameter n1            = 1<<4,
        parameter n2            = 1<<4,
        parameter n3            = 1<<4,
        parameter n4            = 1<<4,     
        parameter TP            = 1<<5,
        parameter LOGQ          = 32,
        parameter BTF_LAT       = 8
    )
    (
        input                           clk,
        input                           rst,
        input                           START_NTT_ALL,
        input   [1:0]                   OP_TYPE_INPUT,
        input   [LOGQ-1:0]              Q_in,
        input   [LOGQ-1:0]           NTT_INPUT,
        input   [LOGQ-1:0]       TWIDDLE_INPUT,
        output reg  [LOGQ-1:0]           dout
    );

    // Parameters for the karatsuba_parametric module


    // reg  START_NTT_ALL_reg;
    // reg [1:0] OP_TYPE_reg;
    // reg [TP*LOGQ-1:0] NTT_INPUT_reg;
    // reg [(TP-1)*LOGQ-1:0] TWIDDLE_INPUT_reg;
    // wire [TP*LOGQ-1:0] NTT_out;
    
    // reg  [TP*LOGQ-1:0]           NTT_OUTPUT_reg;
    // reg [LOGQ-1:0]               Q_in_reg;

    // //Instantiate the karatsuba_parametric module
    // iterative_tp_super_top #(
    //     .iter_choice(iter_choice),
    //     .N(N),
    //     .n1(n1),
    //     .n2(n2),
    //     .n3(n3),
    //     .n4(n4),
    //     .TP(TP),
    //     .LOGQ(LOGQ),
    //     .BTF_LAT(BTF_LAT)
    // ) uut (
    //     .clk(clk),
    //     .rst(rst),
    //     .START_NTT_ALL(START_NTT_ALL_reg),
    //     .OP_TYPE_INPUT(OP_TYPE_reg),
    //     .Q_in(Q_in_reg),
    //     .NTT_INPUT(NTT_INPUT_reg),
    //     .TWIDDLE_INPUT(TWIDDLE_INPUT_reg),
    //     .NTT_OUTPUT(NTT_out)
    // );


    // always @(posedge clk or posedge rst) begin
    //     if(rst) begin
    //         START_NTT_ALL_reg <= 0;
    //         OP_TYPE_reg <= 0;
    //         Q_in_reg <= 0;
    //         NTT_INPUT_reg <= 0;
    //         TWIDDLE_INPUT_reg <= 0;
    //         NTT_OUTPUT_reg <= 0;
    //     end
    //     else begin
    //         START_NTT_ALL_reg <= START_NTT_ALL;
    //         OP_TYPE_reg <= OP_TYPE_INPUT;
    //         Q_in_reg        <= Q_in;
    //         NTT_INPUT_reg <= 64*{NTT_INPUT};
    //         TWIDDLE_INPUT_reg <= 64*{TWIDDLE_INPUT};
    //         NTT_OUTPUT_reg <= NTT_out;
    //     end
    // end
    
    // assign NTT_OUTPUT_last = NTT_OUTPUT_reg[LOGQ-1:0];

    reg [LOGQ-1:0]      din_R      [31:0];

    wire[LOGQ-1:0]      dout_W     [31:0];

     reg [4:0]       i_cntr;

      reg [4:0]       o_cntr;

    always @(posedge clk or posedge reset) 
    begin
        if(reset) begin
            i_cntr <= 0;
            
            o_cntr <= 0;
            
        end
        else begin
            i_cntr <= i_cntr+1;
            
            o_cntr <= o_cntr+1;
        end
    end
    
    always @(posedge clk or posedge reset) 
    begin
        if(reset) begin
            
    
            {din_R[31],din_R[30],din_R[29],din_R[28],din_R[27],din_R[26],din_R[25],din_R[24],din_R[23],din_R[22],din_R[21],din_R[20],din_R[19],din_R[18],din_R[17],din_R[16],din_R[15],din_R[14],din_R[13],din_R[12],din_R[11],din_R[10],din_R[9],din_R[8],din_R[7],din_R[6],din_R[5],din_R[4],din_R[3],din_R[2],din_R[1],din_R[0]} <= 0;

            dout          <= 0;
        end
        else begin
            
            //done          <= done_wire;
    
            din_R[i_cntr] <= NTT_INPUT;
            dout          <= dout_W[o_cntr];
        end
    end

    iterative_tp_super_top #(
        .iter_choice(iter_choice),
        .N(N),
        .n1(n1),
        .n2(n2),
        .n3(n3),
        .n4(n4),
        .TP(TP),
        .LOGQ(LOGQ),
        .BTF_LAT(BTF_LAT)
    ) unit(clk,reset, START_NTT_reg, OP_TYPE_reg, Q_in_reg,
            {din_R[15],din_R[14],din_R[13],din_R[12],din_R[11],din_R[10],din_R[9],din_R[8],din_R[7],din_R[6],din_R[5],din_R[4],din_R[3],din_R[2],din_R[1],din_R[0]},
            {din_R[7],din_R[6],din_R[5],din_R[4],din_R[3],din_R[2],din_R[1],din_R[0]},
            {dout_W[15],dout_W[14],dout_W[13],dout_W[12],dout_W[11],dout_W[10],dout_W[9],dout_W[8],dout_W[7],dout_W[6],dout_W[5],dout_W[4],dout_W[3],dout_W[2],dout_W[1],dout_W[0]}
             );
    

endmodule