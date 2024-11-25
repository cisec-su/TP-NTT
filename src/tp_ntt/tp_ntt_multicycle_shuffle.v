/*
    Move data_in[indexes] to data_out[:] in 4 cycles
*/

module tp_ntt_multicycle_shuffle
   #(
        parameter TP            = 32,
        parameter LOGQ          = 60,
    )
    (
        input                        clk   ,
        input                        rst   ,
        input      [TP*LOGQ -1:0]  data_in ,
        input      [TP*LOGTP-1:0]  indexes ,
        output reg [TP*LOGQ -1:0]  data_out
    );


localparam LOGTP = $rtoi($ceil($clog2(TP)));



reg clk_0;
reg clk_1;

reg [TP*LOGQ -1:0] data_int_0;
reg [TP*LOGTP-1:0] indexes_int_0;
reg [TP*LOGQ -1:0] data_int_0_shuffled;
reg [TP*LOGQ -1:0] data_int_1;
reg [TP*LOGTP-1:0] indexes_int_1;
reg [TP*LOGQ -1:0] data_int_1_shuffled;


always @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_0 <= 0;
    end else begin
        if (clk)
           clk_0 <= ~clk_0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_1 <= 1;
    end else begin
        if (clk)
           clk_1 <= ~clk_1;
    end
end


// moving to clock domain 0
always @(posedge clk_0) begin
    data_int_0 <= data_in;
    indexes_int_0 <= indexes;
end


// moving to clock domain 1
always @(posedge clk_1) begin
    data_int_1 <= data_in;
    indexes_int_1 <= indexes;
end


// shuffling in clock domain 0
generate
    for (genvar i = 0; i < TP ; i = i + 1 ) begin
        always @(posedge clk_0) begin
            data_int_0_shuffled[(TP-i)*LOGQ-1-:LOGQ] <= data_int_0[(i+1)*LOGTP-1-:LOGTP] * LOGQ - 1 -: LOGQ;
        end
    end
endgenerate


// shuffling in clock domain 1
generate
    for (genvar i = 0; i < TP ; i = i + 1 ) begin
        always @(posedge clk_1) begin
            data_int_1_shuffled[(TP-i)*LOGQ-1-:LOGQ] <= data_int_1[(i+1)*LOGTP-1-:LOGTP] * LOGQ - 1 -: LOGQ;
        end
    end
endgenerate


// return to main clock domain
always @(posedge clk) begin
    if (clk_1)
        data_out <= data_int_0_shuffled;
    else
        data_out <= data_int_1_shuffled;
end



endmodule