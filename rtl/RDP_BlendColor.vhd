library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;
use work.pFunctions.all;

entity RDP_BlendColor is
   port 
   (
      clk1x                   : in  std_logic;
      trigger                 : in  std_logic;
      mode2                   : in  std_logic;
      step2                   : in  std_logic;

      settings_otherModes     : in  tsettings_otherModes;
      settings_blendcolor     : in  tsettings_blendcolor;
      settings_fogcolor       : in  tsettings_fogcolor;
     
      blend_ena               : in  std_logic;
      zOverflow               : in  std_logic;
      pipeInColor             : in  tcolor4_u9;
      combine_color           : in  tcolor3_u8;
      combine_alpha           : in  unsigned(7 downto 0);
      combine_alpha2          : in  unsigned(7 downto 0);
      FB_color                : in  tcolor4_u8;
      blend_shift_a           : in  unsigned(2 downto 0);
      blend_shift_b           : in  unsigned(2 downto 0);
      random8                 : in  unsigned(7 downto 0);
      ditherAlpha             : in  unsigned(2 downto 0);
      
      blend_alphaIgnore       : out std_logic := '0';
      blend_divEna            : out std_logic := '0';
      blend_divVal            : out unsigned(3 downto 0) := (others => '0');
      blender_color           : out tcolor3_u14
   );
end entity;

architecture arch of RDP_BlendColor is

   signal mode_1_R            : unsigned(1 downto 0);
   signal mode_1_A            : unsigned(1 downto 0);
   signal mode_2_R            : unsigned(1 downto 0);
   signal mode_2_A            : unsigned(1 downto 0);
      
   signal color_1_R           : tcolor3_u8;
   signal color_2_R           : tcolor3_u8;
   signal color_1_A           : unsigned(7 downto 0);
   signal color_2_A           : unsigned(7 downto 0);
   
   signal color_1_A_reduced   : unsigned(4 downto 0);
   signal color_2_A_reduced   : unsigned(4 downto 0);
   
   signal blend               : std_logic;
   signal zCheck              : std_logic;
         
   signal blend_mul1          : tcolor3_u13;
   signal blend_mul2          : tcolor3_u14;
   signal blend_add           : tcolor3_u14;
   
   signal blender_next        : tcolor3_u8 := (others => (others => '0'));
   
   signal blend_alphaIgnore_next : std_logic := '0';

begin 

   mode_1_R <= settings_otherModes.blend_m1a1 when (mode2 = '1' and step2 = '0') else settings_otherModes.blend_m1a0;
   mode_1_A <= settings_otherModes.blend_m1b1 when (mode2 = '1' and step2 = '0') else settings_otherModes.blend_m1b0;
   mode_2_R <= settings_otherModes.blend_m2a1 when (mode2 = '1' and step2 = '0') else settings_otherModes.blend_m2a0;
   mode_2_A <= settings_otherModes.blend_m2b1 when (mode2 = '1' and step2 = '0') else settings_otherModes.blend_m2b0;
   
   process (all)
   begin

      -- todo: also disable for step 2?
      blend <= blend_ena;
      if (mode_1_A = 0 and mode_2_A = 0 and combine_alpha = 255) then
         blend <= '0';
      end if;
      
      if (mode2 = '1' and step2 = '1') then
         blend <= '1';
      end if;

      for i in 0 to 2 loop
         
         color_1_R(i) <= (others => '0');
         case (to_integer(mode_1_R)) is
            when 0 => 
               if (mode2 = '1' and step2 = '0') then
                  color_1_R <= blender_next;
               else
                  color_1_R <= combine_color;
               end if;
            when 1 =>
               color_1_R(0) <= FB_color(0);
               color_1_R(1) <= FB_color(1);
               color_1_R(2) <= FB_color(2);
            when 2 => 
               color_1_R(0) <= settings_blendcolor.blend_R;
               color_1_R(1) <= settings_blendcolor.blend_G;
               color_1_R(2) <= settings_blendcolor.blend_B;
            when 3 => 
               color_1_R(0) <= settings_fogcolor.fog_R;
               color_1_R(1) <= settings_fogcolor.fog_G;
               color_1_R(2) <= settings_fogcolor.fog_B;
            when others => null;
         end case;
         
         color_2_R(i) <= (others => '0');
         case (to_integer(mode_2_R)) is
            when 0 => 
               if (mode2 = '1' and step2 = '0') then
                  color_2_R <= blender_next;
               else
                  color_2_R <= combine_color;
               end if;
            when 1 =>
               -- todo: use fb_1 color for step 2...but should be same as it's the same pixel?
               color_2_R(0) <= FB_color(0);
               color_2_R(1) <= FB_color(1);
               color_2_R(2) <= FB_color(2);
            when 2 => 
               color_2_R(0) <= settings_blendcolor.blend_R;
               color_2_R(1) <= settings_blendcolor.blend_G;
               color_2_R(2) <= settings_blendcolor.blend_B;
            when 3 => 
               color_2_R(0) <= settings_fogcolor.fog_R;
               color_2_R(1) <= settings_fogcolor.fog_G;
               color_2_R(2) <= settings_fogcolor.fog_B;
            when others => null;
         end case;
   
      end loop;
      
      
      case (to_integer(mode_1_A)) is
         when 0 => 
            color_1_A <= combine_alpha;
         when 1 =>
            color_1_A <= settings_fogcolor.fog_A;
         when 2 => 
            if (pipeInColor(3) + ditherAlpha >= 16#100#) then
               color_1_A <= (others => '1');
            else
               color_1_A <= unsigned(pipeInColor(3)(7 downto 0) + to_integer(ditherAlpha));
            end if;
         when 3 => color_1_A <= (others => '0'); -- zero
         when others => null;
      end case;
      
      color_2_A <= (others => '0');
      case (to_integer(mode_2_A)) is
         when 0 => 
            color_2_A <= to_unsigned(16#FF#, 8) - color_1_A;
         when 1 =>
            -- todo: use fb_1 color for step 2...but should be same as it's the same pixel?
            color_2_A <= FB_color(3);
         when 2 => 
            color_2_A <= (others => '1');
         when 3 => 
            color_2_A <= (others => '0');
         when others => null;
      end case;

   end process;
   
   color_1_A_reduced <= shift_right(color_1_A(7 downto 5), to_integer(blend_shift_a)) & "00" when (mode_2_A = 1) else color_1_A(7 downto 3);
   color_2_A_reduced <= shift_right(color_2_A(7 downto 5), to_integer(blend_shift_b)) & "11" when (mode_2_A = 1) else color_2_A(7 downto 3);
   
   gcalc: for i in 0 to 2 generate
   begin
   
      blend_mul1(i)   <= color_1_R(i) * color_1_A_reduced;
      blend_mul2(i)   <= color_2_R(i) * (resize(color_2_A_reduced, 6) + 1);
      blend_add(i)    <= resize(blend_mul1(i), 14) + blend_mul2(i);
      
   end generate;
   
   zCheck <= zOverflow when (mode2 = '0' or (mode2 = '1' and step2 = '0')) else '1';
   
   process (clk1x)
      variable blender_result : tcolor3_u14;
   begin
      if rising_edge(clk1x) then
         
         -- color
         for i in 0 to 2 loop
         
            if (settings_otherModes.colorOnCvg = '0' or zCheck = '1') then
               if (blend = '1') then
                  blender_result(i) := blend_add(i);
               else
                  blender_result(i) := "0" & color_1_R(i) & "00000";
               end if;
            else
               blender_result(i) := "0" & color_2_R(i) & "00000";
            end if;
   
            if (step2 = '1') then 
               blender_next(i) <= blender_result(i)(12 downto 5);
            end if;
            
            if (trigger = '1') then
               blender_color(i) <= blender_result(i);
            end if;
                
         end loop;
            
         -- alpha ignore
         if (trigger = '1') then
            if (mode2 = '1') then
               blend_alphaIgnore <= blend_alphaIgnore_next;
            else
               blend_alphaIgnore <= '0';
               if (settings_otherModes.alphaCompare = '1') then
                  if (settings_otherModes.ditherAlpha = '0') then
                     if (combine_alpha < settings_blendcolor.blend_A) then
                        blend_alphaIgnore <= '1';
                     end if;
                  else
                     if (combine_alpha < random8) then
                        blend_alphaIgnore <= '1';
                     end if;
                  end if;
               end if;
            end if;
         end if;
         
         if (step2 = '1') then
            blend_alphaIgnore_next <= '0';
            if (settings_otherModes.alphaCompare = '1') then
               if (settings_otherModes.ditherAlpha = '0') then
                  if (combine_alpha2 < settings_blendcolor.blend_A) then
                     blend_alphaIgnore_next <= '1';
                  end if;
               else
                  if (combine_alpha2 < random8) then
                     blend_alphaIgnore_next <= '1';
                  end if;
               end if;
            end if;
         end if;
          
         -- blend div
         if (trigger = '1') then
         
            blend_divVal <= ('0' & color_1_A_reduced(4 downto 2)) + ('0' & color_2_A_reduced(4 downto 2)) + 1;
         
            blend_divEna <= '0';
            if (settings_otherModes.colorOnCvg = '0' or zCheck = '1') then
               if (blend = '1') then
                  if ((mode2 = '1' and step2 = '0') or mode2 = '0') then
                     if (settings_otherModes.forceBlend = '0') then
                        blend_divEna <= '1';
                     end if;
                  end if;
               end if;
            end if;
            
         end if;

         
      end if;
   end process;
   

end architecture;





