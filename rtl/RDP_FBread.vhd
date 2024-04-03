library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;
use work.pFunctions.all;

entity RDP_FBread is
   port 
   (
      clk1x                   : in  std_logic;
      trigger                 : in  std_logic;
   
      settings_otherModes     : in  tsettings_otherModes;
      settings_colorImage     : in  tsettings_colorImage;
      
      xIndexPx                : in  unsigned(11 downto 0);
      xIndexPxZ               : in  unsigned(11 downto 0);
      xIndex9                 : in  unsigned(11 downto 0);
      yOdd                    : in  std_logic;
      
      FBAddr                  : out unsigned(10 downto 0);
      FBData_in               : in  unsigned(31 downto 0);
      
      FBAddr9                 : out unsigned(7 downto 0);
      FBData9_in              : in  unsigned(31 downto 0);
      FBData9Z_in             : in  unsigned(31 downto 0);
      
      FBAddrZ                 : out unsigned(11 downto 0);
      FBDataZ_in              : in  unsigned(15 downto 0);
     
      FBcolor                 : out  tcolor4_u8 := (others => (others => '0'));
      cvgFB                   : out unsigned(2 downto 0) := (others => '0');
      FBData9_old             : out unsigned(31 downto 0) := (others => '0');
      FBData9_oldZ            : out unsigned(31 downto 0) := (others => '0');
      old_Z_mem               : out unsigned(17 downto 0) := (others => '0')
   );
end entity;

architecture arch of RDP_FBread is

   signal muxselect  : unsigned(1 downto 0) := (others => '0');
   signal muxselect9 : unsigned(3 downto 0) := (others => '0');

   -- 1 cycle delay
   signal FBData        : unsigned(31 downto 0) := (others => '0');
   signal FBData9       : unsigned(31 downto 0) := (others => '0');
   signal FBData9Z      : unsigned(31 downto 0) := (others => '0');
   signal FBDataZ       : unsigned(15 downto 0) := (others => '0');
   
   signal muxselect_1   : unsigned(1 downto 0) := (others => '0');
   signal muxselect9_1  : unsigned(3 downto 0) := (others => '0');
   
   signal Fbdata8       : unsigned(7 downto 0);
   signal Fbdata16      : unsigned(15 downto 0);
   signal Fbdata16_9    : unsigned(1 downto 0);
   

begin 
   
   -- todo: must increase line size if games really use more than 2048 pixels in 16bit mode or 1024 pixels in 32 bit mode
   FBAddr <= yOdd & xIndexPx(11 downto 2) when (settings_colorImage.FB_size = SIZE_8BIT) else
             yOdd & xIndexPx(10 downto 1) when (settings_colorImage.FB_size = SIZE_16BIT) else
             yOdd & xIndexPx(9 downto 0);
   
   FBAddr9 <= yOdd & xIndex9(10 downto 4);
   
   FBAddrZ <= yOdd & xIndexPxZ(10 downto 0);
   
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (trigger = '1') then
         
            muxselect  <= xIndexPx(1 downto 0);
            muxselect9 <= xIndex9(3 downto 0);
         
            FBData    <= FBData_in;
            FBData9   <= FBData9_in;  
            FBData9Z  <= FBData9Z_in; 
            FBDataZ   <= FBDataZ_in;  
         
         end if;

      end if;
   end process;
   
   Fbdata8    <= FBData(31 downto 24) when (muxselect_1 = "11") else
                 FBData(23 downto 16) when (muxselect_1 = "10") else
                 FBData(15 downto  8) when (muxselect_1 = "01") else
                 FBData( 7 downto  0);
   
   Fbdata16   <= byteswap16(FBData(31 downto 16)) when (muxselect_1(0) = '1') else byteswap16(FBData(15 downto 0));
   
   Fbdata16_9(1) <= FBData9((to_integer(muxselect9_1) * 2) + 1);
   Fbdata16_9(0) <= FBData9((to_integer(muxselect9_1) * 2) + 0);
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (trigger = '1') then
         
            muxselect_1  <= muxselect;
            muxselect9_1 <= muxselect9;
         
            FBData9_old  <= FBData9;
            FBData9_oldZ <= FBData9Z;
            
            old_Z_mem(15 downto 0) <= byteswap16(FBDataZ);
   
            old_Z_mem(17) <= FBData9Z((to_integer(muxselect9_1) * 2) + 1);
            old_Z_mem(16) <= FBData9Z((to_integer(muxselect9_1) * 2) + 0);
         
            case (settings_colorImage.FB_size) is
               when SIZE_8BIT =>
                  FBcolor(0) <= Fbdata8;
                  FBcolor(1) <= Fbdata8;
                  FBcolor(2) <= Fbdata8;
                  FBcolor(3) <= x"E0"; -- todo: unclear
            
               when SIZE_16BIT =>
                  FBcolor(0) <= Fbdata16(15 downto 11) & "000";
                  FBcolor(1) <= Fbdata16(10 downto 6) & "000";
                  FBcolor(2) <= Fbdata16(5 downto 1) & "000";
                  if (settings_otherModes.imageRead = '1') then
                     FBcolor(3) <= Fbdata16(0) & Fbdata16_9 & "00000";
                     cvgFB      <= Fbdata16(0) & Fbdata16_9;
                  else
                     FBcolor(3) <= x"E0";
                     cvgFB      <= (others => '1');
                  end if;
                  
               when SIZE_32BIT =>
                  FBcolor(0) <= Fbdata( 7 downto  0);
                  FBcolor(1) <= Fbdata(15 downto  8);
                  FBcolor(2) <= Fbdata(23 downto 16);
                  if (settings_otherModes.imageRead = '1') then
                     FBcolor(3) <= Fbdata(31 downto 29) & "00000";
                     cvgFB      <= Fbdata(31 downto 29);
                  else
                     FBcolor(3) <= x"E0";
                     cvgFB      <= (others => '1');
                  end if;
               
               when others => null;
            end case;
            
         end if;
         
      end if;
   end process;
      
      


end architecture;





