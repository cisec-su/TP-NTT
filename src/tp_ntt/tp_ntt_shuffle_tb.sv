`timescale 1ns / 1ps

module tp_ntt_shuffle_tb();

    `include "tp_ntt.svh"

    // TP-NTT Parameters
    parameter LOGN                      = 12;
    parameter LOGN1                     = 5;
    parameter LOGN2                     = 2;
    parameter LOGN3                     = 5;
    parameter LOGTP                     = 5;
    parameter LOGQ                      = 60;
    parameter LOGQH                     = 17;
    parameter NON_STD                   = 1;
    parameter MORE_DSP                  = 0;
    
 
    // Test-Bench Parameters
    parameter BATCH_SIZE                = 3;
    parameter BATCH_DELAY               = 1;
    parameter HP                        = 5;
    parameter FP                        = (2*HP);
    parameter TEST_DIR                  = "../../../../../test";
    parameter PYTHON                    = "/usr/bin/python3";
    parameter GEN_TEST_VEC              = 1;

    localparam LOGN4                    = LOGN - LOGN1 - LOGN2 - LOGN3;
    localparam N                        = 1 << LOGN;
    localparam N1                       = 1 << LOGN1;
    localparam N2                       = 1 << LOGN2;
    localparam N3                       = 1 << LOGN3;
    localparam N4                       = 1 << LOGN4;
    localparam TP                       = 1 << LOGTP;
    localparam SIZE0                    = N1*N2;
    localparam SIZE1                    = N3*N4;
    localparam DIM                      = (N4 != 1) ? 2 : ((N3 != 1) ? 1 : 0);
    localparam MAX_BATCH_DELAY          = 20;

    localparam DEPTH                    = N/TP;
    localparam TOTAL_STEPS              = $clog2(N);
    localparam TP_LOG                   = $clog2(TP);
    localparam N_OVER_TP                = N/TP;

    localparam LARGE_STEPS              = (TOTAL_STEPS/TP_LOG);

    localparam LARGE_STEPS_LOG_NUM      = LARGE_STEPS*TP_LOG;
    localparam LAST_STEP                = TOTAL_STEPS - LARGE_STEPS_LOG_NUM;

    localparam LAST_ELEMENT_LOG         = (LAST_STEP == 0 ) ? 0 :  TOTAL_STEPS- LARGE_STEPS_LOG_NUM; 

    localparam IS_LAST_PROBLEM          = (LAST_ELEMENT_LOG == 0) ? 0 : 1;
    localparam TOTAL_STEP_NUMBERS_REAL  =  DIM == 0 ? 2 : (DIM == 1 ? 3 : 4); 
    localparam PSI_COUNT                = (N_OVER_TP)*((1<<LOGN1)-1)*(1<<(LOGN1)) + (N_OVER_TP)*((1<<LOGN2)-1)*(1<<(LOGN2)) + (N_OVER_TP)*((1<<LOGN3)-1)*(1<<(LOGN3)) + (N_OVER_TP)*((1<<LOGN4)-1)*(1<<(LOGN4));

    // Testbench variables
    reg INTT;
    reg clk;
    reg rst;
    reg START_NTT;
    reg [1:0] OP_TYPE;
    reg [LOGQ*TP-1:0] NTT_in;
    reg [LOGQ*TP-1:0] NTT_res;
    reg [LOGQ*(TP)-1:0] W_in;
    wire [LOGQ*TP-1:0] NTT_out;

    reg [LOGQ-1:0] a0_0 [0:N-1]; 
    reg [LOGQ-1:0] a0_0_2 [0:N-1]; 
    reg [LOGQ-1:0] res [0:N-1]; 
    reg [LOGQ-1:0] res2 [0:N-1]; 
    reg [LOGQ-1:0] q [0:6];
    reg [LOGQ-1:0] psi0  [0:N-1];

    reg [LOGQ-1:0] NTT_res_store [0:N-1]; 
    reg [LOGQ-1:0] NTT_res_store2 [0:N-1]; 
    reg [LOGQ-1:0] INTT_res_store [0:N-1]; 
    reg [LOGQ-1:0] INTT_res_store2 [0:N-1];


    reg [LOGQ-1:0] INTT_COEF_IN [0:N-1]; 
    reg [LOGQ-1:0] INTT_COEF_IN2 [0:N-1]; 
    reg [LOGQ-1:0] intt_psi0  [0:PSI_COUNT-1];
    reg [LOGQ-1:0] INTT_RES  [0:PSI_COUNT-1];
    reg [LOGQ-1:0] INTT_RES_2  [0:PSI_COUNT-1];

    reg [TP_LOG:0] ctr1;
    
    reg[LOGQH-1:0] q_tb;
    
    reg shuffle_mod;

    int flag, flag1;
    int flag_ntt1, flag_ntt_single, flag_ntt_batch, flag_intt1, flag_intt_single, flag_intt_batch;
    string cmd;

    // Test sequence
    integer i, j, k, k2, id11, idx_here, t;

    integer random_wait;
    integer random_wait_array [0:BATCH_SIZE-1];

    reg [31:0] input_idx_ctr, output_idx_ctr, input_idy_ctr, output_idy_ctr;
    reg input_state, output_state, batch_done;

    always #HP clk = ~clk;

    initial begin
        // ntt
        if (GEN_TEST_VEC) begin
            $sformat(cmd, "sh %s/test_vector_gen.sh %0d %0d %0d %0d %0d %0d %0d %0d %s 0", TEST_DIR, N, N1, N2, N3, N4, TP, DIM, LOGQ, PYTHON);
            $display("Executing: %s", cmd);
            $system(cmd);
        end
        $readmemh({TEST_DIR, "/ntt_in.txt"  }, a0_0);
        $readmemh({TEST_DIR, "/ntt_in2.txt"  }, a0_0_2);
        $readmemh({TEST_DIR, "/intt_in.txt"  }, INTT_COEF_IN);
        $readmemh({TEST_DIR, "/intt_in2.txt"  }, INTT_COEF_IN2);
        $readmemh({TEST_DIR, "/ntt_out.txt" }, res);      
        $readmemh({TEST_DIR, "/ntt_out2.txt" }, res2); 
        $readmemh({TEST_DIR, "/intt_out_wo_last.txt" }, INTT_RES);  
        $readmemh({TEST_DIR, "/intt_out_wo_last2.txt" }, INTT_RES_2);   
        $readmemh({TEST_DIR, "/psi_unique.txt"     }, psi0);
        $readmemh({TEST_DIR, "/psi_inv_unique.txt"     }, intt_psi0);
        $readmemh({TEST_DIR, "/q.txt"       }, q);    
    end

    initial begin

        $display("Simulation started.");

        clk = 1'b1;
        INTT = 1'b0;
        rst = 1'b0;
        OP_TYPE = 2'b0;
        START_NTT = 1'b0;
        NTT_in = 0;
        W_in = 0;
        shuffle_mod = 0;
        #FP;
        rst = 1'b1;
        #FP;
        rst = 1'b0;
        
        #FP;
        
        OP_TYPE = 2'd3;
        #FP;
        // Q-LOAD
        q_tb = q[0][LOGQ-1 -: LOGQH];

        #FP;
        OP_TYPE = 2'd0;

        #(FP*3);
        
        OP_TYPE = 2'b1;
        #FP;
        OP_TYPE = 2'b0;

        for (k = 0; k < N_OVER_TP ; k = k+1) begin
            for (j = 0; j < TP ; j = j + 1 ) begin
                if (k == N_OVER_TP-1 && j == TP-1) begin
                    W_in[(TP-j)*LOGQ-1-:LOGQ] = 0; 
                end else begin
                    W_in[(TP-j)*LOGQ-1-:LOGQ] = psi0[k*TP+j];
                end
                    
            end                
            #FP;
        end


        OP_TYPE = 2'b0;
        @(posedge clk);
        START_NTT = 1'b1;
        @(posedge clk);
        START_NTT = 1'b0;
        // Initialize inputs
        for (i = 0; i < DEPTH ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
            if (INTT == 1'b1) begin
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_COEF_IN[idx_here]};
            end else begin
                //idx_here = ((j*N_OVER_TP) + ((i & (SIZE0/TP-1)) * (N/SIZE0)) + (i/(SIZE0/TP))) & (N-1);
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0[idx_here]};
            end
                
            end
            @(posedge clk);
        end
        
        repeat(uut.LAT) begin
            @(posedge clk);
        end
        flag_ntt_single = 1;
        i = 0;
        $display("SINGLE NTT TEST STARTING");
        for (i = 0; i < DEPTH ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
                if (INTT == 1'b1) begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_RES[j+i*TP]};
                end else begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res[j+i*TP]};
                    NTT_res_store[j+i*TP] = NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
                end
                
            end
            if( NTT_out == NTT_res) begin 
                $display("CORRECT IDX: %d ", i);
            end
            else begin
                flag_ntt_single = 0;
                $display("WRONG IDX !!!!: %d ", i);
            end
            @(posedge clk);
        end


        $display("BATCH NTT TEST STARTING");

        input_state = 0;
        output_state = 0;
        input_idx_ctr = 0;
        output_idx_ctr = 0;
        input_idy_ctr = 0;
        output_idy_ctr = 0;
        batch_done = 0;
        k = 0;

        START_NTT = 1'b1;

        @(posedge clk);

        flag_ntt_batch = 1;
        flag_ntt1 = 1;

        random_wait_array[0] = 1;

        for (i = 1; i < BATCH_SIZE-1 ; i = i + 1) begin
            //random_wait = ($urandom(random_wait_array[i-1]) % MAX_BATCH_DELAY) + 1;
            random_wait = i+1;
            random_wait_array[i] = random_wait;
        end
        

        while (batch_done == 0) begin
            if (input_state == 0) begin
                if (input_idy_ctr == 0) begin
                    $display("BATCH NTT IDY: %d", input_idx_ctr);
                    START_NTT = 1'b0;
                end
                for (j = 0; j < TP; j = j + 1) begin
                    //idx_here = ((j*N_OVER_TP) + ((input_idy_ctr & (SIZE0/TP-1)) * (N/SIZE0)) + (input_idy_ctr/(SIZE0/TP))) & (N-1);
                    idx_here = (input_idy_ctr*TP + j) & (N-1);
                    if (input_idx_ctr[0] == 0) begin
                        NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0[idx_here]};
                    end
                    else begin
                        NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0_2[idx_here]};
                    end
                    
                end
                if (input_idy_ctr == DEPTH-1) begin
                    input_state = 1;
                    input_idy_ctr = 0;
                end
                else begin
                    input_idy_ctr = input_idy_ctr + 1;
                end
            end
            else begin
                if (input_idx_ctr == BATCH_SIZE-1) begin
                    
                end
                else if (input_idy_ctr == random_wait_array[input_idx_ctr]) begin
                    input_idy_ctr = 0;
                    input_state = 0;
                    START_NTT = 1'b1;
                    input_idx_ctr = input_idx_ctr + 1;
                end
                else begin
                    input_idy_ctr = input_idy_ctr + 1;
                end
            end

            

            if (k >= (uut.LAT + DEPTH)) begin
                if (output_state == 0) begin
                    i = output_idy_ctr;
                    if (i == 0) begin
                        flag_ntt1 = 1;
                    end
                    for ( j = 0; j < TP; j = j + 1) begin // For every stage
                        if (output_idx_ctr[0] == 0) begin
                            NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res[j+i*TP]};
                        end
                        else begin
                            NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res2[j+i*TP]};
                        end
                        
                    end
                    if( NTT_out == NTT_res) begin
                        $display("CORRECT IDX:%d - IDY:%d ", output_idx_ctr, output_idy_ctr);
                    end
                    else begin
                        flag_ntt1 = 0;
                        $display("WRONG IDX:%d -  IDY:%d ",  output_idx_ctr, output_idy_ctr);
                    end
                    if (output_idy_ctr == DEPTH-1) begin
                        if (flag_ntt1) begin
                            $display("BATCH: %d IS SUCCESSFUL", output_idx_ctr);        
                        end
                        else begin
                            flag_ntt_batch = 0;
                        end
                        if (flag_ntt_batch) begin
                            $display("PROCESSED BATCHES ARE SUCCESSFUL");
                        end
                        output_state = 1;
                        output_idy_ctr = 0;
                    end
                    else begin
                        output_idy_ctr = output_idy_ctr + 1;
                    end
                    
                end
                else begin
                    if (output_idx_ctr == (BATCH_SIZE-1)) begin
                        batch_done = 1;
                    end
                    else if (output_idy_ctr == random_wait_array[output_idx_ctr]) begin
                        output_idy_ctr = 0;
                        output_state = 0;
                        output_idx_ctr = output_idx_ctr + 1;
                        
                        
                    end
                    else begin
                        output_idy_ctr = output_idy_ctr + 1;
                    end
                end
            end

            
            ////////////// NEXT CYCLE //////////////////
            @(posedge clk);
            k = k + 1;
        end

        


        ////// INTT TESTS ////////

        INTT = 1'b1;
        rst = 1'b0;
        OP_TYPE = 2'b0;
        START_NTT = 1'b0;
        NTT_in = 0;
        W_in = 0;
        shuffle_mod = 0;
        #FP;

        #FP;
        OP_TYPE = 2'd3;
        #FP;
        //Q-LOAD
        q_tb = q[0][LOGQ-1 -: LOGQH];

        #FP;
        OP_TYPE = 2'd0;

        #(FP*3);
        
        OP_TYPE = 2'b1;
        #FP;
        OP_TYPE = 2'b0;


        for (k = 0; k < N_OVER_TP ; k = k+1) begin
            for (j = 0; j < TP ; j = j + 1 ) begin
                if (k == N_OVER_TP-1 && j == TP-1) begin
                    W_in[(TP-j)*LOGQ-1-:LOGQ] = 0; 
                end else begin
                    W_in[(TP-j)*LOGQ-1-:LOGQ] = intt_psi0[k*TP+j];
                end
                    
            end                
            #FP;
        end


        OP_TYPE = 2'b0;

        @(posedge clk);
        START_NTT = 1'b1;
        @(posedge clk);
        START_NTT = 1'b0;
        //Initialize inputs
        for (i = 0; i < DEPTH ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_COEF_IN[idx_here]};
            end
            @(posedge clk);
        end
        
        repeat(uut.LAT) begin
            @(posedge clk);
        end
        flag_intt_single = 1;
        i = 0;
        $display("SINGLE INTT TEST STARTING");
        for (i = 0; i < DEPTH ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
                NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_RES[j+i*TP]};
            end
            if( NTT_out == NTT_res) begin 
                $display("CORRECT IDX: %d ", i);
            end
            else begin
                flag_intt_single = 0;
                $display("WRONG IDX !!!!: %d ", i);
            end
            @(posedge clk);
        end


        
        


        $display("BATCH INTT TEST STARTING");

        input_state = 0;
        output_state = 0;
        input_idx_ctr = 0;
        output_idx_ctr = 0;
        input_idy_ctr = 0;
        output_idy_ctr = 0;
        batch_done = 0;
        k = 0;

        START_NTT = 1'b1;

        @(posedge clk);

        flag_intt_batch = 1;
        flag_intt1 = 1;

        while (batch_done == 0) begin
            if (input_state == 0) begin
                if (input_idy_ctr == 0) begin
                    $display("BATCH INTT IDY: %d", input_idx_ctr);
                    START_NTT = 1'b0;
                end
                for (j = 0; j < TP; j = j + 1) begin
                    idx_here = (input_idy_ctr*TP + j) & (N-1);
                    if (input_idx_ctr[0] == 0) begin
                        NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_COEF_IN[idx_here]};
                    end
                    else begin
                        NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_COEF_IN2[idx_here]};
                    end
                    
                end
                if (input_idy_ctr == DEPTH-1) begin
                    input_state = 1;
                    input_idy_ctr = 0;
                end
                else begin
                    input_idy_ctr = input_idy_ctr + 1;
                end
            end
            else begin
                if (input_idx_ctr == BATCH_SIZE-1) begin
                    
                end
                else if (input_idy_ctr == random_wait_array[input_idx_ctr]) begin
                    input_idy_ctr = 0;
                    input_state = 0;
                    START_NTT = 1'b1;
                    input_idx_ctr = input_idx_ctr + 1;
                end
                else begin
                    input_idy_ctr = input_idy_ctr + 1;
                end
            end

            

            if (k >= (uut.LAT + DEPTH)) begin
                if (output_state == 0) begin
                    i = output_idy_ctr;
                    if (i == 0) begin
                        flag_intt1 = 1;
                    end
                    for ( j = 0; j < TP; j = j + 1) begin // For every stage
                        if (output_idx_ctr[0] == 0) begin
                            NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_RES[j+output_idy_ctr*TP]};
                        end
                        else begin
                            NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_RES_2[j+output_idy_ctr*TP]};
                        end
                        
                    end
                    if( NTT_out == NTT_res) begin
                        $display("CORRECT IDX:%d - IDY:%d ", output_idx_ctr, output_idy_ctr);
                    end
                    else begin
                        flag_intt1 = 0;
                        $display("WRONG IDX:%d -  IDY:%d ",  output_idx_ctr, output_idy_ctr);
                    end
                    if (output_idy_ctr == DEPTH-1) begin
                        if (flag_intt1) begin
                            $display("BATCH: %d IS SUCCESSFUL", output_idx_ctr);        
                        end
                        else begin
                            flag_intt_batch = 0;
                        end
                        if (flag_intt_batch) begin
                            $display("PROCESSED BATCHES ARE SUCCESSFUL");
                        end
                        output_state = 1;
                        output_idy_ctr = 0;
                    end
                    else begin
                        output_idy_ctr = output_idy_ctr + 1;
                    end
                    
                end
                else begin
                    if (output_idx_ctr == (BATCH_SIZE-1)) begin
                        batch_done = 1;
                    end
                    else if (output_idy_ctr == random_wait_array[output_idx_ctr]) begin
                        output_idy_ctr = 0;
                        output_state = 0;
                        output_idx_ctr = output_idx_ctr + 1;
                    end
                    else begin
                        output_idy_ctr = output_idy_ctr + 1;
                    end
                end
            end
            //////////// NEXT CYCLE //////////////////
            @(posedge clk);
            k = k + 1;
        end

        if (flag_ntt_single) begin
                $display("SINGLE NTT TEST IS SUCCESSFUL. ALL COEFFICIENTS ARE CORRECT\n");        
        end
        else begin
            $display("FAIL IN SINGLE NTT TEST");
        end

        if (flag_ntt_batch) begin
            $display("BATCH NTT TEST IS SUCCESSFUL. \nALL BATCHESxCOEFFICIENTS ARE CORRECT\n");
        end
        else begin
            $display("SOME BATCHES FAILED\n");
        end

        if (flag_intt_single) begin
                $display("SINGLE INTT TEST IS SUCCESSFUL. ALL COEFFICIENTS ARE CORRECT\n");        
        end
        else begin
            $display("FAIL IN SINGLE INTT TEST");
        end

        if (flag_intt_batch) begin
            $display("BATCH INTT TEST IS SUCCESSFUL. \nALL BATCHESxCOEFFICIENTS ARE CORRECT\n");
        end
        else begin
            $display("SOME BATCHES FAILED\n");
        end

        $finish;

    end

    tp_ntt_top_w_shuffle #(
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
        .start(START_NTT),
        .op(OP_TYPE),
        .intt(INTT),
        .shuffle_mod(shuffle_mod),
        .qH(q_tb),
        .i_poly(NTT_in),
        .psi(W_in),
        .o_poly(NTT_out)
    );




endmodule
