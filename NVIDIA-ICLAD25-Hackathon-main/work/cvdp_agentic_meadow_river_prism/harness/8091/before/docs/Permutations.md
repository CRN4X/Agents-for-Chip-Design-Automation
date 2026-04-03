# Initial Permutation (IP)

The 64 bits of the input block to be enciphered are first subjected to the following permutation, called the initial permutation IP:

IP:
| 58 | 50 | 42 | 34 | 26 | 18 | 10 |  2 |
|----|----|----|----|----|----|----|----|
| 60 | 52 | 44 | 36 | 28 | 20 | 12 |  4 |
| 62 | 54 | 46 | 38 | 30 | 22 | 14 |  6 |
| 64 | 56 | 48 | 40 | 32 | 24 | 16 |  8 |
| 57 | 49 | 41 | 33 | 25 | 17 |  9 |  1 |
| 59 | 51 | 43 | 35 | 27 | 19 | 11 |  3 |
| 61 | 53 | 45 | 37 | 29 | 21 | 13 |  5 |
| 63 | 55 | 47 | 39 | 31 | 23 | 15 |  7 |


That is the permuted input has bit 58 of the input as its first bit, bit 50 as its second bit, and so on with bit 7 as its last bit.

# Feistel Rounds

Let **Expansion (E)** denote a function which takes a block of 32 bits as input and yields a block of 48 bits as output. E bits are obtained by selecting the bits in its inputs in order according to the following table:

| 32 |  1 |  2 |  3 |  4 |  5 |
|----|----|----|----|----|----|
|  4 |  5 |  6 |  7 |  8 |  9 |
|  8 |  9 | 10 | 11 | 12 | 13 |
| 12 | 13 | 14 | 15 | 16 | 17 |
| 16 | 17 | 18 | 19 | 20 | 21 |
| 20 | 21 | 22 | 23 | 24 | 25 |
| 24 | 25 | 26 | 27 | 28 | 29 |
| 28 | 29 | 30 | 31 | 32 |  1 |

Thus the first three bits of E(R) are the bits in positions 32, 1 and 2 of R while the last 2 bits of E(R) are the bits in positions 32 and 1.

The **Permutation (P)** function yields a 32-bit output from a 32-bit input by permuting the bits of the input block. Such a function is defined by the following table:

| 16 |  7 | 20 | 21 |
|----|----|----|----|
| 29 | 12 | 28 | 17 |
|  1 | 15 | 23 | 26 |
|  5 | 18 | 31 | 10 |
|  2 |  8 | 24 | 14 |
| 32 | 27 |  3 |  9 |
| 19 | 13 | 30 |  6 |
| 22 | 11 |  4 | 25 |

The output **P(L)** for the function **P** defined by this table is obtained from the input **L** by taking the 16th bit of **L** as the first bit of **P(L)**, the 7th bit as the second bit of **P(L)**, and so on until the 25th bit of **L** is taken as the 32nd bit of **P(L)**.

# Final Permutation (FP)

The final permutation uses the 64 bits of the calculated operation and subjects it to the following permutation which is the inverse of the initial permutation:

| 40 |  8 | 48 | 16 | 56 | 24 | 64 | 32 |
|----|----|----|----|----|----|----|----|
| 39 |  7 | 47 | 15 | 55 | 23 | 63 | 31 |
| 38 |  6 | 46 | 14 | 54 | 22 | 62 | 30 |
| 37 |  5 | 45 | 13 | 53 | 21 | 61 | 29 |
| 36 |  4 | 44 | 12 | 52 | 20 | 60 | 28 |
| 35 |  3 | 43 | 11 | 51 | 19 | 59 | 27 |
| 34 |  2 | 42 | 10 | 50 | 18 | 58 | 26 |
| 33 |  1 | 41 |  9 | 49 | 17 | 57 | 25 |