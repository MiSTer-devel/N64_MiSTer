library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity VI_shadow_stub is
   port
   (
      enable      : in  std_logic;
      pixel_in_r  : in  std_logic_vector(7 downto 0);
      pixel_in_g  : in  std_logic_vector(7 downto 0);
      pixel_in_b  : in  std_logic_vector(7 downto 0);
      fillrect_count : in unsigned(15 downto 0);
      fill_color  : in  unsigned(23 downto 0);
      xpos        : in  unsigned(9 downto 0);
      ypos        : in  unsigned(8 downto 0);
      pixel_out_r : out std_logic_vector(7 downto 0);
      pixel_out_g : out std_logic_vector(7 downto 0);
      pixel_out_b : out std_logic_vector(7 downto 0)
   );
end entity;

architecture arch of VI_shadow_stub is
   signal checker : std_logic;
begin
   checker <= xpos(0) xor ypos(0);

   process (all)
      variable mix_r : unsigned(8 downto 0);
      variable mix_g : unsigned(8 downto 0);
      variable mix_b : unsigned(8 downto 0);
   begin
      pixel_out_r <= pixel_in_r;
      pixel_out_g <= pixel_in_g;
      pixel_out_b <= pixel_in_b;

      if (enable = '1') then
         if (fillrect_count /= 0) then
            -- Phase 5 PoC: use real fill command metadata to tint the shadow output.
            mix_r := ('0' & unsigned(pixel_in_r)) + ('0' & fill_color(23 downto 16));
            mix_g := ('0' & unsigned(pixel_in_g)) + ('0' & fill_color(15 downto 8));
            mix_b := ('0' & unsigned(pixel_in_b)) + ('0' & fill_color(7 downto 0));
            pixel_out_r <= std_logic_vector(mix_r(8 downto 1));
            pixel_out_g <= std_logic_vector(mix_g(8 downto 1));
            pixel_out_b <= std_logic_vector(mix_b(8 downto 1));
         else
            pixel_out_g <= '0' & pixel_in_g(7 downto 1);
            pixel_out_b <= pixel_in_b(7 downto 1) & checker;
         end if;
      end if;
   end process;

end architecture;
