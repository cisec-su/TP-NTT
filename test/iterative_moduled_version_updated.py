from math import ceil, log, log2
from tp_oriented_twiddle_model import find_twiddle_map, find_twiddle_map_INTT, nth_root_of_unity
import sys
import sympy
import math
from tp_ntt_api import * 


def bitreverse(value, width):
    """
    Reverse the bits of a number within a specified bit width.

    :param value: The integer value to reverse.
    :param width: The bit width (number of bits to reverse).
    :return: The bit-reversed integer.
    """
    reversed_value = 0
    for i in range(width):
        bit = (value >> i) & 1  # Extract the i-th bit
        reversed_value |= (bit << (width - 1 - i))  # Set the reversed position
    return reversed_value

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
            print((input1[i][2*j    ], input1[i][2*j + 1]))
            if twiddle not in TWIDDLE_used_arr:
                TWIDDLE_used_arr.append(twiddle)

    res = [0 for i in range(TP)]

    for twid in TWIDDLE_used_arr:
        TWIDDLE_file.write(str(hex(twid)[2:]) + "\t")
    if not cont_write:
        TWIDDLE_file.write("\n")

    return input1[int(log2(TP))-1]



def iterative_first_block1(input1, TP, n1, n2, size0, bram_skip, IDX, verbose, file_in, TWIDDLE_tuple_map):
    iter0_out = [[] for i in range(depth)]

    if verbose:
        print("BLOCK IDX: ", IDX)

    for ctr in range(depth):
        arr1 = [0 for i in range(TP)]
        if verbose:
            print("AAAA: ", input1[ctr])
        for i in range(TP):
            if not bram_skip:
                #arr1[((i%(n2))*n1 + (i//(TP//2)) + ((i%(TP//2))//(TP//n1))*2)%TP] = input1[ctr][i]
                #arr1[i%2 + ((i%4))//2*8 + (i%8)//4*4 + (i//8)*2] = input1[ctr][i]
                #arr1[i%2 + (i%4)//2*4 + (i//4)*2] = input1[ctr][i] # 8-8 8
                #arr1[i%2 + (i%4)//2*(TP//2) + ((i%(TP//2))//4)*4 + (i//(TP//2))*2 ] = input1[ctr][i]
                #print(i%2 + (i%4)//2*16 + (i%8)//4*8 + (i%16)//8*4 + (i//16)*2)
                #arr1[i%2 + (i%4)//2*16 + (i%8)//4*8 + (i%16)//8*4 + (i//16)*2] = input1[ctr][i]
                arr1[i%2 + (i%4)//2*(TP//2) + (i%8)//4*(TP//4) + (i%16)//8*(TP//8) + (i%32)//16*(TP//16) + (i%64)//32*(TP//32) + (i%128)//64*(TP//64) + (i//128)*(TP//128)] = input1[ctr][i]
            else:
                #arr1[((i%(n1//2))*(2) + ((i%n1)//(n1//2)) + (i//(n1))*(n1))%TP] = input1[ctr][i]
                arr1[i%2 + (i%4)//2*(TP//2) + (i%8)//4*(TP//4) + (i%16)//8*(TP//8) + (i%32)//16*(TP//16) + (i%64)//32*(TP//32) + (i%128)//64*(TP//64) + (i//128)*(TP//128)] = input1[ctr][i]

        if verbose:
            print("NTT_CORE INPUT: ", ctr , arr1)



        calc_res_poly = [0 for i in range(TP)]
        
        for ntt_num in range(TP//n1):
            in_poly = arr1[ntt_num*n1:(ntt_num+1)*n1]
            if ntt_num == TP//n1-1:
                cont_write = False
            else:
                cont_write = True
            calc_ntt = small_stage_model(N, n1, in_poly, file_in, TWIDDLE_tuple_map, cont_write)
            calc_res_poly[ntt_num*n1:(ntt_num+1)*n1] = calc_ntt

        
        calc_res = calc_res_poly

        if verbose:
            print("NTT_CORE OUTPUT and AUTOMORPHISM INPUT: ", ctr , calc_res)

        arr_new = [0 for i in range(TP)]

        for i in range(TP):
            if not bram_skip:
                #arr_new[i] = calc_res[((((i-(ctr%(size0//TP)))%TP)//(TP//n2) + (((i-(ctr%(size0//TP)))%TP)%(TP//n2))*n2)%TP)%TP]
                arr_new[i] = calc_res[(((i - (ctr%(size0//TP)))%TP)//n2 + ((i - (ctr%(size0//TP)))%n2)*(TP//n2))%TP]
                #print("new: ", ((i - (ctr%(size0//TP)))//n2 + (((i - (ctr%(size0//TP))))%n2)*2)%TP, i)
                #print("prev: ", i, ((i//(TP//n2) + (i%(TP//n2))*n2)%TP+(ctr%(size0//TP)))%TP)
                #arr_new[((i//(TP//n2) + (i%(TP//n2))*n2)%TP+(ctr%(size0//TP)))%TP] = calc_res[i]
            else:
                arr_new[i] = calc_res[i]
            a = 0

        if verbose:        
            print("AUTOMORPHISM INPUT SHIFTED for di00 BRAM", ctr , arr_new)
        
        
        iter0_out[ctr] = arr_new

    if verbose:
        print("\n\nITERATION " + str(IDX) + " OUT and ITERATION " + str(IDX + 1) + " IN , AFTER BRAM WRITE: ")
        for a in iter0_out:
            print(a)
        print("\n\nITERATION " + str(IDX) + " OUT and ITERATION " + str(IDX + 1) + " IN , AFTER BRAM WRITE:")

    iter0_read = []

    for ctr in range(depth):
        ##### READ FROM BRAM

        bram_start = (ctr//(size0//TP))*(size0//TP)

        new_arr = []
        for i in range(TP):
            if not bram_skip:
                new_arr.append(iter0_out[bram_start+(i%(size0//TP))][(i + (ctr%(size0//TP))) % TP])
            else:
                new_arr.append(iter0_out[ctr][i])
        if verbose:
            print("AUTOMORPHISM BRAM READ for do000 BRAM for next NTT BLOCK", ctr , new_arr)
        iter0_read.append(new_arr)
         ##### READ FROM BRAM

    return iter0_read





def iterative_second_block(iter0_read, TP, n2, size0, size1, bram_skip, IDX, verbose, file_in, TWIDDLE_tuple_map):
    iter1_out = [[] for i in range(depth)]

    if verbose:
        print("BLOCK IDX: ", IDX)

    for ctr in range(depth):

        new_arr = iter0_read[ctr]
        in_arr = [0 for i in range(TP)]

        if verbose:
            print("BEFORE: ", ctr, new_arr)

        for i in range(TP):
            #in_arr[i] = new_arr[((i//n2*n2) + ((i)%2)*(n2//2) + (i%n2)//2)%TP]
            #in_arr[i%2 + (i%4)//2*4 + (i//4)*2] = new_arr[i] # --> 8-8
            #in_arr[i%2 + (i%(TP//2))//2*(TP//2) + (i//(TP//2))*2] = new_arr[i]
            print(i,i%2 + ((i%n2)%4)//2*(n2//2) + ((i%n2)%8)//4*(n2//4) + ((i%n2)%16)//8*(n2//8) + ((i%n2)%32)//16*(n2//16) + (((i%n2)%64)//32)*(n2//32) + (((i%n2)%128)//64)*(n2//64) + ((i%n2)//128)*(n2//128) + (i//n2)*n2)
            in_arr[i%2 + ((i%n2)%4)//2*(n2//2) + ((i%n2)%8)//4*(n2//4) + ((i%n2)%16)//8*(n2//8) + ((i%n2)%32)//16*(n2//16) + (((i%n2)%64)//32)*(n2//32) + (((i%n2)%128)//64)*(n2//64) + ((i%n2)//128)*(n2//128) + (i//n2)*n2] = new_arr[i]

        if verbose:
            print("NTT_CORE INPUT: ", ctr , in_arr)

        #### NTT STAGE CALCULATION 2

        calc_res_poly = [0 for i in range(TP)]

        for ntt_num in range(TP//n2):
            in_poly = in_arr[ntt_num*n2:(ntt_num+1)*n2]
            if ntt_num == TP//n2-1:
                cont_write = False
            else:
                cont_write = True
            calc_ntt = small_stage_model(N, n2, in_poly, file_in, TWIDDLE_tuple_map, cont_write)
            calc_res_poly[ntt_num*n2:(ntt_num+1)*n2] = calc_ntt
    
        if verbose:
            print("NTT_CORE OUTPUT and AUTOMORPHISM INPUT: ", ctr , calc_res_poly)
        #### NTT STAGE CALCULATION 2

        #### WRITE TO BRAM

        write_arr = [0 for i in range(TP)]

        for i in range(TP):
            if not bram_skip:
                #write_arr[( (i) + ctr//((size0//TP)*(size1//TP)))%TP] = calc_res_poly[i]
                write_arr[( (i) + ctr//((size0//TP)))%TP] = calc_res_poly[i]
            else:
                write_arr[i] = calc_res_poly[i]

        if verbose:   
            print("AUTOMORPHISM INPUT SHIFTED for di00 BRAM", ctr , write_arr)

        #### WRITE TO BRAM

        iter1_out[ctr] = write_arr # Output Result


    if verbose:
        print("\n\nITERATION " + str(IDX) + " OUT and ITERATION " + str(IDX + 1) + " IN , AFTER BRAM WRITE: ")
        for a in iter1_out:
            print(a)
        print("\n\nITERATION " + str(IDX) + " OUT and ITERATION " + str(IDX + 1) + " IN , AFTER BRAM WRITE: ")

    #### STAGE 1 NTT ####



    #### STAGE 2 NTT

    iter1_read = []

    for ctr in range(depth):
        #### READ FROM BRAM
        read_arr = [0 for i in range(TP)]
        for i in range(TP):
            if not bram_skip:
                read_arr[i] = iter1_out[ (((size0//TP))*i + (size0//TP*size1//TP)*(ctr%(size1//TP)) + (ctr//size1)  ) % depth][(i + (ctr//(size1//TP)) )%TP]
            else:
                read_arr[i] = iter1_out[ctr][i]
        if verbose:
            print("AUTOMORPHISM BRAM READ for do000 BRAM for next NTT BLOCK", ctr , read_arr)
        iter1_read.append(read_arr)
        #### READ FROM BRAM
    
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


# if __name__ == "__main__":
    
#     N = int(sys.argv[1])
#     n1 = int(sys.argv[2])
#     n2 = int(sys.argv[3])
#     n3 = int(sys.argv[4])
#     n4 = int(sys.argv[5])
#     TP = int(sys.argv[6])
#     choice = int(sys.argv[7])
#     q_bit_size = int(sys.argv[8])
#     test_dir = sys.argv[9]
#     verbose = int(sys.argv[10]) == 1

#     if q_bit_size == 60:
#         width = 17
#     else:
#         width = 13
    

#     k = q_bit_size # bit size

#     LOGQ = q_bit_size

#     if q_bit_size == 60:
#         LOGQH = 17
#     else:
#         LOGQH = 15

#     q = ntt_friendly_prime_gen(LOGQ, LOGQH, 1)[0]

#     size0 = n1*n2
#     size1 = n3*n4


#     TWIDDLE_tuple_map = find_twiddle_map(N, q, math.ceil(q_bit_size/width), width)

#     file1 = open(f"{test_dir}/psi.txt", 'w+')

    

#     iterative_seven = False
#     iterative_six   = False
#     iterative_four  = False

#     if choice == 0:
#         iterative_four = True
#     elif choice == 1:
#         iterative_six = True
#     elif choice == 2:
#         iterative_seven = True

#     assert N == n1*n2*n3*n4 , "ERRORRRR"

#     depth = N//TP

#     in1 = [[0 for j in range(TP)] for i in range(depth)]

#     input1 = []

#     for ctr in range(depth):
#         arr1 = []
#         for i in range(TP):
#             # Generate correct input sequence
#             arr1.append((   (i)*(N//TP) + (ctr%(size0//TP))*(N//size0) + (ctr//(size0//TP))) % N)
#         input1.append(arr1)


#     if iterative_seven:
#         iter_0_read = iterative_first_block1(input1, TP, n1, n2, size0, False, 0, verbose)

#         iter_1_read = iterative_second_block(iter_0_read, TP, n2, size0, size1, False, 1, verbose)

#         iter_2_read = iterative_first_block1(iter_1_read, TP, n3, n4, size1, False, 2, verbose)

#         iter_3_read = iterative_first_block1(iter_2_read, TP, n4, n3, size1, True, 3, verbose)
#     elif iterative_four:
#         iter_0_read = iterative_first_block1(input1, TP, n1, n2, size0, False, 0, verbose)

#         iter_3_read = iterative_second_block(iter_0_read, TP, n2, n1, n1*n2, True, 1, verbose)
#     elif iterative_six:
#         iter_0_read = iterative_first_block1(input1, TP, n1, n2, size0, False, 0, verbose)

#         iter_1_read = iterative_second_block(iter_0_read, TP, n2, size0, size1, False, 1, verbose)

#         iter_3_read = iterative_first_block1(iter_1_read, TP, n3, n4, size1, True, 2, verbose)


#     # Check can you generate all elements in correct order, 0 to N-1
#     last1 = []
#     for r in iter_3_read:
#         for e in r:
#             last1.append(e)
    
#     print("check ? " , last1 == [i for i in range(N)])

def shuffle_modop_0(input1):
    new_check = [[0 for i in range(len(input1[0]))] for j in range(len(input1))]

    for i in range(N//TP):
        for j in range(TP):
            new_check[i][j] = input1[
            (
                j*4 + (i%4) 
            ) % (N // TP)
            ][
            (
                (j)*4 + (i%4) + (i//4)
            ) % TP]

    return new_check

def shuffle_modop_1(input1):
    print(input1, )
    new_check = [[0 for i in range(len(input1[0]))] for j in range(len(input1))]

    # for ctr in range(N//TP):
    #     for j in range(TP):
    #         new_check[ctr][j] = input1[ctr][(j - (ctr>>4)) % TP]

    # print("PREV AAAAAAA")
    # for arr in new_check:
    #     print(arr)

    # new_check_last = [[0 for i in range(len(input1[0]))] for j in range(len(input1))]

    # for ctr in range(N//TP):
    #     for j in range(TP):
    #         if ctr == 0:
    #             print((j % 8)*16, j)
    #         new_check_last[ctr][j] = new_check[((j % 8)*16 + (ctr % 8)*8) % (N//TP)][j]

    input1_new = []

    for idx,arr in enumerate(input1):
        ee = []
        for elm in arr:
            ee.append(elm)
        rotated = ee[-(idx//16):] + ee[:-(idx//16)] 
        input1_new.append(rotated)

    print("FUNCTION GENERATED ARR: ")

    for idx, arr in enumerate(input1_new):
        print(arr)
    
    magical = (N//(n1*TP))

    ###### GENERIC ##### 
    for i in range(N//TP):
        for j in range(TP):
            new_check[i][j] = input1[
            (
                (j % 2) * magical * (n1 >> 1) +
                ((j % 4) // 2) * magical * (n1 >> 2) +
                ((j % 8) // 4) * magical * (n1 >> 3) +
                ((j % 16) // 8) * magical * (n1 >> 4) +
                ((j % 32) // 16) * magical *  (n1 >> 5) +
                ((j % 64) // 32) * magical * (n1 >> 6) +
                ((j % 128) // 64) * magical * (n1 >> 7) + 
                (i % 2)//1 * (magical//2) + 
                (i % 4)//2 * (magical//4) + 
                (i % 8)//4 * (magical//8) + 
                (i % 16)//8 * (magical//16) + 
                (i % 32)//16 * (magical//32) + 
                (i % 64)//32 * (magical//64)
            ) % (N // TP)
            ][
            (
                ((i//16)%4)//2*4 +
                ((i//16)%8)//4*2 +
                (i//(depth//2))
            ) % TP]

    # ###### 4-2-4-4 4
    # for i in range(N//TP):
    #     for j in range(TP):
    #         new_check[i][j] = input1[
    #         (
    #             (j % 2) * 8 * (n1 >> 1) +
    #             ((j % 4) // 2) * 8 * (n1 >> 2) +
    #             ((j % 8) // 4) * 8 * (n1 >> 3) +
    #             ((j % 16) // 8) * 8 * (n1 >> 4) +
    #             ((j % 32) // 16) * (n1 >> 5) +
    #             ((j % 64) // 32) * (n1 >> 6) +
    #             ((j % 128) // 64) * (n1 >> 7) + 
    #             (i%2)*4 + 
    #             (i%4)//2*2 + 
    #             (i%8)//4*1
    #         ) % (N // TP)
    #         ][
    #         (
    #             ((i//4)%2)//1*4 +
    #             ((i//4)%4)//2*2 +
    #             (i//16)
    #         ) % TP]


    

    # ###### 4-4-4-4 4
    # for i in range(N//TP):
    #     for j in range(TP):
    #         new_check[i][j] = input1[
    #         (
    #             (j % 2) * 16 * (n1 >> 1) +
    #             ((j % 4) // 2) * 16 * (n1 >> 2) +
    #             ((j % 8) // 4) * 16 * (n1 >> 3) +
    #             ((j % 16) // 8) * 16 * (n1 >> 4) +
    #             ((j % 32) // 16) * (n1 >> 5) +
    #             ((j % 64) // 32) * (n1 >> 6) +
    #             ((j % 128) // 64) * (n1 >> 7) + 
    #             (i%2)*8 + 
    #             (i%4)//2*4 + 
    #             (i%8)//4*2 +
    #             (i%16)//8*1
    #         ) % (N // TP)
    #         ][
    #         (
    #             ((i//8)%2)//1*4 +
    #             ((i//8)%4)//2*2 +
    #             (i//32)
    #         ) % TP]

    ##### 8-2-8-8 8
    # for i in range(N//TP):
    #     for j in range(TP):
    #         new_check[i][j] = input1[
    #         (
    #             (j % 2) * 16 * (n1 >> 1) +
    #             ((j % 4) // 2) * 16 * (n1 >> 2) +
    #             ((j % 8) // 4) * 16 * (n1 >> 3) +
    #             ((j % 16) // 8) * 16 * (n1 >> 4) +
    #             ((j % 32) // 16) * (n1 >> 5) +
    #             ((j % 64) // 32) * (n1 >> 6) +
    #             ((j % 128) // 64) * (n1 >> 7) + 
    #             (i%2)*8 + 
    #             (i%4)//2*4 + 
    #             (i%8)//4*2 +
    #             ((i%16)//8)*1
    #         ) % (N // TP)
    #         ][
    #         (
    #             ((i//8)%4)//2*4 +
    #             ((i//8)%8)//4*2 +
    #             (i//64)
    #         ) % TP]

    ####### 8-4-8-8 8
    # for i in range(N//TP):
    #     for j in range(TP):
    #         new_check[i][j] = input1[
    #         (
    #             (j % 2) * 32 * (n1 >> 1) +
    #             ((j % 4) // 2) * 32 * (n1 >> 2) +
    #             ((j % 8) // 4) * 32 * (n1 >> 3) +
    #             ((j % 16) // 8) * 32 * (n1 >> 4) +
    #             ((j % 32) // 16) * (n1 >> 5) +
    #             ((j % 64) // 32) * (n1 >> 6) +
    #             ((j % 128) // 64) * (n1 >> 7) + 
    #             (i%2)*16 + 
    #             (i%4)//2*8 + 
    #             (i%8)//4*4 + 
    #             (i%16)//8*2 + 
    #             ((i%128)//16)%2
    #         ) % (N // TP)
    #         ][
    #         (
    #             ((i//16)%4)//2*4 +
    #             ((i//16)%8)//4*2 +
    #             (i//128)
    #         ) % TP]

    ####### 8-8-8-8 8
    # for i in range(N//TP):
    #     for j in range(TP):
    #         new_check[i][j] = input1[
    #         (
    #             (j % 2) * 64 * (n1 >> 1) +
    #             ((j % 4) // 2) * 64 * (n1 >> 2) +
    #             ((j % 8) // 4) * 64 * (n1 >> 3) +
    #             ((j % 16) // 8) * 64 * (n1 >> 4) +
    #             ((j % 32) // 16) * 64 * (n1 >> 5) +
    #             ((j % 64) // 32) * (n1 >> 6) +
    #             ((j % 128) // 64) * (n1 >> 7) + 
    #             (i%2)*32 + 
    #             (i%4)//2*16 + 
    #             (i%8)//4*8 + 
    #             (i%16)//8*4 + 
    #             (i%32)//16*2 + 
    #             ((i%256)//32)%2
    #         ) % (N // TP)
    #         ][
    #         (
    #             ((i//32)%4)//2*4 +
    #             ((i//32)%8)//4*2 +
    #             (i//256)
    #         ) % TP]

    # ###### 16-4-16-1 1
    # for i in range(N//TP):
    #     for j in range(TP):
    #         new_check[i][j] = input1[
    #         (
    #             (j % 2) * 4 * (n1 >> 1) +
    #             ((j % 4) // 2) * 4 * (n1 >> 2) +
    #             ((j % 8) // 4) * 4 * (n1 >> 3) +
    #             ((j % 16) // 8) * 4 * (n1 >> 4) +
    #             ((j % 32) // 16) * 4 * (n1 >> 5) +
    #             ((j % 64) // 32 * 4) * (n1 >> 6) +
    #             ((j % 128) // 64) * 4 * (n1 >> 7) +
    #             (i%2)*2 +
    #             (i%4)//2*1
    #             # (i%8)//4*8 + 
    #             # (i%16)//8*4 + 
    #             # (i%32)//16*2 + 
    #             # ((i)//32)%2
    #         ) % (N // TP)
    #         ][
    #         (
    #             ((i//4)%2)*8 + 
    #             ((i//4)%4)//2*4 + 
    #             ((i//4)%8)//4*2 + 
    #             i//32
    #         ) % TP]

    # ###### 16-8-16-1 16
    # for i in range(N//TP):
    #     for j in range(TP):
    #         new_check[i][j] = input1[
    #         (
    #             (j % 2) * 8 * (n1 >> 1) +
    #             ((j % 4) // 2) * 8 * (n1 >> 2) +
    #             ((j % 8) // 4) * 8 * (n1 >> 3) +
    #             ((j % 16) // 8) * 8 * (n1 >> 4) +
    #             ((j % 32) // 16) * 8 * (n1 >> 5) +
    #             ((j % 64) // 32 * 8) * (n1 >> 6) +
    #             ((j % 128) // 64) * 8 * (n1 >> 7) +
    #             (i%2)*4 +
    #             (i%4)//2*2 +
    #             (i%8)//4*1 
    #             # (i%16)//8*4 + 
    #             # (i%32)//16*2 + 
    #             # ((i)//32)%2
    #         ) % (N // TP)
    #         ][
    #         (
    #             ((i//8)%2)*8 + 
    #             ((i//8)%4)//2*4 + 
    #             ((i//8)%8)//4*2 + 
    #             i//64
    #         ) % TP]

    ##### 16-16-16-1 1
    # for i in range(N//TP):
    #     for j in range(TP):
    #         new_check[i][j] = input1[
    #         (
    #             (j % 2) * 16 * (n1 >> 1) +
    #             ((j % 4) // 2) * 16 * (n1 >> 2) +
    #             ((j % 8) // 4) * 16 * (n1 >> 3) +
    #             ((j % 16) // 8) * 16 * (n1 >> 4) +
    #             ((j % 32) // 16) * 16 * (n1 >> 5) +
    #             ((j % 64) // 32) * 16 * (n1 >> 6) +
    #             ((j % 128) // 64) * 16 * (n1 >> 7) +
    #             (i%2)*8 +
    #             (i%4)//2*4 +
    #             (i%8)//4*2 +
    #             (i%16)//8*1 
    #             # (i%32)//16*2 + 
    #             # ((i)//32)%2
    #         ) % (N // TP)
    #         ][
    #         (
    #             ((i//16)%2)*8 + 
    #             ((i//16)%4)//2*4 + 
    #             ((i//16)%8)//4*2 + 
    #             i//128
    #         ) % TP]

     ##### 16-16-1-1 16
    # for i in range(N//TP):
    #     for j in range(TP):
    #         new_check[i][j] = input1[
    #         (
    #             (j % 2) * 1 * (n1 >> 1) +
    #             ((j % 4) // 2) * 1 * (n1 >> 2) +
    #             ((j % 8) // 4) * 1 * (n1 >> 3) +
    #             ((j % 16) // 8) * 1 * (n1 >> 4) +
    #             ((j % 32) // 16) * 1 * (n1 >> 5) +
    #             ((j % 64) // 32) * 1 * (n1 >> 6) +
    #             ((j % 128) // 64) * 1 * (n1 >> 7)
    #             #(i%2)*2 +
    #             #(i%4)//2*1 +
    #             #(i%8)//4*0 +
    #             #(i%16)//8*0 
    #             # (i%32)//16*2 + 
    #             # ((i)//4)%1
    #         ) % (N // TP)
    #         ][
    #         (
    #             ((i//1)%2)*8 + 
    #             ((i//1)%4)//2*4 + 
    #             ((i//1)%8)//4*2 + 
    #             i//8
    #         ) % TP]

    ##### 8-8-1-1 8
    # for i in range(N//TP):
    #     for j in range(TP):
    #         new_check[i][j] = input1[
    #         (
    #             (j % 2) * 1 * (n1 >> 1) +
    #             ((j % 4) // 2) * 1 * (n1 >> 2) +
    #             ((j % 8) // 4) * 1 * (n1 >> 3) +
    #             ((j % 16) // 8) * 1 * (n1 >> 4) +
    #             ((j % 32) // 16) * 1 * (n1 >> 5) +
    #             ((j % 64) // 32) * 1 * (n1 >> 6) +
    #             ((j % 128) // 64) * 1 * (n1 >> 7)
    #             #(i%2)*2 +
    #             #(i%4)//2*1 +
    #             #(i%8)//4*0 +
    #             #(i%16)//8*0 
    #             # (i%32)//16*2 + 
    #             # ((i)//4)%1
    #         ) % (N // TP)
    #         ][
    #         (
    #             ((i//1)%2)*4 + 
    #             ((i//1)%4)//2*2 +
    #             i//4
    #         ) % TP]

    return new_check



    


def iterative_seven_model(new_check, TP, n1, n2, n3, n4, size0, size1, verbose, file1, TWIDDLE_tuple_map):
    iter_0_read = iterative_first_block1(new_check, TP, n1, n2, size0, False, 0, verbose, file1, TWIDDLE_tuple_map)

    iter_1_read = iterative_second_block(iter_0_read, TP, n2, size0, size1, False, 1, verbose, file1, TWIDDLE_tuple_map)

    iter_2_read = iterative_first_block1(iter_1_read, TP, n3, n4, size1, False, 2, verbose, file1, TWIDDLE_tuple_map)

    iter_3_read = iterative_first_block1(iter_2_read, TP, n4, n3, size1, True, 3, verbose, file1, TWIDDLE_tuple_map)

    return iter_3_read


##### 2D: TP-TP TP
##### 3D: TP-x-TP TP : x<=TP
##### 4D: TP-x-TP-TP : x<=TP

def iterative_four_model(new_check, TP, n1, n2, size0, verbose, file1, TWIDDLE_tuple_map):
    iter_0_read = iterative_first_block1(new_check, TP, n1, n2, size0, False, 0, verbose, file1, TWIDDLE_tuple_map)

    iter_3_read = iterative_second_block(iter_0_read, TP, n2, n1, n1*n2, True, 1, verbose, file1, TWIDDLE_tuple_map)

    return iter_3_read


def iterative_six_model(new_check, TP, n1, n2, n3, n4, size0, size1, verbose, file1, TWIDDLE_tuple_map):
    iter_0_read = iterative_first_block1(new_check, TP, n1, n2, size0, False, 0, verbose, file1, TWIDDLE_tuple_map)

    iter_1_read = iterative_second_block(iter_0_read, TP, n2, size0, size1, False, 1, verbose, file1, TWIDDLE_tuple_map)

    iter_3_read = iterative_first_block1(iter_1_read, TP, n3, n4, size1, True, 2, verbose, file1, TWIDDLE_tuple_map)

    return iter_3_read




if __name__ == "__main__":
    
    N = int(sys.argv[1])
    n1 = int(sys.argv[2])
    n2 = int(sys.argv[3])
    n3 = int(sys.argv[4])
    n4 = int(sys.argv[5])
    TP = int(sys.argv[6])
    choice = int(sys.argv[7])
    q_bit_size = int(sys.argv[8])
    test_dir = sys.argv[9]
    verbose = int(sys.argv[10]) == 1

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

    q = ntt_friendly_prime_gen(LOGQ, LOGQH, 1)[0]

    size0 = n1*n2
    size1 = n3*n4


    TWIDDLE_tuple_map = find_twiddle_map(N, q, math.ceil(q_bit_size/width), width)
    TWIDDLE_inv_tuple_map = find_twiddle_map_INTT(N, q, math.ceil(q_bit_size/width), width)

    file1 = open(f"{test_dir}/psi.txt", 'w+')

    file2 = open(f"{test_dir}/psi_inv.txt", 'w+')

    

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

    new_check = [[0 for i in range(TP)] for j in range(N//TP)]

    add = int(log2(N//TP))

    start = int(log2(n2))-1
    

    #### following line needs to be deleted ####
    # new_check = input1

    new_in = [i for i in range(N)]
    new_in_arr = []

    new_in_bit_rev = [bitreverse(i, int(log2(N))) for i in new_in]

    new_input_2 = []

    for i in range(0, len(new_in_bit_rev), TP):
        part = new_in_bit_rev[i:i + TP]
        new_input_2.append(part)
        new_in_arr.append(new_in[i:i + TP])


    print("PREVIOUS VERSION")
    for arr in new_in_arr:
        print(arr)

    new_in_arr_shuff = shuffle_modop_1(new_in_arr)
    print("NEW VERSION")
    for arr in new_in_arr_shuff:
        print(arr)

    print("NEEDED VERSION")
    for arr in new_input_2:
        print(arr)
    
    print("shuffle check ? " , new_input_2 == new_in_arr_shuff)

    if iterative_four:
        iter_3_read = iterative_four_model(new_input_2, TP, n1, n2, size0, verbose, file1, TWIDDLE_tuple_map)
    elif iterative_six:
        iter_3_read = iterative_six_model(new_input_2, TP, n1, n2, n3, n4, size0, size1, verbose, file1, TWIDDLE_tuple_map)
    elif iterative_seven:
        iter_3_read = iterative_seven_model(new_input_2, TP, n1, n2, n3, n4, size0, size1, verbose, file1, TWIDDLE_tuple_map)

    file1.close()

    # Check can you generate all elements in correct order, 0 to N-1
    last1 = []
    for r in iter_3_read:
        for e in r:
            last1.append(e)
    

    coeff_read_file = open(f"{test_dir}/ntt_out.txt", 'r')

    hex_lines = []

    for line in coeff_read_file:
        # Split line into tokens and strip newlines/spaces
        token = line.strip()
        # Convert each hex token to an integer
        int_values = int(token, 16)
        hex_lines.append(int_values)

    intt_coeff_in_write_file = open(f"{test_dir}/intt_in.txt", 'w+')

    #print("hex: ", hex_lines)
    for e in iter_3_read:
        for ide in e:
            intt_coeff_in_write_file.write(str(hex(hex_lines[ide])[2:]) + "\n")

    coeff2_read_file = open(f"{test_dir}/ntt_out2.txt", 'r')

    hex_lines = []

    for line in coeff2_read_file:
        # Split line into tokens and strip newlines/spaces
        token = line.strip()
        # Convert each hex token to an integer
        int_values = int(token, 16)
        hex_lines.append(int_values)

    intt_coeff_in2_write_file = open(f"{test_dir}/intt_in2.txt", 'w+')

    #print("hex: ", hex_lines)
    for e in iter_3_read:
        for ide in e:
            intt_coeff_in2_write_file.write(str(hex(hex_lines[ide])[2:]) + "\n")



    print("check ? " , last1 == [i for i in range(N)])


    if iterative_four:
        iter_3_read_intt = iterative_four_model(iter_3_read, TP, n1, n2, size0, verbose, file2, TWIDDLE_inv_tuple_map)
    elif iterative_six:
        iter_3_read_intt = iterative_six_model(iter_3_read, TP, n1, n2, n3, n4, size0, size1, verbose, file2, TWIDDLE_inv_tuple_map)
    elif iterative_seven:
        iter_3_read_intt = iterative_seven_model(iter_3_read, TP, n1, n2, n3, n4, size0, size1, verbose, file2, TWIDDLE_inv_tuple_map)
    
    file2.close()

    intt_res_read_file = open(f"{test_dir}/intt_out_wo_last.txt", 'r')

    hex_lines = []

    for line in intt_res_read_file:
        # Split line into tokens and strip newlines/spaces
        token = line.strip()
        # Convert each hex token to an integer
        int_values = int(token, 16)
        hex_lines.append(int_values)

    intt_coeff_out_write_file = open(f"{test_dir}/intt_out.txt", 'w+')

    #print("hex: ", hex_lines)
    for e in iter_3_read_intt:
        for ide in e:
            intt_coeff_out_write_file.write(str(hex(hex_lines[ide])[2:]) + "\n")


    intt_res_read_file = open(f"{test_dir}/intt_out_wo_last2.txt", 'r')

    hex_lines = []

    for line in intt_res_read_file:
        # Split line into tokens and strip newlines/spaces
        token = line.strip()
        # Convert each hex token to an integer
        int_values = int(token, 16)
        hex_lines.append(int_values)

    intt_coeff_out_write_file = open(f"{test_dir}/intt_out2.txt", 'w+')

    #print("hex: ", hex_lines)
    for e in iter_3_read_intt:
        for ide in e:
            intt_coeff_out_write_file.write(str(hex(hex_lines[ide])[2:]) + "\n")


    # Check can you generate all elements in correct order, 0 to N-1
    last1 = []
    for r in iter_3_read_intt:
        for e in r:
            last1.append(e)

    print("AFTER INTT")
    for e in iter_3_read_intt:
        print(e)

    #last1_bit_rev_again = [last1[bitreverse(i, int(log2(N)))] for i in range(N)]

    #last1_bit_rev_again = shuffle_modop_1(last1)

    

    last1_bit_rev_again = shuffle_modop_1(iter_3_read_intt)

    last1_bit_rev_again_res = []
    for r in last1_bit_rev_again:
        for e in r:
            last1_bit_rev_again_res.append(e)

    print("LAST CHECK ? ", last1_bit_rev_again_res == [i for i in range(N)])

    ####### create unique twiddles #######
    psi = nth_root_of_unity(2*N, q)
    
    create_unique_twiddles(psi, N, TP , q, test_dir, False)
    create_unique_twiddles(psi, N, TP , q, test_dir, True)
    
    ####### create unique twiddles #######

