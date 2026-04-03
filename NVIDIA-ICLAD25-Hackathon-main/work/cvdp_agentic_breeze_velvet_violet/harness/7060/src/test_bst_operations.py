import cocotb
from cocotb.triggers import RisingEdge, Timer
import random
import harness_library as hrs_lb
import math


@cocotb.test()
async def test_bst_operations(dut):
    ARRAY_SIZE = int(dut.ARRAY_SIZE.value)
    DATA_WIDTH = int(dut.DATA_WIDTH.value)

    clk_period = 10  # ns
    random.seed(0)  # For reproducibility

    cocotb.start_soon(clock(dut, clk_period))

    await reset_dut(dut, 5)
    dut.start.value = 0

    build_tree_latency = (((ARRAY_SIZE - 1) * ARRAY_SIZE)/2 + 2 * ARRAY_SIZE + 2)
    sort_latency = (4 * ARRAY_SIZE + 3)
    invalid = 0

    # Test Case 2: Non-empty BST
    if (ARRAY_SIZE == 10 and DATA_WIDTH == 16):
        keys = arr = [58514, 50092, 48887, 48080, 5485, 5967, 19599, 23938, 34328, 42874]
        right_child = [31, 31, 31, 31, 5, 6, 7, 8, 9, 31]
        left_child = [1, 2, 3, 4, 31, 31, 31, 31, 31, 31]
        run = 0
        expected_latency_smallest_delete = 8 
        expected_latency_largest_delete = 4 
        expected_latency_smallest_search =  8 
        expected_latency_largest_search = (ARRAY_SIZE - 1) * 2 + 2  + 2
    elif (ARRAY_SIZE == 15 and DATA_WIDTH == 6):
        run = 1
        keys =  arr = [9, 14, 15, 17, 19, 21, 30, 32, 35, 40, 46, 47, 48, 49, 50]
        left_child = [31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31]
        right_child = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 31]
        expected_latency_smallest_delete = 4
        expected_latency_largest_delete =  ((ARRAY_SIZE - 1) * 2 + 3)      
        expected_latency_smallest_search = 3
        expected_latency_largest_search = (ARRAY_SIZE - 1) * 2 + 2 + 2
    elif (ARRAY_SIZE == 15 and DATA_WIDTH == 32):
        run = 1
        keys =  arr =  [200706183, 259064287, 811616460, 956305578, 987713153, 1057458493, 1425113391, 1512400858, 2157180141, 2322902151, 2683058769, 2918411874, 2982472603, 3530595430, 3599316877]
        keys =  arr = sorted(keys, reverse=True)
        right_child = [31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31]
        left_child = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 31]
        expected_latency_smallest_delete = (ARRAY_SIZE - 1) + 4
        expected_latency_largest_delete = 4
        expected_latency_smallest_search = (ARRAY_SIZE - 1) + 2 + 2
        expected_latency_largest_search = (ARRAY_SIZE - 1) * 2 + 2 + 2
    elif (ARRAY_SIZE == 5 and DATA_WIDTH == 6):
        keys =  arr = [1, 20, 0, 61, 5]
        left_child = [2,4,15,15,15]
        right_child = [1,3,15,15,15]
        run = 0
        expected_latency_smallest_delete = 5 
        expected_latency_largest_delete = (ARRAY_SIZE - 1) + 3 + 2
        expected_latency_smallest_search = 5 
        expected_latency_largest_search = (ARRAY_SIZE - 1)*2 + 2 
    elif (ARRAY_SIZE == 6 and DATA_WIDTH == 6):
        keys = arr = [2, 20, 63, 61, 5, 1]
        left_child = [5,4,15,15,15, 15]
        right_child = [1,3,15,15,15, 15]
        run = 0
        invalid = 1
        expected_latency_smallest_delete = 5 
        expected_latency_largest_delete = (ARRAY_SIZE - 1) + 3 + 2
        expected_latency_smallest_search = 5 
        expected_latency_largest_search = (ARRAY_SIZE - 1)*2 + 2 

    if (invalid != 1):

        packed_keys = 0
        for i, val in enumerate(arr):
            packed_keys |= (val << (i * DATA_WIDTH))

        dut.data_in.value = packed_keys
        sort_after_operation = random.randint(0, 1)
        key_random = random.randint(0, 2)
        if key_random == 0:
            operation_key = sorted(arr)[0]  # Smallest key
            expected_latency = 4 + expected_latency_smallest_search + build_tree_latency + sort_after_operation * sort_latency
            check_latency = 1
            label = "SEARCH (smallest key)"
        elif key_random == 1:
            operation_key = sorted(arr)[ARRAY_SIZE-1]  # largest key
            expected_latency =  4 + expected_latency_largest_search + build_tree_latency + sort_after_operation * sort_latency
            check_latency = 1
            label = "SEARCH (largest key)"
        else:
            index = random.randint(1, ARRAY_SIZE-2)
            operation_key = sorted(arr)[index]  # random key
            check_latency = 0
            label = "SEARCH (random key)"

        expected_position = hrs_lb.search_reference_model(operation_key, keys)

        # === Test: Search ===
        await run_operation(
            dut,
            operation_key=operation_key,
            operation=0b0,  # Search
            sort_after_operation=sort_after_operation,
            label=label, 
            keys=keys, left_child=left_child, right_child=right_child, 
            check_latency=check_latency*run, expected_latency=expected_latency, 
            ARRAY_SIZE=ARRAY_SIZE, DATA_WIDTH=DATA_WIDTH,
            key_position = expected_position, operation_invalid = 0  
        )

        sort_after_operation = random.randint(0, 1)
        key_random = random.randint(0, 2)
        if key_random == 0:
            operation_key = sorted(arr)[0]  # Smallest key
            expected_latency = expected_latency_smallest_delete + build_tree_latency + sort_after_operation * sort_latency + 4 * (sort_after_operation != 1)
            check_latency = 1
            label = "DELETE (smallest key)"
        elif key_random == 1:
            operation_key = sorted(arr)[ARRAY_SIZE-1]  # largest key
            expected_latency = expected_latency_largest_delete + build_tree_latency + sort_after_operation * sort_latency + 4 * (sort_after_operation != 1)
            check_latency = 1
            label = "DELETE (largest key)"
        else:
            index = random.randint(1, ARRAY_SIZE-2)
            operation_key = sorted(arr)[index]  # random key
            check_latency = 0
            label = "DELETE (Random key)"

        key_bst, left_child_bst, right_child_bst = hrs_lb.delete_bst_key(keys, left_child, right_child, operation_key, DATA_WIDTH)

        print('key', key_bst)
        print('left_child', left_child_bst)
        print('right_child', right_child_bst)

        # === Test: Delete ===
        await run_operation(
            dut,
            operation_key=operation_key,
            operation=0b1,  # Delete
            sort_after_operation=sort_after_operation,
            label=label, 
            keys=key_bst, left_child=left_child_bst, right_child=right_child_bst, 
            check_latency=check_latency*run, expected_latency=expected_latency, ARRAY_SIZE=ARRAY_SIZE, DATA_WIDTH=DATA_WIDTH,
            key_position = expected_position, operation_invalid = 0     
        )
    else:
        left_child = []
        right_child = []
        keys = []
        for i in range(ARRAY_SIZE):
            left_child.append(2**(math.ceil(math.log2(ARRAY_SIZE)) + 1)-1)
            right_child.append(2**(math.ceil(math.log2(ARRAY_SIZE)) + 1)-1)
            keys.append(2**(DATA_WIDTH)-1)

        expected_position = 2**(math.ceil(math.log2(ARRAY_SIZE)) + 1)-1
        dut.start.value = 1
        sort_after_operation = random.randint(0, 1)
        operation_key = sorted(arr)[0]  # Smallest key
        expected_latency = expected_latency_smallest_delete + build_tree_latency + sort_after_operation * sort_latency
        check_latency = 1
        label = "DELETE (smallest key)"
        await run_operation(
            dut,
            operation_key=operation_key,
            operation=0b1,  # Delete
            sort_after_operation=sort_after_operation,
            label=label, 
            keys=keys, left_child=left_child, right_child=right_child, 
            check_latency=1, expected_latency=2, ARRAY_SIZE=ARRAY_SIZE, DATA_WIDTH=DATA_WIDTH,
            key_position = expected_position, operation_invalid = 1     
        )
    

async def reset_dut(dut, duration):
    dut.reset.value = 1
    for _ in range(duration):
        await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

async def clock(dut, clk_period):
        while True:
            dut.clk.value = 0
            await Timer(clk_period/2, units='ns')
            dut.clk.value = 1
            await Timer(clk_period/2, units='ns')


async def run_operation(dut, operation_key, operation, sort_after_operation, label, 
                        keys, left_child, right_child,  check_latency, expected_latency, ARRAY_SIZE, DATA_WIDTH,
                        key_position, operation_invalid = 0 ):


    dut.operation_key.value = operation_key
    dut.operation.value = operation
    dut.sort_after_operation.value = sort_after_operation

    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    cycle = 0
    while True:
        await RisingEdge(dut.clk)
        cycle += 1
        if (dut.complete_operation.value == 1 or dut.operation_invalid.value == 1):
            break

    if (dut.operation_invalid.value == 1):
        cocotb.log.warning(f"[{label}] Operation invalid")
    else:
        cocotb.log.info(f"[{label}] Operation complete in {cycle} cycles")
        cocotb.log.info(f"[{label}] out_keys: {dut.out_keys.value}")
        cocotb.log.info(f"[{label}] out_sorted_data: {dut.out_sorted_data.value}")


    if (operation_invalid != 1):
        if (sort_after_operation == 1):
            out_data_val = int(dut.out_sorted_data.value)
            print('output data', out_data_val)
            output_array = [ (out_data_val >> (i * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1) for i in range(ARRAY_SIZE)]
            expected_sorted_out = sorted(keys)
            assert output_array == expected_sorted_out, f"[Output incorrect. Got: {output_array}, Expected: {expected_sorted_out}]"
    
    output_keys = [ (int(dut.out_keys.value) >> (i * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1) for i in range(ARRAY_SIZE)]
    output_left_child = [ (int(dut.out_left_child.value) >> (i *  (math.ceil(math.log2(ARRAY_SIZE)) + 1) )) & ((1 <<  (math.ceil(math.log2(ARRAY_SIZE)) + 1)) - 1) for i in range(ARRAY_SIZE)]
    output_right_child = [ (int(dut.out_right_child.value) >> (i *  (math.ceil(math.log2(ARRAY_SIZE)) + 1))) & ((1 <<  (math.ceil(math.log2(ARRAY_SIZE)) + 1)) - 1) for i in range(ARRAY_SIZE)]

    assert ((keys == output_keys)), \
                f"Failed: Key {output_keys} should be modified as {keys}."
    assert ((left_child == output_left_child)), \
            f"Failed: Key {output_left_child} should be modified as  {left_child}."
    assert ((right_child == output_right_child)), \
            f"Failed: Key {output_right_child} should be modified as {right_child}."
    
    assert (dut.operation_invalid.value == operation_invalid) , "Failed: delete_invalid  set, but delete_key present"
    
    if (operation == 0):
         assert dut.key_position.value.to_unsigned() == key_position, \
            f"Failed: Smallest key {dut.search_key.value} should be at position {key_position}."

    if (check_latency):
        cocotb.log.debug(f"Total Latency : {cycle}, expected : {expected_latency}")
        assert expected_latency == cycle, f"Latency incorrect. Got: {cycle}, Expected: {expected_latency}"
