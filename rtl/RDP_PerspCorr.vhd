library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;

entity RDP_PerspCorr is
   port 
   (
      clk1x                : in  std_logic;
      trigger              : in  std_logic;
      
      settings_otherModes  : in  tsettings_otherModes;
      
      pipeIn_S             : in  signed(15 downto 0);
      pipeIn_T             : in  signed(15 downto 0);
      pipeInWCarry         : in  std_logic;
      pipeInWShift         : in  integer range 0 to 14 := 0;
      pipeInWNormLow       : in  unsigned(7 downto 0) := (others => '0');
      pipeInWtemppoint     : in  signed(15 downto 0) := (others => '0');
      pipeInWtempslope     : in  unsigned(7 downto 0) := (others => '0');
      
      texture_S_unclamped  : out signed(18 downto 0) := (others => '0');
      texture_T_unclamped  : out signed(18 downto 0) := (others => '0')
   );
end entity;

architecture arch of RDP_PerspCorr is
  
   signal wslopeMul           : signed(17 downto 0);
   signal wslopeResult        : signed(15 downto 0) := (others => '0');
   signal wMulS               : signed(31 downto 0);
   signal wMulT               : signed(31 downto 0);
   signal wShiftedS           : signed(32 downto 0);
   signal wShiftedT           : signed(32 downto 0);
   signal WMask               : signed(31 downto 0) := (others => '0');
   
   signal outBoundSmask       : signed(31 downto 0);
   signal outBoundTmask       : signed(31 downto 0);
   signal outBoundSHi         : std_logic;
   signal outBoundSLo         : std_logic;
   signal outBoundTHi         : std_logic;
   signal outBoundTLo         : std_logic;
  
   -- FFs
   signal pipeIn_S_1          : signed(15 downto 0) := (others => '0');
   signal pipeIn_T_1          : signed(15 downto 0) := (others => '0');
   signal pipeInWShift_1      : integer range 0 to 14 := 0;
   signal pipeInWCarry_1      : std_logic := '0';
  
begin 

   -- perspective correction - input stage
   wslopeMul    <= ('1' & signed(pipeInWtempslope)) * ('0' & signed(pipeInWNormLow));
   
   -- perspective correction - perspective stage
   wMulS <= pipeIn_S_1 * wslopeResult;
   wMulT <= pipeIn_T_1 * wslopeResult;
   
   wShiftedS <= shift_right(wMulS & '0', pipeInWShift_1);
   wShiftedT <= shift_right(wMulT & '0', pipeInWShift_1);
   
   outBoundSmask <= wMulS and WMask;
   outBoundTmask <= wMulT and WMask;
   
   outBoundSHi <= '1' when (outBoundSmask /= WMask and outBoundSmask /= 0 and wShiftedS(29) = '0') else '0';
   outBoundSLo <= '1' when (outBoundSmask /= WMask and outBoundSmask /= 0 and wShiftedS(29) = '1') else '0';
   outBoundTHi <= '1' when (outBoundTmask /= WMask and outBoundTmask /= 0 and wShiftedT(29) = '0') else '0';
   outBoundTLo <= '1' when (outBoundTmask /= WMask and outBoundTmask /= 0 and wShiftedT(29) = '1') else '0';

   process (clk1x)
   begin
      if rising_edge(clk1x) then
   
         if (trigger = '1') then

            -- ######### STAGE_INPUT ############################

            wslopeResult   <= pipeInWtemppoint + to_integer(wslopeMul(17 downto 8));
            pipeIn_S_1     <= pipeIn_S;    
            pipeIn_T_1     <= pipeIn_T;    
            pipeInWShift_1 <= pipeInWShift;
            pipeInWCarry_1 <= pipeInWCarry;
            
            WMask <= x"20000000";
            for i in 0 to 14 loop
               if (pipeInWShift < i) then WMask(i + 14) <= '1'; end if;
            end loop;
            
            -- ######### STAGE_PERSPCOR #########################
            
            if (settings_otherModes.perspTex = '1') then
               texture_S_unclamped <= (pipeInWCarry_1 or outBoundSHi) & outBoundSLo & wShiftedS(16 downto 0);
               texture_T_unclamped <= (pipeInWCarry_1 or outBoundTHi) & outBoundTLo & wShiftedT(16 downto 0);
            else
               texture_S_unclamped <= "00" & pipeIn_S_1(15) & pipeIn_S_1;
               texture_T_unclamped <= "00" & pipeIn_T_1(15) & pipeIn_T_1;
            end if;
         
         end if;
         
      end if;
   end process;
   
end architecture;





