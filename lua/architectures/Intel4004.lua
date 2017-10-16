-- 
-- This architecture implements the Intel 4004 instruction
-- set. This particular microprocessor is usually seen as
-- the first ever microprocessor. A real game changer at
-- the time! While this isn't really meant to be used for
-- anything other than tests, I would be pretty impressed
-- if someone made something cool for this. :)
--
-- Some super helpful and interesting links!
--
-- http://e4004.szyc.org/iset.ht
-- https://en.wikipedia.org/wiki/Intel_4004
-- http://codeabbey.github.io/heavy-data-1/msc-4-asm-manual-1973.pdf
--

require "/lua/api/filesystem.lua"
require "/lua/api/cconfig.lua"

function archEnvironment(ComputerAPI)

end

function archRuntime(Environment)
    -- The Accumulator, essentially a more 
    -- "Powerful" Register at 4 Bits wide.
    local Acc = 0x0

    -- The Carry Flag, set when the
    -- Accumulator overflows.
    local CY = false

    -- Sixteen General Purpose Registers,
    -- all of which are 4 Bits wide.
    local R0  = 0x0
    local R1  = 0x0
    local R2  = 0x0
    local R3  = 0x0
    local R4  = 0x0
    local R5  = 0x0
    local R6  = 0x0
    local R7  = 0x0
    local R8  = 0x0
    local R9  = 0x0
    local R10 = 0x0
    local R11 = 0x0
    local R12 = 0x0
    local R13 = 0x0
    local R14 = 0x0
    local R15 = 0x0

    -- The Program Counter which points to where the
    -- next instruction is. It's 12 Bits wide.
    local PC = 0x000

    -- Push-Down Address Call Stack, 3 Levels Deep.
    -- Of course, each address is 12 Bits wide.
    local PC1 = 0x000
    local PC2 = 0x000
    local PC3 = 0x000

    -- Banks for switching different sections of RAM in and out.
    -- Holds 8 banks, allowing for a total of 1,024 Bytes of RAM.
    -- Note that is specifically for DATA RAM.
    local Banks = {}
    for i = 0, 7 do
        local DRAM = {}; for i = 0x00, 0xFF do DRAM[i] = 0x0 end
        Banks[i] = DRAM
    end

    -- Current Data RAM Bank. Holds 256 4-Bit Characters, or 128 Bytes.
    -- DRAM is short for Data RAM.
    local DRAM = Banks[0]

    -- The Data Pointer which points to where the next
    -- memory operation is to take place. It's 8 Bits wide.
    local DP = 0x00

    -- Addressable ROM. Holds 4,096 8-Bit Words, or 4,096 Bytes.
    local ROM = {}

    --
    -- Find out what these are.
    --
    local Test = 0
    local KBP = {[0]=
        0x0, 0x1, 0x2, 0x3, 0x4, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF
    }

    -- Returns another byte for instructions that are 16-Bits long.
    local function Byte()
        return ROM[PC + 1]
    end

    -- All opcodes and their possible states, mostly for speed gain.
    -- It should be noted that these opcodes are /mostly/ accurate,
    -- but some specific exceptions are NOT implemented.
    local Opcodes = {
        -- NOP; No Operation.
        [0x00] = function() end,
        [0x01] = function() end,
        [0x02] = function() end,
        [0x03] = function() end,
        [0x04] = function() end,
        [0x05] = function() end,
        [0x06] = function() end,
        [0x07] = function() end,
        [0x08] = function() end,
        [0x09] = function() end,
        [0x0A] = function() end,
        [0x0B] = function() end,
        [0x0C] = function() end,
        [0x0D] = function() end,
        [0x0E] = function() end,
        [0x0F] = function() end,

        -- JCN; Jump Conditional.
        [0x10] = function() end,
        [0x11] = function() if                                         (Test == 0) then PC = PC & (Byte() | 0xF00) end end, -- Jump if Test == 0.
        [0x12] = function() if               ((Acc & 0x10) == 0x10)                then PC = PC & (Byte() | 0xF00) end end, -- Jump if Carry == 1.
        [0x13] = function() if               ((Acc & 0x10) == 0x10) or (Test == 0) then PC = PC & (Byte() | 0xF00) end end, -- Jump if Carry == 1 or Test == 0.
        [0x14] = function() if (Acc == 0)                                          then PC = PC & (Byte() | 0xF00) end end, -- Jump if Acc == 0.
        [0x15] = function() if (Acc == 0) or                           (Test == 0) then PC = PC & (Byte() | 0xF00) end end, -- Jump if Acc == 0 or Test == 0.
        [0x16] = function() if (Acc == 0) or ((Acc & 0x10) == 0x10)                then PC = PC & (Byte() | 0xF00) end end, -- Jump if Acc == 0 or Carry == 1.
        [0x17] = function() if (Acc == 0) or ((Acc & 0x10) == 0x10) or (Test == 0) then PC = PC & (Byte() | 0xF00) end end, -- Jump if Acc == 0 or Carry == 1 or Test == 0.
        [0x18] = function() end,
        [0x19] = function() if                                         (Test == 1) then PC = PC & (Byte() | 0xF00) end end, -- Jump if Test == 1.
        [0x1A] = function() if               ((Acc & 0x10) == 0x00)                then PC = PC & (Byte() | 0xF00) end end, -- Jump if Carry == 0.
        [0x1B] = function() if               ((Acc & 0x10) == 0x00) or (Test == 1) then PC = PC & (Byte() | 0xF00) end end, -- Jump if Carry == 0 or Test == 1.
        [0x1C] = function() if (Acc ~= 0)                                          then PC = PC & (Byte() | 0xF00) end end, -- Jump if Acc ~= 0.
        [0x1D] = function() if (Acc ~= 0) or                           (Test == 1) then PC = PC & (Byte() | 0xF00) end end, -- Jump if Acc ~= 0 or Test == 1.
        [0x1E] = function() if (Acc ~= 0) or ((Acc & 0x10) == 0x00)                then PC = PC & (Byte() | 0xF00) end end, -- Jump if Acc ~= 0 or Carry == 0.
        [0x1F] = function() if (Acc ~= 0) or ((Acc & 0x10) == 0x00) or (Test == 1) then PC = PC & (Byte() | 0xF00) end end, -- Jump if Acc ~= 0 or Carry == 0 or Test == 1.

        -- SRC; Send Register Control.
        [0x21] = function() DP = R0  | (R1  << 4) end,
        [0x23] = function() DP = R2  | (R3  << 4) end,
        [0x25] = function() DP = R4  | (R5  << 4) end,
        [0x27] = function() DP = R6  | (R7  << 4) end,
        [0x29] = function() DP = R8  | (R9  << 4) end,
        [0x2B] = function() DP = R10 | (R11 << 4) end,
        [0x2D] = function() DP = R12 | (R13 << 4) end,
        [0x2F] = function() DP = R14 | (R15 << 4) end,

        -- FIM; Fetch Immediate.
        [0x20] = function() local D = Byte(); R0  = D >> 4; R1  = D & 0x0F end,
        [0x22] = function() local D = Byte(); R2  = D >> 4; R3  = D & 0x0F end,
        [0x24] = function() local D = Byte(); R4  = D >> 4; R5  = D & 0x0F end,
        [0x26] = function() local D = Byte(); R6  = D >> 4; R7  = D & 0x0F end,
        [0x28] = function() local D = Byte(); R8  = D >> 4; R9  = D & 0x0F end,
        [0x2A] = function() local D = Byte(); R10 = D >> 4; R11 = D & 0x0F end,
        [0x2C] = function() local D = Byte(); R12 = D >> 4; R13 = D & 0x0F end,
        [0x2E] = function() local D = Byte(); R14 = D >> 4; R15 = D & 0x0F end,

        -- FIN; Fetch Indirect. --------------------------------------------------------------------
        [0x30] = 
        [0x32] = 
        [0x34] = 
        [0x36] = 
        [0x38] = 
        [0x3A] = 
        [0x3C] = 
        [0x3E] = 

        -- JIN; Jump Indirect.
        [0x31] = function() PC = PC & (R1  | (R0  << 4) | 0xF00) end,
        [0x33] = function() PC = PC & (R3  | (R2  << 4) | 0xF00) end,
        [0x35] = function() PC = PC & (R5  | (R4  << 4) | 0xF00) end,
        [0x37] = function() PC = PC & (R7  | (R6  << 4) | 0xF00) end,
        [0x39] = function() PC = PC & (R9  | (R8  << 4) | 0xF00) end,
        [0x3B] = function() PC = PC & (R11 | (R10 << 4) | 0xF00) end,
        [0x3D] = function() PC = PC & (R13 | (R12 << 4) | 0xF00) end,
        [0x3F] = function() PC = PC & (R15 | (R14 << 4) | 0xF00) end,

        -- JUN; Jump Unconditional.
        [0x40] = function() PC = Byte()         end,
        [0x41] = function() PC = Byte() | 0x100 end,
        [0x42] = function() PC = Byte() | 0x200 end,
        [0x43] = function() PC = Byte() | 0x300 end,
        [0x44] = function() PC = Byte() | 0x400 end,
        [0x45] = function() PC = Byte() | 0x500 end,
        [0x46] = function() PC = Byte() | 0x600 end,
        [0x47] = function() PC = Byte() | 0x700 end,
        [0x48] = function() PC = Byte() | 0x800 end,
        [0x49] = function() PC = Byte() | 0x900 end,
        [0x4A] = function() PC = Byte() | 0xA00 end,
        [0x4B] = function() PC = Byte() | 0xB00 end,
        [0x4C] = function() PC = Byte() | 0xC00 end,
        [0x4D] = function() PC = Byte() | 0xD00 end,
        [0x4E] = function() PC = Byte() | 0xE00 end,
        [0x4F] = function() PC = Byte() | 0xF00 end,

        -- JMS; Jump to Subroutine.
        [0x50] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte()         end,
        [0x51] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0x100 end,
        [0x52] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0x200 end,
        [0x53] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0x300 end,
        [0x54] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0x400 end,
        [0x55] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0x500 end,
        [0x56] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0x600 end,
        [0x57] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0x700 end,
        [0x58] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0x800 end,
        [0x59] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0x900 end,
        [0x5A] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0xA00 end,
        [0x5B] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0xB00 end,
        [0x5C] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0xC00 end,
        [0x5D] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0xD00 end,
        [0x5E] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0xE00 end,
        [0x5F] = function() PC3 = PC2; PC2 = PC1; PC1 = PC + 1; PC = Byte() | 0xF00 end,

        -- INC; Increment Index Register.
        [0x60] = function() R0  = (R0  + 1) & 0xF end,
        [0x61] = function() R1  = (R1  + 1) & 0xF end,
        [0x62] = function() R2  = (R2  + 1) & 0xF end,
        [0x63] = function() R3  = (R3  + 1) & 0xF end,
        [0x64] = function() R4  = (R4  + 1) & 0xF end,
        [0x65] = function() R5  = (R5  + 1) & 0xF end,
        [0x66] = function() R6  = (R6  + 1) & 0xF end,
        [0x67] = function() R7  = (R7  + 1) & 0xF end,
        [0x68] = function() R8  = (R8  + 1) & 0xF end,
        [0x69] = function() R9  = (R9  + 1) & 0xF end,
        [0x6A] = function() R10 = (R10 + 1) & 0xF end,
        [0x6B] = function() R11 = (R11 + 1) & 0xF end,
        [0x6C] = function() R12 = (R12 + 1) & 0xF end,
        [0x6D] = function() R13 = (R13 + 1) & 0xF end,
        [0x6E] = function() R14 = (R14 + 1) & 0xF end,
        [0x6F] = function() R15 = (R15 + 1) & 0xF end,

        -- ISZ; Increment and Skip.
        [0x70] = function() R0  = (R0  + 1) & 0xF; if R0  ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x71] = function() R1  = (R1  + 1) & 0xF; if R1  ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x72] = function() R2  = (R2  + 1) & 0xF; if R2  ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x73] = function() R3  = (R3  + 1) & 0xF; if R3  ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x74] = function() R4  = (R4  + 1) & 0xF; if R4  ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x75] = function() R5  = (R5  + 1) & 0xF; if R5  ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x76] = function() R6  = (R6  + 1) & 0xF; if R6  ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x77] = function() R7  = (R7  + 1) & 0xF; if R7  ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x78] = function() R8  = (R8  + 1) & 0xF; if R8  ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x79] = function() R9  = (R9  + 1) & 0xF; if R9  ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x7A] = function() R10 = (R10 + 1) & 0xF; if R10 ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x7B] = function() R11 = (R11 + 1) & 0xF; if R11 ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x7C] = function() R12 = (R12 + 1) & 0xF; if R12 ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x7D] = function() R13 = (R13 + 1) & 0xF; if R13 ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x7E] = function() R14 = (R14 + 1) & 0xF; if R14 ~= 0 then PC = PC & (Byte() | 0xF00) end end,
        [0x7F] = function() R15 = (R15 + 1) & 0xF; if R15 ~= 0 then PC = PC & (Byte() | 0xF00) end end,

        -- ADD; Add Index Register to Accumulator with Carry.
        [0x80] = function() local a = Acc + R0;  CY = a > 0xF; Acc = a & 0xF end,
        [0x81] = function() local a = Acc + R1;  CY = a > 0xF; Acc = a & 0xF end,
        [0x82] = function() local a = Acc + R2;  CY = a > 0xF; Acc = a & 0xF end,
        [0x83] = function() local a = Acc + R3;  CY = a > 0xF; Acc = a & 0xF end,
        [0x84] = function() local a = Acc + R4;  CY = a > 0xF; Acc = a & 0xF end,
        [0x85] = function() local a = Acc + R5;  CY = a > 0xF; Acc = a & 0xF end,
        [0x86] = function() local a = Acc + R6;  CY = a > 0xF; Acc = a & 0xF end,
        [0x87] = function() local a = Acc + R7;  CY = a > 0xF; Acc = a & 0xF end,
        [0x88] = function() local a = Acc + R8;  CY = a > 0xF; Acc = a & 0xF end,
        [0x89] = function() local a = Acc + R9;  CY = a > 0xF; Acc = a & 0xF end,
        [0x8A] = function() local a = Acc + R10; CY = a > 0xF; Acc = a & 0xF end,
        [0x8B] = function() local a = Acc + R11; CY = a > 0xF; Acc = a & 0xF end,
        [0x8C] = function() local a = Acc + R12; CY = a > 0xF; Acc = a & 0xF end,
        [0x8D] = function() local a = Acc + R13; CY = a > 0xF; Acc = a & 0xF end,
        [0x8E] = function() local a = Acc + R14; CY = a > 0xF; Acc = a & 0xF end,
        [0x8F] = function() local a = Acc + R15; CY = a > 0xF; Acc = a & 0xF end,

        -- SUB; Subtract Index Register from Accumulator with Borrow.
        [0x90] = function() local a = Acc - R0;  CY = a > -0x01; Acc = a & 0xF end,
        [0x91] = function() local a = Acc - R1;  CY = a > -0x01; Acc = a & 0xF end,
        [0x92] = function() local a = Acc - R2;  CY = a > -0x01; Acc = a & 0xF end,
        [0x93] = function() local a = Acc - R3;  CY = a > -0x01; Acc = a & 0xF end,
        [0x94] = function() local a = Acc - R4;  CY = a > -0x01; Acc = a & 0xF end,
        [0x95] = function() local a = Acc - R5;  CY = a > -0x01; Acc = a & 0xF end,
        [0x96] = function() local a = Acc - R6;  CY = a > -0x01; Acc = a & 0xF end,
        [0x97] = function() local a = Acc - R7;  CY = a > -0x01; Acc = a & 0xF end,
        [0x98] = function() local a = Acc - R8;  CY = a > -0x01; Acc = a & 0xF end,
        [0x99] = function() local a = Acc - R9;  CY = a > -0x01; Acc = a & 0xF end,
        [0x9A] = function() local a = Acc - R10; CY = a > -0x01; Acc = a & 0xF end,
        [0x9B] = function() local a = Acc - R11; CY = a > -0x01; Acc = a & 0xF end,
        [0x9C] = function() local a = Acc - R12; CY = a > -0x01; Acc = a & 0xF end,
        [0x9D] = function() local a = Acc - R13; CY = a > -0x01; Acc = a & 0xF end,
        [0x9E] = function() local a = Acc - R14; CY = a > -0x01; Acc = a & 0xF end,
        [0x9F] = function() local a = Acc - R15; CY = a > -0x01; Acc = a & 0xF end,

        -- LD; Load Index Register to Accumulator.
        [0xA0] = function() Acc = R0  end,
        [0xA1] = function() Acc = R1  end,
        [0xA2] = function() Acc = R2  end,
        [0xA3] = function() Acc = R3  end,
        [0xA4] = function() Acc = R4  end,
        [0xA5] = function() Acc = R5  end,
        [0xA6] = function() Acc = R6  end,
        [0xA7] = function() Acc = R7  end,
        [0xA8] = function() Acc = R8  end,
        [0xA9] = function() Acc = R9  end,
        [0xAA] = function() Acc = R10 end,
        [0xAB] = function() Acc = R11 end,
        [0xAC] = function() Acc = R12 end,
        [0xAD] = function() Acc = R13 end,
        [0xAE] = function() Acc = R14 end,
        [0xAF] = function() Acc = R15 end,

        -- XCH; Exchange Index Register and Accumulator.
        [0xB0] = function() Acc, R0  = R0, Acc  end,
        [0xB1] = function() Acc, R1  = R1, Acc  end,
        [0xB2] = function() Acc, R2  = R2, Acc  end,
        [0xB3] = function() Acc, R3  = R3, Acc  end,
        [0xB4] = function() Acc, R4  = R4, Acc  end,
        [0xB5] = function() Acc, R5  = R5, Acc  end,
        [0xB6] = function() Acc, R6  = R6, Acc  end,
        [0xB7] = function() Acc, R7  = R7, Acc  end,
        [0xB8] = function() Acc, R8  = R8, Acc  end,
        [0xB9] = function() Acc, R9  = R9, Acc  end,
        [0xBA] = function() Acc, R10 = R10, Acc end,
        [0xBB] = function() Acc, R11 = R11, Acc end,
        [0xBC] = function() Acc, R12 = R12, Acc end,
        [0xBD] = function() Acc, R13 = R13, Acc end,
        [0xBE] = function() Acc, R14 = R14, Acc end,
        [0xBF] = function() Acc, R15 = R15, Acc end,

        -- BBL; Branch Back and Load.
        [0xC0] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0x0 end,
        [0xC1] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0x1 end,
        [0xC2] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0x2 end,
        [0xC3] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0x3 end,
        [0xC4] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0x4 end,
        [0xC5] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0x5 end,
        [0xC6] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0x6 end,
        [0xC7] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0x7 end,
        [0xC8] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0x8 end,
        [0xC9] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0x9 end,
        [0xCA] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0xA end,
        [0xCB] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0xB end,
        [0xCC] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0xC end,
        [0xCD] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0xD end,
        [0xCE] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0xE end,
        [0xCF] = function() PC = PC1; PC1 = PC2; PC2 = PC3; PC3 = 0x000; Acc = 0xF end,

        -- LDM; Load Data to Accumulator.
        [0xD0] = function() Acc = 0x0 end,
        [0xD1] = function() Acc = 0x1 end,
        [0xD2] = function() Acc = 0x2 end,
        [0xD3] = function() Acc = 0x3 end,
        [0xD4] = function() Acc = 0x4 end,
        [0xD5] = function() Acc = 0x5 end,
        [0xD6] = function() Acc = 0x6 end,
        [0xD7] = function() Acc = 0x7 end,
        [0xD8] = function() Acc = 0x8 end,
        [0xD9] = function() Acc = 0x9 end,
        [0xDA] = function() Acc = 0xA end,
        [0xDB] = function() Acc = 0xB end,
        [0xDC] = function() Acc = 0xC end,
        [0xDD] = function() Acc = 0xD end,
        [0xDE] = function() Acc = 0xE end,
        [0xDF] = function() Acc = 0xF end,

        -- Input/Output and RAM Instructions --

        -- WRM; Write Main Memory from Accumulator.
        [0xE0] = function() DRAM[DP] = Acc end,

        -- WMP; Write RAM Port. --------------------------------------------------------------------
        [0xE1] = function() end,

        -- WRR; Write ROM Port. --------------------------------------------------------------------
        [0xE2] = function() end,

        -- WPM; Write Program Memory (This instruction is available on the 4008/4009 only).
        [0xE3] = function() end,

        -- WR0; Write Status Char 0. --------------------------------------------------------------------
        [0xE4] = function() end,

        -- WR1; Write Status Char 1. --------------------------------------------------------------------
        [0xE5] = function() end,

        -- WR2; Write Status Char 2. --------------------------------------------------------------------
        [0xE6] = function() end,

        -- WR3; Write Status Char 3. --------------------------------------------------------------------
        [0xE7] = function() end,

        -- SBM; Subtract Main Memory.
        [0xE8] = function() local a = Acc - DRAM[DP]; CY = a > -0x01; Acc = a & 0xF end,
 
        -- RDM; Read Main Memory into Accumulator.
        [0xE9] = function() Acc = DRAM[DP] end,

        -- RDR; Read ROM Port. --------------------------------------------------------------------
        [0xEA] = function() end,

        -- ADM; Add Main Memory.
        [0xEB] = function() local a = Acc + DRAM[DP]; CY = a > 0xF; Acc = a & 0xF end,

        -- RD0; Read Status Char 0. --------------------------------------------------------------------
        [0xEC] = function() end,

        -- RD1; Read Status Char 1. --------------------------------------------------------------------
        [0xED] = function() end,

        -- RD2; Read Status Char 2. --------------------------------------------------------------------
        [0xEE] = function() end,

        -- RD3; Read Status Char 3. --------------------------------------------------------------------
        [0xEF] = function() end,

        -- Accumulator Group Instructions --

        -- CLB; Clear Both.
        [0xF0] = function() Acc = 0x0; CY = false end,

        -- CLC; Clear Carry.
        [0xF1] = function() CY = false end,

        -- IAC; Increment Accumulator.
        [0xF2] = function() local a = Acc + 1; if a < 0x10 then Acc = a; CY = false else Acc = 0; CY = true end end,

        -- CMC; Complement Carry.
        [0xF3] = function() CY = not CY end,

        -- CMA; Complement Accumulator.
        [0xF4] = function() Acc = ~Acc end,

        -- RAL; Rotate Left.
        [0xF5] = function() local a = Acc << 1; if CY then a = a | 1 end; CY = ((a & 32) == 32); Acc = a & 0xF  end,

        -- RAR; Rotate Right.
        [0xF6] = function() local a = Acc; if CY then a = a | 32 end; CY = ((a & 1) == 1); Acc = (a >> 1) & 0xF end,

        -- TCC; Transfer Carry and Clear.
        [0xF7] = function() Acc = CY and 0x1 or 00; CY = false end,

        -- DAC; Decrement Accumulator.
        [0xF8] = function() local a = Acc - 1; if a > -0x01 then Acc = a; CY = true else Acc = 0; CY = false end end,

        -- TCS; Transfer Carry Subtract.
        [0xF9] = function() Acc = CY and 0xA or 0x9; CY = false end,

        -- STC; Set Carry.
        [0xFA] = function() CY = true end,

        -- DAA; Decimal Adjust Accumulator.
        [0xFB] = function() local a = Acc; if CY or a > 9 then a = a + 6 end; if a > 0xF then CY = true; a = a & 0xF end; Acc = a end,

        -- KBP; Keyboard Process.
        [0xFC] = function() Acc = KBP[Acc] end,

        -- DCL; Designate Command Line.
        [0xFD] = function() DRAM = Bank[Acc & 0x8] end,

        -- NOP; No Operation. --
        [0xFE] = function() end,
        [0xFF] = function() end
    }
end