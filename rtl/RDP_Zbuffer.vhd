library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;
use work.pFunctions.all;

entity RDP_Zbuffer is
   port 
   (
      clk1x                   : in  std_logic;
      trigger                 : in  std_logic;
   
      settings_poly           : in  tsettings_poly;
      settings_otherModes     : in  tsettings_otherModes;
      dzPix                   : in  unsigned(15 downto 0);
      dzPixEnc                : in  unsigned(3 downto 0);

      -- STAGE_INPUT
      zIn                     : in  signed(21 downto 0);
      offX                    : in  unsigned(1 downto 0);
      offY                    : in  unsigned(1 downto 0);
      
      -- STAGE_TEXCOORD
      old_Z_mem               : in unsigned(17 downto 0);
      
      -- STAGE_COMBINER
      cvg_overflow            : in  std_logic;
      blend_shift_a           : out unsigned(2 downto 0);
      blend_shift_b           : out unsigned(2 downto 0);
      
      -- synthesis translate_off
      export_zNewRaw          : out unsigned(31 downto 0);
      export_zOld             : out unsigned(31 downto 0);
      export_dzOld            : out unsigned(15 downto 0);
      export_dzNew            : out unsigned(15 downto 0);
      -- synthesis translate_on
      
      blend_enable            : out std_logic := '0';
      zOverflow               : out std_logic := '0';
      zUsePixel               : out std_logic := '0';
      zResult                 : out unsigned(15 downto 0) := (others => '0');
      zResultH                : out unsigned(1 downto 0) := (others => '0');
      
      -- STAGE_BLENDER
      cvgCount_combine        : in  unsigned(3 downto 0);
      cvgCount_out            : out  unsigned(3 downto 0) := (others => '0')
   );
end entity;

architecture arch of RDP_Zbuffer is

   -- STAGE_INPUT
   signal corrected_sum_x   : signed(24 downto 0);
   signal corrected_sum_y   : signed(24 downto 0);
      
   signal corrected_sum     : signed(25 downto 0) := (others => '0');
   signal zIn_1             : signed(21 downto 0) := (others => '0');
      
   -- STAGE_PERSPCOR  
   signal new_z_calc        : signed(26 downto 0);
   signal new_z_selected    : signed(18 downto 0);
      
   signal new_z_p           : unsigned(17 downto 0) := (others => '0');
    
   -- STAGE_TEXCOORD
   signal new_z             : unsigned(17 downto 0) := (others => '0');
    
   -- STAGE_TEXCOORD
   signal new_z_1           : unsigned(17 downto 0)  := (others => '0');   
   signal old_Z_mem_1       : unsigned(17 downto 0)  := (others => '0');
   
   -- STAGE_TEXFETCH     
   signal new_z_2           : unsigned(17 downto 0)  := (others => '0');
   signal old_Z_mem_2       : unsigned(17 downto 0)  := (others => '0');
   
   -- STAGE_TEXREAD
   signal oldZ_mantissa     : unsigned(10 downto 0);
   signal oldZ_shift        : unsigned(2 downto 0);
   signal oldZ_mantShifted  : unsigned(16 downto 0);
   type t_oldAddTable is array( 0 to 7) of unsigned(17 downto 0);
   constant oldAddTable     : t_oldAddTable := (18x"00000", 18x"20000", 18x"30000", 18x"38000", 18x"3c000", 18x"3e000", 18x"3f000", 18x"3f800");
   signal oldZ_addValue     : unsigned(17 downto 0);
   
   signal old_dz_mem        : unsigned(3 downto 0);
   signal old_dz_raw        : unsigned(15 downto 0);
   signal dzmin             : unsigned(4 downto 0);
   
   signal old_z             : unsigned(17 downto 0)  := (others => '0');
   signal planar            : std_logic := '0';
   signal old_dz            : unsigned(15 downto 0)  := (others => '0');
   signal new_z_3           : unsigned(17 downto 0)  := (others => '0');
   
   -- STAGE_PALETTE
   signal dz_compare        : unsigned(15 downto 0);
   
   signal dzNew             : unsigned(15 downto 0) := (others => '0');
   signal new_z_4           : unsigned(17 downto 0)  := (others => '0');
   signal planar_1          : std_logic := '0';
   signal old_z_1           : unsigned(17 downto 0)  := (others => '0');
   signal old_dz_mem_1      : unsigned(3 downto 0) := (others => '0');
   
    -- synthesis translate_off
   signal old_dz_1          : unsigned(15 downto 0)  := (others => '0');
   -- synthesis translate_on
   
   -- STAGE_COMBINER
   signal zNewSigned        : signed(19 downto 0);
   signal dzNewSigned       : signed(19 downto 0);
   signal diffZ             : signed(19 downto 0);
   signal calc_max          : std_logic;
   signal calc_front        : std_logic;
   signal calc_near         : std_logic;
   signal calc_far          : std_logic;
   
   signal is_max            : std_logic := '0';
   signal is_front          : std_logic := '0';
   signal is_near           : std_logic := '0';
   signal is_far            : std_logic := '0';
   signal is_overflow       : std_logic := '0';
   signal new_z_5           : unsigned(17 downto 0)  := (others => '0');
   signal old_z_2           : unsigned(17 downto 0)  := (others => '0');
   signal old_dz_mem_2      : unsigned(3 downto 0) := (others => '0');
   
   -- STAGE BLENDER
   signal cvg_dzShift       : unsigned(3 downto 0);
   signal cvg_oldZ_shifted  : unsigned(17 downto 0);
   signal cvg_newZ_shifted  : unsigned(17 downto 0);
   signal cvg_sub           : unsigned(17 downto 0);
   signal cvg_mul           : unsigned(7 downto 0);
  
begin 
  
   -- STAGE_INPUT
   corrected_sum_x <= settings_poly.zBuffer_DzDx(31 downto 10) * ('0' & signed(offX));
   corrected_sum_y <= settings_poly.zBuffer_DzDy(31 downto 10) * ('0' & signed(offY));
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (trigger = '1') then
         
            -- correct z based on CVG
            corrected_sum <= resize(corrected_sum_x, 26) + resize(corrected_sum_y, 26);
            zIn_1         <= zIn;
            
         end if;
         
      end if;
   end process;
      
   -- STAGE_PERSPCOR
   new_z_calc     <= resize((zIn_1 & "00"), 27) + resize(corrected_sum, 27);
   new_z_selected <= new_z_calc(23 downto 5);
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (trigger = '1') then
         
            case (new_z_selected(18 downto 17)) is
               when "00" | "01" => new_z_p <= unsigned(new_z_selected(17 downto 0));
               when "10"        => new_z_p <= (others => '1');
               when "11"        => new_z_p <= (others => '0');
               when others      => null;
            end case;

         end if;
         
      end if;
   end process;
   
   -- STAGE_LOD
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (trigger = '1') then
         
            new_z <= new_z_p;
            
         end if;
         
      end if;
   end process;
   
   -- STAGE_TEXCOORD   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (trigger = '1') then
         
            new_z_1 <= unsigned(new_z);
            old_Z_mem_1 <= old_Z_mem;

         end if;
         
      end if;
   end process;
   
   -- STAGE_TEXFETCH   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (trigger = '1') then
         
            new_z_2     <= new_z_1;
            old_Z_mem_2 <= old_Z_mem_1;

         end if;
         
      end if;
   end process;
   
   -- STAGE_TEXREAD
   oldZ_mantissa   <= old_Z_mem_2(12 downto 2);
   oldZ_shift      <= to_unsigned(6, 3) - old_Z_mem_2(15 downto 13) when (old_Z_mem_2(15 downto 13) < 7) else (others => '0');
   oldZ_mantShifted <= ("000000" & oldZ_mantissa) sll to_integer(oldZ_shift);
   oldZ_addValue   <= oldAddTable(to_integer(old_Z_mem_2(15 downto 13)));
   
   old_dz_mem      <= old_Z_mem_2(1 downto 0) & old_Z_mem_2(17 downto 16);
   old_dz_raw      <= to_unsigned(1, 16) sll to_integer(old_dz_mem);
   dzmin           <= shift_right(to_unsigned(16, 5), to_integer(old_Z_mem_2(14 downto 13)));
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (trigger = '1') then
         
            new_z_3      <= new_z_2;
            old_dz_mem_1 <= old_dz_mem;
            old_z        <= oldZ_mantShifted + oldZ_addValue;
 
            planar <= '0';
            if (old_Z_mem_2(15 downto 13) < 3) then
               if (old_dz_raw /= x"8000") then
                  if (to_integer(old_dz_raw(14 downto 0) & '0') < to_integer(dzmin)) then
                     old_dz <= 11x"0" & dzmin;
                  else
                     old_dz <= old_dz_raw(14 downto 0) & '0';
                  end if;
               else
                  planar <= '1';
                  old_dz <= (others => '1');
               end if;
            else
               old_dz <= old_dz_raw;
            end if;

         end if;
         
      end if;
   end process;
   
   -- STAGE_PALETTE
   dz_compare <= dzPix or old_dz;
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (trigger = '1') then
         
            new_z_4      <= new_z_3;
            old_z_1      <= old_z;
            planar_1     <= planar;
            old_dz_mem_2 <= old_dz_mem_1;
         
            dzNew <= (others => '0');
            for i in 0 to 15 loop
               if (dz_compare(i) = '1') then
                  dzNew    <= (others => '0');
                  dzNew(i) <= '1';
               end if;
            end loop;
            
            -- synthesis translate_off
            old_dz_1 <= old_dz;
            -- synthesis translate_on

         end if;
         
      end if;
   end process;
   
   -- STAGE_COMBINER
   zNewSigned  <=  "00" & signed(new_z_4);
   dzNewSigned <=  '0' & signed(dzNew) & "000";
   diffZ       <= zNewSigned - dzNewSigned;
   
   calc_max      <= '1' when (old_z_1 = 18x"3FFFF") else '0';
   calc_front    <= '1' when (new_z_4 < old_z_1) else '0';
   calc_near     <= '1' when (planar_1 = '1' or to_integer(diffZ) <= to_integer(old_z_1)) else '0';
   calc_far      <= '1' when (planar_1 = '1' or (new_z_4 + (dzNew & "000")) >= old_z_1) else '0'; 
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (trigger = '1') then
         
            new_z_5 <= new_z_4;
            old_z_2 <= old_z_1;
            
            is_max       <= calc_max;
            is_front     <= calc_front;
            is_near      <= calc_near;
            is_far       <= calc_far; 
            is_overflow  <= cvg_overflow;

            blend_enable <= '0';
            if (settings_otherModes.zCompare = '1') then
               if (settings_otherModes.forceBlend = '1' or (cvg_overflow = '0' and settings_otherModes.AntiAlias = '1' and calc_far = '1')) then
                  blend_enable <= '1';
               end if;
            else
               if (settings_otherModes.forceBlend = '1' or (cvg_overflow = '0' and settings_otherModes.AntiAlias = '1')) then
                  blend_enable <= '1';
               end if;
            end if;
            
            if (settings_otherModes.zCompare = '1') then
               if (old_dz_mem_2 > dzPixEnc) then
                  blend_shift_a <= "000";
               elsif ((dzPixEnc - old_dz_mem_2) > 4) then
                  blend_shift_a <= "100";
               else
                  blend_shift_a <= resize(dzPixEnc - old_dz_mem_2, 3);
               end if;
               
               if (dzPixEnc > old_dz_mem_2) then
                  blend_shift_b <= "000";
               elsif ((old_dz_mem_2 - dzPixEnc) > 4) then
                  blend_shift_b <= "100";
               else
                  blend_shift_b <= resize(old_dz_mem_2 - dzPixEnc, 3);
               end if;
            else
               blend_shift_a <= "000";
               blend_shift_b <= "000";
               if (dzPixEnc >= 12) then -- max 4
                  blend_shift_b <= to_unsigned(15 - to_integer(dzPixEnc),3);
               else
                  blend_shift_b <= "100";
               end if;
            end if;
            
            -- synthesis translate_off
            export_zNewRaw  <= 14x"0" & new_z_4;
            export_zOld     <= 14x"0" & old_z_1;
            export_dzOld    <= old_dz_1;
            export_dzNew    <= dzNew;
            -- synthesis translate_on

         end if;
         
      end if;
   end process;
   
   zOverflow <= is_overflow;


   cvg_dzShift(3) <= '1' when (dzNew(15 downto 8) > 0) else '0';
   cvg_dzShift(2) <= '1' when ((dzNew(15 downto 12) & dzNew(7 downto 4)) > 0) else '0';
   cvg_dzShift(1) <= '1' when ((dzNew(15 downto 14) & dzNew(11 downto 10) & dzNew(7 downto 6) & dzNew(3 downto 2)) > 0) else '0';
   cvg_dzShift(0) <= '1' when ((dzNew(15) or dzNew(13) or dzNew(11) or dzNew(9) or dzNew(7) or dzNew(5) or dzNew(3) or dzNew(1)) = '1') else '0';
   
   cvg_oldZ_shifted <= shift_right(old_z_2, to_integer(cvg_dzShift));
   cvg_newZ_shifted <= shift_right(new_z_5, to_integer(cvg_dzShift));
   
   cvg_sub <= cvg_oldZ_shifted - cvg_newZ_shifted;
   cvg_mul <= cvgCount_combine * cvg_sub(3 downto 0);
   
   -- STAGE_BLENDER
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (trigger = '1') then
         
            cvgCount_out <= cvgCount_combine;
         
            zUsePixel <= '0';
            case (settings_otherModes.zMode) is
               when "00" =>
                  if (is_overflow = '1') then
                     zUsePixel <= is_front or is_max;
                  else
                     zUsePixel <= is_near or is_max;
                  end if;
               
               when "01" =>
                  if (is_front = '0' or is_far = '0' or is_overflow = '0') then
                     if (is_overflow = '1') then
                        zUsePixel <= is_front or is_max;
                     else
                        zUsePixel <= is_near or is_max;
                     end if;
                  else
                     zUsePixel    <= '1';
                     cvgCount_out <= cvg_mul(6 downto 3);
                  end if;
            
               when "10" =>
                  zUsePixel <= is_front or is_max;
            
               when "11" =>
                  zUsePixel <= is_far and is_near and (not is_max);
            
               when others => null;
            end case;

            if (settings_otherModes.zCompare = '0') then
               zUsePixel <= '1';
            end if;

            if    (new_z_5(17 downto 11) < 16#40#) then zResult <= "000" & new_z_5(16 downto 6) & "00";
            elsif (new_z_5(17 downto 11) < 16#60#) then zResult <= "001" & new_z_5(15 downto 5) & "00";
            elsif (new_z_5(17 downto 11) < 16#70#) then zResult <= "010" & new_z_5(14 downto 4) & "00";
            elsif (new_z_5(17 downto 11) < 16#78#) then zResult <= "011" & new_z_5(13 downto 3) & "00";
            elsif (new_z_5(17 downto 11) < 16#7C#) then zResult <= "100" & new_z_5(12 downto 2) & "00";
            elsif (new_z_5(17 downto 11) < 16#7E#) then zResult <= "101" & new_z_5(11 downto 1) & "00";
            elsif (new_z_5(17 downto 11) < 16#7F#) then zResult <= "110" & new_z_5(10 downto 0) & "00";
            else                                        zResult <= "111" & new_z_5(10 downto 0) & "00";
            end if;
            
            zResult(1 downto 0) <= dzPixEnc(3 downto 2);
            zResultH            <= dzPixEnc(1 downto 0);

         end if;
         
      end if;
   end process;

end architecture;





