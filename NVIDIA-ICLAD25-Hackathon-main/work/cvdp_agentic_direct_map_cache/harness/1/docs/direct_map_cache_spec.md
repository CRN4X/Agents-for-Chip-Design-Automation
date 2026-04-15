# direct_map_cache Module

The `direct_map_cache` module implements a direct-mapped cache system designed to store and retrieve data efficiently. This cache is structured with a single tag and data storage per index, supporting read and write operations while maintaining valid and dirty bit tracking. The module also detects errors related to misaligned memory accesses.

## Parameterization

- **CACHE_SIZE**: Defines the number of cache lines available. Default is 256. A positive integer (≥2) that defines the total number of cache lines, typically a power of two.
- **DATA_WIDTH**: Specifies the width of each data entry in bits and must be a positive integer. Default is 16. 
- **TAG_WIDTH**: Determines the width of the tag used for cache addressing and must be a positive integer. Default is 5.
- **OFFSET_WIDTH**: Defines the bit-width for the byte offset within a cache line, where offset[0]==1 triggers an error. Default is 3.
- **INDEX_WIDTH**: Automatically computed as `$clog2(CACHE_SIZE)`, determining the number of index bits required.

## Interfaces

### Data Inputs

- **clk**: The input clock signal used for synchronous operations.
- **rst**: Synchronous active-high reset signal. When asserted, all counters and pulse signals are cleared.
- **enable**: Single bit Control signal that enables cache operations.
- **index** [INDEX_WIDTH-1:0]: : The cache line index, using INDEX_WIDTH bits to select one of the cache lines.
- **offset** [OFFSET_WIDTH-1:0]: Byte offset within the selected cache line, where offset[0]==1 causes an error.
- **comp**: Single bit Compare mode signal; 1 checks for a tag match (hit/miss), while 0 allows direct access.
- **write**: Single bit Read/write control; 1 enables write operations, while 0 performs a read operation.
- **tag_in** [TAG_WIDTH-1:0]: Input tag used for comparison during lookup or assigned when writing new data.
- **data_in** [DATA_WIDTH-1:0]: Data written to the cache if write=1; must match DATA_WIDTH bits.
- **valid_in**: Single bit signal indicates if the cache line is valid upon writing.

### Data Outputs

- **hit**: Single bit signal Indicates if the requested data is found in the cache.
- **dirty**: Single bit indicates if the accessed line has been modified (1) or remains clean (0).
- **tag_out** [TAG_WIDTH-1:0]: Outputs the stored tag of the cache line.
- **data_out** [DATA_WIDTH-1:0]: Outputs the retrieved data from the cache.
- **valid**: valid is a 1-bit signal. Logic high represents valid data.
- **error**: 1 bit signal. Logic high Indicates an invalid memory access, such as an unaligned offset.

## Detailed Functionality

### Cache Structure

The direct-mapped cache is structured using:

- **Tag Storage (tags)**: Stores the tag bits associated with each cache line.
- **Data Storage (data_mem)**: Holds the actual data in a multi-dimensional array indexed by index and offset.
- **Valid Bits (valid_bits)**: Indicates whether a cache line contains valid data.
- **Dirty Bits (dirty_bits)**: Shows if the cache line has been modified since it was loaded.

### Cache Operations

#### Reset Behavior:
- When `rst` is high, all cache contents, including tags, valid bits, and dirty bits, are cleared.
- The output registers (`hit`, `dirty`, `valid`, `data_out`) are reset to zero.

#### Error Detection:
- If `offset[0] == 1'b1`, the module detects an unaligned access error, sets `error` high, and clears all outputs.

#### Compare Mode (`comp = 1`):

- **Write (`write = 1`)**:
  - If the tag matches the stored tag and the cache line is valid, a cache hit occurs.
  - The data at the specified index and offset is updated.
  - The dirty bit is set to indicate that the cache line has been modified.

- **Read (`write = 0`)**:
  - If the tag matches and the line is valid, the cache outputs the stored data, tag, valid bit, and dirty bit.
  - If the tag does not match, a cache miss occurs.

#### Direct Access Mode (`comp = 0`):

- **Write (`write = 1`)**:
  - The tag is updated, and the new data is written to the cache.
  - The valid bit is updated, but the dirty bit remains clear.

- **Read (`write = 0`)**:
  - Outputs the stored tag, data, and associated valid and dirty bits.

#### Cache Hit/Miss Handling:
- If a cache hit occurs, the requested data is provided immediately.
- If a cache miss occurs, data needs to be fetched from main memory (not handled in this module).

## Example Usage

### Cache Write Operation (Hit)

#### Inputs:
- `index = 5`
- `tag_in = 3'b101`
- `offset = 3'b010`
- `write = 1`
- `comp = 1`
- `data_in = 16'hABCD`
- `valid_in = 1`

#### Operation:
- The module checks if the tag matches and the cache line is valid.
- If matched, it writes `data_in` (16'hABCD) to `data_mem[5][1]`.
- The dirty bit for the cache line is set.

### Cache Read Operation (Miss)

#### Inputs:
- `index = 12`
- `tag_in = 3'b010`
- `offset = 3'b100`
- `write = 0`
- `comp = 1`

#### Operation:
- The stored tag does not match `tag_in`, resulting in a cache miss.
- The `hit` output is de-asserted (`hit = 0`).
- The cache retains its current state, waiting for external memory access.

## Summary

### Functionality:
- The `direct_map_cache` module implements a direct-mapped cache system with valid-bit tracking, dirty-bit handling, and tag-based lookup.

### Cache Operations:
- **Compare Mode (`comp = 1`)** enables direct tag comparisons for read/write operations.
- **Direct Access Mode (`comp = 0`)** allows writing new values without checking existing data.

### Hit & Miss Handling:
- A cache hit occurs when the tag matches and the valid bit is set.
- A cache miss occurs if the tag does not match, requiring external memory access.

### Error Detection:
- The module detects and flags misaligned memory accesses when `offset[0] == 1'b1`.

### Modular Design:
- The cache structure is designed for easy scalability and integration with memory subsystems.
- Separate valid, dirty, and tag storage allows efficient tracking and access control.