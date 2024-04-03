library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;

entity RDP_DitherCalc is
   port 
   (
      settings_otherModes  : in  tsettings_otherModes;
      ditherColor          : in  unsigned(2 downto 0);
      random9              : in  unsigned(8 downto 0);
      color_in             : in  tcolor3_u8;
      color_out            : out tcolor3_u8
   );
end entity;

architecture arch of RDP_DitherCalc is
  
   type tditherColorArray is array(0 to 2) of unsigned(2 downto 0);
   signal ditherColorArray : tditherColorArray;
  
   signal useDith    : std_logic_vector(0 to 2);
   
   type tditherDiff is array(0 to 2) of integer range 0 to 8;
   signal ditherDiff : tditherDiff;
  
begin 

   ditherColorArray(0) <= random9(2 downto 0) when (settings_otherModes.rgbDitherSel = "10") else ditherColor;
   ditherColorArray(1) <= random9(5 downto 3) when (settings_otherModes.rgbDitherSel = "10") else ditherColor;
   ditherColorArray(2) <= random9(8 downto 6) when (settings_otherModes.rgbDitherSel = "10") else ditherColor;


   process (all)
   begin
      for i in 0 to 2 loop

         if (settings_otherModes.rgbDitherSel /= "11" and ditherColorArray(i) < color_in(i)(2 downto 0)) then 
            useDith(i) <= '1'; 
         else 
            useDith(i) <= '0'; 
         end if;
      
         if (color_in(i) > 247) then
            ditherDiff(i) <= 7 - to_integer(color_in(i)(2 downto 0));
         else
            ditherDiff(i) <= 8 - to_integer(color_in(i)(2 downto 0));
         end if;
         
         if (useDith(i) = '1') then
            color_out(i) <= color_in(i) + ditherDiff(i);
         else
            color_out(i) <= color_in(i);
         end if;
      
      end loop; 
   end process;
   
end architecture;





