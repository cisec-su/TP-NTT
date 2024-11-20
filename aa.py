import random, sympy

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


def wlm_iter(c, w, q, debug=False):
    T1 = c
    T1H = T1 >> w
    T1L = T1 & ((1<<w)-1)
    if debug:
        print("T1H: ", hex(T1H))
        print("T1L: ", hex(T1L))
    T2 = (-T1L) & ((1<<w)-1)
    if debug:
        print("T2: ", hex(T2))
    c = (T2 | T1L) >> (w - 1)
    if debug:
        print("c: ", hex(c))
    qh = q >> w
    if debug:
        print("qh: ", hex(qh))
    if debug:
        print("(qh)*T2: ", hex((qh)*T2))
    T3 = T1H + (qh)*T2 + c
    if debug:
        print("T3: ", hex(T3))
    return T3



def wlm_mixed(c, q, logq, logqh, dsp_a, dsp_b, correct=True, debug=False):
    w = logq - logqh
    if (logqh <= dsp_b):
        d = dsp_a
    else:
        d = dsp_a
    if (w > d):
        w1 = d
    else:
        w1 = w
    w0 = logq - w1

    if debug:
        print(w0, w1)


    c0 = wlm_iter(c, w0, q)
    c1 = wlm_iter(c0, w1, q)

    t = ((c * pow(2, -(w0+w1), q) ) % q)
    assert (c1 == t) or ((c1 - q) == t)
    if correct:
        return t
    else:
        return c1





LOGQ = 60
LOGQH = 17

q = ntt_friendly_prime_gen(LOGQ, LOGQH, 1)[0]

a = random.randint(2, q-1)
b = random.randint(2, q-1)
w = random.randint(2, q-1)

R_mixed                 = pow(2, (LOGQ))
w_mont_mixed            = (w * R_mixed) % q


res_mixed               = wlm_mixed(w_mont_mixed*b, q, LOGQ, LOGQH, 26, 17, True)


print(res_mixed == w*b%q)
