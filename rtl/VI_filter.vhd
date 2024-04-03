library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;
use work.pVI.all;
use work.pFunctions.all;

entity VI_filter is
   port 
   (
      clk1x                            : in  std_logic;
      reset                            : in  std_logic;
      
      VI_DEDITHEROFF                   : in  std_logic;
      VI_DEDITHERFORCE                 : in  std_logic;
      VI_AAOFF                         : in  std_logic;
      VI_DIVOTOFF                      : in  std_logic;
      
      VI_CTRL_AA_MODE                  : in  unsigned(1 downto 0);
      VI_CTRL_DEDITHER_FILTER_ENABLE   : in  std_logic;
      VI_CTRL_DIVOT_ENABLE             : in  std_logic;
      
      proc_pixel                       : in  std_logic;
      proc_border                      : in  std_logic;
      proc_x                           : in  unsigned(9 downto 0);        
      proc_y                           : in  unsigned(9 downto 0);
      proc_pixel_Mid                   : in  tfetchelement := (others => (others => '0'));
      proc_pixels_AA                   : in  tfetcharray_AA := (others => (others => (others => '0')));
      proc_pixels_DD                   : in  tfetcharray_DD := (others => (others => (others => '0')));
                     
      filter_pixel                     : out std_logic := '0';
      filter_x_out                     : out unsigned(9 downto 0) := (others => '0');        
      filter_y_out                     : out unsigned(9 downto 0) := (others => '0');
      filter_color                     : out tfetchelement := (others => (others => '0'))
   );
end entity;

architecture arch of VI_filter is

   signal mid_color        : tcolor := (others => (others => '0'));
   signal mid_color_1      : tcolor := (others => (others => '0'));

   -- dedither
   type t_dedithercolor is array(0 to 7) of tcolor;
   signal dedithercolor    : t_dedithercolor := (others => (others => (others => '0')));

   type t_deditheradd is array(0 to 2) of integer range -8 to +8;
   signal dedither_add     : t_deditheradd;
   
   type t_dedither_result is array(0 to 2) of integer range -8 to 263;
   signal dedither_result  : t_dedither_result;
   signal dedither_clamp   : t_dedither_result;
   
   signal dedither_out     : tcolor := (others => (others => '0'));
   
   -- Anti Aliasing
   signal penmin           : tcolor := (others => (others => '0'));
   signal penmax           : tcolor := (others => (others => '0'));
   
   signal penmin_1         : tcolor := (others => (others => '0'));
   signal penmax_1         : tcolor := (others => (others => '0'));
   
   type t_pendiff is array(0 to 2) of signed(9 downto 0);   
   signal pendiff          : t_pendiff := (others => (others => '0'));
   
   signal inv_c            : unsigned(2 downto 0);
   
   type tdiff_mul is array(0 to 2) of signed(12 downto 0);      
   signal diff_mul         : tdiff_mul := (others => (others => '0'));
   signal diff_add4        : tdiff_mul := (others => (others => '0'));
   
   signal AA_result        : tcolor := (others => (others => '0'));
   
   -- pipelining
   signal stage0_ena       : std_logic := '0';
   signal stage0_border    : std_logic := '0';
   signal stage0_x         : unsigned(9 downto 0) := (others => '0');        
   signal stage0_y         : unsigned(9 downto 0) := (others => '0');
   signal stage0_Mid       : tfetchelement := (others => (others => '0'));
   
   signal stage1_ena       : std_logic := '0';
   signal stage1_border    : std_logic := '0';
   signal stage1_x         : unsigned(9 downto 0) := (others => '0');        
   signal stage1_y         : unsigned(9 downto 0) := (others => '0');
   signal stage1_Pix       : tfetchelement := (others => (others => '0'));   
   
   signal stage2_ena       : std_logic := '0';
   signal stage2_border    : std_logic := '0';
   signal stage2_x         : unsigned(9 downto 0) := (others => '0');        
   signal stage2_y         : unsigned(9 downto 0) := (others => '0');
   signal stage2_Pix       : tfetchelement := (others => (others => '0'));
   
   signal stage3_ena       : std_logic := '0';
   signal stage3_Pix       : tfetchelement := (others => (others => '0'));
   
begin 

   mid_color(0) <= proc_pixel_Mid.r;
   mid_color(1) <= proc_pixel_Mid.g;
   mid_color(2) <= proc_pixel_Mid.b;   
   
   mid_color_1(0) <= stage0_Mid.r;
   mid_color_1(1) <= stage0_Mid.g;
   mid_color_1(2) <= stage0_Mid.b;

   -- dedither
   process(all)
      variable dither_calc : integer range -8 to +8;
   begin
      
      for i in 0 to 7 loop
         dedithercolor(i)(0) <= proc_pixels_DD(i).r;
         dedithercolor(i)(1) <= proc_pixels_DD(i).g;
         dedithercolor(i)(2) <= proc_pixels_DD(i).b;
      end loop;

      for c in 0 to 2 loop
         dither_calc := 0;
         for i in 0 to 7 loop
            if (dedithercolor(i)(c)(7 downto 3) > mid_color(c)(7 downto 3)) then
               dither_calc := dither_calc + 1;
            elsif (dedithercolor(i)(c)(7 downto 3) < mid_color(c)(7 downto 3)) then
               dither_calc := dither_calc - 1;
            end if;
         end loop;
         dedither_add(c) <= dither_calc;
      end loop;
      
      for c in 0 to 2 loop
         dedither_result(c) <= to_integer(mid_color(c)) + dedither_add(c);
         if (dedither_result(c) > 255) then
            dedither_clamp(c) <= 255;
         else
            dedither_clamp(c) <= dedither_result(c);
         end if;
      end loop;
      
   end process;
   
   -- Anti Aliasing
   iVI_filter_pen : entity work.VI_filter_pen 
   port map
   (
      proc_pixels_AA   => proc_pixels_AA,
      mid_color        => mid_color,
      penmin           => penmin,        
      penmax           => penmax        
   );
   
   process(all)
   begin
      
      for i in 0 to 2 loop
         
         pendiff(i) <= ("00" & signed(penmin_1(i))) + ("00" & signed(penmax_1(i))) - ('0' & signed(mid_color_1(i)) & '0');
         
         diff_mul(i) <= to_signed(to_integer(pendiff(i)) * to_integer(inv_c), 13);
         
         diff_add4(i) <= diff_mul(i) + 4;
         
         AA_result(i) <= mid_color_1(i) + unsigned(diff_add4(i)(10 downto 3));

      end loop;

   end process;
   
   
   
   
   process (clk1x)
      variable color_0 : tcolor;
      variable color_1 : tcolor;
      variable color_2 : tcolor;
      variable median  : tcolor;
   begin
      if rising_edge(clk1x) then
      
         -- stage 0
         stage0_ena     <= proc_pixel;
         stage0_border  <= proc_border;
         stage0_x       <= proc_x;
         stage0_y       <= proc_y;
         stage0_Mid     <= proc_pixel_Mid;
         
         for i in 0 to 2 loop
            dedither_out(i) <= to_unsigned(dedither_clamp(i), 8);
            
            penmin_1(i) <= penmin(i);
            penmax_1(i) <= penmax(i);
         end loop;
             
         inv_c <= to_unsigned(7, 3) - proc_pixel_Mid.c;
         
         -- stage 1
         stage1_ena    <= stage0_ena;
         stage1_border <= stage0_border;
         stage1_x      <= stage0_x;
         stage1_y      <= stage0_y;
         stage1_Pix  <= stage0_Mid;
         if (stage0_Mid.c = 7 and (VI_DEDITHERFORCE = '1' or (VI_CTRL_DEDITHER_FILTER_ENABLE = '1' and VI_DEDITHEROFF = '0'))) then
            stage1_Pix.r <= dedither_out(0);
            stage1_Pix.g <= dedither_out(1);
            stage1_Pix.b <= dedither_out(2);
         elsif (stage0_Mid.c < 7 and VI_CTRL_AA_MODE(1) = '0' and VI_AAOFF = '0') then
            stage1_Pix.r <= AA_result(0);
            stage1_Pix.g <= AA_result(1);
            stage1_Pix.b <= AA_result(2);
         end if;
         
         -- stage 2
         stage2_ena    <= stage1_ena;
         stage2_border <= stage1_border;
         stage2_x      <= stage1_x;     
         stage2_y      <= stage1_y;     
         stage2_Pix    <= stage1_Pix;   
         
         -- stage 3   
         stage3_ena    <= stage2_ena and (not stage2_border);
         stage3_Pix    <= stage2_Pix;   
         
         -- output + divot
         filter_pixel <= stage3_ena;
         filter_x_out <= stage2_x;
         filter_y_out <= stage2_y;
         filter_color <= stage2_Pix;
         if (stage2_border = '1') then
            filter_color <= (others => (others => '0'));
         elsif (VI_CTRL_DIVOT_ENABLE = '1' and VI_DIVOTOFF = '0' and (stage1_Pix.c /= 7 or stage2_Pix.c /= 7 or stage3_Pix.c /= 7)) then
            color_2(0) := stage1_Pix.r;
            color_2(1) := stage1_Pix.g;
            color_2(2) := stage1_Pix.b;
            
            color_1(0) := stage2_Pix.r;
            color_1(1) := stage2_Pix.g;
            color_1(2) := stage2_Pix.b;
            
            color_0(0) := stage3_Pix.r;
            color_0(1) := stage3_Pix.g;
            color_0(2) := stage3_Pix.b;
            
            for i in 0 to 2 loop
            
               median(i) := color_1(i);
               if (color_0(i) < color_1(i)) then
                  if (color_1(i) > color_2(i)) then
                     if (color_0(i) < color_2(i)) then
                        median(i) := color_2(i);
                     else
                        median(i) := color_0(i);
                     end if;
                  end if;
               else
                  if (color_1(i) < color_2(i)) then
                     if (color_0(i) < color_2(i)) then
                        median(i) := color_0(i);
                     else
                        median(i) := color_2(i);
                     end if;
                  end if;
               end if;
                  
            end loop;
            
            filter_color.r <= median(0);
            filter_color.g <= median(1);
            filter_color.b <= median(2);
            
         end if;

      end if;
   end process;

--##############################################################
--############################### export
--##############################################################
   
   -- synthesis translate_off
   goutput : if 1 = 1 generate
      signal tracecounts : integer := 0;
   begin
   
      process
         file outfile      : text;
         variable f_status : FILE_OPEN_STATUS;
         variable line_out : line;
         variable color32  : unsigned(31 downto 0);         
      begin
   
         file_open(f_status, outfile, "R:\\vi_n64_1_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\vi_n64_1_sim.txt", append_mode);

         while (true) loop
            
            wait until rising_edge(clk1x);
            
            if (stage1_ena = '1') then
               write(line_out, string'(" X ")); 
               write(line_out, to_string_len(to_integer(stage1_x), 5));
               write(line_out, string'(" Y ")); 
               write(line_out, to_string_len(to_integer(stage1_y), 5));
               write(line_out, string'(" C "));
               color32 := 5x"0" & stage1_Pix.c & stage1_Pix.r & stage1_Pix.g & stage1_Pix.b;
               write(line_out, to_hstring(color32));
               writeline(outfile, line_out);
               tracecounts <= tracecounts + 1;
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;

   goutput2 : if 1 = 1 generate
      signal tracecounts2 : integer := 0;
   begin
   
      process
         file outfile      : text;
         variable f_status : FILE_OPEN_STATUS;
         variable line_out : line;
         variable color32  : unsigned(31 downto 0);         
      begin
   
         file_open(f_status, outfile, "R:\\vi_n64_2_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\vi_n64_2_sim.txt", append_mode);

         while (true) loop
            
            wait until rising_edge(clk1x);
            
            if (filter_pixel = '1') then
               write(line_out, string'(" X ")); 
               write(line_out, to_string_len(to_integer(filter_x_out), 5));
               write(line_out, string'(" Y ")); 
               write(line_out, to_string_len(to_integer(filter_y_out), 5));
               write(line_out, string'(" C "));
               color32 := 5x"0" & filter_color.c & filter_color.r & filter_color.g & filter_color.b;
               write(line_out, to_hstring(color32));
               writeline(outfile, line_out);
               tracecounts2 <= tracecounts2 + 1;
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput2;

   -- synthesis translate_on  
   
   
end architecture;





