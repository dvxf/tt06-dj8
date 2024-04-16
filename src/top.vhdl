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
    type romType is array (0 to 15) of std_logic_vector(7 downto 0);
    signal tt06rom: romType := (
        -- Test ROM: rotating indicator on 7-segment display, paused when all DIP switches are reset
        x"F8", x"01",  -- 0000: movi A, 0x01
        x"9C", x"00",  -- 0002: movr E,A
        x"99", x"12",  -- 0004: movr B,(EF)
        x"10", x"02",  -- 0006: jz 0004
        x"80", x"00",  -- 0008: add A,A,A
        x"D4", x"40",  -- 000A: subc E, 0x40
        x"10", x"00",  -- 000C: jz 0000
        x"30", x"01"  -- 000E: jmp 0002
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
            mem_data_in <= tt06rom(to_integer(unsigned(address_bus_out(3 downto 0))));
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
            if (ir_useEF='1') then 
                if (ir_toMem='1' and ir_immE='0') then
                    address_bus_out <= EF(15 downto 8) & REGS_data_out;
                else
                    address_bus_out <= EF;
                end if;
            else
                if (ir_toMem='1' and ir_immE='0') then
                    address_bus_out <= GH(15 downto 8) & REGS_data_out;
                else
                    address_bus_out <= GH;
                end if;
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
        pc <= (others=>'0');
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
