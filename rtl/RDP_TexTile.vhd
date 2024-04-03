library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;

entity RDP_TexTile is
   port 
   (
      clk1x                : in  std_logic;
      trigger              : in  std_logic;
      step2                : in  std_logic;
      mode2                : in  std_logic;
   
      settings_otherModes  : in  tsettings_otherModes;
      
      coordIn              : in  signed(15 downto 0);
      tile_max             : in  unsigned(11 downto 0);
      tile_min             : in  unsigned(11 downto 0);
      tile_clamp           : in  std_logic;
      tile_mirror          : in  std_logic;
      tile_mask            : in  unsigned(3 downto 0);
      tile_shift           : in  unsigned(3 downto 0);
            
      index_out            : out unsigned(9 downto 0) := (others => '0');
      index_out1           : out unsigned(9 downto 0) := (others => '0');
      index_out2           : out unsigned(9 downto 0) := (others => '0');
      index_out3           : out unsigned(9 downto 0) := (others => '0');
      index_outN           : out unsigned(9 downto 0) := (others => '0');
      frac_out             : out unsigned(4 downto 0) := (others => '0')
   );
end entity;

architecture arch of RDP_TexTile is

   signal coord            : signed(15 downto 0);
   signal coord_1          : signed(15 downto 0) := (others => '0');

   signal shifted          : signed(15 downto 0);
            
   signal relative         : signed(15 downto 0);
   
   signal clampMax         : unsigned(9 downto 0);
   signal clamp_index      : unsigned(10 downto 0);
   signal clamp_index1     : unsigned(10 downto 0);
   signal clamp_index2     : unsigned(10 downto 0);
   signal clamp_index3     : unsigned(10 downto 0);
   signal frac             : unsigned(4 downto 0);
         
   signal maskShift        : integer range 0 to 10;
   signal maskShifted      : unsigned(15 downto 0);
   signal mask             : unsigned(9 downto 0);
         
   signal wrap_index       : unsigned(10 downto 0);
   signal wrap_index1      : unsigned(10 downto 0);
   signal wrap_index2      : unsigned(10 downto 0);
   signal wrap_index3      : unsigned(10 downto 0);
   signal wrap             : std_logic;
   signal wrap1            : std_logic;
   signal wrap2            : std_logic;
   signal wrap3            : std_logic;
   signal wrapped_index    : unsigned(9 downto 0);
   signal wrapped_index1   : unsigned(9 downto 0);
   signal wrapped_index2   : unsigned(9 downto 0);
   signal wrapped_index3   : unsigned(9 downto 0);
   
   signal index_calc       : unsigned(9 downto 0) := (others => '0');
   signal index_calc_1     : unsigned(9 downto 0) := (others => '0');
   signal index_calc_2     : unsigned(9 downto 0) := (others => '0');
   signal index_calc_3     : unsigned(9 downto 0) := (others => '0');
   signal index_calc_N     : unsigned(9 downto 0) := (others => '0');
   signal index_calc_N_mux : unsigned(9 downto 0) := (others => '0');
   
   signal index_1          : unsigned(9 downto 0) := (others => '0');
   signal index_1_N        : unsigned(9 downto 0) := (others => '0');
   signal frac_1           : unsigned(4 downto 0) := (others => '0');   
   
   signal index_2          : unsigned(9 downto 0) := (others => '0');
   signal index_2_N        : unsigned(9 downto 0) := (others => '0');
   signal frac_2           : unsigned(4 downto 0) := (others => '0');

begin 

   coord <= coordIn; -- when (mode2 = '0') else coord_1;

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (trigger = '1' or step2 = '1') then
            coord_1 <= coordIn;
         end if;
         
      end if;
   end process;

   shifted <= shift_right(coord, to_integer(tile_shift)) when (tile_shift < 11) else
              coord sll (16 - to_integer(tile_shift));
   
   relative <= shifted - to_integer(tile_min & "000");
   
   
   -- clamp
   clampMax <= tile_max(11 downto 2) - tile_min(11 downto 2);
      
   process (all)
   begin
   
      clamp_index <= unsigned(relative(15 downto 5));
      frac        <= unsigned(relative(4 downto 0));
   
      if (settings_otherModes.cycleType(1) = '0') then -- only in non-copy mode
         if (tile_clamp = '1' or tile_mask = 0) then
            if (to_integer(shifted(15 downto 3)) >= to_integer(tile_max)) then
               clamp_index <= clampMax(clampMax'left) & clampMax;
               frac        <= (others => '0');
            elsif (relative < 0) then
               clamp_index <= (others => '0');
               frac        <= (others => '0');
            end if;
         end if;
      end if;
      
   end process;
   
   clamp_index1 <= clamp_index + 1;
   clamp_index2 <= clamp_index + 2;
   clamp_index3 <= clamp_index + 3;
   
   -- mask
   maskShift   <= 10 when (tile_mask > 10) else to_integer(tile_mask);
   maskShifted <= shift_right(to_unsigned(16#FFFF#, 16), 16 - maskShift);
   mask        <= maskShifted(9 downto 0);
   
   wrap_index    <= clamp_index;
   wrap_index1   <= clamp_index1;
   wrap_index2   <= clamp_index2;
   wrap_index3   <= clamp_index3;
   
   wrap          <= wrap_index(maskShift);
   wrap1         <= wrap_index1(maskShift);
   wrap2         <= wrap_index2(maskShift);
   wrap3         <= wrap_index3(maskShift);
   
   wrapped_index  <= not clamp_index(9 downto 0)  when (wrap  = '1') else clamp_index(9 downto 0);
   wrapped_index1 <= not clamp_index1(9 downto 0) when (wrap1 = '1') else clamp_index1(9 downto 0);
   wrapped_index2 <= not clamp_index2(9 downto 0) when (wrap2 = '1') else clamp_index2(9 downto 0);
   wrapped_index3 <= not clamp_index3(9 downto 0) when (wrap3 = '1') else clamp_index3(9 downto 0);

   process (all)
   begin
            
      index_calc   <= clamp_index(9 downto 0);
      index_calc_1 <= clamp_index1(9 downto 0);
      index_calc_2 <= clamp_index2(9 downto 0);
      index_calc_3 <= clamp_index3(9 downto 0);
      index_calc_N <= clamp_index(9 downto 0) + 1;
      
      if (tile_mask > 0) then
         if (tile_mirror = '1') then
            index_calc  <= wrapped_index  and mask;
            index_calc_1 <= wrapped_index1 and mask;
            index_calc_2 <= wrapped_index2 and mask;
            index_calc_3 <= wrapped_index3 and mask;
            
            index_calc_N <= (wrapped_index + 1) and mask;
            if (wrap = '1') then
               index_calc_N <= (wrapped_index - 1) and mask;
            end if; 
            if (wrap = '1' and ((((wrapped_index and mask) - 1) and mask) = mask)) then index_calc_N <= wrapped_index and mask; end if;
            if (wrap = '0' and ((wrapped_index and mask)       = mask))            then index_calc_N <= wrapped_index and mask; end if;           
         else
            index_calc   <= clamp_index(9 downto 0)  and mask;
            index_calc_1 <= clamp_index1(9 downto 0) and mask;
            index_calc_2 <= clamp_index2(9 downto 0) and mask;
            index_calc_3 <= clamp_index3(9 downto 0) and mask;
            
            index_calc_N <= (clamp_index(9 downto 0) + 1) and mask;
            if (clamp_index = mask) then
               index_calc_N  <= (others => '0');
            end if;
         end if;
      end if;

   end process;
   
   index_calc_N_mux <= index_calc_N when (settings_otherModes.sampleType = '1') else index_calc;
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         if (trigger = '1') then
            frac_1     <= frac;
            index_1    <= index_calc;
            index_out1 <= index_calc_1;
            index_out2 <= index_calc_2;
            index_out3 <= index_calc_3;
            index_1_N  <= index_calc_N_mux;
         end if;
         
         if (step2 = '1') then
            frac_2     <= frac;
            index_2    <= index_calc;
            index_2_N  <= index_calc_N_mux;
         end if;
      
      end if;
   end process;
   
   frac_out   <= frac_2    when (step2 = '1') else frac_1;   
   index_out  <= index_2   when (step2 = '1') else index_1;  
   index_outN <= index_2_N when (step2 = '1') else index_1_N;
   
end architecture;





