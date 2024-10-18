from math import log, log2, ceil
import random
#from sympy import *
import sympy
import math
import sys


# --------------------------------------------------
# Author: Emre Koçer

# ---------------------------------------------------
# ------------Helper Functions ----------------------
# ---------------------------------------------------

multiplier_type = ""


def egcd(a, b):
    if a == 0:
        return (b, 0, 1)
    else:
        g, y, x = egcd(b % a, a)
        return (g, x - (b // a) * y, y)

def modinv(a, m):
    g, x, y = egcd(a, m)
    if g != 1:
        raise Exception('Modular inverse does not exist')
    else:
        return x % m

# Bit-Reverse integer
def intReverse(a,n):
    b = ('{:0'+str(n)+'b}').format(a)
    return int(b[::-1],2)

# Bit-Reversed index
def indexReverse(a,r):
    n = len(a)
    b = [0]*n
    for i in range(n):
        rev_idx = intReverse(i,r)
        b[rev_idx] = a[i]
    return b

# Check if input is m-th (could be n or 2n) primitive root of unity of q
def isrootofunity(w,m,q):
    if pow(w,m,q) != 1:
        return False
    elif pow(w,m//2,q) != (q-1):
        return False
    else:
        v = w
        for i in range(1,m):
            if v == 1:
                return False
            else:
                v = (v*w) % q
        return True


# ---------------------------------------------------
# ---------------------------------------------------
# ---------------------------------------------------

#--------------------------SchoolBook Multiplication---------------

def SchoolbookModPolMul_minus_1(A, B, q):
    n = len(A)
    C = [0] * (2 * n)
    D = [0] * n
    for indA, indC in enumerate(A):
        for indB, indD in enumerate(B):
            C[indA + indB] = (C[indA + indB] + indC * indD) % q

    for i in range(n):
        D[i] = (C[i] - C[i + n]) % q

    return D

#--------------------------Four-Step NTT--------------------------

def generate_psi_table(w, n, q):
    psi_table = []
    for i in range(int(n / 2)):
        index_re = intReverse(i, int(log(int(n / 2), 2)))
        psi_table.append(pow(w, index_re, q))
    return psi_table



#----------------------------------Merge NTT----------------------------------------



twids = []

def NTT(A, Psi_table, q, only_1):
    if only_1:
        debug_file = open("FNTT_debug.txt", 'w+')
    N = len(A)
    B = [_ for _ in A]

    l = int(log(N, 2))
    MulCnt, AddCnt, SubCnt, BtfCnt = 0, 0, 0, 0

    t = N
    m = 1

    
    counterr = 0
    while (m < N):
        if only_1:
            debug_file.write("----------------------" + str(math.log2(m)) + "------------------------------------ \n")
        counterr += 1
        t = int(t / 2)
        for i in range(m):
            j1 = 2 * i * t
            j2 = j1 + t - 1
            Psi_pow = intReverse(m + i, l)
            S = Psi_table[Psi_pow]

            for j in range(j1, j2 + 1):

                U = B[j]
                V = (B[j + t] * S) % q
                aa = B[j + t]

                #debug_file.write("{} {} {} {} \n".format(hex(B[j]), hex(B[j + t]), hex((S*2**39)%q), hex(q)))
                B[j] = (U + V) % q
                B[j + t] = (U - V) % q

                

                
                SS = S * pow(2,13*3,q) % q
                #if SS not in twids and only_1:
                    #twids.append((j, j+t, SS))
                
                if only_1:
                    debug_file.write("A[{}]--{} ve A[{}]--{} + W^{} --> A[{}] ve A[{}] \n".format( hex(U), j, hex(aa), j+t, hex(SS), hex(B[j]), hex(B[j + t])))


        m = 2 * m
    #print(counterr)
    return B


#----------------------------------Merge INTT----------------------------------------

def INTT(A, Psi_table, q):
    counterr = 0
    N = len(A)
    B = [_ for _ in A]

    l = int(log(N, 2))

    MulCnt, AddCnt, SubCnt, BtfCnt = 0, 0, 0, 0

    t = 1
    m = N
    while (m > 1):
        j1 = 0
        h = int(m / 2)
        for i in range(h):

            j2 = j1 + t - 1
            Psi_pow = intReverse(h + i, l)
            S = Psi_table[Psi_pow]
            counterr += 1
            #print(S)
            for j in range(j1, j2 + 1):
                #print(S)
                U = B[j]
                V = B[j + t]

                B[j] = (U + V) % q
                a = (U - V) * S
                B[j + t] = a % q
            j1 = j1 + 2 * t
        t = 2 * t
        m = int(m / 2)

    N_inv = modinv(N, q)
    for i in range(N):
        B[i] = (B[i] * N_inv) % q

    return B






# Psi table for Merge NTT
def generate_ntt_tables(n, q, np):
    t0 = [1]*n

    for i in range(1,n):
        t0[i] = (t0[i-1] * np) % q

    return t0


def modular_exponentiation(base, exponent, mod):
    result = 1
    base = base % mod
    while exponent > 0:
        if exponent % 2 == 1:
            result = (result * base) % mod
        exponent = exponent >> 1
        base = (base * base) % mod
    return result

def find_primitive_root(p):
    """ Find a primitive root modulo p """
    if p == 2:
        return 1
    p1, p2 = 2, (p - 1) // 2
    while True:
        g = random.randint(2, p - 1)
        if (modular_exponentiation(g, (p - 1) // p1, p) != 1 and
            modular_exponentiation(g, (p - 1) // p2, p) != 1):
            return g

def nth_root_of_unity(n, p):
    """ Calculate the nth root of unity in the field F_p """
    g = find_primitive_root(p)
    root_of_unity = modular_exponentiation(g, (p - 1) // n, p)
    return root_of_unity


def find_twiddle_map(N, q):
    N = N
    B = [i for i in range(N)]

    l = int(log(N, 2))

    t = N
    m = 1

    random.seed(0)

    psi = nth_root_of_unity(2*N, q)

    print("nth root: ", psi)

    Psi_table = generate_ntt_tables(N, q, psi)

    twiddle_map = {}

    
    counterr = 0
    while (m < N):
        counterr += 1
        t = int(t / 2)
        for i in range(m):
            j1 = 2 * i * t
            j2 = j1 + t - 1
            Psi_pow = intReverse(m + i, l)
            S = Psi_table[Psi_pow]

            for j in range(j1, j2 + 1):

                #U = B[j]
                #V = (B[j + t] * S) % q
                #aa = B[j + t]

                #debug_file.write("{} {} {} {} \n".format(hex(B[j]), hex(B[j + t]), hex((S*2**39)%q), hex(q)))
                #B[j] = (U + V) % q
                #B[j + t] = (U - V) % q

            
                SS = S * pow(2,13*3,q) % q
                twiddle_map[(B[j], B[j+t])] = SS

            

        m = 2 * m
    #print(counterr)
    return twiddle_map



if __name__ == "__main__":

    # n = 8192
    # PE_number = 8
    # PE = 2*PE_number

    n = int(sys.argv[1])
    PE_number = int(sys.argv[2])
    PE = 2*PE_number
    user_input = sys.argv[3]
    
    q = 0x7ffe0001
    fd1_R = pow(2, 13*3, q)

    WLMONT = False

    if user_input == "word_level_mont":
        WLMONT = True

    multiplier_type = user_input

    random.seed(0)


    psi = nth_root_of_unity(2*n, q)

    psi = psi
    psi_inv = modinv(psi, q)
    w = pow(psi, 2, q)
    w_inv = modinv(w, q)


    #----- Create Random Inputs -------

    A = [random.randint(0, q - 1) for x in range(n)]
    #print("A: ", A)

    f0 = open('test_files/NTT_inputs_hexa.txt', 'w+')
    for i in range(n):
        f0.write('{}'.format(hex(A[i])[2:]))
        f0.write('\n')
    f0.close()

    B = [random.randint(0, q - 1) for x in range(n)]

    # -------Merge NTT -------
    psi_table = generate_ntt_tables(n, q, pow(psi, 1, q))

    print("nth root 2: ", psi)    

    A_NTT_merge = NTT(A, psi_table, q, True)
    B_NTT_merge = NTT(B, psi_table, q, False)

    f1 = open('W_in.txt', 'w+')

    for elm_idx in range(len(twids)):
        if elm_idx == len(twids) - 1:
            f1.write(str(hex(twids[elm_idx][2]))[2:] + "\n")
        else:
            f1.write(str(hex(twids[elm_idx][2]))[2:] + "\n")
    f1.write("\n")

    
    f2 = open('W_in_tp.txt', 'w+')

    

    

    res_merge = []

    for i in range(n):
        res_merge.append((A_NTT_merge[i] * B_NTT_merge[i]) % q)

    psi_table_inv = generate_ntt_tables(n, q, pow(psi_inv, 1, q))
    INTT_res_merge = INTT(res_merge,psi_table_inv, q)

    check_res_minus_1 = []
    #check_res_minus_1 = SchoolbookModPolMul_minus_1(A, B, q)

    print("----------------Parameters---------------\n")

    print("Ring size    : ", n)
    print("q            :", q)
    print("w            :", w)
    print("w_inv        :", w_inv)
    print("psi          :", psi)
    print("psiv            :", psi_inv)

    print("******************************************\n")

    if INTT_res_merge == check_res_minus_1:

        print("**********Correct_Merge*************")

    else:

        print("**********Incorrect_Merge*************")

    # Decimal to Hexadecimal -----------> Check FGPA results

    # --------------------Input NTT---------------------------------


    #--------------------Output NTT---------------------------------


    f0 = open('test_files/NTT_outputs_hexa.txt','w')

    for i in range(n):
        f0.write('{}'.format(hex(A_NTT_merge[i])[2:]))
        f0.write('\n')
    f0.close()