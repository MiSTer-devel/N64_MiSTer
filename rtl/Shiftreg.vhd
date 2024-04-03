library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity Shiftreg is
   generic
   (
      USE_BRAM    : std_logic;
      DEPTH       : natural;
      BITS        : natural
   );
   port
   (
      clk         : in std_logic;
      clk_en      : in std_logic;
      data_in     : in std_logic_vector(BITS-1 downto 0);
      data_out    : out std_logic_vector(BITS-1 downto 0)
   );
end entity;

architecture arch of Shiftreg is

begin

   gbram: if USE_BRAM = '1' generate
   begin
      ialtshift_taps : altshift_taps
      generic map 
      (
         number_of_taps    => 1,
         tap_distance      => DEPTH,
         width             => BITS,
         lpm_hint          => "RAM_BLOCK_TYPE=M10K",
         lpm_type          => "altshift_taps"
      )
      port map 
      (
         aclr     => '0',
         clken    => clk_en,
         clock    => clk,
         shiftin  => data_in,
         shiftout => data_out,
         taps     => open
      );   
   end generate;
   
   gmlab: if USE_BRAM = '0' generate
   begin
      ialtshift_taps2 : altshift_taps
      generic map 
      (
         number_of_taps    => 1,
         tap_distance      => DEPTH,
         width             => BITS,
         lpm_hint          => "RAM_BLOCK_TYPE=MLAB",
         lpm_type          => "altshift_taps"
      )
      port map 
      (
         aclr     => '0',
         clken    => clk_en,
         clock    => clk,
         shiftin  => data_in,
         shiftout => data_out,
         taps     => open
      );
   end generate;

end architecture;
