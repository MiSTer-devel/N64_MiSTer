library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity VI_shadow_stub is
   port
   (
      enable      : in  std_logic;
      shadow_mode : in  unsigned(1 downto 0);
      pixel_in_r  : in  std_logic_vector(7 downto 0);
      pixel_in_g  : in  std_logic_vector(7 downto 0);
      pixel_in_b  : in  std_logic_vector(7 downto 0);
      fillrect_count : in unsigned(15 downto 0);
      fill_color  : in  unsigned(23 downto 0);
      fillrect_valid : in std_logic;
      fillrect_x0 : in unsigned(9 downto 0);
      fillrect_x1 : in unsigned(9 downto 0);
      fillrect_y0 : in unsigned(8 downto 0);
      fillrect_y1 : in unsigned(8 downto 0);
      fillrect0_valid : in std_logic;
      fillrect0_x0 : in unsigned(9 downto 0);
      fillrect0_x1 : in unsigned(9 downto 0);
      fillrect0_y0 : in unsigned(8 downto 0);
      fillrect0_y1 : in unsigned(8 downto 0);
      fillrect0_color : in unsigned(23 downto 0);
      fillrect1_valid : in std_logic;
      fillrect1_x0 : in unsigned(9 downto 0);
      fillrect1_x1 : in unsigned(9 downto 0);
      fillrect1_y0 : in unsigned(8 downto 0);
      fillrect1_y1 : in unsigned(8 downto 0);
      fillrect1_color : in unsigned(23 downto 0);
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
      variable inside_fillrect : boolean;
      variable inside_fillrect0 : boolean;
      variable inside_fillrect1 : boolean;
      variable use_fill_color : boolean;
      variable selected_fill_color : unsigned(23 downto 0);
   begin
      pixel_out_r <= pixel_in_r;
      pixel_out_g <= pixel_in_g;
      pixel_out_b <= pixel_in_b;

      if (enable = '1') then
         use_fill_color := false;
         selected_fill_color := fill_color;
         inside_fillrect0 :=
            (xpos >= fillrect0_x0) and (xpos <= fillrect0_x1) and
            (ypos >= fillrect0_y0) and (ypos <= fillrect0_y1);
         inside_fillrect1 :=
            (xpos >= fillrect1_x0) and (xpos <= fillrect1_x1) and
            (ypos >= fillrect1_y0) and (ypos <= fillrect1_y1);
         if (fillrect1_valid = '1' and inside_fillrect1) then
            use_fill_color := true;
            selected_fill_color := fillrect1_color;
         end if;
         if (fillrect0_valid = '1' and inside_fillrect0) then
            use_fill_color := true;
            selected_fill_color := fillrect0_color;
         end if;

         -- Fallback to aggregate rectangle metadata when slot list is empty.
         if (use_fill_color = false and fillrect_count /= 0 and fillrect_valid = '1') then
            inside_fillrect :=
               (xpos >= fillrect_x0) and (xpos <= fillrect_x1) and
               (ypos >= fillrect_y0) and (ypos <= fillrect_y1);
            if (inside_fillrect) then
               use_fill_color := true;
               selected_fill_color := fill_color;
            end if;
         end if;

         if (use_fill_color) then
            -- Command-driven regional effect using fill-rectangle metadata.
            mix_r := ('0' & unsigned(pixel_in_r)) + ('0' & selected_fill_color(23 downto 16));
            mix_g := ('0' & unsigned(pixel_in_g)) + ('0' & selected_fill_color(15 downto 8));
            mix_b := ('0' & unsigned(pixel_in_b)) + ('0' & selected_fill_color(7 downto 0));
            pixel_out_r <= std_logic_vector(mix_r(8 downto 1));
            pixel_out_g <= std_logic_vector(mix_g(8 downto 1));
            pixel_out_b <= std_logic_vector(mix_b(8 downto 1));
         elsif (shadow_mode = "01") then
            pixel_out_g <= '0' & pixel_in_g(7 downto 1);
            pixel_out_b <= pixel_in_b(7 downto 1) & checker;
         end if;
      end if;
   end process;

end architecture;
