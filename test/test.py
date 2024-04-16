import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles

NB_CYCLES = 2000
ROM = [
        0xF8, 0xAA,  # 0000: movi A, 0xAA
        0xF9, 0xBB,  # 0002: movi B, 0xBB
        0x82, 0x20,  # 0004: add C,B,A
        0x8D, 0x40,  # 0006: addc F,C,A
        0x9D, 0xA4,  # 0008: movr F,F,shr
        0xC5, 0x42,  # 000A: add F, 0x42
        0xFC, 0x41,  # 000C: movi E, 0x41
        0x98, 0xB1,  # 000E: movr (EF),F    mov (e),f for tt06
        0xC4, 0xFF,  # 0010: add E, 0xFF
        0xFA, 0x06,  # 0012: movi C, 0x06
        0xC5, 0xFF,  # 0014: add F, 0xFF
        0xC2, 0xFF,  # 0016: add C, 0xFF
        0x20, 0x0A,  # 0018: jnz 0014
        0x98, 0xB1,  # 001A: movr (EF),F    mov (e),f for tt06
        0xFE, 0x00,  # 001C: movi G, 0x00
        0xFF, 0x1C,  # 001E: movi H, 0x1C
        0xC7, 0x0C,  # 0020: add H, 0x0C
        0xCE, 0x00,  # 0022: addc G, 0x00
        0x40, 0x00,  # 0024: jmp gh
        0x30, 0x13,  # 0026: jmp 0026
        0xFE, 0x40,  # 0028: movi G, 0x40
        0xFF, 0x00,  # 002A: movi H, 0x00
        0x98, 0x02,  # 002C: movr A,(GH)
        0xFC, 0x41,  # 002E: movi E, 0x41
        0xFD, 0x00,  # 0030: movi F, 0x00
        0x99, 0x12,  # 0032: movr B,(EF)
        0x80, 0x20,  # 0034: add A,B,A
        0xC0, 0xAA,  # 0036: add A, 0xAA
        0xC6, 0x02,  # 0038: add G, 0x02
        0x9F, 0x00,  # 003A: movr H,A
        0x98, 0xE1,  # 003C: movr (GH),H    mov (g),h for tt06
        0xF9, 0x21,  # 003E: movi B, 0x21
        0xC6, 0x01,  # 0040: add G, 0x01
        0x98, 0x21,  # 0042: movr (GH),B    mov (g),h for tt06
        0x30, 0x22,  # 0044: jmp 0044
       ]
RAM = bytearray(0x40)

prev_we = 1
write_address = -1
def sim_memory(dut):
    global prev_we, write_address

    # ROM + RAM reads
    we = dut.uo_out.value>>7
    addr = ((dut.uo_out.value<<8) | dut.uio_out.value) & 0x7fff
    if addr < len(ROM):
        dut.ui_in.value = ROM[addr]
    elif addr >= 0x4000:
        dut.ui_in.value = RAM[(addr>>8) & 0x3f]
    else:
        dut.ui_in.value = 0x66 # unknown

    # RAM writes
    if we == 0 and prev_we == 1: 
        write_address = dut.uo_out.value & 0x3f 
    if we == 1 and prev_we == 0: 
        RAM[write_address] = dut.uio_out.value

    prev_we = we

@cocotb.test()
async def test_dj8(dut):
    dut._log.info("start")

    # init
    dut.clk = 0
    dut.ui_in.value = 0

    # Phase 1: Test with external memory

    # reset
    dut._log.info("reset")
    dut.rst_n.value = 0
    await Timer(10,"us")
    dut.rst_n.value = 1
    await Timer(10,"us")
    
    # clk
    for cycle in range(NB_CYCLES):
        await Timer(1,"us")
        sim_memory(dut)
        dut.clk.value = 0
        await Timer(8,"us")
        sim_memory(dut)
        dut.clk.value = 0
        await Timer(1,"us")
        sim_memory(dut)
        dut.clk.value = 1
        await Timer(1,"us")
        sim_memory(dut)
        dut.clk.value = 1
        await Timer(8,"us")
        sim_memory(dut)
        dut.clk.value = 1
        await Timer(1,"us")
        sim_memory(dut)
        dut.clk.value = 0

    dut._log.info("magic: %02X %02X %02X %02X" % (RAM[0],RAM[1],RAM[2],RAM[3]))
    assert RAM[0:4] == "DJ8!".encode() # Verify magic value in RAM

    # Phase 2: Test with internal ROM
    # tt06 demo board DIP switches = 0x40 to generate opcode 0x4040 = jmp gh and jump to ROM
    # As all registers are set to 0x80 at reset, it will jump to 0x8080 (value of GH)
    # 16-bytes test ROM is mirrored from 0x8000 to 0xFFFF

    # reset
    dut._log.info("reset")
    dut.rst_n.value = 0
    await Timer(100,"us")
    dut.ui_in.value = 0x40     # DIP = 01000000
    dut.rst_n.value = 1
    await Timer(10,"us")

    for cycle in range(300):
        dut.clk.value = 1
        await Timer(10,"us")
        dut.clk.value = 0
        await Timer(10,"us")

    dut.ui_in.value = 0       # DIP = 00000000
    for cycle in range(300):
        dut.clk.value = 1
        await Timer(10,"us")
        dut.clk.value = 0
        await Timer(10,"us")

    dut.ui_in.value = 1       # DIP = 00000001
    for cycle in range(300):
        dut.clk.value = 1
        await Timer(10,"us")
        dut.clk.value = 0
        await Timer(10,"us")