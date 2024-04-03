library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;

entity RDP_DitherFetch is
   port 
   (
      clk1x                : in  std_logic;
      trigger              : in  std_logic;
      
      DISABLEDITHER        : in  std_logic;
      settings_otherModes  : in  tsettings_otherModes;
      
      X_in                 : in  unsigned(11 downto 0);
      Y_in                 : in  unsigned(11 downto 0);
      random3              : in  unsigned(2 downto 0);
      random2              : in  unsigned(1 downto 0);
      
      ditherColor          : out unsigned(2 downto 0) := (others => '0');
      ditherAlpha          : out unsigned(2 downto 0) := (others => '0')
   );
end entity;

architecture arch of RDP_DitherFetch is
  
   type tdither is array(0 to 15) of unsigned(2 downto 0);
   
   constant dither1 : tdither := 
   (
      3x"0",
      3x"6",
      3x"1",
      3x"7",
      3x"4",
      3x"2",
      3x"5",
      3x"3",
      3x"3",
      3x"5",
      3x"2",
      3x"4",
      3x"7",
      3x"1",
      3x"6",
      3x"0"
   );  

   constant dither2 : tdither := 
   (
      3x"0",
      3x"4",
      3x"1",
      3x"5",
      3x"4",
      3x"0",
      3x"5",
      3x"1",
      3x"3",
      3x"7",
      3x"2",
      3x"6",
      3x"7",
      3x"3",
      3x"6",
      3x"2"
   );
   
   signal dither_selected : unsigned(2 downto 0);
  
begin 

   dither_selected <= dither2(to_integer(Y_in(1 downto 0) & X_in(1 downto 0))) when (settings_otherModes.rgbDitherSel(0) = '1') else dither1(to_integer(Y_in(1 downto 0) & X_in(1 downto 0)));
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
   
         if (trigger = '1') then
            
            case (settings_otherModes.rgbDitherSel) is
               when "00" => ditherColor <= dither_selected;
               when "01" => ditherColor <= dither_selected;
               when "10" => ditherColor <= random3;
               when "11" => ditherColor <= "111";
               when others => null;
            end case;
            
            case (settings_otherModes.alphaDitherSel) is
               when "00" => ditherAlpha <= dither_selected;
               when "01" => ditherAlpha <= not dither_selected;
               when "10" => ditherAlpha <= random2 & '1';
               when "11" => ditherAlpha <= "000";
               when others => null;
            end case;
            
            if (DISABLEDITHER = '1') then
               ditherColor <= "000";
               ditherAlpha <= "000";
            end if;
         
         end if;
         
      end if;
   end process;
   
end architecture;





