library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   

library mem;
use work.pFunctions.all;
use work.pRSP.all;

entity RSP_vector is
   generic 
   (
      V_INDEX : integer range 0 to 7
   );
   port 
   (
      clk1x                 : in  std_logic;
      
      CalcNew               : in  std_logic;
      CalcType              : in  VECTOR_CALCTYPE;
      CalcSign1             : in  std_logic;
      CalcSign2             : in  std_logic;
      VectorValue1          : in  std_logic_vector(15 downto 0);
      VectorValue2          : in  std_logic_vector(15 downto 0);
      element               : in  unsigned(3 downto 0);
      destElement           : in  unsigned(2 downto 0);
      rdBit0                : in  std_logic;
      outputSelect_in       : in  toutputSelect;
      storeMACHigh          : in  std_logic;
      
      set_vco               : in  std_logic;
      set_vcc               : in  std_logic;
      set_vce               : in  std_logic;
      vco_in_lo             : in  std_logic;
      vco_in_hi             : in  std_logic;
      vcc_in_lo             : in  std_logic;
      vcc_in_hi             : in  std_logic;
      vce_in                : in  std_logic;
      
      -- synthesis translate_off
      export_accu           : out unsigned(47 downto 0) := (others => '0');
      export_vco_lo         : out std_logic := '0';
      export_vco_hi         : out std_logic := '0';
      export_vcc_lo         : out std_logic := '0';
      export_vcc_hi         : out std_logic := '0';
      export_vce            : out std_logic := '0';
      -- synthesis translate_on
      
      writebackEna          : out std_logic := '0';
      writebackData         : out std_logic_vector(15 downto 0) := (others => '0');
      
      flag_vco_lo           : out std_logic;
      flag_vco_hi           : out std_logic;
      flag_vcc_lo           : out std_logic;
      flag_vcc_hi           : out std_logic;
      flag_vce              : out std_logic
   );
end entity;

architecture arch of RSP_vector is
          
   -- stage 3   
   signal value_in1       : signed(16 downto 0);
   signal value_in2       : signed(16 downto 0);
   
   signal value2Not       : std_logic_vector(15 downto 0);
   
   signal carry_vector    : signed(16 downto 0);
   signal add_result      : signed(16 downto 0);
   signal sub_result      : signed(16 downto 0);
   
   signal and_result      : unsigned(15 downto 0);
   signal or_result       : unsigned(15 downto 0);
   signal xor_result      : unsigned(15 downto 0);
   
   signal AddIsZero       : std_logic;
   signal SubIsZero       : std_logic;
   signal AgreaterB       : std_logic;
   signal AequalB         : std_logic;
   signal AlesserB        : std_logic;
   signal AequalNotB      : std_logic;
   
   signal value_in1mul    : signed(16 downto 0);
   signal value_in2mul    : signed(17 downto 0);
   signal mul_result      : signed(34 downto 0);
   signal mulAddValue     : signed(47 downto 0);
   signal mulShiftedRND   : std_logic;
   signal mulIgnoreRND    : std_logic;
   signal mulShifted      : signed(47 downto 0);
   signal mac_result      : signed(47 downto 0);
   
   signal mpeg_result     : signed(47 downto 0);
   
   -- regs
   signal acc             : signed(47 downto 0) := (others => '0');
   alias acc_h              is acc(47 downto 32);
   alias acc_m              is acc(31 downto 16);
   alias acc_l              is acc(15 downto  0);
   
   signal vco_lo          : std_logic := '0';
   signal vco_hi          : std_logic := '0';
   signal vcc_lo          : std_logic := '0';
   signal vcc_hi          : std_logic := '0';
   signal vce             : std_logic := '0';
   
   signal outputSelect    : toutputSelect;
   
   signal add_carry       : std_logic := '0';
   
   -- stage 4 
   signal clamp_signbit   : std_logic;
  
   -- synthesis translate_off
   signal acc_1           : signed(47 downto 0) := (others => '0');
   signal vco_lo_1        : std_logic := '0';
   signal vco_hi_1        : std_logic := '0';
   signal vcc_lo_1        : std_logic := '0';
   signal vcc_hi_1        : std_logic := '0';
   signal vce_1           : std_logic := '0';
   -- synthesis translate_on
   
begin 

   flag_vco_lo <= vco_lo;
   flag_vco_hi <= vco_hi;
   flag_vcc_lo <= vcc_lo;
   flag_vcc_hi <= vcc_hi;
   flag_vce    <= vce;   
   
--##############################################################
--############################### stage 3
--##############################################################
   
   -- signed/unsigned
   value_in1 <= resize(signed(VectorValue1), 17) when (CalcSign1 = '1') else '0' & signed(VectorValue1);
   value_in2 <= resize(signed(VectorValue2), 17) when (CalcSign2 = '1') else '0' & signed(VectorValue2);
   
   value2Not <= not VectorValue2;
   
   -- calc
   carry_vector <= x"0000" & vco_lo when (CalcType = VCALC_VADD or CalcType = VCALC_VSUB) else 
                   17x"00001"       when (CalcType = VCALC_VCR and xor_result(15) = '1') else
                  (others => '0');
   
   add_result <= value_in1 + value_in2 + carry_vector;
   sub_result <= value_in1 - value_in2 - carry_vector;
   
   and_result <= unsigned(VectorValue1) and unsigned(VectorValue2);
   or_result  <= unsigned(VectorValue1) or unsigned(VectorValue2);
   xor_result <= unsigned(VectorValue1) xor unsigned(VectorValue2);
   
   -- mul
   value_in1mul <= 17x"00001" when (CalcType = VCALC_VRNDP or CalcType = VCALC_VRNDN) else
                   value_in1;
   
   value_in2mul <= value_in2 & '0' when (CalcType = VCALC_VMULF or CalcType = VCALC_VMULU or CalcType = VCALC_VMACF or CalcType = VCALC_VMACU) else
                   value_in2(16) & value_in2;
   
   mul_result   <= value_in1mul * value_in2mul;
   
   mulAddValue  <= to_signed(16#8000#, 48)      when (CalcType = VCALC_VMULF or CalcType = VCALC_VMULU) else
                   to_signed(16#1F0000#, 48)    when (CalcType = VCALC_VMULQ and mul_result < 0) else
                   acc                          when (CalcType = VCALC_VMACF or CalcType = VCALC_VMACU or CalcType = VCALC_VMADL or CalcType = VCALC_VMADM or CalcType = VCALC_VMADN or CalcType = VCALC_VMADH or CalcType = VCALC_VRNDP or CalcType = VCALC_VRNDN) else
                   acc(47 downto 16) & x"0000"  when (CalcType = VCALC_VMACQ) else
                   (others => '0');
       
   mulShiftedRND <= '1' when (CalcType = VCALC_VRNDP and acc(47) = '0' and rdBit0 = '1') else
                    '1' when (CalcType = VCALC_VRNDN and acc(47) = '1' and rdBit0 = '1') else
                    '0';
   
   mulIgnoreRND  <= '1' when (CalcType = VCALC_VRNDP and acc(47) = '1') else
                    '1' when (CalcType = VCALC_VRNDN and acc(47) = '0') else
                    '0';
   
   mulShifted   <= mul_result(31 downto 0) & x"0000"      when (CalcType = VCALC_VMUDH or CalcType = VCALC_VMADH or CalcType = VCALC_VMULQ or mulShiftedRND = '1') else
                   resize(shift_right(mul_result,16), 48) when (CalcType = VCALC_VMUDL or CalcType = VCALC_VMADL) else
                   to_signed(16#200000#, 48)              when (CalcType = VCALC_VMACQ and acc < 0 and acc(21) = '0')                else
                   to_signed(-16#200000#, 48)             when (CalcType = VCALC_VMACQ and acc(47 downto 16) > 32 and acc(21) = '0') else
                   (others => '0')                        when (CalcType = VCALC_VMACQ or mulIgnoreRND = '1') else
                   resize(mul_result, 48);
                   
   mac_result   <= mulShifted + mulAddValue;
   
   -- compares
   AddIsZero  <= '1' when (add_result(15 downto 0) = 0) else '0';
   SubIsZero  <= '1' when (sub_result = 0) else '0';
   AgreaterB  <= not sub_result(16) and (not AequalB);
   AequalB    <= SubIsZero;
   AlesserB   <= sub_result(16) and (not AequalB);
   AequalNotB <= '1' when (VectorValue1 = value2Not) else '0';
   
   process (clk1x)
      variable vcc_lo_calc : std_logic;
      variable vcc_hi_calc : std_logic;
   begin
      if (rising_edge(clk1x)) then
      
         writebackEna <= '0';
         
         if (set_vco = '1') then
            vco_lo <= vco_in_lo;
            vco_hi <= vco_in_hi;
         end if;
         
         if (set_vcc = '1') then
            vcc_lo <= vcc_in_lo;
            vcc_hi <= vcc_in_hi;
         end if;
         
         if (set_vce = '1') then
            vce <= vce_in;
         end if; 

         vcc_lo_calc := vcc_lo;
         vcc_hi_calc := vcc_hi;
      
         if (CalcNew = '1') then
         
            writebackEna <= '1';
            outputSelect <= outputSelect_in;
            
            if (storeMACHigh = '1') then
               acc(47 downto 16) <= mac_result(47 downto 16);
            end if;
         
            case (CalcType) is
         
               when VCALC_VMULF =>
                  acc(15 downto 0) <= mac_result(15 downto 0);             
                  
               when VCALC_VMULU =>
                  acc(15 downto 0) <= mac_result(15 downto 0);
                  
               when VCALC_VRNDP => 
                  acc(15 downto 0) <= mac_result(15 downto 0);
               
               when VCALC_VMULQ => 
                  acc(15 downto 0) <= x"0000";
                  
               when VCALC_VMUDL => 
                  acc(15 downto 0) <= mac_result(15 downto 0);
                  
               when VCALC_VMUDM => 
                  acc(15 downto 0) <= mac_result(15 downto 0);
                  
               when VCALC_VMUDN => 
                  acc(15 downto 0) <= mac_result(15 downto 0);
                  
               when VCALC_VMUDH =>
                  acc(15 downto 0) <= mac_result(15 downto 0);  

               when VCALC_VMACF => 
                  acc(15 downto 0) <= mac_result(15 downto 0);

               when VCALC_VMACU => 
                  acc(15 downto 0) <= mac_result(15 downto 0); 
                  
               when VCALC_VRNDN => 
                  acc(15 downto 0) <= mac_result(15 downto 0); 
                  
               when VCALC_VMACQ => 
                  --acc(47 downto 16) <= mac_result(47 downto 16);
                  
               when VCALC_VMADL => 
                  acc(15 downto 0) <= mac_result(15 downto 0);     

               when VCALC_VMADM => 
                  acc(15 downto 0) <= mac_result(15 downto 0);                   
                  
               when VCALC_VMADN =>
                  acc(15 downto 0) <= mac_result(15 downto 0);

               when VCALC_VMADH => 
                  acc(15 downto 0) <= mac_result(15 downto 0);                
                  
               when VCALC_VADD =>
                  acc(15 downto 0) <= add_result(15 downto 0);
                  vco_lo           <= '0';
                  vco_hi           <= '0';
                  add_carry        <= add_result(16);               
                  
               when VCALC_VSUB =>
                  acc(15 downto 0) <= sub_result(15 downto 0);
                  vco_lo           <= '0';
                  vco_hi           <= '0';
                  add_carry        <= sub_result(16);
         
               when VCALC_VABS =>
                  if (signed(VectorValue1) < 0) then
                     acc(15 downto 0) <= -signed(VectorValue2);
                     if (VectorValue2 = x"8000") then
                        outputSelect     <= CLAMP_ADDSUB;
                        add_carry        <= '0';
                     end if;
                  elsif (signed(VectorValue1) > 0) then
                     acc(15 downto 0) <= signed(VectorValue2);
                  else
                     acc(15 downto 0) <= (others => '0');
                  end if;
 
               when VCALC_VADDC =>
                  acc(15 downto 0) <= add_result(15 downto 0);
                  vco_lo           <= add_result(16); 
                  vco_hi           <= '0';
                  
               when VCALC_VSUBC =>
                  acc(15 downto 0) <= sub_result(15 downto 0);
                  vco_lo           <= sub_result(16);
                  vco_hi           <= not SubIsZero;
                  
               when VCALC_VSAR => null;
                  
               when VCALC_VLT =>  
                  vco_lo         <= '0';
                  vco_hi         <= '0';
                  vcc_hi         <= '0';
                  if (AlesserB = '1' or (AequalB = '1' and vco_lo = '1' and vco_hi = '1')) then 
                     acc(15 downto 0) <= signed(VectorValue1);
                     vcc_lo           <= '1';
                  else
                     acc(15 downto 0) <= signed(VectorValue2);
                     vcc_lo           <= '0';
                  end if;
               
               when VCALC_VEQ =>   
                  vco_lo         <= '0';
                  vco_hi         <= '0';
                  vcc_hi         <= '0';
                  if (vco_hi = '0' and AequalB = '1') then 
                     acc(15 downto 0) <= signed(VectorValue1);
                     vcc_lo           <= '1';
                  else
                     acc(15 downto 0) <= signed(VectorValue2);
                     vcc_lo           <= '0';
                  end if;
               
               when VCALC_VNE => 
                  vco_lo         <= '0';
                  vco_hi         <= '0';
                  vcc_hi         <= '0';
                  if (vco_hi = '1' or AequalB = '0') then 
                     acc(15 downto 0) <= signed(VectorValue1);
                     vcc_lo           <= '1';
                  else
                     acc(15 downto 0) <= signed(VectorValue2);
                     vcc_lo           <= '0';
                  end if;
               
               when VCALC_VGE => 
                  vco_lo         <= '0';
                  vco_hi         <= '0';
                  vcc_hi         <= '0';
                  if (AgreaterB = '1' or (AequalB = '1' and (vco_lo = '0' or vco_hi = '0'))) then 
                     acc(15 downto 0) <= signed(VectorValue1);
                     vcc_lo           <= '1';
                  else
                     acc(15 downto 0) <= signed(VectorValue2);
                     vcc_lo           <= '0';
                  end if;
               
               when VCALC_VCL =>  
                  vco_lo           <= '0';
                  vco_hi           <= '0';
                  vce              <= '0';
                  acc(15 downto 0) <= signed(VectorValue1); -- default, maybe overwritten
                  if (vco_lo = '1') then
                     if (vco_hi = '0') then
                        if (vce = '1') then
                           vcc_lo_calc := AddIsZero or (not add_result(16));
                        else
                           vcc_lo_calc := AddIsZero and (not add_result(16));
                        end if;
                     end if;
                     vcc_lo <= vcc_lo_calc;
                     if (vcc_lo_calc = '1') then
                        acc(15 downto 0) <= -signed(VectorValue2);
                     end if;
                  else
                     if (vco_hi = '0') then
                        vcc_hi_calc := not sub_result(16);
                     end if;
                     vcc_hi <= vcc_hi_calc;
                     if (vcc_hi_calc = '1') then
                        acc(15 downto 0) <= signed(VectorValue2);
                     end if;
                  end if;
               
               when VCALC_VCH => 
                  vco_lo           <= '0';
                  vco_hi           <= '0';
                  vcc_lo           <= '0';
                  vcc_hi           <= '0';
                  vce              <= '0';
                  acc(15 downto 0) <= signed(VectorValue1); -- default, maybe overwritten
                  if (xor_result(15) = '1') then
                     if (add_result(16) = '1' or AddIsZero = '1') then
                        vcc_lo <= '1';
                        acc(15 downto 0) <= -signed(VectorValue2);
                     end if;
                     vcc_hi <= VectorValue2(15);
                     vco_lo <= '1';
                     vco_hi <= (add_result(16) or (not AddIsZero)) and (not AequalNotB);
                     if (add_result(15 downto 0) = x"FFFF") then
                        vce <= '1';
                     end if;
                  else
                     if (sub_result(16) = '0' or subIsZero = '1') then
                        vcc_hi <= '1';
                        acc(15 downto 0) <= signed(VectorValue2);
                     end if;
                     vcc_lo <= VectorValue2(15);
                     vco_hi <= (not subIsZero) and (not AequalNotB);
                  end if;
               
               when VCALC_VCR => 
                  vco_lo           <= '0';
                  vco_hi           <= '0';
                  vcc_lo           <= '0';
                  vcc_hi           <= '0';
                  vce              <= '0';
                  acc(15 downto 0) <= signed(VectorValue1); -- default, maybe overwritten
                  if (xor_result(15) = '1') then
                     if (add_result(16) = '1' or AddIsZero = '1') then
                        vcc_lo <= '1';
                        acc(15 downto 0) <= signed(value2Not);
                     end if;
                     vcc_hi <= VectorValue2(15);
                  else
                     if (sub_result(16) = '0' or subIsZero = '1') then
                        vcc_hi <= '1';
                        acc(15 downto 0) <= signed(VectorValue2);
                     end if;
                     vcc_lo <= VectorValue2(15);
                  end if;
               
               when VCALC_VMRG => 
                  vco_lo         <= '0';
                  vco_hi         <= '0';
                  if (vcc_lo = '1') then 
                     acc(15 downto 0) <= signed(VectorValue1);
                  else
                     acc(15 downto 0) <= signed(VectorValue2);
                  end if;
                  
               when VCALC_VAND =>
                  acc(15 downto 0)  <= signed(and_result);
               
               when VCALC_VNAND =>
                  acc(15 downto 0)  <= not signed(and_result);
               
               when VCALC_VOR =>

                  acc(15 downto 0)  <= signed(or_result);
               
               when VCALC_VNOR =>
                  acc(15 downto 0)  <= not signed(or_result);
               
               when VCALC_VXOR =>
                  acc(15 downto 0)  <= signed(xor_result);
               
               when VCALC_VNXOR =>
                  acc(15 downto 0)  <= not signed(xor_result);
                  
               when VCALC_VMOV | VCALC_VRCP | VCALC_VRCPL | VCALC_VRCPH | VCALC_VSRQ | VCALC_VSRQL | VCALC_VRSQH =>
                  if (destElement /= V_INDEX) then
                     writebackEna     <= '0';
                  end if;
                  acc(15 downto 0) <= signed(VectorValue2);
                  
               when VCALC_VZERO =>
                  acc(15 downto 0) <= add_result(15 downto 0);
                  
               when others => null;
         
            end case;
         
         end if;
         
      end if; -- clock
   end process;
   
   
--##############################################################
--############################### stage 4
--##############################################################
   
   clamp_signbit <= '1' when (outputSelect = CLAMP_SIGNED) else '0';
   
   process (all)
   begin
      
      case (outputSelect) is
      
         when OUTPUT_ZERO => writebackData <= (others => '0');
         when OUTPUT_ACCL => writebackData <= std_logic_vector(acc_l);
         when OUTPUT_ACCM => writebackData <= std_logic_vector(acc_m);
         when OUTPUT_ACCH => writebackData <= std_logic_vector(acc_h);
         
         when CLAMP_SIGNED | CLAMP_UNSIGNED => 
            if    (acc_h < 0  and acc_h /= x"FFFF") then writebackData <= clamp_signbit & 15X"0";
            elsif (acc_h < 0  and acc_m >= 0)       then writebackData <= clamp_signbit & 15X"0";
            elsif (acc_h >= 0 and acc_h /= 0)       then writebackData <= (not clamp_signbit) & 15X"7FFF";
            elsif (acc_h >= 0 and acc_m < 0)        then writebackData <= (not clamp_signbit) & 15X"7FFF";
            elsif (outputSelect = CLAMP_SIGNED)     then writebackData <= std_logic_vector(acc_m); 
            else                                         writebackData <= std_logic_vector(acc_l); 
            end if;
            
         when CLAMP_VMACU =>
            if    (acc_h < 0)                       then writebackData <= x"0000";
            elsif (acc_h /= 0 or acc_m < 0)         then writebackData <= x"FFFF";
            else                                         writebackData <= std_logic_vector(acc_m); 
            end if;
            
         when CLAMP_MPEG =>
            if (acc(47 downto 17) > 32767) then
               writebackData <= x"7FF0";
            elsif (acc(47 downto 17) < -32768) then
               writebackData <= x"8000";
            else
               writebackData <= std_logic_vector(acc(32 downto 21)) & x"0";
            end if;
            
         when CLAMP_RND =>
            if (acc(47 downto 16) > 16#7FFF#) then
               writebackData <= x"7FFF";
            elsif (acc(47 downto 16) < -32768) then
               writebackData <= x"8000";
            else
               writebackData <= std_logic_vector(acc(31 downto 16));
            end if;
            
         when CLAMP_ADDSUB =>
            if (add_carry = '0' and acc_l(15) = '1') then
               writebackData <= x"7FFF";
            elsif (add_carry = '1' and acc_l(15) = '0') then
               writebackData <= x"8000";
            else
               writebackData <= std_logic_vector(acc_l);
            end if;
            
      end case;
      
   end process;
   
--##############################################################
--############################### export
--############################################################## 
   
-- synthesis translate_off
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         acc_1 <= acc;
         export_accu <= unsigned(acc_1);
         
         vco_lo_1 <= vco_lo;
         vco_hi_1 <= vco_hi;
         vcc_lo_1 <= vcc_lo;
         vcc_hi_1 <= vcc_hi;
         vce_1    <= vce;
         export_vco_lo <= vco_lo_1;
         export_vco_hi <= vco_hi_1;
         export_vcc_lo <= vcc_lo_1;
         export_vcc_hi <= vcc_hi_1;
         export_vce    <= vce_1;
         
      end if;
   end process;
-- synthesis translate_on

end architecture;





