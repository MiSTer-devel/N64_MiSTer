library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;
use work.pFunctions.all;

entity RDP_RGBACorrection is
   port 
   (
      settings_poly           : in  tsettings_poly;
      offX                    : in  unsigned(1 downto 0);
      offY                    : in  unsigned(1 downto 0);
      InColor                 : in  tcolor4_s32;
      corrected_color         : out tcolor4_u9
   );
end entity;

architecture arch of RDP_RGBACorrection is

   type tcolor_s18 is array(0 to 3) of signed(17 downto 0);
   signal shift14_s18 : tcolor_s18;
   signal dxshifted   : tcolor_s18;
   signal dyshifted   : tcolor_s18;

   type tcolor_s20 is array(0 to 3) of signed(19 downto 0);
   signal add_x : tcolor_s20;
   signal add_y : tcolor_s20;   
   
   type tcolor_s21 is array(0 to 3) of signed(20 downto 0);
   signal add : tcolor_s21;   
   
   type tcolor_s22 is array(0 to 3) of signed(21 downto 0);
   signal sum : tcolor_s22;   
   
   signal cut : tcolor_s18;

begin 

   dxshifted(0) <= settings_poly.shade_DrDx(31 downto 14);
   dxshifted(1) <= settings_poly.shade_DgDx(31 downto 14);
   dxshifted(2) <= settings_poly.shade_DbDx(31 downto 14);
   dxshifted(3) <= settings_poly.shade_DaDx(31 downto 14);   
   
   dyshifted(0) <= settings_poly.shade_DrDy(31 downto 14);
   dyshifted(1) <= settings_poly.shade_DgDy(31 downto 14);
   dyshifted(2) <= settings_poly.shade_DbDy(31 downto 14);
   dyshifted(3) <= settings_poly.shade_DaDy(31 downto 14);

   process (all)
   begin        
      
      for i in 0 to 3 loop
      
         shift14_s18(i) <= InColor(i)(31 downto 14);
         
         case (offX) is
            when "00" => add_x(i) <= (others => '0');
            when "01" => add_x(i) <= resize(dxshifted(i), 20);
            when "10" => add_x(i) <= resize(dxshifted(i) & '0', 20);
            when "11" => add_x(i) <= resize(dxshifted(i) & '0', 20) + resize(dxshifted(i), 20);
            when others => null;
         end case;
         
         case (offY) is
            when "00" => add_y(i) <= (others => '0');
            when "01" => add_y(i) <= resize(dyshifted(i), 20);
            when "10" => add_y(i) <= resize(dyshifted(i) & '0', 20);
            when "11" => add_y(i) <= resize(dyshifted(i) & '0', 20) + resize(dyshifted(i), 20);
            when others => null;
         end case;
         
         add(i) <= resize(add_x(i), 21) + resize(add_y(i), 21);
         
         sum(i) <= resize(shift14_s18(i) & "00", 22) + resize(add(i), 22);

         cut(i) <= sum(i)(21 downto 4);
         
         if (cut(i) < 0) then
            corrected_color(i) <= (others => '0');
         elsif (cut(i) > 511) then
            corrected_color(i) <= (others => '1');
         else
            corrected_color(i) <= unsigned(cut(i)(8 downto 0));
         end if;
   
      end loop;

   end process;
   
end architecture;





