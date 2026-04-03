## DES Encryption

In the description of this algorithm, the first `n` bits of a value declared as [1:NBW] are `1, 2, 3, ... , n-1, n`, and the last `n` bits are `NBW-(n-1), NBW-(n-2), ... , NBW-1, NBW`.

The **DES** encryption operation is divided in four steps:

### 1. Initial Permutation (IP)

The 64-bit input block undergoes a fixed initial permutation. The description for this step is available at the "Permutations.md" file.

The first 32 bits are stored in $`L_0`$ and the last 32 bits in $`R_0`$.

### 2. Key Schedule

- The 64-bit input key is reduced to 56 bits via a **parity drop**.
- It is then split into two 28-bit halves.
- Each half is rotated left based on a fixed schedule per round.
- A **PC-2** permutation compresses the result to 48-bit round keys (`K1` to `K16`).

The "Key_schedule.md" file describes this operation in more detail.

### 3. Feistel Rounds

Each of the 16 rounds updates the left and right halves as follows:

$`L_n = R_{n-1}`$

$`R_n = L_{n-1} ⊕ F(R_{n-1}, K_n)`$

Where `F` is the round function consisting of:

- **Expansion (E)**: Expands 32-bit R to 48 bits using a fixed table. Described in the "Permutations.md" file.
- **Key Mixing**: Uses the expanded value from the **Expansion (E)** operation and XORs it with the 48-bit round key $`K_n`$.
- **S-box Substitution**: 48 bits are split into 8 groups of 6 bits, passed through S-boxes S1–S8. Each S-box is a 4x16 table (64 entries) mapping a 6-bit input to a 4-bit output.
- **Permutation (P)**: 32-bit output of S-boxes is permuted via a fixed permutation. Described in the "Permutations.md" file.

### 4. Final Permutation (FP)

After the 16th round, the L and R halves are concatenated in reverse order and passed through the **Final Permutation**, which is the inverse of IP. This concatenation is described in the "Permutations.md" file.