from math import ceil, log, log2
from tp_oriented_twiddle_model import find_twiddle_map, find_twiddle_map_INTT
import sys
import sympy
import math


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
                arr1[((i%(n2))*n1 + (i//(TP//2)) + ((i%(TP//2))//(TP//n1))*2)%TP] = input1[ctr][i]
            else:
                arr1[((i%(n1//2))*(2) + ((i%n1)//(n1//2)) + (i//(n1))*(n1))%TP] = input1[ctr][i]

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

        for i in range(TP):
            in_arr[i] = new_arr[((i//n2*n2) + ((i)%2)*(n2//2) + (i%n2)//2)%TP]

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
                write_arr[( (i) + ctr//((size0//TP)*(size1//TP)))%TP] = calc_res_poly[i]
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
                read_arr[i] = iter1_out[ (((size0//TP)*(size1//TP))*i + (size0//TP)*(ctr%(size1//TP)) + (ctr//size1)  ) % depth][(i + (ctr//(size1//TP)) )%TP]
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
    for i in range(N//TP):
        for j in range(TP):
            new_check[i][j] = input1[
            (
                ((i % 2) << ((add>=1)*((0 > start)*(add - (0 - start)) + (0 <= start)*(start - 0)))) +
                (((i % 4) // 2) << ((add>=2)*((1 > start)*(add - (1 - start)) + (1 <= start)*(start - 1)))) +
                (((i % 8) // 4) << ((add>=3)*((2 > start)*(add - (2 - start)) + (2 <= start)*(start - 2)))) +
                (((i % 16) // 8) << ((add>=4)*((3 > start)*(add - (3 - start)) + (3 <= start)*(start - 3)))) +
                (((i % 32) // 16) << ((add>=5)*((4 > start)*(add - (4 - start)) + (4 <= start)*(start - 4)))) +
                (((i % 64) // 32) << ((add>=6)*((5 > start)*(add - (5 - start)) + (5 <= start)*(start - 5)))) +
                (((i % 128) // 64) << ((add>=7)*((6 > start)*(add - (6 - start)) + (6 <= start)*(start - 6)))) +
                (((i % 256) // 128) << ((add>=8)*((7 > start)*(add - (7 - start)) + (7 <= start)*(start - 7)))) +
                (((i % 512) // 256) << ((add>=9)*((8 > start)*(add - (8 - start)) + (8 <= start)*(start - 8)))) +
                (((i % 1024) // 512) << (add>=10)*(((9 > start)*(add - (9 - start)) + (9 <= start)*(start - 9)))) +
                (((i % 2048) // 1024) << ((add>=11)*((10 > start)*(add - (10 - start)) + (10 <= start)*(start - 10)))) +
                (((i % 4096) // 2048) << ((add>=12)*((11 > start)*(add - (11 - start)) + (11 <= start)*(start - 11))))
            ) % (N // TP)
            ][
            (
                (j % 2) * (n1 >> 1) +
                ((j % 4) // 2) * (n1 >> 2) +
                ((j % 8) // 4) * (n1 >> 3) +
                ((j % 16) // 8) * (n1 >> 4) +
                ((j % 32) // 16) * (n1 >> 5) +
                ((j % 64) // 32) * (n1 >> 6) +
                ((j % 128) // 64) * (n1 >> 7)
            )]

    return new_check

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

    in1 = [[0 for j in range(TP)] for i in range(depth)]

    input1 = []
    bef_shuf = []

    for ctr in range(depth):
        arr1 = []
        arr2 = []
        for i in range(TP):
            # Generate correct input sequence
            arr1.append((   (i)*(N//TP) + (ctr%(size0//TP))*(N//size0) + (ctr//(size0//TP))) % N)
            arr2.append((i+ctr*TP))
        input1.append(arr1)
        bef_shuf.append(arr2[-(ctr%TP):] + arr2[:-(ctr%TP)])


    print("before shuf: ")
    for e in bef_shuf:
        print(e)
    print("wanted: ")
    for e in input1:
        print(e)
    print("APPLY SHUFFLE: ")

    new_check = [[0 for i in range(TP)] for j in range(N//TP)]

    add = int(log2(N//TP))

    start = int(log2(n2))-1

    print("start: ", start, n2)

    new_check = shuffle_modop_0(bef_shuf)

    print("ITERATIVE NTT INPUT AFTER SHUFFLE: ")

    for e in new_check:
        print(e)

    print(input1 == new_check)
    if iterative_seven:
        iter_0_read = iterative_first_block1(new_check, TP, n1, n2, size0, False, 0, verbose, file1, TWIDDLE_tuple_map)

        iter_1_read = iterative_second_block(iter_0_read, TP, n2, size0, size1, False, 1, verbose, file1, TWIDDLE_tuple_map)

        iter_2_read = iterative_first_block1(iter_1_read, TP, n3, n4, size1, False, 2, verbose, file1, TWIDDLE_tuple_map)

        iter_3_read = iterative_first_block1(iter_2_read, TP, n4, n3, size1, True, 3, verbose, file1, TWIDDLE_tuple_map)
    elif iterative_four:
        iter_0_read = iterative_first_block1(new_check, TP, n1, n2, size0, False, 0, verbose, file1, TWIDDLE_tuple_map)

        iter_3_read = iterative_second_block(iter_0_read, TP, n2, n1, n1*n2, True, 1, verbose, file1, TWIDDLE_tuple_map)
    elif iterative_six:
        iter_0_read = iterative_first_block1(new_check, TP, n1, n2, size0, False, 0, verbose, file1, TWIDDLE_tuple_map)

        iter_1_read = iterative_second_block(iter_0_read, TP, n2, size0, size1, False, 1, verbose, file1, TWIDDLE_tuple_map)

        iter_3_read = iterative_first_block1(iter_1_read, TP, n3, n4, size1, True, 2, verbose, file1, TWIDDLE_tuple_map)


    # Check can you generate all elements in correct order, 0 to N-1
    last1 = []
    for r in iter_3_read:
        for e in r:
            last1.append(e)
    
    print("check ? " , last1 == [i for i in range(N)])




    
    # print("ITERATIVE NTT INPUT: ")
    # for e in input1:
    #     print(e)
    
    print("ITERATIVE NTT OUTPUT: ")
    for e in iter_3_read:
        print(e)
    
    print("APPLY SHUFFLE: ")

    new_check = [[0 for i in range(TP)] for j in range(N//TP)]

    add = int(log2(N//TP))

    start = int(log2(n2))-1

    print("start: ", start, n2)

    new_check = shuffle_modop_1(iter_3_read)

    

    print("ITERATIVE INTT INPUT: ")

    for e in new_check:
        print(e)

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
    for e in new_check:
        for ide in e:
            intt_coeff_in_write_file.write(str(hex(hex_lines[ide])[2:]) + "\n")




    if iterative_seven:
        iter_0_read_intt = iterative_first_block1(new_check, TP, n1, n2, size0, False, 0, verbose, file2, TWIDDLE_inv_tuple_map)

        iter_1_read_intt = iterative_second_block(iter_0_read_intt, TP, n2, size0, size1, False, 1, verbose, file2, TWIDDLE_inv_tuple_map)

        iter_2_read_intt = iterative_first_block1(iter_1_read_intt, TP, n3, n4, size1, False, 2, verbose, file2, TWIDDLE_inv_tuple_map)

        iter_3_read_intt = iterative_first_block1(iter_2_read_intt, TP, n4, n3, size1, True, 3, verbose, file2, TWIDDLE_inv_tuple_map)
    if iterative_six:
        iter_0_read_intt = iterative_first_block1(new_check, TP, n1, n2, size0, False, 3, verbose, file2, TWIDDLE_inv_tuple_map)

        iter_1_read_intt = iterative_second_block(iter_0_read_intt, TP, n2, size0, size1, False, 4, verbose, file2, TWIDDLE_inv_tuple_map)

        iter_3_read_intt = iterative_first_block1(iter_1_read_intt, TP, n3, n4, size1, True, 5, verbose, file2, TWIDDLE_inv_tuple_map)

    elif iterative_four:
        iter_0_read_intt = iterative_first_block1(new_check, TP, n1, n2, size0, False, 0, verbose, file2, TWIDDLE_inv_tuple_map)

        iter_3_read_intt = iterative_second_block(iter_0_read_intt, TP, n2, n1, n1*n2, True, 1, verbose, file2, TWIDDLE_inv_tuple_map)

    print("ITERATIVE INTT RESULT: ")
    for e in iter_3_read_intt:
        print(e)

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

    print("APPLY SHUFFLE AGAIN: ")

    try_arr = [[0 for i in range(TP)] for j in range(N//TP)]
    

    try_arr = shuffle_modop_1(iter_3_read_intt)

    print("NTT INPUT AGAIN SANITY ? ")

    print(input1 == try_arr)

