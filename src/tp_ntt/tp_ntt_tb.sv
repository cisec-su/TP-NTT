`timescale 1ns / 1ps

module tp_ntt_tb();

    `include "tp_ntt.svh"

    // Parameters
    parameter LOGN          = 10;
    parameter LOGN1         = 5;
    parameter LOGN2         = 5;
    parameter LOGN3         = 0;
    parameter LOGTP         = 5;
    parameter LOGQ          = 60;
    parameter LOGQH         = 17;
    parameter NON_STD       = 1;
    parameter MORE_DSP      = 0; 
    parameter BATCH_SIZE    = 10;
    parameter BATCH_DELAY   = 1;
    parameter HP            = 5;
    parameter FP            = (2*HP);
    parameter TEST_DIR      = "../../../../../test";
    parameter PYTHON        = "/home/toluntosun/miniconda3/bin/python3";
    parameter GEN_TEST_VEC  = 1;

    localparam LOGN4        = LOGN - LOGN1 - LOGN2 - LOGN3;
    localparam N            = 1 << LOGN;
    localparam N1           = 1 << LOGN1;
    localparam N2           = 1 << LOGN2;
    localparam N3           = 1 << LOGN3;
    localparam N4           = 1 << LOGN4;
    localparam TP           = 1 << LOGTP;
    localparam size0        = N1*N2;
    localparam size1        = N3*N4;
    localparam DIM          = (N4 != 1) ? 2 : ((N3 != 1) ? 1 : 0);


    localparam input_bits = LOGQ*TP;
    localparam depth =  $rtoi($ceil(N/TP));
    localparam total_steps = $rtoi($ceil($clog2(N)));
    localparam TP_log = $rtoi($ceil($clog2(TP)));
    localparam N_over_TP =  $rtoi($ceil(N/TP));

    localparam large_steps = (total_steps/TP_log);

    localparam large_steps_log_num = large_steps*TP_log;
    localparam last_step = total_steps - large_steps_log_num;

    localparam last_elmnt_log = (last_step == 0 ) ? 0 :  total_steps- large_steps_log_num; 
    localparam last_step_ntt_num = (last_elmnt_log == 0) ? 0 : (TP/(1<<last_elmnt_log)) ;

    localparam is_last_problem = (last_elmnt_log == 0) ? 0 : 1;
    localparam total_step_numbers_real =  DIM == 0 ? 2 : (DIM == 1 ? 3 : 4); 
    localparam psi_count = (N_over_TP)*((1<<LOGN1)-1)*(1<<(LOGN1)) + (N_over_TP)*((1<<LOGN2)-1)*(1<<(LOGN2)) + (N_over_TP)*((1<<LOGN3)-1)*(1<<(LOGN3)) + (N_over_TP)*((1<<LOGN4)-1)*(1<<(LOGN4));

    // Testbench variables
    reg clk;
    reg rst;
    reg START_NTT;
    reg [1:0] OP_TYPE;
    reg [LOGQ*TP-1:0] NTT_in;
    reg [LOGQ*TP-1:0] NTT_res;
    reg [LOGQ*(TP-1)-1:0] W_in;
    wire [LOGQ*TP-1:0] NTT_out;

    reg [LOGQ-1:0] a0_0 [0:N-1]; 
    reg [LOGQ-1:0] res [0:N-1]; 
    reg [LOGQ-1:0] q [0:6];
    reg [LOGQ-1:0] psi0  [0:psi_count-1];

    reg [TP_log:0] ctr1;
    
    reg[LOGQH-1:0] q_tb;

    int flag, flag1;
    string cmd;

    // Test sequence
    integer i, j, k, id11, idx_here, idx_start, t;

    always #HP clk = ~clk;

    initial begin
        // ntt
        if (GEN_TEST_VEC) begin
            $sformat(cmd, "sh %s/test_vector_gen.sh %0d %0d %0d %0d %0d %0d %0d %0d %s 0", TEST_DIR, N, N1, N2, N3, N4, TP, DIM, LOGQ, PYTHON);
            $display("Executing: %s", cmd);
            $system(cmd);
        end
        $readmemh({TEST_DIR, "/ntt_in.txt"  }, a0_0);
        $readmemh({TEST_DIR, "/ntt_out.txt" }, res);      
        $readmemh({TEST_DIR, "/psi.txt"     }, psi0);
        $readmemh({TEST_DIR, "/q.txt"       }, q);    
    end

    initial begin

        $display("Simulation started.");

        clk = 1'b0;
        rst = 1'b0;
        OP_TYPE = 2'b0;
        START_NTT = 1'b0;
        NTT_in = 0;
        W_in = 0;
        #FP;
        rst = 1'b1;
        #FP;
        rst = 1'b0;

        #HP;
        
        
        #FP;

        #HP;
        OP_TYPE = 2'd3;
        #HP;
        // Q-LOAD
        q_tb = q[0][LOGQ-1 -: LOGQH];

        #FP;
        OP_TYPE = 2'd0;

        #(FP*3);
        
        OP_TYPE = 2'b1;
        #FP;

        for (i = 0 ; i < total_step_numbers_real ; i = i+1) begin
            if(is_last_problem && i == 1) begin
                ctr1 = ((1<<LOGN2)-1)*(TP>>LOGN2);
            end
            else begin
                ctr1 = TP-4'b1;
            end

            for (k = 0; k < N_over_TP ; k = k+1) begin
                if (i == 0) begin
                    for (j = 0; j < TP-1 ; j = j + 1 ) begin
                        //id11 = 0 + k * (TP-1) + j;
                        if(j<((1<<LOGN1)-1)*(TP>>LOGN1)) begin
                            id11 = 0 + k * ((1<<LOGN1)-1)*(TP>>LOGN1) + j;
                            W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                        end
                        else begin
                            id11 = N_over_TP*(TP-1) + k * ctr1 + j;
                            W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
                        end
                        
                    end
                end
                else if (i == 1) begin
                    for (j = 0; j < TP-1 ; j = j + 1 ) begin
                        if(j<((1<<LOGN2)-1)*(TP>>LOGN2)) begin
                            id11 = N_over_TP*((1<<LOGN1)-1)*(TP>>LOGN1) + k * ((1<<LOGN2)-1)*(TP>>LOGN2) + j;
                            W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                        end
                        else begin
                            id11 = N_over_TP*(TP-1) + k * ctr1 + j;
                            W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
                        end
                        
                    end
                end else if (i == 2) begin
                    for (j = 0; j < TP-1 ; j = j + 1 ) begin

                        if(j<((1<<LOGN3)-1)*(TP>>LOGN3)) begin
                            id11 = N_over_TP*(((1<<LOGN1)-1)*(TP>>LOGN1) + ((1<<LOGN2)-1)*(TP>>LOGN2)) + k * ((1<<LOGN3)-1)*(TP>>LOGN3) + j;
                            W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                        end
                        else begin
                            id11 = N_over_TP*(TP-1) + k * ctr1 + j;
                            W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
                        end
                    end
                end
                else if (i == 3) begin
                    for (j = 0; j < TP-1 ; j = j + 1 ) begin

                        if(j<((1<<LOGN4)-1)*(TP>>LOGN4)) begin
                            id11 = N_over_TP*(((1<<LOGN1)-1)*(TP>>LOGN1) + ((1<<LOGN2)-1)*(TP>>LOGN2) + ((1<<LOGN3)-1)*(TP>>LOGN3)) + k * ((1<<LOGN4)-1)*(TP>>LOGN4) + j;
                            W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                        end
                        else begin
                            id11 = N_over_TP*(TP-1) + k * ctr1 + j;
                            W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
                        end
                    end
                end
                #FP;
            end
            
            
        end
        OP_TYPE = 2'b0;
        #(FP*5);
        //OP_TYPE = 3'd2;
        @(posedge clk);
        @(posedge clk);
        START_NTT = 1'b1;
        @(posedge clk);
        START_NTT = 1'b0;
        // Initialize inputs
        for (i = 0; i < depth ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
                idx_here = ((j*N_over_TP) + ((i & (size0/TP-1)) * (N/size0)) + (i/(size0/TP))) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0[idx_here]};
            end
            @(posedge clk);
        end
        
        repeat(uut.LAT) begin
            @(posedge clk);
        end
        flag = 1;
        i = 0;
        $display("SINGLE NTT TEST STARTING");
        for (i = 0; i < depth ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
                NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res[j+i*TP]};
            end
            if( NTT_out == NTT_res) begin 
                $display("CORRECT IDX: %d ", i);
            end
            else begin
                flag = 0;
                $display("WRONG IDX !!!!: %d ", i);
            end
            @(posedge clk);
        end
        if (flag) begin
                $display("SINGLE NTT TEST IS SUCCESSFUL. ALL COEFFICIENTS ARE CORRECT");        
        end
        else begin
            $display("FAIL IN SINGLE NTT TEST");
        end

        $display("BATCH NTT TEST STARTING");
        START_NTT = 1'b1;
        t = depth + BATCH_DELAY;
        @(posedge clk);

        flag1 = 1;
        for (k = 0; k < BATCH_SIZE*t + uut.LAT + depth; k = k + 1) begin

            i = k % t;

            if (k < BATCH_SIZE*t) begin
                if (i == 0) begin
                    $display("BATCH NTT IDY: %d", k / t);
                    START_NTT = 1'b0;
                end
                if (i < depth) begin
                    for (j = 0; j < TP; j = j + 1) begin
                        idx_here = ((j*N_over_TP) + ((i & (size0/TP-1)) * (N/size0)) + (i/(size0/TP))) & (N-1);
                        NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0[idx_here]};
                    end
                end
                else if ((i == (t - 1)) && ((k / t) < (BATCH_SIZE - 1))) begin
                    START_NTT = 1'b1;
                end
            end

            if (k > (uut.LAT + depth)) begin
                i = (k - uut.LAT - depth) % t;
                if (i == 0) begin
                    flag = 1;
                end
                if (i < depth) begin
                    for ( j = 0; j < TP; j = j + 1) begin // For every stage
                        NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res[j+i*TP]};
                    end
                    if( NTT_out == NTT_res) begin
                        $display("CORRECT IDX:%d - IDY:%d ", i, (k - uut.LAT - depth) / t);
                    end
                    else begin
                        flag = 0;
                        $display("WRONG IDX:%d -  IDY:%d ", i, (k - uut.LAT - depth) / t);
                    end
                end
                if (i == (depth - 1)) begin
                    if (flag) begin
                        $display("BATCH: %d IS SUCCESSFUL", (k - uut.LAT - depth) / t);        
                    end
                    else begin
                        flag1 = 0;
                    end
                    if (flag1) begin
                        $display("PROCESSED BATCHES ARE SUCCESSFUL");
                    end
                end
            end

            ////////////// NEXT CYCLE //////////////////
            @(posedge clk);
        end

        if (flag1) begin
            $display("BATCH NTT TEST IS SUCCESSFUL. ALL BATCHESxCOEFFICIENTS ARE CORRECT");
        end
        else begin
            $display("SOME BATCHES FAILED");
        end
        $finish;
    end

     tp_ntt_top #(
        .LOGN    (LOGN    ),
        .LOGN1   (LOGN1   ),
        .LOGN2   (LOGN2   ),
        .LOGN3   (LOGN3   ),
        .LOGTP   (LOGTP   ),
        .LOGQ    (LOGQ    ),
        .LOGQH   (LOGQH   ),
        .NON_STD (NON_STD ),
        .MORE_DSP(MORE_DSP)
    ) uut (
        .clk(clk),
        .rst(rst),
        .START_NTT_ALL(START_NTT),
        .OP_TYPE_INPUT(OP_TYPE),
        .Q_in(q_tb),
        .NTT_INPUT(NTT_in),
        .TWIDDLE_INPUT(W_in),
        .NTT_OUTPUT(NTT_out)
    );



endmodule
