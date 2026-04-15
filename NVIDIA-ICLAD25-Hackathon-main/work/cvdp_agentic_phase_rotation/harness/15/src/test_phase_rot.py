import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import harness_library as hrs_lb
import random
import math
import cmath

@cocotb.test()
async def test_convolution_0(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
     
    debug = 0
    # Retrieve the parameters from the DUT    
    NBW_IN_DATA = int(dut.NBW_IN_DATA.value)
    NBW_OUT_DATA = int(dut.NBW_OUT_DATA.value)
    NBW_ANG = int(dut.NBW_ANG.value)
    NBW_COS = int(dut.NBW_COS.value)
    NS_IN   = int(dut.NS_IN.value)

    min_ang = -1*(2**NBW_ANG)//2
    max_ang = (2**NBW_ANG)//2 - 1

    runs = 10

    # Initialize DUT
    await hrs_lb.dut_init(dut) 
    await hrs_lb.reset_dut(dut.rst_async_n)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    rotated_values_delayed = []

    for i in range(NS_IN):
      rotated_values_delayed.append((0, 0))

    data_re_values = NS_IN*[0]
    data_im_values = NS_IN*[0]
    data_re_values_delayed = NS_IN*[0]
    data_im_values_delayed = NS_IN*[0]

    angle_values = NS_IN*[0]
    angle_values_delayed = NS_IN*[0]

    i_bypass = random.randint(0, 1)

    for i in range(runs):

      # Check if the interfaces changes were applied
      for j in range(NS_IN):
        # Check in uu_gen_cos_sin_lut
        assert hasattr(dut.gen_lut_phase_rot[j].uu_gen_cos_sin_lut, "clk")
        assert hasattr(dut.gen_lut_phase_rot[j].uu_gen_cos_sin_lut, "rst_async_n")
        assert hasattr(dut.gen_lut_phase_rot[j].uu_gen_cos_sin_lut, "i_en_capture_cos_sin")
        
        #Check in uu_phase_rotation
        assert hasattr(dut.gen_lut_phase_rot[j].uu_phase_rotation, "rst_async_n")
        assert hasattr(dut.gen_lut_phase_rot[j].uu_phase_rotation, "i_bypass")

      i_enable_capture_data    = random.randint(0, 1)
      i_enable_capture_cos_sin = random.randint(0, 1)

      dut.i_bypass.value = i_bypass

      angle_values = [(random.randint(min_ang, max_ang)) for _ in range(NS_IN)]  # Generate NS_IN random values
      i_angle_value = 0
      for i in range(NS_IN):
          i_angle_value |= (angle_values[i] & ((1 << NBW_ANG) - 1)) << (i * NBW_ANG)
  
      dut.i_angle.value = i_angle_value  # Assign the full concatenated value
      dut.i_en_capture_data.value    = i_enable_capture_data
      dut.i_en_capture_cos_sin.value = i_enable_capture_cos_sin

      data_re_values = [random.randint(-2**(NBW_IN_DATA-1), 2**(NBW_IN_DATA-1)-1) for _ in range(NS_IN)]
      data_im_values = [random.randint(-2**(NBW_IN_DATA-1), 2**(NBW_IN_DATA-1)-1) for _ in range(NS_IN)]


      rotated_values = []
      for i in range(NS_IN):
          theta = (angle_values_delayed[i] / 64) * math.pi  # Convert to radians
          #if debug:
          #  cocotb.log.info(f"theta = {theta} and angle int = {angle_values_delayed[i]}")
          
          rotation_factor = cmath.exp(1j * theta)  # e^(jθ)
  
          # Original complex number
          original_complex = complex(data_re_values_delayed[i], data_im_values_delayed[i])
  
          # Perform rotation
          rotated_complex = original_complex * rotation_factor

          # Store real and imaginary parts separately
          if i_bypass:
            rotated_values.append((data_re_values_delayed[i], data_im_values_delayed[i]))
          else:
            rotated_values.append((rotated_complex.real*256, rotated_complex.imag*256))

      if i_enable_capture_cos_sin:
        angle_values_delayed = angle_values

      if i_enable_capture_data:
        data_re_values_delayed = data_re_values
        data_im_values_delayed = data_im_values

      i_data_re_value = 0
      i_data_im_value = 0
  
      # Concatenate NS_IN values for real and imaginary data
      for i in range(NS_IN):
          i_data_re_value |= (data_re_values[i] & ((1 << NBW_IN_DATA) - 1)) << (i * NBW_IN_DATA)
          i_data_im_value |= (data_im_values[i] & ((1 << NBW_IN_DATA) - 1)) << (i * NBW_IN_DATA)
  
      # Assign the full concatenated data values
      dut.i_data_re.value = i_data_re_value
      dut.i_data_im.value = i_data_im_value

      await RisingEdge(dut.clk)
      if debug:
         cocotb.log.info(f"[INPUTS] i_en_capture_data = {i_enable_capture_data}, i_en_capture_cos_sin = {i_enable_capture_cos_sin}, i_angle = {angle_values}, i_data_re = {data_re_values}, i_data_im = {data_im_values}")
         cocotb.log.info(f"[DEBUG] re = {dut.gen_lut_phase_rot[0].uu_phase_rotation.i_data_re.value.to_signed()}")
         cocotb.log.info(f"[DEBUG] im = {dut.gen_lut_phase_rot[0].uu_phase_rotation.i_data_im.value.to_signed()}")
         cocotb.log.info(f"[DEBUG] cos = {dut.gen_lut_phase_rot[0].uu_phase_rotation.i_cos.value.to_signed()}")
         cocotb.log.info(f"[DEBUG] sim = {dut.gen_lut_phase_rot[0].uu_phase_rotation.i_sin.value.to_signed()}")

      raw_data_re = dut.o_data_re.value.to_unsigned()  # Full NS_IN * NBW_OUT_DATA vector
      extracted_values_re = []
      
      # Extract imaginary part (o_data_im)
      raw_data_im = dut.o_data_im.value.to_unsigned()  # Full NS_IN * NBW_OUT_DATA vector
      extracted_values_im = []
      
      # Loop through each NS_IN segment to extract real and imaginary parts
      for i in range(NS_IN):
          shift_amount = i * NBW_OUT_DATA
      
          # Extract real part
          value_re = (raw_data_re >> shift_amount) & ((1 << NBW_OUT_DATA) - 1)
          if value_re & (1 << (NBW_OUT_DATA - 1)):  # Convert to signed
              value_re -= (1 << NBW_OUT_DATA)
          extracted_values_re.append(value_re)
      
          # Extract imaginary part
          value_im = (raw_data_im >> shift_amount) & ((1 << NBW_OUT_DATA) - 1)
          if value_im & (1 << (NBW_OUT_DATA - 1)):  # Convert to signed
              value_im -= (1 << NBW_OUT_DATA)
          extracted_values_im.append(value_im)
      
      # Logging extracted values
      if debug:
         cocotb.log.info(f"[DUT OUTPUT] extracted_values_re = {extracted_values_re}")
         cocotb.log.info(f"[DUT OUTPUT] extracted_values_im = {extracted_values_im}")
         cocotb.log.info(f"[EXP OUTPUT] expected_values_re = {rotated_values_delayed}")
      
      if i_bypass == 1:
        rotated_values_delayed = rotated_values.copy()      

      if len(extracted_values_re) == len(rotated_values_delayed):
          # Compute angles for extracted values
          angles_extracted = [math.degrees(math.atan2(im, re)) for re, im in zip(extracted_values_re, extracted_values_im)]
          
          # Compute angles for rotated (expected) values
          angles_rotated = [math.degrees(math.atan2(rotated[1], rotated[0])) for rotated in rotated_values_delayed]
      
          # Compute angular difference
          angle_differences = [
              (diff + 180) % 360 - 180  # Normalize to range [-180, 180]
              for diff in [extracted - rotated for extracted, rotated in zip(angles_extracted, angles_rotated)]
          ]
      
          # Log results
          if debug:
            cocotb.log.info(f"[ANGLE EXTRACTED] {angles_extracted}")
            cocotb.log.info(f"[ANGLE ROTATED] {angles_rotated}")
            cocotb.log.info(f"[ANGLE DIFFERENCE] {angle_differences}\n")
      else:
          cocotb.log.error("List size mismatch between extracted_values and rotated_values_delayed!")
      
      if i_bypass == 0:
        rotated_values_delayed = rotated_values.copy()

      assert all(diff <= 1 for diff in angle_differences), f"Differences are too large: {angle_differences}"

    #for item in dir(dut.gen_lut_phase_rot[0].uu_phase_rotation.i_data_re):
    #  print(f"- {item}")      
  