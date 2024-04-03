library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

entity RDP_raster_perspcorr is
   port 
   (
      pixel_Texture_W    : in  signed(31 downto 0) := (others => '0');
      WCarry             : out std_logic := '0';
      WShift             : out integer range 0 to 14 := 0;
      WNormLow           : out unsigned(7 downto 0) := (others => '0');
      Wtemppoint         : out signed(15 downto 0) := (others => '0');
      Wtempslope         : out unsigned(7 downto 0)
   );
end entity;

architecture arch of RDP_raster_perspcorr is

   signal wShift_intern    : integer range 0 to 14;
   signal wShifted         : unsigned(13 downto 0);
   
   type tnormPoint is array(0 to 63) of signed(15 downto 0);
   constant normPoint : tnormPoint := 
   ( 
      x"4000", x"3f04", x"3e10", x"3d22", x"3c3c", x"3b5d", x"3a83", x"39b1",
      x"38e4", x"381c", x"375a", x"369d", x"35e5", x"3532", x"3483", x"33d9",
      x"3333", x"3291", x"31f4", x"3159", x"30c3", x"3030", x"2fa1", x"2f15",
      x"2e8c", x"2e06", x"2d83", x"2d03", x"2c86", x"2c0b", x"2b93", x"2b1e",
      x"2aab", x"2a3a", x"29cc", x"2960", x"28f6", x"288e", x"2828", x"27c4",
      x"2762", x"2702", x"26a4", x"2648", x"25ed", x"2594", x"253d", x"24e7",
      x"2492", x"243f", x"23ee", x"239e", x"234f", x"2302", x"22b6", x"226c",
      x"2222", x"21da", x"2193", x"214d", x"2108", x"20c5", x"2082", x"2041"
   );
   type tnormSlope is array(0 to 63) of unsigned(7 downto 0);
   constant normSlope : tnormSlope := 
   (
      x"03", x"0b", x"11", x"19", x"20", x"25", x"2d", x"32",
      x"37", x"3d", x"42", x"47", x"4c", x"50", x"55", x"59",
      x"5d", x"62", x"64", x"69", x"6c", x"70", x"73", x"76",
      x"79", x"7c", x"7f", x"82", x"84", x"87", x"8a", x"8c",
      x"8e", x"91", x"93", x"95", x"97", x"99", x"9b", x"9d",
      x"9f", x"a1", x"a3", x"a4", x"a6", x"a8", x"a9", x"aa",
      x"ac", x"ae", x"af", x"b0", x"b2", x"b3", x"b5", x"b5",
      x"b7", x"b8", x"b9", x"ba", x"bc", x"bc", x"be", x"be"
   );
   
begin 

   process (pixel_Texture_W)
   begin
      wShift_intern <= 14;
      for i in 1 to 14 loop
         if (pixel_Texture_W(i + 16) = '1') then
            wShift_intern <= 14 - i;
         end if;
      end loop;
   end process;
   
   wShifted <= unsigned(pixel_Texture_W(29 downto 16)) sll wShift_intern;
   
   
   WCarry      <= pixel_Texture_W(31);
   WShift      <= 14 - wShift_intern;
   WNormLow    <= wShifted(7 downto 0);
   Wtemppoint  <= normPoint(to_integer(wShifted(13 downto 8)));
   Wtempslope  <= normSlope(to_integer(wShifted(13 downto 8))) + 1;

end architecture;





