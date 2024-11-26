from math import ceil, log, log2
from tp_oriented_twiddle_model import find_twiddle_map
import sys
import sympy
import math



def small_stage_model(N, TP, start1, TWIDDLE_file, TWIDDLE_tuple_map, cont_write): ##### AIM: to produce MERGED-NTT module with TP output
    input1 = []

    stage_nums = int(log2(TP))
    rest = [[0 for i in range(TP)] for i in range(stage_nums)]

    input1.append(start1)

    for elm in rest:
        input1.append(elm)

    TWIDDLE_used_arr = []

    for i in range(int(log2(TP))): #### fOR EVERY Stage
        for j in range(int(TP//2)): #### for every butterfly
            input1[i + 1][(((2*j)%(TP>>i))//(TP>>(i+1))) + ((2*j) % ((TP>>(i+1)))) + (((2*j)//(TP>>(i)))*(TP>>(i)))     ] =  input1[i][2*j    ] 
            input1[i + 1][(((2*j)%(TP>>i))//(TP>>(i+1))) + ((2*j) % ((TP>>(i+1)))) + (((2*j)//(TP>>(i)))*(TP>>(i))) + ((TP>>(i+1))*1)] =  input1[i][2*j + 1] 
            twiddle = TWIDDLE_tuple_map[(input1[i][2*j    ], input1[i][2*j + 1])]
            if twiddle not in TWIDDLE_used_arr:
                TWIDDLE_used_arr.append(twiddle)

    res = [0 for i in range(TP)]

    #for i in range(TP):
        #res[i] =  input1[int(log2(TP))-1][((i%(N//TP))*(TP*TP//N)+(i//(N//TP)))%TP]
    for twid in TWIDDLE_used_arr:
        TWIDDLE_file.write(str(hex(twid)[2:]) + "\t")
    if not cont_write:
        TWIDDLE_file.write("\n")

    return input1[int(log2(TP))-1]



def iterative_first_block1(input1, TP, n1, n2, size0, bram_skip):
    iter0_out = [[] for i in range(depth)]
    print("FIRSTTTTT: ", bram_skip, n1, n2)

    for ctr in range(depth):
        arr1 = [0 for i in range(TP)]
        for i in range(TP):
            #### STAGE 0 NTT ####
            #print(i, ((i%(TP//n1)))*(n1), ((i//(TP//n1))%2)*2, (i//(TP//n1))//2)
            #arr1[(((i%1))*(2) + (i//2) + ((i%2)//1)*2)%TP] = input1[ctr][i]
            #arr1[(((i%(TP//n1)))*(n1) )%TP] = input1[ctr][i]
            #print(((i%n1)*n1 + (i//(TP//2)) + ((i%(TP//2))//(TP//n1))*2)%TP, i)
            
            if not bram_skip:
                arr1[((i%(n2))*n1 + (i//(TP//2)) + ((i%(TP//2))//(TP//n1))*2)%TP] = input1[ctr][i]
            else:
                arr1[((i%(n1//2))*(2) + ((i%n1)//(n1//2)) + (i//(n1))*(n1))%TP] = input1[ctr][i]
                if ctr < 10:
                    print(((i%2)*(4) + ((i%8)//2) + (i//(2))*(2))%TP,i)
            #arr1.append(input1[ctr][i])
        
        #print("vv: ", input1[ctr])
        #print(arr1)



        calc_res_poly = [0 for i in range(TP)]
        
        for ntt_num in range(TP//n1):
            in_poly = arr1[ntt_num*n1:(ntt_num+1)*n1]
            #print("in1: ", in_poly)
            print(ntt_num)
            if ntt_num == TP//n1-1:
                cont_write = False
            else:
                cont_write = True
            print("cont ? ", cont_write)
            calc_ntt = small_stage_model(N, n1, in_poly, file1, TWIDDLE_tuple_map, cont_write)
            calc_res_poly[ntt_num*n1:(ntt_num+1)*n1] = calc_ntt

        
        calc_res = calc_res_poly

        #print("ca: ", calc_res)

        #print("ss: ", calc_res)

        arr_new = [0 for i in range(TP)]

        for i in range(TP):
            if not bram_skip:
                arr_new[((i//(TP//n2) + (i%(TP//n2))*n2)%TP+(ctr%(size0//TP)))%TP] = calc_res[i]
            else:
                arr_new[i] = calc_res[i]
            a = 0
        #print("rot: ", arr_new)
        
        
        iter0_out[ctr] = arr_new

    print("\n\nITERATION 0 OUT and ITERATION 1 IN: ")
    # for a in iter0_out:
    #     print(a)
    print("ITERATION 0 OUT and ITERATION 1 IN: \n\n")

    iter0_read = []

    for ctr in range(depth):
        ##### READ FROM BRAM

        bram_start = (ctr//(size0//TP))*(size0//TP)

        new_arr = []
        for i in range(TP):
            if not bram_skip:
                #print("de: ", bram_start+(i%(size0//TP)), (i + (ctr%(size0//TP))) % TP)
                new_arr.append(iter0_out[bram_start+(i%(size0//TP))][(i + (ctr%(size0//TP))) % TP])
            else:
                new_arr.append(iter0_out[ctr][i])
        #print("read: ", new_arr)
        iter0_read.append(new_arr)
         ##### READ FROM BRAM

    return iter0_read





def iterative_second_block(iter0_read, TP, n2, size0, size1, bram_skip):
    iter1_out = [[] for i in range(depth)]

    for ctr in range(depth):

        new_arr = iter0_read[ctr]

        in_arr = [0 for i in range(TP)]

        print("in_arr prev: ", new_arr)

        for i in range(TP):
            in_arr[i] = new_arr[((i//n2*n2) + ((i)%2)*(n2//2) + (i%n2)//2)%TP]

        #print("in_arr: ", in_arr)

        #### READ FROM BRAM

        #### NTT STAGE CALCULATION 2

        calc_res_poly = [0 for i in range(TP)]

        for ntt_num in range(TP//n2):
            in_poly = in_arr[ntt_num*n2:(ntt_num+1)*n2]
            #print("in1: ", in_poly)
            if ntt_num == TP//n2-1:
                cont_write = False
            else:
                cont_write = True
            calc_ntt = small_stage_model(N, n2, in_poly, file1, TWIDDLE_tuple_map, cont_write)
            calc_res_poly[ntt_num*n2:(ntt_num+1)*n2] = calc_ntt
        
        #print("res poly: ", calc_res_poly)

        #### NTT STAGE CALCULATION 2

        #### WRITE TO BRAM

        write_arr = [0 for i in range(TP)]

        for i in range(TP):
            if not bram_skip:
                write_arr[( (i) + ctr//((size0//TP)*(size1//TP)))%TP] = calc_res_poly[i]
            else:
                write_arr[i] = calc_res_poly[i]
        
        #print("deb: ", write_arr)
        #### WRITE TO BRAM

        iter1_out[ctr] = write_arr # Output Result


    print("\n\nITERATION 1 OUT and ITERATION 2 IN: ")
    #for a in iter1_out:
        #print(a)
    print("\n\nITERATION 1 OUT and ITERATION 2 IN: ")

    #### STAGE 1 NTT ####



    #### STAGE 2 NTT

    iter1_read = []

    for ctr in range(depth):
        #### READ FROM BRAM
        read_arr = [0 for i in range(TP)]
        #### 8-4-4 --> 0-4-8-12
        for i in range(TP):
            #print("dev: ", (((size0//TP)*(size1//TP))*i + (size0//TP)*(ctr%(size1//TP)) + (ctr//size1)  ) % depth, (i + (ctr//(size1//TP)) )%TP  )
            if not bram_skip:
                read_arr[i] = iter1_out[ (((size0//TP)*(size1//TP))*i + (size0//TP)*(ctr%(size1//TP)) + (ctr//size1)  ) % depth][(i + (ctr//(size1//TP)) )%TP]
            else:
                read_arr[i] = iter1_out[ctr][i]
        #print("rr: ", read_arr)
        iter1_read.append(read_arr)
    
    return iter1_read

MAX_TRIAL = 100000000

def ntt_friendly_prime_gen(logq, logqh, num_primes=None, debug=False, random=None):

    primes = []

    def core(qH):
        q = (1 << (logq - 1)) + 1 + (qH << (logq - logqh))
        if sympy.isprime(q) and q < (1 << logq) and q > (1 << (logq - 1)):
            if debug:
                print(q, hex(q), len(bin(q)[2:]), hex(q % (1 << (logq - logqh))), len(primes))
            primes.append(q)

    if random is None:
        for qH in range(1, pow(2, (logqh - 1))):
            core(qH)
            if num_primes is not None and len(primes) >= num_primes:
                return primes

    else:
        l = pow(2, (logqh - 1)) + 1
        for _ in range(MAX_TRIAL):
            qH = random.randint(1, l)
            core(qH)
            if num_primes is not None and len(primes) >= num_primes:
                return primes

    if debug:
        print(len(primes))

    return primes


if __name__ == "__main__":
    
    #q = 0x7ffe0001

    

   
    q_bit_size =  int(sys.argv[8])

    if q_bit_size == 60:
        width = 17
    else:
        width = 13
    

    k = q_bit_size # bit size

    LOGQ = q_bit_size

    if q_bit_size == 60:
        LOGQH = 17
    else:
        LOGQH = 15

    # prime_num_try = pow(2,k-1) + 1
    


    # for i in range(1,pow(2,20)):
    #     try1 = prime_num_try + (i<<18)
    #     if sympy.isprime(try1):
    #         print(try1, bin(try1)[2:], hex(try1)[2:], len(bin(try1)[2:]))
    #         break

    # random_prime = try1

    q = ntt_friendly_prime_gen(LOGQ, LOGQH, 1)[0]

    

    N = int(sys.argv[1])
    n1 = int(sys.argv[2])
    n2 = int(sys.argv[3])
    n3 = int(sys.argv[4])
    n4 = int(sys.argv[5])

    size0 = n1*n2
    size1 = n3*n4

    TP = int(sys.argv[6])

    TWIDDLE_tuple_map = find_twiddle_map(N, q, math.ceil(q_bit_size/width), width)

    file1 = open("test/W_in.txt", 'w+')

    
    choice = int(sys.argv[7])

    iterative_seven = False
    iterative_six   = False
    iterative_four  = False

    if choice == 0:
        iterative_four = True
    elif choice == 1:
        iterative_six = True
    elif choice == 2:
        iterative_seven = True

    

    


    assert N == n1*n2*n3*n4 , "ERRORRRR"

    depth = N//TP

    in1 = [[0 for j in range(TP)] for i in range(depth)]

    #### 32-8 --> (ctr%2)*2 + (ctr//2)
    #### 64-8 --> (ctr%2)*4 + (ctr//2)
    #### 

    input1 = []

    for ctr in range(depth):
        arr1 = []
        for i in range(TP):
            #### STAGE 0 NTT ####
            arr1.append((   (i)*(N//TP) + (ctr%(size0//TP))*(N//size0) + (ctr//(size0//TP))) % N)
        input1.append(arr1)
    #### STAGE 0 NTT ####

    #for a in input1:
        #print(a)


    if iterative_seven:
        iter_0_read = iterative_first_block1(input1, TP, n1, n2, size0, bram_skip=False)

        iter_1_read = iterative_second_block(iter_0_read, TP, n2, size0, size1, False)

        iter_2_read = iterative_first_block1(iter_1_read, TP, n3, n4, size1, bram_skip = False)

        iter_3_read = iterative_first_block1(iter_2_read, TP, n4, n3, size1, bram_skip = True)
    elif iterative_four:
        iter_0_read = iterative_first_block1(input1, TP, n1, n2, size0, bram_skip=False)

        iter_3_read = iterative_second_block(iter_0_read, TP, n2, n1, n1*n2, True)
    elif iterative_six:
        print("eee")
        iter_0_read = iterative_first_block1(input1, TP, n1, n2, size0, bram_skip=False)

        iter_1_read = iterative_second_block(iter_0_read, TP, n2, size0, size1, False)

        #iter_3_read = []
        iter_3_read = iterative_first_block1(iter_1_read, TP, n3, n4, size1, bram_skip = True)



    last1 = []
    for r in iter_3_read:
        for e in r:
            last1.append(e)
    
    print("check ? " , last1 == [i for i in range(N)])

    print("asdasd")


