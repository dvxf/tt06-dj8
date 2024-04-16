----------------------------------------------------------------------------
-- DJ8 CPU (C) DaveX 2003-2024
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity register_file is
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
end register_file;

architecture behavioral of register_file is    
    
    type rfType is array (8-1 downto 0) of std_logic_vector(7 downto 0);    
    signal regs : rfType;

    signal loadRegI : std_logic_vector(8-1 downto 0);
    
    component register8 is
        port (clk, reset: in std_logic;
              load: in std_logic;
              data_in: in std_logic_vector(7 downto 0);
              data_out: out std_logic_vector(7 downto 0)
    	);
    end component;

begin    

    process(write_addr, we)
    begin        
        loadRegI <= (others=>'0');          
    
        if (we = '1') then
            loadRegI(to_integer(unsigned(write_addr))) <= '1';    
        end if;  
    end process;
            
as :  for i in 0 to 8 - 1 generate        
         c1 : component register8 port map(clk, reset, loadRegI(i), data_in, regs(i));
      end generate;
       
    data_out <= regs(to_integer(unsigned(read_addr)));
    
    ACC <= regs(0);
    EF <= regs(4) & regs(5);
    GH <= regs(6) & regs(7);
    
end behavioral;
