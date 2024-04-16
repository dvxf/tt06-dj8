----------------------------------------------------------------------------
-- DJ8 CPU (C) DaveX 2003-2024
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is port
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
end alu;

architecture behavioral of alu is
    signal resultS : std_logic_vector(7 downto 0);
    signal temp : std_logic_vector(8 downto 0);
    signal c_in_v: std_logic_vector(0 downto 0);
begin

result <= resultS;

process(resultS)
begin
if (resultS = x"00") then
	z <= '1';
else
	z <= '0';
end if;
end process;

process(opalu, temp, a, b, c_in)
begin

    temp <= (others=>'0');
    c_out <= temp(8);
    c_in_v(0) <= c_in;
    resultS <= (others=>'0');
    
    case shift is
        when "00" => 
            resultS <= temp(7 downto 0); -- no shift
        when "01" => 
            resultS <= '0' & temp(7 downto 1); -- >> shift logical
        when "10" => 
            resultS <= temp(7)&temp(7 downto 1); -- >> shift arithmetic
        when "11" => 
            resultS <= temp(7 downto 0); -- no shift
        when others =>
            null;
    end case;
        
    case opalu is     
        
        -- ADD
        when "000" => 
            temp <= std_logic_vector(unsigned('0' & a) + unsigned('0' & b));
    
        -- ADDC
        when "001" =>
            temp <= std_logic_vector(unsigned('0' & a) + (unsigned('0' & b)) + (unsigned(c_in_v)));
                    
        -- SUBC
        when "010" => 
            temp <= std_logic_vector(unsigned('0' & a) - ((unsigned('0' & b)+unsigned(c_in_v))));
        
        -- MOVR
        when "011" =>
            temp <= ('0' & a);
        
        -- XOR
        when "100" =>
            temp <= '0' & (a xor b);
    
        -- OR
        when "101" =>
            temp <= '0' & (a or b);
        
        -- AND
        when "110" =>
            temp <= '0' & (a and b);
        
        -- MOVI
        when "111" => 
            temp <= ('0' & b);

		when others => null;
        
    end case;
end process;

end behavioral;