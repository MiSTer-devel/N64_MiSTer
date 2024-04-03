library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;    
use STD.textio.all;

entity cpu_FPU_sqrt is
   port 
   (
      clk               : in  std_logic;
      reset             : in  std_logic;
     
      start             : in  std_logic;
      bit64             : in  std_logic;
      exp0              : in  std_logic;
      mant              : in  unsigned(51 downto 0);
      result            : out unsigned(54 downto 0) := (others => '0');
      lostBits          : out std_logic := '0';
      done              : out std_logic := '0'
   );
end entity;

architecture arch of cpu_FPU_sqrt is
   
   signal shiftdata  : unsigned(109 downto 0);
   signal remain     : unsigned(56 downto 0);
   signal resultaccu : unsigned(56 downto 0);
   signal nextAdd    : std_logic;
   
   signal step       : integer range 0 to 55 := 0;
   signal complete   : std_logic := '1';
   
begin 

   result <= resultaccu(56 downto 2);
   
   process (clk)
      variable calcresult : unsigned(56 downto 0);
   begin
      if (rising_edge(clk)) then

         done     <= '0';

         if (reset = '1') then
         
            complete <= '1';
           
         else 
         
            if (start = '1') then
            
               remain     <= (others => '0');
               resultaccu <= to_unsigned(1, 57);
               nextAdd    <= '0';
               complete   <= '0';
               lostBits   <= '1';
               if (bit64 = '1') then
                  step               <= 55;
                  if (exp0 = '1') then
                     shiftdata          <= mant(51 downto 0) & 58x"0";
                     remain(1 downto 0) <= "01";
                  else
                     shiftdata          <= mant(50 downto 0) & 59x"0";
                     remain(1 downto 0) <= '1' & mant(51);
                  end if;
               else
                  step               <= 26;
                  if (exp0 = '1') then
                     shiftdata          <= mant(22 downto 0) & 87x"0";
                     remain(1 downto 0) <= "01";
                  else
                     shiftdata          <= mant(21 downto 0) & 88x"0";
                     remain(1 downto 0) <= '1' & mant(22);
                  end if;
               end if;
               
            elsif (complete = '0') then
   
               if (remain = 0) then
                  lostBits <= '0';
               end if;
   
               if (nextAdd = '1') then
                  calcresult := remain + resultaccu;
               else
                  calcresult := remain - resultaccu;
               end if;
   
               shiftdata    <= shiftdata(107 downto 0) & "00";
               remain       <= calcresult(54 downto 0) & shiftdata(109 downto 108);
               resultaccu   <= resultaccu(55 downto 2) & (not calcresult(56)) & calcresult(56) & '1';
               nextAdd      <= calcresult(56);
               
               if (calcresult(56) = '0') then
                  lostBits <= '1';
               end if;
               
               step <= step - 1;
               if (step = 1) then
                  done     <= '1';
                  complete <= '1';
               end if;
               
            end if;

         end if;

      end if;
   end process;

end architecture;
