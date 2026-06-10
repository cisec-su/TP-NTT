# TP-NTT

**Throughput-NTT Implementation with a Hierarchical Approach**

This repository contains the **ThroughPut-NTT (TP-NTT)** implementation using a hierarchical multi-dimensional approach. The project includes Vivado simulation support, test-vector generation scripts, twiddle-factor generation, and correctness testing for NTT/INTT under different parameter configurations.

---

## 1. Repository Setup

Clone the repository:

```bash
git clone <repository-url> TP-NTT
cd TP-NTT
```

Initialize and update the Git submodules:

```bash
git submodule update --init --recursive
```

Alternatively, the repository can be cloned directly with submodules using:

```bash
git clone --recursive <repository-url> TP-NTT
cd TP-NTT
```

---

## 2. Vivado Simulation Testing

Open the Vivado project:

```bash
vivado/iterative_parametric_32_64.xpr
```

In Vivado, go to the testbench source:

```text
src/tp_ntt_shuffle_tb
```

Update the following parameters according to the desired NTT configuration:

```verilog
parameter LOGN;
parameter LOGN1;
parameter LOGN2;
parameter LOGN3;
parameter LOGTP;
parameter LOGQ;
parameter LOGQH;
parameter BATCH_SIZE;
parameter GEN_TEST_VEC;
```

### Parameter Description

| Parameter      | Description                                                                        |
| -------------- | ----------------------------------------------------------------------------------------- |
| `LOGN`         | Ring dimension, i.e. polynomial degree                                                    |
| `LOGN1`        | Logarithm of size of first hierarchical dimension                                         |
| `LOGN2`        | Logarithm of size of second hierarchical dimension                                        |
| `LOGN3`        | Logarithm of size of third hierarchical dimension                                         |
| `LOGTP`        | Logarithm of throughput, i.e. number of parallel processing elements                      |
| `LOGQ`         | Coefficient modulus bit-length                                                            |
| `LOGQH`        | Bit-length of most-significant non-zero bits of the modulus, `Q=(QH << (LOGQ-LOGQH)) + 1` |
| `BATCH_SIZE`   | Number of consecutive NTT/INTT operations to test                                         |
| `GEN_TEST_VEC` | Enables or disables test-vector generation inside the testbench                           |

The `BATCH_SIZE` parameter specifies how many consecutive NTT/INTT operations are tested for correctness.

The `GEN_TEST_VEC` parameter controls test-vector generation in the testbench:

```text
GEN_TEST_VEC = 1  -> Generate test vectors
GEN_TEST_VEC = 0  -> Bypass test-vector generation
```

For example, if:

```text
N  = 2^12
n1 = 2^5
n2 = 2^2
n3 = 2^5
TP = 2^5
```

then the corresponding Vivado parameters should be:

```verilog
parameter LOGN       = 12;
parameter LOGN1      = 5;
parameter LOGN2      = 2;
parameter LOGN3      = 5;
parameter LOGTP      = 5;
```

For modulus-size parameters:

```text
LOGQ = 60  -> LOGQH = 17
LOGQ = 32  -> LOGQH = 15
```

Make sure that the Vivado simulation parameters match the test-vector generation parameters.

---

## 3. Test Vector Generation

First, go to the test directory:

```bash
cd test
```

Run the test-vector generation script:

```bash
./test_vector_gen.sh <N> <n1> <n2> <n3> <n4> <TP> <choice> <q_size>
```

The script arguments are:

```bash
N=$1

n1=$2
n2=$3
n3=$4
n4=$5

TP=$6

choice=$7   # 0 -> 2D, 1 -> 3D, 2 -> 4D
q_size=$8
```

### Parameter Description

| Parameter | Description                                         |
| --------- | --------------------------------------------------- |
| `N`       | `1 << LOGN`                                         |
| `n1`      | `1 << LOGN1`                                        |
| `n2`      | `1 << LOGN2`                                        |
| `n3`      | `1 << LOGN3`                                        |
| `n4`      | `1 << (LOGN - LOGN1 - LOGN2 - LOGN3)`               |
| `TP`      | `1 << LOGTP`                                        |
| `choice`  | Hierarchical decomposition type                     |
| `q_size`  | `LOGQ`                                              |

The `choice` parameter selects the decomposition type:

```text
choice = 0  -> 2D decomposition
choice = 1  -> 3D decomposition
choice = 2  -> 4D decomposition
```

The `q_size` parameter can be:

```text
q_size = 32
q_size = 60
```

The parameters `n1`, `n2`, `n3`, and `n4` should be selected according to the decompositions specified in the paper. These values must be chosen carefully, otherwise the generated test vectors may not match the hardware configuration.

### Example

For:

```text
N      = 2^12
TP     = 2^5
choice = 1  # 3D decomposition
```

The decomposition is:

```text
n1 = 2^5
n2 = 2^2
n3 = 2^5
n4 = 2^0
```

Therefore, the script can be run as:

```bash
./test_vector_gen.sh 4096 32 4 32 1 32 1 60
```

Here:

```text
N      = 4096
n1     = 32
n2     = 4
n3     = 32
n4     = 1
TP     = 32
choice = 1
q_size = 60
```

---

## 4. Twiddle Factor Generation

Twiddle factors are generated in the correct order using the helper functions in:

```text
test/tp_ntt_api.py
```

In these function calls, `n` denotes the NTT size. The parameter `q` denotes the selected modulus from the RNS modulus list. The parameter `q_idx` denotes the index of this modulus in the RNS modulus list. The parameter `root_unity` denotes the forward root of unity used for the selected modulus, while `root_unity_inv` denotes the corresponding inverse root of unity. Finally, `LOGQ` denotes the bit-size of the modulus.

The required twiddle tables are generated as follows:

```python
create_twiddles(
    n,
    q,
    q_idx,
    root_unity=root_unity,
    root_unity_inv=root_unity_inv,
    LOGQ=LOGQ,
)

create_unique_twiddles(
    n,
    q,
    q_idx,
    "test_vectors",
    False,
    LOGQ,
)

create_unique_twiddles(
    n,
    q,
    q_idx,
    "test_vectors",
    True,
    LOGQ,
)
```

The purpose of these calls is:

| Function                                  | Description                                                                                             |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `create_twiddles(...)`                    | Generates the full twiddle and inverse twiddle tables using the selected modulus `q` and roots of unity |
| `create_unique_twiddles(..., False, ...)` | Generates the unique forward twiddle factors required by the hardware                                   |
| `create_unique_twiddles(..., True, ...)`  | Generates the unique inverse twiddle factors required by the hardware                                   |

These functions should be called with parameters consistent with the selected `N`, modulus size, and hierarchical decomposition configuration.


---

## 5. Run Simulation

After setting the parameters, click:

```text
Run Simulation
```

If the generated test vectors and the Vivado parameters are consistent, the simulation should print correctness messages in the console.

You should see messages such as:

```text
CORRECT IDX
```

At the end of the simulation, the console should also print the final correctness logs.

There should be no mismatch or error messages in the simulation output.

---

## Notes

Make sure the following parameters are consistent between test-vector generation, twiddle generation, and Vivado simulation:

* `N`
* `n1`
* `n2`
* `n3`
* `n4`
* `TP`
* `choice`
* `q_size`
* `LOGN`
* `LOGN1`
* `LOGN2`
* `LOGN3`
* `LOGTP`
* `LOGQ`
* `LOGQH`
* `BATCH_SIZE`
* `GEN_TEST_VEC`

Mismatch between the generated test vectors, twiddle factors, and Vivado testbench parameters may cause incorrect simulation results.

The decomposition parameters `n1`, `n2`, `n3`, and `n4` should be selected according to the hierarchical decompositions described in the paper.

---

## Citation

If you use this repository or the TP-NTT design in your work, please cite:

```bibtex
@misc{kocer_tp_ntt,
      author = {Emre Koçer and Tolun Tosun and Beren Aydoğan and Erkay Savaş and Furkan Turan and Ingrid Verbauwhede},
      title = {{TP}-{NTT}: Batch {NTT} Hardware with Application to Relinearization},
      howpublished = {Cryptology {ePrint} Archive, Paper 2026/556},
      year = {2026},
      url = {https://eprint.iacr.org/2026/556}
}
```

---

## Contact

For any questions, please contact:

**Emre Koçer**
`kocer@sabanciuniv.edu`
