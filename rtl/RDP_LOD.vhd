library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;

entity RDP_LOD is
   port 
   (
      clk1x                : in  std_logic;
      trigger              : in  std_logic;
      step2                : in  std_logic;
      
      DISABLELOD           : in  std_logic;
      
      settings_poly        : in  tsettings_poly;
      settings_otherModes  : in  tsettings_otherModes;
      settings_primcolor   : in  tsettings_primcolor;
      
      texture_S            : in  signed(18 downto 0);
      texture_T            : in  signed(18 downto 0);
      texture_S_nextX      : in  signed(18 downto 0);
      texture_T_nextX      : in  signed(18 downto 0);
      texture_S_nextY      : in  signed(18 downto 0);
      texture_T_nextY      : in  signed(18 downto 0);
      
      lod_frac             : out unsigned(8 downto 0) := (others => '0');
      tile0_out            : out unsigned(2 downto 0) := (others => '0');
      tile1_out            : out unsigned(2 downto 0) := (others => '0')
   );
end entity;

architecture arch of RDP_LOD is
   
   signal lodclamp  : std_logic;
   
   -- LOD
   signal delta_S_X     : signed(17 downto 0);
   signal delta_T_X     : signed(17 downto 0);   
   signal delta_S_Xneg  : signed(16 downto 0);
   signal delta_T_Xneg  : signed(16 downto 0);   
   signal delta_X       : signed(16 downto 0);   
   
   signal delta_S_Y     : signed(17 downto 0);
   signal delta_T_Y     : signed(17 downto 0);   
   signal delta_S_Yneg  : signed(16 downto 0);
   signal delta_T_Yneg  : signed(16 downto 0);   
   signal delta_Y       : signed(16 downto 0); 
   
   signal lod           : unsigned(14 downto 0);
      
   -- LOD fraction      
   signal magnify       : std_logic;
   signal distant       : std_logic;
   signal lodtile_shift : unsigned(2 downto 0);
   signal lodtile       : unsigned(2 downto 0);
   signal lodfrac       : unsigned(8 downto 0);

   -- tile
   signal tile0         : unsigned(2 downto 0);
   signal tile1         : unsigned(2 downto 0);
   
begin 

   lodclamp <= '1' when (texture_S(18 downto 17)       /= 0 or texture_T(18 downto 17)       /= 0 or
                         texture_S_nextX(18 downto 17) /= 0 or texture_T_nextX(18 downto 17) /= 0 or
                         texture_S_nextY(18 downto 17) /= 0 or texture_T_nextY(18 downto 17) /= 0) else '0';

   -- LOD
   delta_S_X <= resize(texture_S_nextX(16 downto 0),18) - resize(texture_S(16 downto 0), 18);
   delta_T_X <= resize(texture_T_nextX(16 downto 0),18) - resize(texture_T(16 downto 0), 18);
   
   delta_S_Xneg <= not delta_S_X(16 downto 0) when (delta_S_X(17) = '1') else delta_S_X(16 downto 0);
   delta_T_Xneg <= not delta_T_X(16 downto 0) when (delta_T_X(17) = '1') else delta_T_X(16 downto 0);
   
   delta_X   <= delta_S_Xneg when (delta_S_Xneg > delta_T_Xneg) else delta_T_Xneg;
   
   delta_S_Y <= resize(texture_S_nextY(16 downto 0),18) - resize(texture_S(16 downto 0), 18);
   delta_T_Y <= resize(texture_T_nextY(16 downto 0),18) - resize(texture_T(16 downto 0), 18);
   
   delta_S_Yneg <= not delta_S_Y(16 downto 0) when (delta_S_Y(17) = '1') else delta_S_Y(16 downto 0);
   delta_T_Yneg <= not delta_T_Y(16 downto 0) when (delta_T_Y(17) = '1') else delta_T_Y(16 downto 0);
   
   delta_Y   <= delta_S_Yneg when (delta_S_Yneg > delta_T_Yneg) else delta_T_Yneg;

   process (all)
   begin
   
      if (delta_Y < 0 and delta_X < 0) then
         lod <= (others => '0');
      elsif (delta_Y > delta_X) then
         lod <= unsigned(delta_Y(14 downto 0));
         if (delta_Y(16 downto 14) = "111") then lod(14) <= '1'; end if;
      else
         lod <= unsigned(delta_X(14 downto 0));
         if (delta_X(16 downto 14) = "111") then lod(14) <= '1'; end if;
      end if;
      
   end process;
   
   -- LOD fraction
   process (all)
   begin
   
      lodtile_shift <= (others => '0');
   
      if (lod(14) = '1' or lodclamp = '1') then
         magnify <= '0';
         distant <= '1';
         lodtile <= "000";
         lodfrac <= 9x"0FF";
         
      elsif (unsigned(lod) < settings_primcolor.prim_minLevel or lod < 32) then
         magnify <= '1';
         lodtile <= "000";
         if (settings_poly.maxLODlevel = 0) then 
            distant <= '1';
         else
            distant <= '0';
         end if;
         
         if (settings_otherModes.sharpenTex = '0' and settings_otherModes.detailTex = '0') then
            if (settings_poly.maxLODlevel = 0) then 
               lodfrac <= 9x"0FF";
            else
               lodfrac <= 9x"000";
            end if;
         elsif (unsigned(lod) < settings_primcolor.prim_minLevel) then
            lodfrac <= settings_otherModes.sharpenTex & settings_primcolor.prim_minLevel & "000";
         else
            lodfrac <= settings_otherModes.sharpenTex & lod(4 downto 0) & "000";
         end if;
      
      else
         
         magnify <= '0';
         if    (lod(12) = '1') then lodtile_shift <= 3x"7"; lodfrac <= '0' & lod(11 downto 4);
         elsif (lod(11) = '1') then lodtile_shift <= 3x"6"; lodfrac <= '0' & lod(10 downto 3);
         elsif (lod(10) = '1') then lodtile_shift <= 3x"5"; lodfrac <= '0' & lod( 9 downto 2);
         elsif (lod( 9) = '1') then lodtile_shift <= 3x"4"; lodfrac <= '0' & lod( 8 downto 1);
         elsif (lod( 8) = '1') then lodtile_shift <= 3x"3"; lodfrac <= '0' & lod( 7 downto 0);
         elsif (lod( 7) = '1') then lodtile_shift <= 3x"2"; lodfrac <= '0' & lod( 6 downto 0) & "0";
         elsif (lod( 6) = '1') then lodtile_shift <= 3x"1"; lodfrac <= '0' & lod( 5 downto 0) & "00";
         else                       lodtile_shift <= 3x"0"; lodfrac <= '0' & lod( 4 downto 0) & "000"; end if;
         
         lodtile <= lodtile_shift;
         
         if (lodtile_shift >= settings_poly.maxLODlevel) then
            distant <= '1';
            lodtile <= settings_poly.maxLODlevel;
         else
            distant <= '0';
         end if;
         
         if (settings_otherModes.sharpenTex = '0' and settings_otherModes.detailTex = '0' and distant = '1') then
            lodfrac <= 9x"0FF";
         end if;

      end if;
               
      if (DISABLELOD = '1') then
         lodfrac <= 9x"0FF";
      end if;
         
      
   end process;
   
   
   -- calculate tile
   process (all)
   begin
      
      if (settings_otherModes.texLod = '1' and DISABLELOD = '0') then
      
         if (settings_otherModes.detailTex = '0') then
            tile0 <= settings_poly.tile + lodtile;
            if (distant = '1' or (settings_otherModes.sharpenTex = '0' and magnify = '1')) then 
               tile1 <= settings_poly.tile + lodtile;
            else
               tile1 <= settings_poly.tile + lodtile + 1;
            end if;
         else
            if (magnify = '0') then
               tile0 <= settings_poly.tile + lodtile + 1;
            else
               tile0 <= settings_poly.tile + lodtile;
            end if;
            if (magnify = '0' and distant = '0') then
               tile1 <= settings_poly.tile + lodtile + 2;
            else
               tile1 <= settings_poly.tile + lodtile + 1;
            end if;
      
         end if;
         
      else
      
         tile0 <= settings_poly.tile;
         tile1 <= settings_poly.tile + 1;
         
         if (settings_otherModes.texLod = '1' and settings_otherModes.detailTex = '0' and settings_poly.maxLODlevel = 0) then
            tile1 <= settings_poly.tile;
         end if;
         
      end if;
   
   end process;
   


   process (clk1x)
   begin
      if rising_edge(clk1x) then
   
         if (trigger = '1') then

            lod_frac   <= lodfrac;
            tile0_out  <= tile0;
            tile1_out  <= tile1;
         
         end if;         

      end if;
   end process;
   
end architecture;





