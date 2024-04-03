library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;
use work.pFunctions.all;

entity RDP_CombineAlpha is
   port 
   (
      clk1x                   : in  std_logic;
      trigger                 : in  std_logic;
      mode2                   : in  std_logic;
      step2                   : in  std_logic;
      
      error_combineAlpha      : out std_logic;
   
      settings_otherModes     : in  tsettings_otherModes;
      settings_combineMode    : in  tsettings_combineMode;
      settings_primcolor      : in  tsettings_primcolor;
      settings_envcolor       : in  tsettings_envcolor;
     
      pipeInColor             : in  tcolor4_u9;
      tex_alpha               : in  unsigned(7 downto 0);
      tex2_alpha              : in  unsigned(7 downto 0);
      lod_frac                : in  unsigned(8 downto 0);
      cvgCount                : in  unsigned(3 downto 0);
      cvgFB                   : in  unsigned(2 downto 0);
      ditherAlpha             : in  unsigned(2 downto 0);

      cvg_overflow            : out std_logic;
      combine_alpha           : out unsigned(7 downto 0) := (others => '0');
      combine_alpha2          : out unsigned(7 downto 0) := (others => '0');
      combine_alpha_save      : out signed(9 downto 0) := (others => '0');
      combine_CVGCount        : out unsigned(3 downto 0) := (others => '0')
   );
end entity;

architecture arch of RDP_CombineAlpha is

   signal mode_sub1          : unsigned(2 downto 0);
   signal mode_sub2          : unsigned(2 downto 0);
   signal mode_mul           : unsigned(2 downto 0);
   signal mode_add           : unsigned(2 downto 0);
                             
   signal alpha_sub1         : signed(9 downto 0);
   signal alpha_sub2         : signed(9 downto 0);
   signal alpha_mul          : signed(9 downto 0);
   signal alpha_add          : signed(9 downto 0);
                             
   signal combiner_sub       : signed(9 downto 0);
   signal combiner_mul       : signed(19 downto 0);
   signal combiner_add       : signed(19 downto 0);
   signal combiner_cut       : signed(11 downto 0);
   signal combiner_result    : unsigned(8 downto 0);
   signal cvgmul             : unsigned(12 downto 0);
   signal cvgCount_select    : unsigned(3 downto 0);

   signal combine_alpha_next : signed(9 downto 0) := (others => '0');
   
   --combine2
   signal cvgmul2            : unsigned(12 downto 0);
   signal combiner_result2   : unsigned(8 downto 0) := (others => '0');
   signal cvgCount2          : unsigned(3 downto 0) := (others => '0');
   signal ditherAlpha2       : unsigned(2 downto 0) := (others => '0');

begin 

   mode_sub1 <= settings_combineMode.combine_sub_a_A_0 when (mode2 = '1' and step2 = '1') else settings_combineMode.combine_sub_a_A_1;
   mode_sub2 <= settings_combineMode.combine_sub_b_A_0 when (mode2 = '1' and step2 = '1') else settings_combineMode.combine_sub_b_A_1;
   mode_mul  <= settings_combineMode.combine_mul_A_0   when (mode2 = '1' and step2 = '1') else settings_combineMode.combine_mul_A_1;
   mode_add  <= settings_combineMode.combine_add_A_0   when (mode2 = '1' and step2 = '1') else settings_combineMode.combine_add_A_1;
   
   process (all)
   begin
      
      alpha_sub1 <= (others => '0');
      case (to_integer(mode_sub1)) is
         when 0 => alpha_sub1 <= combine_alpha_next;
         when 1 => alpha_sub1 <= "00" & signed(tex_alpha);
         when 2 => alpha_sub1 <= "00" & signed(tex2_alpha);
         when 3 => alpha_sub1 <= "00" & signed(settings_primcolor.prim_A);
         when 4 => alpha_sub1 <= '0' & signed(pipeInColor(3));
         when 5 => alpha_sub1 <= "00" & signed(settings_envcolor.env_A);
         when 6 => alpha_sub1 <= 10x"100";
         when 7 => alpha_sub1 <= (others => '0');
         when others => null;
      end case;
      
      alpha_sub2 <= (others => '0');
      case (to_integer(mode_sub2)) is
         when 0 => alpha_sub2 <= combine_alpha_next;
         when 1 => alpha_sub2 <= "00" & signed(tex_alpha);
         when 2 => alpha_sub2 <= "00" & signed(tex2_alpha);
         when 3 => alpha_sub2 <= "00" & signed(settings_primcolor.prim_A);
         when 4 => alpha_sub2 <= '0' & signed(pipeInColor(3));
         when 5 => alpha_sub2 <= "00" & signed(settings_envcolor.env_A);
         when 6 => alpha_sub2 <= 10x"100";
         when 7 => alpha_sub2 <= (others => '0');
         when others => null;
      end case;
      
      alpha_mul <= (others => '0');
      case (to_integer(mode_mul)) is
         when 0 => alpha_mul <= resize(signed(lod_frac),10);
         when 1 => alpha_mul <= "00" & signed(tex_alpha);
         when 2 => alpha_mul <= "00" & signed(tex2_alpha);
         when 3 => alpha_mul <= "00" & signed(settings_primcolor.prim_A);
         when 4 => alpha_mul <= '0' & signed(pipeInColor(3));
         when 5 => alpha_mul <= "00" & signed(settings_envcolor.env_A);
         when 6 => alpha_mul <= "00" & signed(settings_primcolor.prim_levelFrac);
         --when 7 => alpha_sub2 <= (others => '0');
         when others => null;
      end case;
      
      alpha_add <= (others => '0');
      case (to_integer(mode_add)) is
         when 0 => alpha_add <= combine_alpha_next;
         when 1 => alpha_add <= "00" & signed(tex_alpha);
         when 2 => alpha_add <= "00" & signed(tex2_alpha);
         when 3 => alpha_add <= "00" & signed(settings_primcolor.prim_A);
         when 4 => alpha_add <= '0' & signed(pipeInColor(3));
         when 5 => alpha_add <= "00" & signed(settings_envcolor.env_A);
         when 6 => alpha_add <= 10x"100";
         when 7 => alpha_add <= (others => '0');
         when others => null;
      end case;

   end process;
   
   combiner_sub <= alpha_sub1 - alpha_sub2;
   combiner_mul <= combiner_sub * alpha_mul; 
   combiner_add <= combiner_mul + (alpha_add & x"80");
   combiner_cut <= combiner_add(19 downto 8);
   
   
   combiner_result <= 9x"000" when (combiner_cut(8 downto 7) = "11") else
                      9x"100" when (combiner_cut(8) = '1' or combiner_cut(7 downto 0) = x"FF") else
                      '0' & unsigned(combiner_cut(7 downto 0));
                      
   cvgmul <= (combiner_result * cvgCount) + 4;
   
   cvgCount_select <= cvgmul(11 downto 8) when (settings_otherModes.cvgTimesAlpha = '1') else cvgCount;

   cvg_overflow <= '1' when (cvgFB + cvgCount_select >= 8) else '0';

   combine_alpha_save <= combine_alpha_next;
   
   -- combine2
   cvgmul2 <= (combiner_result2 * cvgCount2) + 4;

   process (clk1x)
      variable calc_alpha : unsigned(8 downto 0);
      variable calc_alpha2 : unsigned(8 downto 0);
   begin
      if rising_edge(clk1x) then
      
         error_combineAlpha <= '0';
         
         if (step2 = '1' or trigger = '1') then
            combine_alpha_next <= combiner_cut(9 downto 0);
         end if;
         
         calc_alpha := combiner_result;
            
         if (settings_otherModes.alphaCvgSelect = '0') then
            if (settings_otherModes.key = '0') then
               calc_alpha := combiner_result + to_integer(ditherAlpha);
            else
               error_combineAlpha <= '1'; -- todo: key alpha mode
            end if;
         else
            if (settings_otherModes.cvgTimesAlpha = '1') then
               calc_alpha := cvgmul(11 downto 3);
            else 
               calc_alpha := cvgCount(3 downto 0) & "00000";
            end if;
         end if;
            
         if (calc_alpha(8) = '1') then
            calc_alpha := 9x"0FF";
         end if;
            
         if (trigger = '1') then
            combine_alpha    <= calc_alpha(7 downto 0);
            combine_CVGCount <= cvgCount_select;
         end if;
         
         -- combine2
         if (step2 = '1') then
            combiner_result2 <= combiner_result;
            cvgCount2        <= cvgCount;
            ditherAlpha2     <= ditherAlpha;
         end if;
         
         calc_alpha2 := combiner_result2;
            
         if (settings_otherModes.alphaCvgSelect = '0') then
            if (settings_otherModes.key = '0') then
               calc_alpha2 := combiner_result2 + to_integer(ditherAlpha2);
            else
               error_combineAlpha <= '1'; -- todo: key alpha mode
            end if;
         else
            if (settings_otherModes.cvgTimesAlpha = '1') then
               calc_alpha2 := cvgmul2(11 downto 3);
            else 
               calc_alpha2 := cvgCount2(3 downto 0) & "00000";
            end if;
         end if;
            
         if (calc_alpha2(8) = '1') then
            calc_alpha2 := 9x"0FF";
         end if;
         
         if (trigger = '1') then
            combine_alpha2 <= calc_alpha2(7 downto 0);
         end if;
         
      end if;
   end process;

end architecture;





