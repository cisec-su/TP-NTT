// top_module.v
module iterative_tp_cons_file #(
        parameter N             = 1<<16,
        parameter n1            = 1<<6,
        parameter n2            = 1<<4,
        parameter n3            = 1<<6,
        parameter TP            = 1<<6,
        parameter LOGQ          = 32,
        parameter BTF_LAT       = 8
    )
    (
        input                           clk,
        input                           rst,
        input                           START_NTT_ALL,
        input   [1:0]                   OP_TYPE_INPUT,
        input   [LOGQ-1:0]           NTT_INPUT,
        input   [LOGQ-1:0]       TWIDDLE_INPUT,
        output  [LOGQ-1:0]           NTT_OUTPUT_last
    );

    // Parameters for the karatsuba_parametric module


    reg  START_NTT_ALL_reg;
    reg [1:0] OP_TYPE_reg;
    reg [TP*LOGQ-1:0] NTT_INPUT_reg;
    reg [(TP-1)*LOGQ-1:0] TWIDDLE_INPUT_reg;
    wire [TP*LOGQ-1:0] NTT_out;
    
    reg  [TP*LOGQ-1:0]           NTT_OUTPUT_reg;

    //Instantiate the karatsuba_parametric module
    iterative_tp_super_top #(
        .N(1<<16),
        .n1(1<<6),
        .n2(1<<4),
        .n3(1<<6),
        .TP(1<<6),
        .LOGQ(32),
        .BTF_LAT(8)
    ) uut (
        .clk(clk),
        .rst(rst),
        .START_NTT_ALL(START_NTT_ALL_reg),
        .OP_TYPE_INPUT(OP_TYPE_reg),
        .NTT_INPUT(NTT_INPUT_reg),
        .TWIDDLE_INPUT(TWIDDLE_INPUT_reg),
        .NTT_OUTPUT(NTT_out)
    );


    always @(posedge clk or posedge rst) begin
        if(rst) begin
            START_NTT_ALL_reg <= 0;
            OP_TYPE_reg <= 0;
            NTT_INPUT_reg <= 0;
            TWIDDLE_INPUT_reg <= 0;
            NTT_OUTPUT_reg <= 0;
        end
        else begin
            START_NTT_ALL_reg <= START_NTT_ALL;
            OP_TYPE_reg <= OP_TYPE_INPUT;
            NTT_INPUT_reg <= 64*{NTT_INPUT};
            TWIDDLE_INPUT_reg <= 64*{TWIDDLE_INPUT};
            NTT_OUTPUT_reg <= NTT_out;
        end
    end
    
    assign NTT_OUTPUT_last = NTT_OUTPUT_reg[LOGQ-1:0];

endmodule