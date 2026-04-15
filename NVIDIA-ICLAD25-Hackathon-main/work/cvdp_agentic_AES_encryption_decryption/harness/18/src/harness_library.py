import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from collections import deque

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

def PKCS(data, padding):
    # Convert int to 16-byte array
    data_bytes = data.to_bytes(16, byteorder='big')

    # Trim the last `padding` bytes
    trimmed = data_bytes[:16 - padding]

    # Add padding bytes
    pad_byte = padding.to_bytes(1, byteorder='big')
    padded_bytes = trimmed + pad_byte * padding

    # Convert back to integer
    return int.from_bytes(padded_bytes, byteorder='big')

def OneAndZeroes(data, padding):
    data_bytes = data.to_bytes(16, byteorder='big')

    if padding == 0:
        # No padding needed
        padded_bytes = data_bytes
    else:
        trimmed = data_bytes[:16 - padding]
        padded_bytes = trimmed + b'\x80' + b'\x00' * (padding - 1)

    return int.from_bytes(padded_bytes, byteorder='big')

def ANSIX923(data, padding):
    data_bytes = data.to_bytes(16, byteorder='big')

    if padding == 0:
        padded_bytes = data_bytes
    else:
        trimmed = data_bytes[:16 - padding]
        pad_value = padding.to_bytes(1, byteorder='big')
        padded_bytes = trimmed + b'\x00' * (padding - 1) + pad_value

    return int.from_bytes(padded_bytes, byteorder='big')

def W3C(data, padding, filler_byte=0xAF):
    data_bytes = data.to_bytes(16, byteorder='big')

    if padding == 0:
        # No padding needed
        padded_bytes = data_bytes
    else:
        trimmed = data_bytes[:16 - padding]
        fill = bytes([filler_byte] * (padding - 1)) + bytes([padding])
        padded_bytes = trimmed + fill

    return int.from_bytes(padded_bytes, byteorder='big')

class aes_decrypt:
    RCON = [
        0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36
    ]
    
    SBOX = [
        # S-box table used in AES
        0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
        0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
        0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
        0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
        0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
        0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
        0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
        0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
        0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
        0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
        0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
        0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
        0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
        0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
        0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
        0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
    ]
    
    def __init__(self):
        self.expanded_key = 0
        self.data_out = 0
        self.iv = 0
        self.counter = 0
        self.inv_s_box = [0] * 256
        for i, val in enumerate(self.SBOX):
            self.inv_s_box[val] = i
    
    def reset(self):
        self.expanded_key = 0
        self.data_out = 0
        self.iv = 0
        self.counter = 0
    
    def update_key(self, key):
        key_bytes = key.to_bytes(32, 'big')  # Convert 256-bit key to bytes
        self.expanded_key = self.expand_key(key_bytes)
    
    def expand_key(self, key):
        words = [list(key[i:i+4]) for i in range(0, 32, 4)]
        
        for i in range(8, 60):
            temp = words[i - 1]
            
            if i % 8 == 0:
                temp = self.sub_word(self.rot_word(temp))
                temp[0] ^= self.RCON[i // 8 - 1]
            elif i % 8 == 4:
                temp = self.sub_word(temp)
            
            words.append([words[i - 8][j] ^ temp[j] for j in range(4)])
        
        expanded_key_bytes = b''.join(bytes(word) for word in words)
        return int.from_bytes(expanded_key_bytes, 'big')
    
    def sub_word(self, word):
        return [self.SBOX[b] for b in word]
    
    def rot_word(self, word):
        return word[1:] + word[:1]
    
    def gmul(self, a, b):
        p = 0
        for _ in range(8):
            if b & 1:
                p ^= a
            hi = a & 0x80
            a = (a << 1) & 0xFF
            if hi:
                a ^= 0x1b
            b >>= 1
        return p

    def sub_bytes(self, state):
        for i in range(16):
            state[i] = self.SBOX[state[i]]

    def shift_rows(self, state):
        state[1], state[5], state[9], state[13] = state[5], state[9], state[13], state[1]
        state[2], state[6], state[10], state[14] = state[10], state[14], state[2], state[6]
        state[3], state[7], state[11], state[15] = state[15], state[3], state[7], state[11]

    def mix_columns(self, s):
        for i in range(4):
            a = s[i*4:(i+1)*4]
            s[i*4+0] = self.gmul(a[0],2)^self.gmul(a[1],3)^a[2]^a[3]
            s[i*4+1] = a[0]^self.gmul(a[1],2)^self.gmul(a[2],3)^a[3]
            s[i*4+2] = a[0]^a[1]^self.gmul(a[2],2)^self.gmul(a[3],3)
            s[i*4+3] = self.gmul(a[0],3)^a[1]^a[2]^self.gmul(a[3],2)

    def add_round_key(self, state, round_key_words):
        for col in range(4):
            word = round_key_words[col]
            for row in range(4):
                state[col * 4 + row] ^= (word >> (24 - 8 * row)) & 0xFF

    def get_round_keys(self):
        expanded_bytes = self.expanded_key.to_bytes(240, 'big')
        round_keys = []
        for i in range(0, 240, 16):  # Each round key is 16 bytes (4 words)
            words = [int.from_bytes(expanded_bytes[i + j*4 : i + (j+1)*4], 'big') for j in range(4)]
            round_keys.append(words)
        return round_keys

    def encrypt(self, data):
        state = [(data >> (8 * (15 - i))) & 0xFF for i in range(16)]
        round_keys = self.get_round_keys()
        
        self.add_round_key(state, round_keys[0])

        for rnd in range(1, 14):
            self.sub_bytes(state)
            self.shift_rows(state)
            self.mix_columns(state)
            self.add_round_key(state, round_keys[rnd])

        self.sub_bytes(state)
        self.shift_rows(state)
        self.add_round_key(state, round_keys[14])

        self.data_out = 0
        for b in state:
            self.data_out = (self.data_out << 8) | b
        
    def inv_sub_bytes(self, state):
        for i in range(16):
            state[i] = self.inv_s_box[state[i]]

    def inv_shift_rows(self, state):
        state[1], state[5], state[9], state[13] = state[13], state[1], state[5], state[9]
        state[2], state[6], state[10], state[14] = state[10], state[14], state[2], state[6]
        state[3], state[7], state[11], state[15] = state[7], state[11], state[15], state[3]

    def inv_mix_columns(self, s):
        for i in range(4):
            a = s[i*4:(i+1)*4]
            s[i*4+0] = self.gmul(a[0],14)^self.gmul(a[1],11)^self.gmul(a[2],13)^self.gmul(a[3],9)
            s[i*4+1] = self.gmul(a[0],9)^self.gmul(a[1],14)^self.gmul(a[2],11)^self.gmul(a[3],13)
            s[i*4+2] = self.gmul(a[0],13)^self.gmul(a[1],9)^self.gmul(a[2],14)^self.gmul(a[3],11)
            s[i*4+3] = self.gmul(a[0],11)^self.gmul(a[1],13)^self.gmul(a[2],9)^self.gmul(a[3],14)
    
    def decrypt(self, data):
        state = [(data >> (8 * (15 - i))) & 0xFF for i in range(16)]
        round_keys = self.get_round_keys()

        self.add_round_key(state, round_keys[14])

        for rnd in range(13, 0, -1):
            self.inv_shift_rows(state)
            self.inv_sub_bytes(state)
            self.add_round_key(state, round_keys[rnd])
            self.inv_mix_columns(state)

        self.inv_shift_rows(state)
        self.inv_sub_bytes(state)
        self.add_round_key(state, round_keys[0])

        self.data_out = 0
        for b in state:
            self.data_out = (self.data_out << 8) | b
    
    def MODE(self, data, mode):
        if mode == 0:
            self.ECB(data)
        elif mode == 1:
            self.CBC(data)
        elif mode == 2:
            self.PCBC(data)
        elif mode == 3:
            self.CFB(data)
        elif mode == 4:
            self.OFB(data)
        else:
            self.CTR(data)

    def ECB(self, data):
        self.decrypt(data)
    
    def CBC(self, data):
        self.decrypt(data)
        self.data_out = self.data_out ^ self.iv
        self.iv = data
    
    def PCBC(self, data):
        self.decrypt(data)
        self.data_out = self.data_out ^ self.iv
        self.iv = data ^ self.data_out
    
    def CFB(self, data):
        self.encrypt(self.iv)
        self.data_out = self.data_out ^ data
        self.iv = data
    
    def OFB(self, data):
        self.encrypt(self.iv)
        self.iv = self.data_out
        self.data_out = self.data_out ^ data
    
    def CTR(self, data):
        enc_in = (self.iv & 0x0000FFFFFFFFFFFFFFFFFFFFFFFF0000) + (self.counter & 0x0000FFFF) + ((self.counter & 0xFFFF0000) << 96)
        self.encrypt(enc_in)
        if self.counter < 2**32 - 1:
            self.counter = self.counter + 1
        else:
            self.counter = 0
        
        self.data_out = self.data_out ^ data

class aes_encrypt:
    RCON = [
        0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36
    ]
    
    SBOX = [
        # S-box table used in AES
        0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
        0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
        0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
        0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
        0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
        0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
        0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
        0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
        0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
        0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
        0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
        0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
        0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
        0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
        0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
        0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
    ]
    
    def __init__(self):
        self.expanded_key = 0
        self.data_out = 0
        self.iv = 0
        self.counter = 0
    
    def reset(self):
        self.expanded_key = 0
        self.data_out = 0
        self.iv = 0
        self.counter = 0
    
    def update_key(self, key):
        key_bytes = key.to_bytes(32, 'big')  # Convert 256-bit key to bytes
        self.expanded_key = self.expand_key(key_bytes)
    
    def expand_key(self, key):
        words = [list(key[i:i+4]) for i in range(0, 32, 4)]
        
        for i in range(8, 60):
            temp = words[i - 1]
            
            if i % 8 == 0:
                temp = self.sub_word(self.rot_word(temp))
                temp[0] ^= self.RCON[i // 8 - 1]
            elif i % 8 == 4:
                temp = self.sub_word(temp)
            
            words.append([words[i - 8][j] ^ temp[j] for j in range(4)])
        
        expanded_key_bytes = b''.join(bytes(word) for word in words)
        return int.from_bytes(expanded_key_bytes, 'big')
    
    def sub_word(self, word):
        return [self.SBOX[b] for b in word]
    
    def rot_word(self, word):
        return word[1:] + word[:1]
    
    def gmul(self, a, b):
        p = 0
        for _ in range(8):
            if b & 1:
                p ^= a
            hi = a & 0x80
            a = (a << 1) & 0xFF
            if hi:
                a ^= 0x1b
            b >>= 1
        return p

    def sub_bytes(self, state):
        for i in range(16):
            state[i] = self.SBOX[state[i]]

    def shift_rows(self, state):
        state[1], state[5], state[9], state[13] = state[5], state[9], state[13], state[1]
        state[2], state[6], state[10], state[14] = state[10], state[14], state[2], state[6]
        state[3], state[7], state[11], state[15] = state[15], state[3], state[7], state[11]

    def mix_columns(self, s):
        for i in range(4):
            a = s[i*4:(i+1)*4]
            s[i*4+0] = self.gmul(a[0],2)^self.gmul(a[1],3)^a[2]^a[3]
            s[i*4+1] = a[0]^self.gmul(a[1],2)^self.gmul(a[2],3)^a[3]
            s[i*4+2] = a[0]^a[1]^self.gmul(a[2],2)^self.gmul(a[3],3)
            s[i*4+3] = self.gmul(a[0],3)^a[1]^a[2]^self.gmul(a[3],2)

    def add_round_key(self, state, round_key_words):
        for col in range(4):
            word = round_key_words[col]
            for row in range(4):
                state[col * 4 + row] ^= (word >> (24 - 8 * row)) & 0xFF

    def get_round_keys(self):
        expanded_bytes = self.expanded_key.to_bytes(240, 'big')
        round_keys = []
        for i in range(0, 240, 16):  # Each round key is 16 bytes (4 words)
            words = [int.from_bytes(expanded_bytes[i + j*4 : i + (j+1)*4], 'big') for j in range(4)]
            round_keys.append(words)
        return round_keys

    def encrypt(self, data):
        state = [(data >> (8 * (15 - i))) & 0xFF for i in range(16)]
        round_keys = self.get_round_keys()
        
        self.add_round_key(state, round_keys[0])

        for rnd in range(1, 14):
            self.sub_bytes(state)
            self.shift_rows(state)
            self.mix_columns(state)
            self.add_round_key(state, round_keys[rnd])

        self.sub_bytes(state)
        self.shift_rows(state)
        self.add_round_key(state, round_keys[14])

        self.data_out = 0
        for b in state:
            self.data_out = (self.data_out << 8) | b
    
    def MODE(self, data, mode):
        if mode == 0:
            self.ECB(data)
        elif mode == 1:
            self.CBC(data)
        elif mode == 2:
            self.PCBC(data)
        elif mode == 3:
            self.CFB(data)
        elif mode == 4:
            self.OFB(data)
        else:
            self.CTR(data)
    
    def ECB(self, data):
        self.encrypt(data)
    
    def CBC(self, data):
        enc_in = data ^ self.iv
        self.encrypt(enc_in)
        self.iv = self.data_out
    
    def PCBC(self, data):
        enc_in = data ^ self.iv
        self.encrypt(enc_in)
        self.iv = data ^ self.data_out
    
    def CFB(self, data):
        self.encrypt(self.iv)
        self.iv = self.data_out ^ data
        self.data_out = self.iv
    
    def OFB(self, data):
        self.encrypt(self.iv)
        self.iv = self.data_out
        self.data_out = self.data_out ^ data
    
    def CTR(self, data):
        enc_in = (self.iv & 0x0000FFFFFFFFFFFFFFFFFFFFFFFF0000) + (self.counter & 0x0000FFFF) + ((self.counter & 0xFFFF0000) << 96)
        self.encrypt(enc_in)
        if self.counter < 2**32 - 1:
            self.counter = self.counter + 1
        else:
            self.counter = 0
        
        self.data_out = self.data_out ^ data
