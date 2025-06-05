`timescale 1ns / 1ps

module tp_ntt_tb();

    `include "tp_ntt.svh"

    // TP-NTT Parameters
    parameter LOGN          = 12;
    parameter LOGN1         = 5;
    parameter LOGN2         = 2;
    parameter LOGN3         = 5;
    parameter LOGTP         = 5;
    parameter LOGQ          = 60;
    parameter LOGQH         = 17;
    parameter NON_STD       = 1;
    parameter MORE_DSP      = 0;
    
 
    // Test-Bench Parameters
    parameter BATCH_SIZE    = 2;
    parameter BATCH_DELAY   = 1;
    parameter HP            = 5;
    parameter FP            = (2*HP);
    parameter TEST_DIR      = "../../../../../test";
    parameter PYTHON        = "/usr/bin/python3";
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
    reg INTT;
    reg clk;
    reg rst;
    reg START_NTT;
    reg [1:0] OP_TYPE;
    reg [LOGQ*TP-1:0] NTT_in;
    reg [LOGQ*TP-1:0] NTT_res;
    reg [LOGQ*(TP-1)-1:0] W_in;
    wire [LOGQ*TP-1:0] NTT_out;

    reg [LOGQ-1:0] a0_0 [0:N-1]; 
    reg [LOGQ-1:0] a0_0_2 [0:N-1]; 
    reg [LOGQ-1:0] res [0:N-1]; 
    reg [LOGQ-1:0] res2 [0:N-1]; 
    reg [LOGQ-1:0] q [0:6];
    reg [LOGQ-1:0] psi0  [0:psi_count-1];

    reg [LOGQ-1:0] NTT_res_store [0:N-1]; 
        reg [LOGQ-1:0] NTT_res_store2 [0:N-1]; 
    reg [LOGQ-1:0] INTT_res_store [0:N-1]; 
    reg [LOGQ-1:0] INTT_res_store2 [0:N-1];


    reg [LOGQ-1:0] INTT_COEF_IN [0:N-1]; 
    reg [LOGQ-1:0] intt_psi0  [0:psi_count-1];
    reg [LOGQ-1:0] INTT_RES  [0:psi_count-1];
    reg [LOGQ-1:0] INTT_RES_2  [0:psi_count-1];

    reg [TP_log:0] ctr1;
    
    reg[LOGQH-1:0] q_tb;
    
    reg shuffle_mod;

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
        $readmemh({TEST_DIR, "/ntt_in2.txt"  }, a0_0_2);
        $readmemh({TEST_DIR, "/intt_in.txt"  }, INTT_COEF_IN);
        $readmemh({TEST_DIR, "/ntt_out.txt" }, res);      
        $readmemh({TEST_DIR, "/ntt_out2.txt" }, res2); 
        $readmemh({TEST_DIR, "/intt_out.txt" }, INTT_RES);  
        $readmemh({TEST_DIR, "/intt_out2.txt" }, INTT_RES_2);   
        $readmemh({TEST_DIR, "/psi.txt"     }, psi0);
        $readmemh({TEST_DIR, "/psi_inv.txt"     }, intt_psi0);
        $readmemh({TEST_DIR, "/q.txt"       }, q);    
    end

    initial begin

        $display("Simulation started.");

        clk = 1'b0;
        INTT = 1'b0;
        rst = 1'b1;
        OP_TYPE = 2'b0;
        START_NTT = 1'b0;
        NTT_in = 0;
        W_in = 0;
        shuffle_mod = 0;
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

        // #(FP*3);
        
        // OP_TYPE = 2'b1;
        // #FP;

        // for (i = 0 ; i < total_step_numbers_real ; i = i+1) begin
        //     if(is_last_problem && i == 1) begin
        //         ctr1 = ((1<<LOGN2)-1)*(TP>>LOGN2);
        //     end
        //     else begin
        //         ctr1 = TP-4'b1;
        //     end

        //     for (k = 0; k < N_over_TP ; k = k+1) begin
        //         if (i == 0) begin
        //             for (j = 0; j < TP-1 ; j = j + 1 ) begin
        //                 //id11 = 0 + k * (TP-1) + j;
        //                 if(j<((1<<LOGN1)-1)*(TP>>LOGN1)) begin
        //                     id11 = 0 + k * ((1<<LOGN1)-1)*(TP>>LOGN1) + j;
        //                     if (INTT == 1'b1) begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
        //                     end else begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
        //                     end
                            
        //                 end
        //                 else begin
        //                     id11 = N_over_TP*(TP-1) + k * ctr1 + j;
        //                     W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
        //                 end
                        
        //             end
        //         end
        //         else if (i == 1) begin
        //             for (j = 0; j < TP-1 ; j = j + 1 ) begin
        //                 if(j<((1<<LOGN2)-1)*(TP>>LOGN2)) begin
        //                     id11 = N_over_TP*((1<<LOGN1)-1)*(TP>>LOGN1) + k * ((1<<LOGN2)-1)*(TP>>LOGN2) + j;
        //                     if (INTT == 1'b1) begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
        //                     end else begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
        //                     end
        //                 end
        //                 else begin
        //                     id11 = N_over_TP*(TP-1) + k * ctr1 + j;
        //                     W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
        //                 end
                        
        //             end
        //         end else if (i == 2) begin
        //             for (j = 0; j < TP-1 ; j = j + 1 ) begin

        //                 if(j<((1<<LOGN3)-1)*(TP>>LOGN3)) begin
        //                     id11 = N_over_TP*(((1<<LOGN1)-1)*(TP>>LOGN1) + ((1<<LOGN2)-1)*(TP>>LOGN2)) + k * ((1<<LOGN3)-1)*(TP>>LOGN3) + j;
        //                     if (INTT == 1'b1) begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
        //                     end else begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
        //                     end
        //                 end
        //                 else begin
        //                     id11 = N_over_TP*(TP-1) + k * ctr1 + j;
        //                     W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
        //                 end
        //             end
        //         end
        //         else if (i == 3) begin
        //             for (j = 0; j < TP-1 ; j = j + 1 ) begin

        //                 if(j<((1<<LOGN4)-1)*(TP>>LOGN4)) begin
        //                     id11 = N_over_TP*(((1<<LOGN1)-1)*(TP>>LOGN1) + ((1<<LOGN2)-1)*(TP>>LOGN2) + ((1<<LOGN3)-1)*(TP>>LOGN3)) + k * ((1<<LOGN4)-1)*(TP>>LOGN4) + j;
        //                     if (INTT == 1'b1) begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
        //                     end else begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
        //                     end
        //                 end
        //                 else begin
        //                     id11 = N_over_TP*(TP-1) + k * ctr1 + j;
        //                     W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
        //                 end
        //             end
        //         end
        //         #FP;
        //     end
            
            
        // end
        
        // OP_TYPE = 2'b0;
        // #(FP*5);
        // //OP_TYPE = 3'd2;
        // @(posedge clk);
        // @(posedge clk);
        // START_NTT = 1'b1;
        // @(posedge clk);
        // START_NTT = 1'b0;
        // // Initialize inputs
        // for (i = 0; i < depth ; i = i + 1) begin
        //     for ( j = 0; j < TP; j = j + 1) begin // For every stage
        //     if (INTT == 1'b1) begin
        //         idx_here = (i*TP + j) & (N-1);
        //         NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_COEF_IN[idx_here]};
        //     end else begin
        //         idx_here = (i*TP + j) & (N-1);
        //         NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0[idx_here]};
        //     end
                
        //     end
        //     @(posedge clk);
        // end
        
        // repeat(uut.LAT) begin
        //     @(posedge clk);
        // end
        // flag = 1;
        // i = 0;
        // $display("SINGLE NTT TEST STARTING");
        // for (i = 0; i < depth ; i = i + 1) begin
        //     for ( j = 0; j < TP; j = j + 1) begin // For every stage
        //         if (INTT == 1'b1) begin
        //             NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_RES[j+i*TP]};
        //         end else begin
        //             NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res[j+i*TP]};
        //             NTT_res_store[j+i*TP] = NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
        //         end
                
        //     end
        //     if( NTT_out == NTT_res) begin 
        //         $display("CORRECT IDX: %d ", i);
        //     end
        //     else begin
        //         flag = 0;
        //         $display("WRONG IDX !!!!: %d ", i);
        //     end
        //     @(posedge clk);
        // end
        // if (flag) begin
        //         $display("SINGLE NTT TEST IS SUCCESSFUL. ALL COEFFICIENTS ARE CORRECT");        
        // end
        // else begin
        //     $display("FAIL IN SINGLE NTT TEST");
        // end
        
        // #(FP*(4'd12*depth))
        
        // #(10*FP);
        // OP_TYPE = 2'b0;
        
        
        // INTT = 1'b1;
        // OP_TYPE = 2'b0;
        // START_NTT = 1'b0;
        // shuffle_mod = 1'b1;
        // NTT_in = 0;
        // W_in = 0;
        // #FP;


        // #FP;
        // OP_TYPE = 2'd0;

        // #(FP*3);
        
        // OP_TYPE = 2'b1;
        // #FP;

        // for (i = 0 ; i < total_step_numbers_real ; i = i+1) begin
        //     if(is_last_problem && i == 1) begin
        //         ctr1 = ((1<<LOGN2)-1)*(TP>>LOGN2);
        //     end
        //     else begin
        //         ctr1 = TP-4'b1;
        //     end

        //     for (k = 0; k < N_over_TP ; k = k+1) begin
        //         if (i == 0) begin
        //             for (j = 0; j < TP-1 ; j = j + 1 ) begin
        //                 //id11 = 0 + k * (TP-1) + j;
        //                 if(j<((1<<LOGN1)-1)*(TP>>LOGN1)) begin
        //                     id11 = 0 + k * ((1<<LOGN1)-1)*(TP>>LOGN1) + j;
        //                     if (INTT == 1'b1) begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
        //                     end else begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
        //                     end
                            
        //                 end
        //                 else begin
        //                     id11 = N_over_TP*(TP-1) + k * ctr1 + j;
        //                     W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
        //                 end
                        
        //             end
        //         end
        //         else if (i == 1) begin
        //             for (j = 0; j < TP-1 ; j = j + 1 ) begin
        //                 if(j<((1<<LOGN2)-1)*(TP>>LOGN2)) begin
        //                     id11 = N_over_TP*((1<<LOGN1)-1)*(TP>>LOGN1) + k * ((1<<LOGN2)-1)*(TP>>LOGN2) + j;
        //                     if (INTT == 1'b1) begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
        //                     end else begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
        //                     end
        //                 end
        //                 else begin
        //                     id11 = N_over_TP*(TP-1) + k * ctr1 + j;
        //                     W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
        //                 end
                        
        //             end
        //         end else if (i == 2) begin
        //             for (j = 0; j < TP-1 ; j = j + 1 ) begin

        //                 if(j<((1<<LOGN3)-1)*(TP>>LOGN3)) begin
        //                     id11 = N_over_TP*(((1<<LOGN1)-1)*(TP>>LOGN1) + ((1<<LOGN2)-1)*(TP>>LOGN2)) + k * ((1<<LOGN3)-1)*(TP>>LOGN3) + j;
        //                     if (INTT == 1'b1) begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
        //                     end else begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
        //                     end
        //                 end
        //                 else begin
        //                     id11 = N_over_TP*(TP-1) + k * ctr1 + j;
        //                     W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
        //                 end
        //             end
        //         end
        //         else if (i == 3) begin
        //             for (j = 0; j < TP-1 ; j = j + 1 ) begin

        //                 if(j<((1<<LOGN4)-1)*(TP>>LOGN4)) begin
        //                     id11 = N_over_TP*(((1<<LOGN1)-1)*(TP>>LOGN1) + ((1<<LOGN2)-1)*(TP>>LOGN2) + ((1<<LOGN3)-1)*(TP>>LOGN3)) + k * ((1<<LOGN4)-1)*(TP>>LOGN4) + j;
        //                     if (INTT == 1'b1) begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
        //                     end else begin
        //                         W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
        //                     end
        //                 end
        //                 else begin
        //                     id11 = N_over_TP*(TP-1) + k * ctr1 + j;
        //                     W_in[(TP-1-j)*LOGQ-1-:LOGQ] = 0;
        //                 end
        //             end
        //         end
        //         #FP;
        //     end
            
            
        // end
        // OP_TYPE = 2'b0;
        // #(FP*5);
        
        
        
        // // INTT TEST START
        // OP_TYPE = 2'b0;
        // #(FP*5);
        // //OP_TYPE = 3'd2;
        // @(posedge clk);
        // @(posedge clk);
        // START_NTT = 1'b1;
        // @(posedge clk);
        // START_NTT = 1'b0;
        // // Initialize inputs
        // for (i = 0; i < depth ; i = i + 1) begin
        //     for ( j = 0; j < TP; j = j + 1) begin // For every stage
        //     if (INTT == 1'b1) begin
        //         idx_here = (i*TP + j) & (N-1);
        //         NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {NTT_res_store[idx_here]};
        //     end
                
        //     end
        //     @(posedge clk);
        // end
        
        // repeat(uut.LAT) begin
        //     @(posedge clk);
        // end
        
        // flag = 1;
        // i = 0;
        // $display("INTT TEST STARTING");
        // for (i = 0; i < depth ; i = i + 1) begin
        //     for ( j = 0; j < TP; j = j + 1) begin // For every stage
        //         if (INTT == 1'b1) begin
        //             NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_RES[j+i*TP]};
        //             INTT_res_store[j+i*TP] =  NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
        //         end else begin
        //             NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res[j+i*TP]};
        //             NTT_res_store[j+i*TP] =  NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
        //         end
                
        //     end
        //     if( NTT_out == NTT_res) begin 
        //         $display("CORRECT INTT IDX: %d ", i);
        //     end
        //     else begin
        //         flag = 0;
        //         $display("WRONG INTT IDX !!!!: %d ", i);
        //     end
        //     @(posedge clk);
        // end
        // if (flag) begin
        //         $display("SINGLE INTT TEST IS SUCCESSFUL. ALL COEFFICIENTS ARE CORRECT");        
        // end
        // else begin
        //     $display("FAIL IN SINGLE INTT TEST");
        // end
        
        // #(10*FP);
        // OP_TYPE = 2'b0;
        
        
        OP_TYPE = 2'b0;
        #(FP*5);
        #(FP*(4'd12*depth))
        
        INTT = 1'b0;
        OP_TYPE = 2'b0;
        START_NTT = 1'b0;
        shuffle_mod = 1'b0;
        NTT_in = 0;
        W_in = 0;
        #FP;


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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
                            
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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
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
            if (INTT == 1'b1) begin
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_COEF_IN[idx_here]};
            end else begin
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0[idx_here]};
            end
                
            end
            @(posedge clk);
        end
        for (i = 0; i < depth ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
            if (INTT == 1'b1) begin
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_COEF_IN[idx_here]};
            end else begin
                //idx_here = ((j*N_over_TP) + ((i & (size0/TP-1)) * (N/size0)) + (i/(size0/TP))) & (N-1);
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0_2[idx_here]};
            end
                
            end
            @(posedge clk);
        end
        
        repeat(uut.LAT-depth) begin
            @(posedge clk);
        end
        flag = 1;
        i = 0;
        $display("DOUBLE NTT TEST STARTING");
        for (i = 0; i < depth ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
                if (INTT == 1'b1) begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0[j+i*TP]};
                end else begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res[j+i*TP]};
                    NTT_res_store[j+i*TP] = NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
                end
                
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
        for (i = 0; i < depth ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
                if (INTT == 1'b1) begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0_2[j+i*TP]};
                end else begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res2[j+i*TP]};
                    NTT_res_store2[j+i*TP] = NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
                end
                
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
                $display("DOUBLE NTT TEST IS SUCCESSFUL. ALL COEFFICIENTS ARE CORRECT");        
        end
        else begin
            $display("FAIL IN DOUBLE NTT TEST");
        end

        OP_TYPE = 2'b0;
        #(FP*5);
        #(FP*(4'd12*depth))

        INTT = 1'b1;
        OP_TYPE = 2'b0;
        START_NTT = 1'b0;
        shuffle_mod = 1'b1;
        NTT_in = 0;
        W_in = 0;
        #FP;


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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
                            
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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
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
            if (INTT == 1'b1) begin
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {NTT_res_store[idx_here]};
            end else begin
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0[idx_here]};
            end
                
            end
            @(posedge clk);
        end
        for (i = 0; i < depth ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
            if (INTT == 1'b1) begin
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {NTT_res_store2[idx_here]};
            end else begin
                //idx_here = ((j*N_over_TP) + ((i & (size0/TP-1)) * (N/size0)) + (i/(size0/TP))) & (N-1);
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0_2[idx_here]};
            end
                
            end
            @(posedge clk);
        end
        
        repeat(uut.LAT-depth) begin
            @(posedge clk);
        end
        flag = 1;
        i = 0;
        $display("DOUBLE INTT TEST STARTING");
        for (i = 0; i < depth ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
                if (INTT == 1'b1) begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_RES[j+i*TP]};
                    INTT_res_store[j+i*TP] = NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
                end else begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res[j+i*TP]};
                    NTT_res_store[j+i*TP] = NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
                end
                
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
        for (i = 0; i < depth ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
                if (INTT == 1'b1) begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_RES_2[j+i*TP]};
                    INTT_res_store2[j+i*TP] = NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
                end else begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res2[j+i*TP]};
                    NTT_res_store2[j+i*TP] = NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
                end
                
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
                $display("DOUBLE INTT TEST IS SUCCESSFUL. ALL COEFFICIENTS ARE CORRECT");        
        end
        else begin
            $display("FAIL IN DOUBLE INTT TEST");
        end

        #(FP*5);
        #(FP*(4'd12*depth))

        INTT = 1'b0;
        OP_TYPE = 2'b0;
        START_NTT = 1'b0;
        shuffle_mod = 1'b1;
        NTT_in = 0;
        W_in = 0;
        #FP;


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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
                            
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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
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
                            if (INTT == 1'b1) begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = intt_psi0[id11];
                            end else begin
                                W_in[(TP-1-j)*LOGQ-1-:LOGQ] = psi0[id11];
                            end
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
            if (INTT == 1'b1) begin
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_COEF_IN[idx_here]};
            end else begin
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_res_store[idx_here]};
            end
                
            end
            @(posedge clk);
        end
        for (i = 0; i < depth ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
            if (INTT == 1'b1) begin
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_COEF_IN[idx_here]};
            end else begin
                //idx_here = ((j*N_over_TP) + ((i & (size0/TP-1)) * (N/size0)) + (i/(size0/TP))) & (N-1);
                idx_here = (i*TP + j) & (N-1);
                NTT_in[(TP-(j))*LOGQ-1-:LOGQ] = {INTT_res_store2[idx_here]};
            end
                
            end
            @(posedge clk);
        end
        
        repeat(uut.LAT-depth) begin
            @(posedge clk);
        end
        flag = 1;
        i = 0;
        $display("DOUBLE NTT WITH SHUFFLE TEST STARTING");
        for (i = 0; i < depth ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
                if (INTT == 1'b1) begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0[j+i*TP]};
                end else begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res[j+i*TP]};
                    NTT_res_store[j+i*TP] = NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
                end
                
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
        for (i = 0; i < depth ; i = i + 1) begin
            for ( j = 0; j < TP; j = j + 1) begin // For every stage
                if (INTT == 1'b1) begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {a0_0_2[j+i*TP]};
                end else begin
                    NTT_res[(TP-(j))*LOGQ-1-:LOGQ] = {res2[j+i*TP]};
                    NTT_res_store2[j+i*TP] = NTT_out[(TP-(j))*LOGQ-1-:LOGQ];
                end
                
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
                $display("DOUBLE NTT TEST WITH SHUFFLE IS SUCCESSFUL. ALL COEFFICIENTS ARE CORRECT");        
        end
        else begin
            $display("FAIL IN DOUBLE NTT WITH SHUFFLE TEST");
        end

        OP_TYPE = 2'b0;
        #(FP*5);
        #(FP*(4'd12*depth))
        
        $finish;

    end

    // tp_ntt_top #(
    //     .LOGN    (LOGN    ),
    //     .LOGN1   (LOGN1   ),
    //     .LOGN2   (LOGN2   ),
    //     .LOGN3   (LOGN3   ),
    //     .LOGTP   (LOGTP   ),
    //     .LOGQ    (LOGQ    ),
    //     .LOGQH   (LOGQH   ),
    //     .NON_STD (NON_STD ),
    //     .MORE_DSP(MORE_DSP)
    // ) uut (
    //     .clk(clk),
    //     .rst(rst),
    //     .start(START_NTT),
    //     .op(OP_TYPE),
    //     .intt(INTT),
    //     .qH(q_tb),
    //     .i_poly(NTT_in),
    //     .psi(W_in),
    //     .o_poly(NTT_out)
    // );

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
