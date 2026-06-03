# TP-NTT

**Throughput-NTT Implementation with a Hierarchical Approach**

This repository contains the **ThroughPut-NTT (TP-NTT)** implementation using a hierarchical multi-dimensional approach. The project includes test-vector generation scripts and Vivado simulation support for testing NTT/INTT correctness under different parameter configurations.

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

## 2. Test Vector Generation

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
| `N`       | Total NTT size                                      |
| `n1`      | First hierarchical dimension                        |
| `n2`      | Second hierarchical dimension                       |
| `n3`      | Third hierarchical dimension                        |
| `n4`      | Fourth hierarchical dimension                       |
| `TP`      | Throughput / number of parallel processing elements |
| `choice`  | Hierarchical decomposition type                     |
| `q_size`  | Modulus bit-size, either `32` or `60`               |

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

## 3. Vivado Simulation Testing

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
parameter LOGN       
parameter LOGN1     
parameter LOGN2     
parameter LOGN3     
parameter LOGTP     
parameter LOGQ       
parameter LOGQH      
parameter BATCH_SIZE
```

### Parameter Description

| Parameter    | Description                                       |
| ------------ | ------------------------------------------------- |
| `LOGN`       | `log2(N)`                                         |
| `LOGN1`      | `log2(n1)`                                        |
| `LOGN2`      | `log2(n2)`                                        |
| `LOGN3`      | `log2(n3)`                                        |
| `LOGTP`      | `log2(TP)`                                        |
| `LOGQ`       | Modulus bit-size                                  |
| `LOGQH`      | Internal modulus-related parameter                |
| `BATCH_SIZE` | Number of consecutive NTT/INTT operations to test |

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

## 4. Run Simulation

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

Make sure the following parameters are consistent between test-vector generation and Vivado simulation:

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

Mismatch between the generated test vectors and the Vivado testbench parameters may cause incorrect simulation results.

The decomposition parameters `n1`, `n2`, `n3`, and `n4` should be selected according to the hierarchical decompositions described in the paper.

---

## Contact

For any questions, please contact:

**Emre Koçer**
`kocer@sabanciuniv.edu`
