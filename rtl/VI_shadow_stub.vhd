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
      texrect_count : in unsigned(15 downto 0);
      texrect_valid : in std_logic;
      texrect_x0 : in unsigned(9 downto 0);
      texrect_x1 : in unsigned(9 downto 0);
      texrect_y0 : in unsigned(8 downto 0);
      texrect_y1 : in unsigned(8 downto 0);
      texrect0_valid : in std_logic;
      texrect0_x0 : in unsigned(9 downto 0);
      texrect0_x1 : in unsigned(9 downto 0);
      texrect0_y0 : in unsigned(8 downto 0);
      texrect0_y1 : in unsigned(8 downto 0);
      texrect0_tile : in unsigned(2 downto 0);
      texrect0_flip : in std_logic;
      texrect1_valid : in std_logic;
      texrect1_x0 : in unsigned(9 downto 0);
      texrect1_x1 : in unsigned(9 downto 0);
      texrect1_y0 : in unsigned(8 downto 0);
      texrect1_y1 : in unsigned(8 downto 0);
      texrect1_tile : in unsigned(2 downto 0);
      texrect1_flip : in std_logic;
      texrect2_valid : in std_logic;
      texrect2_x0 : in unsigned(9 downto 0);
      texrect2_x1 : in unsigned(9 downto 0);
      texrect2_y0 : in unsigned(8 downto 0);
      texrect2_y1 : in unsigned(8 downto 0);
      texrect2_tile : in unsigned(2 downto 0);
      texrect2_flip : in std_logic;
      texrect3_valid : in std_logic;
      texrect3_x0 : in unsigned(9 downto 0);
      texrect3_x1 : in unsigned(9 downto 0);
      texrect3_y0 : in unsigned(8 downto 0);
      texrect3_y1 : in unsigned(8 downto 0);
      texrect3_tile : in unsigned(2 downto 0);
      texrect3_flip : in std_logic;
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
      fillrect2_valid : in std_logic;
      fillrect2_x0 : in unsigned(9 downto 0);
      fillrect2_x1 : in unsigned(9 downto 0);
      fillrect2_y0 : in unsigned(8 downto 0);
      fillrect2_y1 : in unsigned(8 downto 0);
      fillrect2_color : in unsigned(23 downto 0);
      fillrect3_valid : in std_logic;
      fillrect3_x0 : in unsigned(9 downto 0);
      fillrect3_x1 : in unsigned(9 downto 0);
      fillrect3_y0 : in unsigned(8 downto 0);
      fillrect3_y1 : in unsigned(8 downto 0);
      fillrect3_color : in unsigned(23 downto 0);
      xpos        : in  unsigned(9 downto 0);
      ypos        : in  unsigned(8 downto 0);
      pixel_out_r : out std_logic_vector(7 downto 0);
      pixel_out_g : out std_logic_vector(7 downto 0);
      pixel_out_b : out std_logic_vector(7 downto 0)
   );
end entity;

architecture arch of VI_shadow_stub is
   function inside_fillrect_2x(
      sample_x   : unsigned(10 downto 0);
      sample_y   : unsigned(9 downto 0);
      rect_valid : std_logic;
      rect_x0    : unsigned(9 downto 0);
      rect_x1    : unsigned(9 downto 0);
      rect_y0    : unsigned(8 downto 0);
      rect_y1    : unsigned(8 downto 0)
   ) return boolean is
      variable rect_x0_2x : unsigned(10 downto 0);
      variable rect_x1_2x : unsigned(10 downto 0);
      variable rect_y0_2x : unsigned(9 downto 0);
      variable rect_y1_2x : unsigned(9 downto 0);
   begin
      if (rect_valid = '0') then
         return false;
      end if;

      rect_x0_2x := resize(rect_x0, 11) sll 1;
      rect_x1_2x := (resize(rect_x1, 11) sll 1) + 1;
      rect_y0_2x := resize(rect_y0, 10) sll 1;
      rect_y1_2x := (resize(rect_y1, 10) sll 1) + 1;

      return (sample_x >= rect_x0_2x) and (sample_x <= rect_x1_2x) and
             (sample_y >= rect_y0_2x) and (sample_y <= rect_y1_2x);
   end function;

   function mul_u8_by_weight(
      component : std_logic_vector(7 downto 0);
      weight    : unsigned(2 downto 0)
   ) return unsigned is
      variable accum : unsigned(9 downto 0);
      variable value : unsigned(9 downto 0);
   begin
      accum := (others => '0');
      value := resize(unsigned(component), 10);

      case weight is
         when "000" =>
            null;
         when "001" =>
            accum := value;
         when "010" =>
            accum := value + value;
         when "011" =>
            accum := value + value + value;
         when "100" =>
            accum := value + value + value + value;
         when others =>
            null;
      end case;

      return accum;
   end function;

   function clamp_u8(
      value : integer
   ) return unsigned is
      variable clipped : integer;
   begin
      if (value < 0) then
         clipped := 0;
      elsif (value > 255) then
         clipped := 255;
      else
         clipped := value;
      end if;

      return to_unsigned(clipped, 8);
   end function;

   function shape_copy_component(
      component : std_logic_vector(7 downto 0);
      sample_x  : unsigned(10 downto 0);
      sample_y  : unsigned(9 downto 0);
      rect_x0   : unsigned(9 downto 0);
      rect_x1   : unsigned(9 downto 0);
      rect_y0   : unsigned(8 downto 0);
      rect_y1   : unsigned(8 downto 0);
      rect_tile : unsigned(2 downto 0);
      rect_flip : std_logic
   ) return unsigned is
      variable value      : integer;
      variable result     : integer;
      variable local_x_2x : integer;
      variable local_y_2x : integer;
      variable major_axis : integer;
      variable minor_axis : integer;
      variable major_span : integer;
      variable minor_span : integer;
      variable phase4     : integer;
      variable lane4      : integer;
      variable strength   : integer;
      variable tile_bias  : integer;
   begin
      value := to_integer(unsigned(component));
      local_x_2x := to_integer(sample_x) - (to_integer(rect_x0) * 2);
      local_y_2x := to_integer(sample_y) - (to_integer(rect_y0) * 2);

      if (rect_flip = '1') then
         major_axis := local_y_2x;
         minor_axis := local_x_2x;
         major_span := (to_integer(rect_y1) - to_integer(rect_y0) + 1) * 2;
         minor_span := (to_integer(rect_x1) - to_integer(rect_x0) + 1) * 2;
      else
         major_axis := local_x_2x;
         minor_axis := local_y_2x;
         major_span := (to_integer(rect_x1) - to_integer(rect_x0) + 1) * 2;
         minor_span := (to_integer(rect_y1) - to_integer(rect_y0) + 1) * 2;
      end if;

      tile_bias := to_integer(rect_tile);
      phase4 := (major_axis + tile_bias) mod 4;
      lane4 := (minor_axis + to_integer(rect_tile(2 downto 1))) mod 4;
      strength := 2 + (to_integer(rect_tile(1 downto 0)) * 2);

      if (phase4 = 0 or phase4 = 3) then
         strength := strength + 2;
      else
         strength := strength + 1;
      end if;

      if (lane4 = 1 or lane4 = 2) then
         strength := strength + 1;
      end if;

      if (major_span <= 4 or minor_span <= 4) then
         strength := strength / 2;
      end if;

      if (strength > 10) then
         strength := 10;
      end if;

      if (value >= 16#80#) then
         result := value + strength;
         if (phase4 = lane4) then
            result := result + 1;
         end if;
      else
         result := value - strength;
         if (phase4 = lane4) then
            result := result - 1;
         end if;
      end if;

      if (phase4 = 2 and lane4 = 0) then
         if (value >= 16#80#) then
            result := result - 2;
         else
            result := result + 2;
         end if;
      end if;

      return resize(clamp_u8(result), 10);
   end function;

   signal checker : std_logic;
begin
   checker <= xpos(0) xor ypos(0);

   process (all)
      variable sample_x : unsigned(10 downto 0);
      variable sample_y : unsigned(9 downto 0);
      variable sample_hit : boolean;
      variable sample_texrect_hit : boolean;
      variable aggregate_hit : boolean;
      variable have_fillrect_slots : boolean;
      variable have_texrect_slots : boolean;
      variable sample_fill_color : unsigned(23 downto 0);
      variable sample_texrect_x0 : unsigned(9 downto 0);
      variable sample_texrect_x1 : unsigned(9 downto 0);
      variable sample_texrect_y0 : unsigned(8 downto 0);
      variable sample_texrect_y1 : unsigned(8 downto 0);
      variable sample_texrect_tile : unsigned(2 downto 0);
      variable sample_texrect_flip : std_logic;
      variable fill_coverage_count : unsigned(2 downto 0);
      variable texrect_coverage_count : unsigned(2 downto 0);
      variable native_weight : unsigned(2 downto 0);
      variable fill_sum_r : unsigned(9 downto 0);
      variable fill_sum_g : unsigned(9 downto 0);
      variable fill_sum_b : unsigned(9 downto 0);
      variable copy_sum_r : unsigned(9 downto 0);
      variable copy_sum_g : unsigned(9 downto 0);
      variable copy_sum_b : unsigned(9 downto 0);
      variable native_mul_r : unsigned(9 downto 0);
      variable native_mul_g : unsigned(9 downto 0);
      variable native_mul_b : unsigned(9 downto 0);
      variable blend_r : unsigned(9 downto 0);
      variable blend_g : unsigned(9 downto 0);
      variable blend_b : unsigned(9 downto 0);
   begin
      pixel_out_r <= pixel_in_r;
      pixel_out_g <= pixel_in_g;
      pixel_out_b <= pixel_in_b;

      if (enable = '1') then
         fill_coverage_count := (others => '0');
         texrect_coverage_count := (others => '0');
         fill_sum_r := (others => '0');
         fill_sum_g := (others => '0');
         fill_sum_b := (others => '0');
         copy_sum_r := (others => '0');
         copy_sum_g := (others => '0');
         copy_sum_b := (others => '0');
         have_fillrect_slots := (fillrect0_valid = '1' or fillrect1_valid = '1' or fillrect2_valid = '1' or fillrect3_valid = '1');
         have_texrect_slots := (texrect0_valid = '1' or texrect1_valid = '1' or texrect2_valid = '1' or texrect3_valid = '1');

         -- Rasterize four 2x subpixels per output pixel. This keeps the current
         -- native timing while making the fill-rectangle subset genuinely
         -- command-driven and internally supersampled. In copy mode, texrect
         -- coverage uses a bounded placeholder enhancement until full texture
         -- fetch/shade replay exists.
         for sy in 0 to 1 loop
            for sx in 0 to 1 loop
               sample_x := (resize(xpos, 11) sll 1) + to_unsigned(sx, 11);
               sample_y := (resize(ypos, 10) sll 1) + to_unsigned(sy, 10);
               sample_hit := false;
               sample_texrect_hit := false;
               sample_fill_color := fill_color;
               sample_texrect_x0 := texrect_x0;
               sample_texrect_x1 := texrect_x1;
               sample_texrect_y0 := texrect_y0;
               sample_texrect_y1 := texrect_y1;
               sample_texrect_tile := (others => '0');
               sample_texrect_flip := '0';

               if (inside_fillrect_2x(sample_x, sample_y, fillrect3_valid, fillrect3_x0, fillrect3_x1, fillrect3_y0, fillrect3_y1)) then
                  sample_hit := true;
                  sample_fill_color := fillrect3_color;
               end if;
               if (inside_fillrect_2x(sample_x, sample_y, fillrect2_valid, fillrect2_x0, fillrect2_x1, fillrect2_y0, fillrect2_y1)) then
                  sample_hit := true;
                  sample_fill_color := fillrect2_color;
               end if;
               if (inside_fillrect_2x(sample_x, sample_y, fillrect1_valid, fillrect1_x0, fillrect1_x1, fillrect1_y0, fillrect1_y1)) then
                  sample_hit := true;
                  sample_fill_color := fillrect1_color;
               end if;
               if (inside_fillrect_2x(sample_x, sample_y, fillrect0_valid, fillrect0_x0, fillrect0_x1, fillrect0_y0, fillrect0_y1)) then
                  sample_hit := true;
                  sample_fill_color := fillrect0_color;
               end if;

               if (inside_fillrect_2x(sample_x, sample_y, texrect3_valid, texrect3_x0, texrect3_x1, texrect3_y0, texrect3_y1)) then
                  sample_texrect_hit := true;
                  sample_texrect_x0 := texrect3_x0;
                  sample_texrect_x1 := texrect3_x1;
                  sample_texrect_y0 := texrect3_y0;
                  sample_texrect_y1 := texrect3_y1;
                  sample_texrect_tile := texrect3_tile;
                  sample_texrect_flip := texrect3_flip;
               end if;
               if (inside_fillrect_2x(sample_x, sample_y, texrect2_valid, texrect2_x0, texrect2_x1, texrect2_y0, texrect2_y1)) then
                  sample_texrect_hit := true;
                  sample_texrect_x0 := texrect2_x0;
                  sample_texrect_x1 := texrect2_x1;
                  sample_texrect_y0 := texrect2_y0;
                  sample_texrect_y1 := texrect2_y1;
                  sample_texrect_tile := texrect2_tile;
                  sample_texrect_flip := texrect2_flip;
               end if;
               if (inside_fillrect_2x(sample_x, sample_y, texrect1_valid, texrect1_x0, texrect1_x1, texrect1_y0, texrect1_y1)) then
                  sample_texrect_hit := true;
                  sample_texrect_x0 := texrect1_x0;
                  sample_texrect_x1 := texrect1_x1;
                  sample_texrect_y0 := texrect1_y0;
                  sample_texrect_y1 := texrect1_y1;
                  sample_texrect_tile := texrect1_tile;
                  sample_texrect_flip := texrect1_flip;
               end if;
               if (inside_fillrect_2x(sample_x, sample_y, texrect0_valid, texrect0_x0, texrect0_x1, texrect0_y0, texrect0_y1)) then
                  sample_texrect_hit := true;
                  sample_texrect_x0 := texrect0_x0;
                  sample_texrect_x1 := texrect0_x1;
                  sample_texrect_y0 := texrect0_y0;
                  sample_texrect_y1 := texrect0_y1;
                  sample_texrect_tile := texrect0_tile;
                  sample_texrect_flip := texrect0_flip;
               end if;

               if (sample_hit = false and have_fillrect_slots = false) then
                  aggregate_hit := inside_fillrect_2x(sample_x, sample_y, fillrect_valid, fillrect_x0, fillrect_x1, fillrect_y0, fillrect_y1);
                  if (fillrect_count /= 0 and aggregate_hit) then
                     sample_hit := true;
                     sample_fill_color := fill_color;
                  end if;
               end if;

               if (sample_texrect_hit = false and have_texrect_slots = false) then
                  aggregate_hit := inside_fillrect_2x(sample_x, sample_y, texrect_valid, texrect_x0, texrect_x1, texrect_y0, texrect_y1);
                  if (texrect_count /= 0 and aggregate_hit) then
                     sample_texrect_hit := true;
                  end if;
               end if;

               if (sample_hit) then
                  fill_coverage_count := fill_coverage_count + 1;
                  fill_sum_r := fill_sum_r + resize(sample_fill_color(23 downto 16), 10);
                  fill_sum_g := fill_sum_g + resize(sample_fill_color(15 downto 8), 10);
                  fill_sum_b := fill_sum_b + resize(sample_fill_color(7 downto 0), 10);
               elsif (shadow_mode = "10" and sample_texrect_hit) then
                  texrect_coverage_count := texrect_coverage_count + 1;
                  copy_sum_r := copy_sum_r + shape_copy_component(pixel_in_r, sample_x, sample_y, sample_texrect_x0, sample_texrect_x1, sample_texrect_y0, sample_texrect_y1, sample_texrect_tile, sample_texrect_flip);
                  copy_sum_g := copy_sum_g + shape_copy_component(pixel_in_g, sample_x, sample_y, sample_texrect_x0, sample_texrect_x1, sample_texrect_y0, sample_texrect_y1, sample_texrect_tile, sample_texrect_flip);
                  copy_sum_b := copy_sum_b + shape_copy_component(pixel_in_b, sample_x, sample_y, sample_texrect_x0, sample_texrect_x1, sample_texrect_y0, sample_texrect_y1, sample_texrect_tile, sample_texrect_flip);
               end if;
            end loop;
         end loop;

         if (fill_coverage_count /= 0) then
            native_weight := to_unsigned(4, 3) - fill_coverage_count;
            native_mul_r := mul_u8_by_weight(pixel_in_r, native_weight);
            native_mul_g := mul_u8_by_weight(pixel_in_g, native_weight);
            native_mul_b := mul_u8_by_weight(pixel_in_b, native_weight);

            blend_r := native_mul_r + fill_sum_r;
            blend_g := native_mul_g + fill_sum_g;
            blend_b := native_mul_b + fill_sum_b;

            pixel_out_r <= std_logic_vector(blend_r(9 downto 2));
            pixel_out_g <= std_logic_vector(blend_g(9 downto 2));
            pixel_out_b <= std_logic_vector(blend_b(9 downto 2));
         elsif (texrect_coverage_count /= 0 and shadow_mode = "10") then
            native_weight := to_unsigned(4, 3) - texrect_coverage_count;
            native_mul_r := mul_u8_by_weight(pixel_in_r, native_weight);
            native_mul_g := mul_u8_by_weight(pixel_in_g, native_weight);
            native_mul_b := mul_u8_by_weight(pixel_in_b, native_weight);

            blend_r := native_mul_r + copy_sum_r;
            blend_g := native_mul_g + copy_sum_g;
            blend_b := native_mul_b + copy_sum_b;

            pixel_out_r <= std_logic_vector(blend_r(9 downto 2));
            pixel_out_g <= std_logic_vector(blend_g(9 downto 2));
            pixel_out_b <= std_logic_vector(blend_b(9 downto 2));
         elsif (shadow_mode = "01" and fillrect_count = 0) then
            pixel_out_g <= '0' & pixel_in_g(7 downto 1);
            pixel_out_b <= pixel_in_b(7 downto 1) & checker;
         end if;
      end if;
   end process;

end architecture;
