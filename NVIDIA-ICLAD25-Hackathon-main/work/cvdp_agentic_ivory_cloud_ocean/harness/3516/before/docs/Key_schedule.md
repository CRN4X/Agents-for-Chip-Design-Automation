# Key Schedule

The **parity drop** operation removes one bit in each 8-bit byte of the KEY. Those bits are 8, 16,..., 64.

The KEY is divided in two parts, the first one named $`C_0`$ and the second one $`D_0`$. They permutate the KEY following those tables:

$`C_0`$:

| 57 | 49 | 41 | 33 | 25 | 17 |  9 |
|----|----|----|----|----|----|----|
|  1 | 58 | 50 | 42 | 34 | 26 | 18 |
| 10 |  2 | 59 | 51 | 43 | 35 | 27 |
| 19 | 11 |  3 | 60 | 52 | 44 | 36 |

$`D_0`$:

| 63 | 55 | 47 | 39 | 31 | 23 | 15 |
|----|----|----|----|----|----|----|
|  7 | 62 | 54 | 46 | 38 | 30 | 22 |
| 14 |  6 | 61 | 53 | 45 | 37 | 29 |
| 21 | 13 |  5 | 28 | 20 | 12 |  4 |

The bits of KEY are numbered 1 through 64. The bits of $`C_0`$ are respectively bits 57, 49, 41,..., 44 and 36 of KEY, with the bits of $`D_0`$ being bits 63, 55, 47,..., 12 and 4 of KEY.

Each pair of ($`C_n`$, $`D_n`$), with n ranging from 1 to 16, are obtained by one or two left rotation(s) of the bits of its previous pair ($`C_{n-1}`$, $`D_{n-1}`$). Each round has a required number of left rotations.

**Rotation per round**:

| Round | Shifts |
|-------|--------|
|   1   |   1    |
|   2   |   1    |
|   3   |   2    |
|   4   |   2    |
|   5   |   2    |
|   6   |   2    |
|   7   |   2    |
|   8   |   2    |
|   9   |   1    |
|  10   |   2    |
|  11   |   2    |
|  12   |   2    |
|  13   |   2    |
|  14   |   2    |
|  15   |   2    |
|  16   |   1    |

For example, $`C_3`$ and $`D_3`$ are obtained from $`C2`$ and $`D2`$, respectively, by two left shifts, and $`C16`$ and $`D16`$ are obtained from $`C15`$ and $`D15`$, respectively, by one left shift. In all cases, by a single left shift is meant a rotation of the bits one place to the left, so that after one left shift the bits in the 28 positions are the bits that were previously in positions 2, 3,..., 28, 1.

**Permuted choice 2 (PC-2)**

Determined by the following table:

| 14 | 17 | 11 | 24 |  1 |  5 |
|----|----|----|----|----|----|
|  3 | 28 | 15 |  6 | 21 | 10 |
| 23 | 19 | 12 |  4 | 26 |  8 |
| 16 |  7 | 27 | 20 | 13 |  2 |
| 41 | 52 | 31 | 37 | 47 | 55 |
| 30 | 40 | 51 | 45 | 33 | 48 |
| 44 | 49 | 39 | 56 | 34 | 53 |
| 46 | 42 | 50 | 36 | 29 | 32 |

Therefore, the first bit of $`K_n`$ is the 14th bit of $`C_nD_n`$, the second bit the 17th, and so on with the 47th bit the 29th, and the 48th bit the 32nd. This way, all $`K_n`$, with n ranging from 1 to 16 is generated and used in the **Feistel Rounds**