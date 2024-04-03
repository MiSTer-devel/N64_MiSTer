library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;
use work.pFunctions.all;

entity RDP_CombineColor is
   port 
   (
      clk1x                   : in  std_logic;
      trigger                 : in  std_logic;
      mode2                   : in  std_logic;
      step2                   : in  std_logic;
   
      errorCombine_out        : out std_logic := '0';
   
      settings_otherModes     : in  tsettings_otherModes;
      settings_combineMode    : in  tsettings_combineMode;
      settings_primcolor      : in  tsettings_primcolor;
      settings_envcolor       : in  tsettings_envcolor;
      settings_KEYRGB         : in  tsettings_KEYRGB;
      settings_Convert        : in  tsettings_Convert;
     
      pipeInColor             : in  tcolor4_u9;
      texture_color           : in  tcolor3_u9;
      tex_alpha               : in  unsigned(7 downto 0);      
      texture2_color          : in  tcolor3_u9;
      tex2_alpha              : in  unsigned(7 downto 0);
      lod_frac                : in  unsigned(8 downto 0);
      combine_alpha           : in  signed(9 downto 0);
      random2                 : in  unsigned(1 downto 0);
      
      -- synthesis translate_off
      export_Comb_R_All       : out unsigned(63 downto 0);
      -- synthesis translate_on

      combine_color           : out tcolor3_u8
   );
end entity;

architecture arch of RDP_CombineColor is

   signal mode_sub1        : unsigned(3 downto 0);
   signal mode_sub2        : unsigned(3 downto 0);
   signal mode_mul         : unsigned(4 downto 0);
   signal mode_add         : unsigned(2 downto 0);
   
   signal primcolor        : tcolor3_u8;
   signal envcolor         : tcolor3_u8;
   signal keyCenter        : tcolor3_u8;
   signal keyScale         : tcolor3_u8;
            
   signal color_sub1       : tcolor3_s16 := (others => (others => '0'));
   signal color_sub2       : tcolor3_s16 := (others => (others => '0'));
   signal color_mul        : tcolor3_s16 := (others => (others => '0'));
   signal color_add        : tcolor3_s16 := (others => (others => '0'));
   
   signal combiner_sub     : tcolor3_s16;
   signal combiner_mul     : tcolor3_s32;
   signal combiner_add     : tcolor3_s32;
   signal combiner_cut     : tcolor3_s16;
   
   signal combiner_save    : tcolor3_s16;
   
   signal errorCombine     : std_logic;

begin 

   mode_sub1 <= settings_combineMode.combine_sub_a_R_0 when (mode2 = '1' and step2 = '1') else settings_combineMode.combine_sub_a_R_1;
   mode_sub2 <= settings_combineMode.combine_sub_b_R_0 when (mode2 = '1' and step2 = '1') else settings_combineMode.combine_sub_b_R_1;
   mode_mul  <= settings_combineMode.combine_mul_R_0   when (mode2 = '1' and step2 = '1') else settings_combineMode.combine_mul_R_1;
   mode_add  <= settings_combineMode.combine_add_R_0   when (mode2 = '1' and step2 = '1') else settings_combineMode.combine_add_R_1;
   
   primcolor(0) <= settings_primcolor.prim_R;
   primcolor(1) <= settings_primcolor.prim_G;
   primcolor(2) <= settings_primcolor.prim_B;   
   
   envcolor(0) <= settings_envcolor.env_R;
   envcolor(1) <= settings_envcolor.env_G;
   envcolor(2) <= settings_envcolor.env_B;
   
   keyCenter(0) <= settings_KEYRGB.center_R;
   keyCenter(1) <= settings_KEYRGB.center_G;
   keyCenter(2) <= settings_KEYRGB.center_B;
   
   keyScale(0) <= settings_KEYRGB.scale_R;
   keyScale(1) <= settings_KEYRGB.scale_G;
   keyScale(2) <= settings_KEYRGB.scale_B;
   
   process (all)
   begin
      
      errorCombine <= '0';
      
      for i in 0 to 2 loop
         
         color_sub1(i) <= (others => '0');
         case (to_integer(mode_sub1)) is
            when 0 => color_sub1(i) <= combiner_save(i);
            when 1 => if ( texture_color(i)(8 downto 7) = "11") then color_sub1(i) <= 7x"7F" & signed(texture_color(i));  else color_sub1(i) <= 7x"00" & signed(texture_color(i));  end if; 
            when 2 => if (texture2_color(i)(8 downto 7) = "11") then color_sub1(i) <= 7x"7F" & signed(texture2_color(i)); else color_sub1(i) <= 7x"00" & signed(texture2_color(i)); end if; 
            when 3 => color_sub1(i) <= x"00" & signed(primcolor(i));
            when 4 => color_sub1(i) <= 7x"00" & signed(pipeInColor(i));
            when 5 => color_sub1(i) <= x"00" & signed(envcolor(i));
            when 6 => color_sub1(i) <= 16x"100";
            when 7 => color_sub1(i) <= x"00" & signed(random2) & "100000";
            when others => null;
         end case;
         
         
         
         color_sub2(i) <= (others => '0');
         case (to_integer(mode_sub2)) is
            when 0 => color_sub2(i) <= combiner_save(i);
            when 1 => if ( texture_color(i)(8 downto 7) = "11") then color_sub2(i) <= 7x"7F" & signed(texture_color(i));  else color_sub2(i) <= 7x"00" & signed(texture_color(i));  end if;
            when 2 => if (texture2_color(i)(8 downto 7) = "11") then color_sub2(i) <= 7x"7F" & signed(texture2_color(i)); else color_sub2(i) <= 7x"00" & signed(texture2_color(i)); end if;
            when 3 => color_sub2(i) <= x"00" & signed(primcolor(i));
            when 4 => color_sub2(i) <= 7x"00" & signed(pipeInColor(i));
            when 5 => color_sub2(i) <= x"00" & signed(envcolor(i));
            when 6 => color_sub2(i) <= x"00" & signed(keyCenter(i));
            when 7 => color_sub2(i) <= 7x"00" & signed(settings_Convert.K4);
            when others => null;
         end case;    
         
         color_mul(i) <= (others => '0');
         case (to_integer(mode_mul)) is
            when  0 => color_mul(i) <= resize(combiner_save(i)(8 downto 0), 16);
            when  1 => color_mul(i) <= resize(signed(texture_color(i)), 16);
            when  2 => color_mul(i) <= resize(signed(texture2_color(i)), 16);
            when  3 => color_mul(i) <= x"00" & signed(primcolor(i));
            when  4 => color_mul(i) <= 7x"00" & signed(pipeInColor(i));
            when  5 => color_mul(i) <= x"00" & signed(envcolor(i));
            when  6 => color_mul(i) <= x"00" & signed(keyScale(i));
            when  7 => color_mul(i) <= resize(combine_alpha, 16);
            when  8 => color_mul(i) <= x"00" & signed(tex_alpha);
            when  9 => color_mul(i) <= x"00" & signed(tex2_alpha);
            when 10 => color_mul(i) <= x"00" & signed(settings_primcolor.prim_A);
            when 11 => color_mul(i) <= 7x"00" & signed(pipeInColor(3));
            when 12 => color_mul(i) <= x"00" & signed(settings_envcolor.env_A);
            when 13 => color_mul(i) <= resize(signed(lod_frac), 16);
            when 14 => color_mul(i) <= x"00" & signed(settings_primcolor.prim_levelFrac);
            when 15 => color_mul(i) <= 7x"00" & signed(settings_Convert.K5);
            when others => null;
         end case;
         
         color_add(i) <= (others => '0');
         case (to_integer(mode_add)) is
            when 0 => color_add(i) <= combiner_save(i);
            when 1 => if ( texture_color(i)(8 downto 7) = "11") then color_add(i) <= 7x"7F" & signed(texture_color(i));  else color_add(i) <= 7x"00" & signed(texture_color(i));  end if;
            when 2 => if (texture2_color(i)(8 downto 7) = "11") then color_add(i) <= 7x"7F" & signed(texture2_color(i)); else color_add(i) <= 7x"00" & signed(texture2_color(i)); end if;
            when 3 => color_add(i) <= x"00" & signed(primcolor(i));
            when 4 => color_add(i) <= 7x"00" & signed(pipeInColor(i));
            when 5 => color_add(i) <= x"00" & signed(envcolor(i));
            when 6 => color_add(i) <= 16x"100";
            when others => null;
         end case;
   
      end loop;

   end process;
   
   gcalc: for i in 0 to 2 generate
   begin
   
      combiner_sub(i)   <= color_sub1(i) - color_sub2(i);
      combiner_mul(i)   <= combiner_sub(i) * color_mul(i); 
      combiner_add(i)   <= combiner_mul(i) + (color_add(i) & x"80");
      combiner_cut(i)   <= combiner_add(i)(23 downto 8);
   
   end generate;
   

   process (clk1x)
   begin
      if rising_edge(clk1x) then

         if (trigger = '1' or step2 = '1') then
         
            for i in 0 to 2 loop
               combiner_save(i) <= combiner_cut(i);
            end loop;
         
         end if;
         
         if (trigger = '1') then
         
            errorCombine_out <= errorCombine;
         
            for i in 0 to 2 loop
            
               if (combiner_cut(i)(8 downto 7) = "11") then
                  combine_color(i) <= (others => '0');
               elsif (combiner_cut(i)(8) = '1') then 
                  combine_color(i) <= (others => '1');
               else
                  combine_color(i) <= unsigned(combiner_cut(i)(7 downto 0));
               end if;
               
            end loop;
            
            -- synthesis translate_off
            export_Comb_R_All <= unsigned(color_sub1(0)) & unsigned(color_sub2(0)) & unsigned(color_mul(0)) & unsigned(color_add(0));
            -- synthesis translate_on
            
         end if;
         
      end if;
   end process;

end architecture;





