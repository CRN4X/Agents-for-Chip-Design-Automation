The **Min_Hamming_Distance_Finder** module computes the minimum Hamming distance between an input query vector and a set of reference vectors, outputting the index of the reference vector with the smallest Hamming distance and the corresponding minimum distance.

## Parameterization

- **BIT_WIDTH** : Defines the number of bits used for both the query vector and each reference vector. This parameter must be set to a positive integer value indicating the width of the vectors.Default value of 8 
- **REFERENCE_COUNT** : Specifies how many reference vectors will be compared to the query. This must be a positive integer greater than zero, representing the total number of vectors stored or used within the design.Default value of 4 

## Interfaces

### Data Inputs

- **input_query [BIT_WIDTH-1:0]**: Input vector to be compared.
- **references [REFERENCE_COUNT*BIT_WIDTH-1:0]**: Concatenated reference vectors against which the query is compared.

### Data Outputs

- **best_match_index [$clog2(REFERENCE_COUNT)-1:0]**: Index of the reference vector with the smallest Hamming distance to the query.
- **min_distance [$clog2(BIT_WIDTH+1)-1:0]**: The minimum Hamming distance found among all reference vectors.

## Detailed Functionality

### Distance Calculation

- The module instantiates multiple instances of the **Bit_Difference_Counter**, one for each reference vector.

- Each **Bit_Difference_Counter** calculates the Hamming distance between `input_query` and its respective reference vector.

### Minimum Distance Determination

- After computing distances, the module iteratively evaluates each distance to find the smallest one.

- The **best_match_index** is updated whenever a smaller distance is encountered.

- The **min_distance** is updated to reflect the smallest Hamming distance identified.

## Submodules Explanation

### 1. Bit_Difference_Counter

- Computes the Hamming distance between two input vectors (`input_A` and `input_B`).
- Uses the **Data_Reduction** submodule with an XOR operation to identify differing bits.
- Counts the differing bits to produce the Hamming distance.

### 2. Data_Reduction

- Performs bitwise reduction operations across multiple data inputs.
- Configurable for various reduction operations (AND, OR, XOR, NAND, NOR, XNOR).
- Utilized by **Bit_Difference_Counter** for computing bitwise differences.

### 3. Bitwise_Reduction

- Executes the actual reduction logic defined by the operation parameter.
- Supports common bitwise reduction operations and their complements.
- Serves as a core computational element within **Data_Reduction**.

## Example Usage

### Valid Input Example

- input_query = 8'b10101010
- references = {8'b10101011, 8'b11110000, 8'b00001111, 8'b10101001}
- The module calculates the Hamming distances:
    - To ref[0]: Distance = 1
    - To ref[1]: Distance = 4
    - To ref[2]: Distance = 4
    - To ref[3]: Distance = 2

- The module outputs:
  - best_match_index = 0 (the first smallest distance encountered)
  - min_distance = 1

## Summary

- **Functionality**: Determines the reference vector closest to a query by Hamming distance.
- **Distance Calculation**: Parallel instantiation of difference counters ensures efficient distance computation.
- **Minimum Selection**: Sequential comparison logic finds the minimum distance and its index.
- **Hierarchical Design**: Composed of reusable submodules (**Bit_Difference_Counter**, **Data_Reduction**, and **Bitwise_Reduction**), enhancing modularity and maintainability.