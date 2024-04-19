----------------------------------------------------------------------------
-- DJ8 CPU (C) DaveX 2003-2024
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tt_um_dvxf_dj8 is
    port (
        ui_in   : in  std_logic_vector(7 downto 0);
        uo_out  : out std_logic_vector(7 downto 0);
        uio_in  : in  std_logic_vector(7 downto 0);
        uio_out : out std_logic_vector(7 downto 0);
        uio_oe  : out std_logic_vector(7 downto 0);
        ena     : in  std_logic;
        clk     : in  std_logic;
        rst_n   : in  std_logic
    );
end tt_um_dvxf_dj8;

architecture behavioral of tt_um_dvxf_dj8 is    
    type stateType is (fetch1,fetch2,execute,writeback);
    signal state, nextState : stateType; 

    signal pc: std_logic_vector(14 downto 0);
    signal nextpc: std_logic_vector(14 downto 0);
    signal ir: std_logic_vector(15 downto 0);
    signal nextir: std_logic_vector(15 downto 0);

    signal ALU_a: std_logic_vector(7 downto 0);
    signal ALU_b: std_logic_vector(7 downto 0);
    signal ALU_result: std_logic_vector(7 downto 0);
    signal ALU_c_in: std_logic;
    signal ALU_c_out: std_logic;
    signal ALU_z_out: std_logic;
    signal ALU_opalu: std_logic_vector(2 downto 0);
    signal ALU_shift: std_logic_vector(1 downto 0);

    signal ir_opalu: std_logic_vector(2 downto 0);
    signal ir_dest: std_logic_vector(2 downto 0);
    signal ir_src: std_logic_vector(2 downto 0);
    signal ir_immE: std_logic;
    signal ir_AluOpToReg: std_logic;
    signal ir_imm8: std_logic_vector(7 downto 0);
    signal ir_imm12: std_logic_vector(11 downto 0);
    signal ir_fromMem: std_logic;
    signal ir_toMem: std_logic;
    signal ir_instruction: std_logic_vector(1 downto 0);
    signal ir_jumpcode: std_logic_vector(1 downto 0);
    signal ir_shift: std_logic_vector(1 downto 0);
    signal ir_useEF: std_logic;

    signal flag_C, next_flag_C: std_logic;
    signal flag_Z, next_flag_Z: std_logic;

    signal REGS_read_A: std_logic_vector(2 downto 0);
    signal REGS_write_A: std_logic_vector(2 downto 0);
    signal REGS_data_out: std_logic_vector(7 downto 0);
    signal REGS_data_in: std_logic_vector(7 downto 0);
    signal REGS_we: std_logic;

    signal ACC: std_logic_vector(7 downto 0);
    signal EF: std_logic_vector(15 downto 0);
    signal GH: std_logic_vector(15 downto 0);

    -- external signals mapped to TT06
    signal reset: std_logic;
    signal address_bus_out: std_logic_vector(15 downto 0);
    signal mem_data_in: std_logic_vector(7 downto 0);
    signal mem_bus_we, next_mem_bus_we: std_logic;

    -- test ROM
    type romType is array (0 to 255) of std_logic_vector(7 downto 0);
    signal tt06rom: romType := (
        -- Test ROM: DP0=0, DP1=1, DP2=0: Rotating indicator on 7-segment display
        -- Test ROM: DP0=0, DP1=1, DP2=1: Bytebeat synth
        -- ROM entry point: 0x8080 
        x"10", x"83",  -- 8000: jz 0106
        x"ED", x"80",  -- 8002: or F, 0x80
        x"30", x"A6",  -- 8004: jmp 014C
        x"98", x"00",  -- 8006: movr A,A
        x"30", x"A6",  -- 8008: jmp 014C
        x"98", x"64",  -- 800A: movr A,D,shr
        x"98", x"04",  -- 800C: movr A,A,shr
        x"9D", x"04",  -- 800E: movr F,A,shr
        x"98", x"40",  -- 8010: movr A,C
        x"80", x"00",  -- 8012: add A,A,A
        x"80", x"00",  -- 8014: add A,A,A
        x"80", x"00",  -- 8016: add A,A,A
        x"80", x"00",  -- 8018: add A,A,A
        x"80", x"00",  -- 801A: add A,A,A
        x"AD", x"A0",  -- 801C: or F,F,A
        x"98", x"02",  -- 801E: movr A,(GH)
        x"E0", x"EA",  -- 8020: xor A, 0xEA
        x"F0", x"30",  -- 8022: and A, 0x30
        x"B4", x"60",  -- 8024: and E,D,A
        x"98", x"02",  -- 8026: movr A,(GH)
        x"E0", x"EA",  -- 8028: xor A, 0xEA
        x"F0", x"C0",  -- 802A: and A, 0xC0
        x"98", x"04",  -- 802C: movr A,A,shr
        x"98", x"04",  -- 802E: movr A,A,shr
        x"98", x"04",  -- 8030: movr A,A,shr
        x"98", x"04",  -- 8032: movr A,A,shr
        x"B0", x"40",  -- 8034: and A,C,A
        x"A8", x"80",  -- 8036: or A,E,A
        x"10", x"A1",  -- 8038: jz 0142
        x"98", x"60",  -- 803A: movr A,D
        x"80", x"00",  -- 803C: add A,A,A
        x"80", x"00",  -- 803E: add A,A,A
        x"30", x"A5",  -- 8040: jmp 014A
        x"98", x"60",  -- 8042: movr A,D
        x"98", x"00",  -- 8044: movr A,A
        x"98", x"00",  -- 8046: movr A,A
        x"30", x"A5",  -- 8048: jmp 014A
        x"AD", x"A0",  -- 804A: or F,F,A
        x"98", x"A1",  -- 804C: movr (GH),F
        x"98", x"20",  -- 804E: movr A,B
        x"F0", x"10",  -- 8050: and A, 0x10
        x"20", x"B5",  -- 8052: jnz 016A
        x"9C", x"A0",  -- 8054: movr E,F
        x"E4", x"FF",  -- 8056: xor E, 0xFF
        x"C4", x"01",  -- 8058: add E, 0x01
        x"C5", x"01",  -- 805A: add F, 0x01
        x"38", x"AF",  -- 805C: jmp 115E
        x"C5", x"FF",  -- 805E: add F, 0xFF
        x"28", x"AF",  -- 8060: jnz 115E
        x"30", x"B2",  -- 8062: jmp 0164
        x"C4", x"FF",  -- 8064: add E, 0xFF
        x"20", x"B2",  -- 8066: jnz 0164
        x"FE", x"00",  -- 8068: movi G, 0x00
        x"98", x"20",  -- 806A: movr A,B
        x"F0", x"03",  -- 806C: and A, 0x03
        x"C0", x"01",  -- 806E: add A, 0x01
        x"83", x"60",  -- 8070: add D,D,A
        x"CA", x"00",  -- 8072: addc C, 0x00
        x"30", x"57",  -- 8074: jmp 00AE
        x"00", x"00",  -- 8076: ???
        x"00", x"00",  -- 8078: ???
        x"00", x"00",  -- 807A: ???
        x"00", x"00",  -- 807C: ???
        x"00", x"00",  -- 807E: ???
        x"FE", x"00",  -- 8080: movi G, 0x00
        x"98", x"02",  -- 8082: movr A,(GH)
        x"F0", x"20",  -- 8084: and A, 0x20
        x"20", x"54",  -- 8086: jnz 00A8
        x"F8", x"01",  -- 8088: movi A, 0x01
        x"9C", x"00",  -- 808A: movr E,A
        x"99", x"12",  -- 808C: movr B,(EF)
        x"10", x"4C",  -- 808E: jz 0098
        x"C3", x"01",  -- 8090: add D, 0x01
        x"CA", x"00",  -- 8092: addc C, 0x00
        x"C9", x"00",  -- 8094: addc B, 0x00
        x"20", x"46",  -- 8096: jnz 008C
        x"80", x"00",  -- 8098: add A,A,A
        x"D4", x"20",  -- 809A: subc E, 0x20
        x"10", x"44",  -- 809C: jz 0088
        x"30", x"45",  -- 809E: jmp 008A
        x"28", x"63",  -- 80A0: jnz 10C6
        x"29", x"44",  -- 80A2: jnz 1288
        x"61", x"76",  -- 80A4: jmp gh
        x"65", x"58",  -- 80A6: jmp gh
        x"FA", x"00",  -- 80A8: movi C, 0x00
        x"FB", x"00",  -- 80AA: movi D, 0x00
        x"99", x"02",  -- 80AC: movr B,(GH)
        x"98", x"02",  -- 80AE: movr A,(GH)
        x"E0", x"EA",  -- 80B0: xor A, 0xEA
        x"F0", x"0C",  -- 80B2: and A, 0x0C
        x"B4", x"60",  -- 80B4: and E,D,A
        x"98", x"02",  -- 80B6: movr A,(GH)
        x"E0", x"EA",  -- 80B8: xor A, 0xEA
        x"F0", x"03",  -- 80BA: and A, 0x03
        x"20", x"61",  -- 80BC: jnz 00C2
        x"98", x"02",  -- 80BE: movr A,(GH)
        x"30", x"63",  -- 80C0: jmp 00C6
        x"E8", x"10",  -- 80C2: or A, 0x10
        x"30", x"63",  -- 80C4: jmp 00C6
        x"B0", x"40",  -- 80C6: and A,C,A
        x"A8", x"80",  -- 80C8: or A,E,A
        x"20", x"85",  -- 80CA: jnz 010A
        x"98", x"44",  -- 80CC: movr A,C,shr
        x"98", x"04",  -- 80CE: movr A,A,shr
        x"98", x"04",  -- 80D0: movr A,A,shr
        x"9C", x"04",  -- 80D2: movr E,A,shr
        x"98", x"64",  -- 80D4: movr A,D,shr
        x"98", x"04",  -- 80D6: movr A,A,shr
        x"98", x"04",  -- 80D8: movr A,A,shr
        x"9D", x"04",  -- 80DA: movr F,A,shr
        x"98", x"40",  -- 80DC: movr A,C
        x"80", x"00",  -- 80DE: add A,A,A
        x"80", x"00",  -- 80E0: add A,A,A
        x"80", x"00",  -- 80E2: add A,A,A
        x"80", x"00",  -- 80E4: add A,A,A
        x"AD", x"A0",  -- 80E6: or F,F,A
        x"98", x"60",  -- 80E8: movr A,D
        x"AD", x"A0",  -- 80EA: or F,F,A
        x"98", x"40",  -- 80EC: movr A,C
        x"AC", x"80",  -- 80EE: or E,E,A
        x"98", x"00",  -- 80F0: movr A,A
        x"98", x"00",  -- 80F2: movr A,A
        x"98", x"00",  -- 80F4: movr A,A
        x"98", x"00",  -- 80F6: movr A,A
        x"98", x"00",  -- 80F8: movr A,A
        x"98", x"00",  -- 80FA: movr A,A
        x"9D", x"A4",  -- 80FC: movr F,F,shr
        x"F4", x"01"  -- 80FE: and E, 0x01
    );

    component alu is port
            (
                a : in std_logic_vector(7 downto 0);
                b : in std_logic_vector(7 downto 0);
                result : out std_logic_vector(7 downto 0);
                opalu  : in std_logic_vector(2 downto 0);            
                c_in   : in std_logic;            
                c_out  : out std_logic;            
                z : out std_logic;
                shift: in std_logic_vector(1 downto 0)
            );
    end component;

    component register_file is
        port (clk, reset: in std_logic;
              read_addr: in std_logic_vector(2 downto 0);
              write_addr: in std_logic_vector(2 downto 0);
              data_in : in std_logic_vector (7 downto 0);
              data_out: out std_logic_vector (7 downto 0);
              we : in std_logic;
              ACC: out std_logic_vector(7 downto 0); 
              EF: out std_logic_vector(15 downto 0); 
              GH: out std_logic_vector(15 downto 0)
    	);
    end component;
      
begin    
    
    -- ALU signals
    alu1: alu port map (a => ALU_a,
                      b => ALU_b,
                      result => ALU_result,
                      opalu => ALU_opalu,
                      c_in => ALU_c_in,
                      c_out => ALU_c_out,
                      z => ALU_z_out,
                      shift => ALU_shift);                      

    -- Register file signals
    register_file1: register_file port map
        (clk => clk, reset => reset,
              read_addr => REGS_read_A,
              write_addr => REGS_write_A,
              data_in => REGS_data_in,
              data_out => REGS_data_out,
              we => REGS_we,
              ACC => ACC,
              EF => EF,
              GH => GH
    	);

    -- TT06 signals mapping
    reset <= not rst_n;
    uo_out(6 downto 0) <= address_bus_out(14 downto 8);
    uo_out(7) <= mem_bus_we;
    uio_out <= address_bus_out(7 downto 0);
    uio_oe <= (others=>'1');
    process (address_bus_out)
    begin
        if (address_bus_out(15)='1') then
            mem_data_in <= tt06rom(to_integer(unsigned(address_bus_out(7 downto 0))));
        else
            mem_data_in <= ui_in;
        end if;
    end process;

    -- IR signals
    ir_opalu <= ir(13 downto 11);
    ir_dest <= ir(10 downto 8);
    ir_src <= ir(7 downto 5);
    ir_immE <= ir(14);
    ir_AluOpToReg <= ir(15);
    ir_imm8 <= ir(7 downto 0);
    ir_imm12 <= ir(11 downto 0);
    ir_fromMem <= ir(1);
    ir_toMem <= ir(0);
    ir_instruction <= ir(15 downto 14);
    ir_jumpcode <= ir(13 downto 12);
    ir_useEF <= ir(4);
    ir_shift <= ir(3 downto 2);
        
    -- ALU signals
    process(REGS_data_out, ir_immE, ir_imm8, ACC, flag_C, ir_opalu)
    begin
        if (ir_immE='1') then
           ALU_shift <= "00";
        else
           ALU_shift <= ir_shift;
        end if;
        ALU_opalu <= ir_opalu; 

        if (ir_fromMem='1' and ir_immE='0') then
            ALU_a <= mem_data_in;
        else
            ALU_a <= REGS_data_out;
        end if;

        if (ir_immE='1') then
           ALU_b <= ir_imm8;
        else
           ALU_b <= ACC;
        end if;
        ALU_c_in <= flag_C;
    end process;
    
    -- Register file
    process (ir_immE, ir_src, ir_dest, ir_fromMem, mem_data_in, ALU_result)
    begin
        if (ir_immE='0') then
           REGS_read_A <= ir_src;
        else
           REGS_read_A <= ir_dest;           
        end if;
        REGS_write_A <= ir_dest;
        REGS_data_in <= ALU_result;
    end process;

    -- Main state machine
    process(state, pc, ir, flag_C, flag_Z, mem_data_in, ir_aluoptoreg, gh, ir_tomem, ir_imme, ir_instruction, 
            ir_jumpcode, ir_imm8, alu_c_out, alu_z_out, regs_data_out)
    begin

        address_bus_out <= pc & '0';
        next_mem_bus_we <= mem_bus_we;
        nextpc <= pc;
        nextir <= ir;
        next_flag_C <= flag_C;
        next_flag_Z <= flag_Z;
        REGS_we <= '0';
        nextState <= state;

        -- Address bus
        if (state=fetch1) then
            address_bus_out <= pc & '0';
        elsif (state=fetch2) then
            address_bus_out <= pc & '1';
        else
            if (ir_AluOpToReg='1' and ir_immE='0' and (ir_toMem='1' or ir_fromMem='1')) then
                if (ir_useEF='1') then 
                    if (ir_toMem='1') then
                        address_bus_out <= EF(15 downto 8) & REGS_data_out;
                    else
                        address_bus_out <= EF;
                    end if;
                else
                    if (ir_toMem='1') then
                        address_bus_out <= GH(15 downto 8) & REGS_data_out;
                    else
                        address_bus_out <= GH;
                    end if;
                end if;
            else
                address_bus_out <= pc & '1';
            end if;
        end if;

        case state is        
            when fetch1 =>
                nextir <= mem_data_in & ir(7 downto 0);
                nextState <= fetch2;
            when fetch2 =>
                nextir <= ir(15 downto 8) & mem_data_in;            
                nextState <= execute;
            when execute =>
                nextState <= fetch1; 
                if (ir_AluOpToReg='1') and (not (ir_immE='0' and ir_toMem='1'))then
                   REGS_we <= '1';
                else
                   REGS_we <= '0';
                end if;
            
            
                if ((ir_instruction="00") and (ir_jumpcode="11")) or
                   ((ir_instruction="00") and (ir_jumpcode="01") and (flag_Z='1')) or
                   ((ir_instruction="00") and (ir_jumpcode="10") and (flag_Z='0')) then                        
                   nextpc <= pc(14 downto 12) & ir_imm12;
                elsif ((ir_instruction="01")) then
                   nextpc <= GH(15 downto 1);
                else
                   nextpc <= std_logic_vector(unsigned(pc)+1);
                end if;

                if ((ir_AluOpToReg='1' and ir_toMem='1') and (ir_immE='0')) then
                   next_mem_bus_we <= '0';
                   nextState <= writeback;
                end if;

                if (ir_AluOpToReg='1') then            
                    next_flag_C <= ALU_c_out;
                    next_flag_Z <= ALU_z_out;
                end if;
            when writeback => 
                
                next_mem_bus_we <= '1';
                nextState <= fetch1;
            when others => null;
        end case;
    end process;
    
    process(reset, clk)
    begin
    if(reset = '1') then    
        state <= fetch1;
        pc <= "010000000000000"; -- tt06: reset PC to 0x4000
        ir <= (others=>'0');
    elsif(falling_edge(clk)) then 
        state <= nextState;
        pc <= nextpc;
        ir <= nextir;
    end if;                        
    end process;

    process (reset,clk)
    begin
    if (reset = '1') then
        flag_C <= '0';
        flag_Z <= '0';
        mem_bus_we <= '1';
    elsif(rising_edge(clk)) then
        flag_C <= next_flag_C;
        flag_Z <= next_flag_Z;
        mem_bus_we <= next_mem_bus_we;
    end if;       
    end process;

end behavioral;
