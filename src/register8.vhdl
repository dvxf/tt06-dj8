----------------------------------------------------------------------------
-- DJ8 CPU (C) DaveX 2003-2024
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity register8 is
    port (clk, reset: in std_logic;
          load: in std_logic;
          data_in: in std_logic_vector(7 downto 0);
          data_out: out std_logic_vector(7 downto 0)
	);
end register8;

architecture behavioral of register8 is
   signal datas: std_logic_vector(7 downto 0);
begin
   data_out <= datas;
   
   process (clk, reset)
   begin
       if (reset='1') then
          -- datas <= (others=>'0');
          datas <= "10000000"; -- t06 hack, in order to jump to ROM with a jmp gh as first instruction
       elsif (rising_edge(clk)) then
          if (load='1') then
             datas <= data_in;
          end if;
       end if;
   end process;

end behavioral;
