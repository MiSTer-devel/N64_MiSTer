library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;
use work.pVI.all;
use work.pFunctions.all;

entity VI_outProcess is
   port 
   (
      clk1x                         : in  std_logic;
      reset                         : in  std_logic;
            
      error_outProcess              : out std_logic := '0';
                  
      ISPAL                         : in  std_logic;
      VI_BILINEAROFF                : in  std_logic;
      VI_GAMMAOFF                   : in  std_logic;
      VI_NOISEOFF                   : in  std_logic;
      VI_CTRL_GAMMA_DITHER_ENABLE   : in  std_logic;
      VI_CTRL_AA_MODE               : in  unsigned(1 downto 0);
            
      VI_CTRL_GAMMA_ENABLE          : in  std_logic;
      VI_H_VIDEO_START              : in  unsigned(9 downto 0);
      VI_H_VIDEO_END                : in  unsigned(9 downto 0);
      VI_X_SCALE_FACTOR             : in  unsigned(11 downto 0);
      VI_X_SCALE_OFFSET             : in  unsigned(11 downto 0);
                  
      newFrame                      : in  std_logic;
      startOut                      : in  std_logic;
      fracYout                      : in  unsigned(4 downto 0);
      outprocIdle                   : out std_logic;
                  
      filter_y                      : in  std_logic;
      filterAddr                    : out unsigned(10 downto 0) := (others => '0');
      filterData                    : in  unsigned(23 downto 0);
          
      line_x_min                    : out unsigned(9 downto 0) := (others => '0');
      line_x_max                    : out unsigned(9 downto 0) := (others => '0');
      line_x_end                    : out unsigned(9 downto 0) := (others => '0');
          
      out_pixel                     : out std_logic := '0';
      out_x                         : out unsigned(9 downto 0) := (others => '0');        
      out_y                         : out unsigned(9 downto 0) := (others => '0');
      out_color                     : out unsigned(23 downto 0) := (others => '0')
   );
end entity;

architecture arch of VI_outProcess is

   constant GUARD_START_NTSC : integer := 108;
   constant GUARD_START_PAL  : integer := 128;
   constant GUARD_STOP_NTSC  : integer := 748; -- 108+640
   constant GUARD_STOP_PAL   : integer := 768; -- 128+640
   
   signal GUARD_START        : integer range 108 to 128;
   signal GUARD_STOP         : integer range 748 to 768;   
   
   signal H_GUARD_START      : unsigned(9 downto 0) := (others => '0');
   signal H_GUARD_STOP       : unsigned(9 downto 0) := (others => '0'); 

   type tstate is
   (
      IDLE,
      STARTFETCH,
      FETCH0,
      FETCH1,
      FETCH2,
      FETCH3
   );
   signal state         : tstate := IDLE; 
   
   signal dx            : unsigned(9 downto 0) := (others => '0');
   signal fetchLine     : std_logic := '0';
   
   signal fetch_x       : unsigned(9 downto 0) := (others => '0');        
   signal fetch_y       : unsigned(9 downto 0) := (others => '0');
   
   signal x_accu        : unsigned(19 downto 0) := (others => '0');
   
   signal topleft       : tcolor := (others => (others => '0'));
   signal bottomleft    : tcolor := (others => (others => '0'));
   signal topright      : tcolor := (others => (others => '0'));
   signal bottomright   : tcolor := (others => (others => '0'));
   
   signal bi_left       : tcolor := (others => (others => '0'));
   signal bi_right      : tcolor := (others => (others => '0'));
   signal bi_out        : tcolor := (others => (others => '0'));
   signal bi_xfrac      : unsigned(4 downto 0) := (others => '0');
   
   type tbi_signed is array(0 to 2) of signed(8 downto 0);
   type tbi_wide is array(0 to 2) of signed(14 downto 0);
   signal bi_a          : tcolor; 
   signal bi_b          : tcolor; 
   signal bi_frac       : unsigned(4 downto 0);
   signal bi_sub        : tbi_signed;
   signal bi_mul        : tbi_wide;
   signal bi_add        : tbi_wide;
   signal bi_shift      : tbi_signed;
   signal bi_result     : tcolor;
   
   signal bi_start      : std_logic := '0';
   signal bi_start_1    : std_logic := '0';
   signal bi_x          : unsigned(9 downto 0);        
   signal bi_y          : unsigned(9 downto 0);
   signal bi_guard      : std_logic := '0';
   -- synthesis translate_off
   signal bi_clear      : std_logic := '0';
   -- synthesis translate_on
   
   signal lfsr          : unsigned(22 downto 0) := (others => '0');
   
   signal gamma_guard   : std_logic := '0';
   signal gamma_start   : std_logic := '0';
   signal gamma_start_1 : std_logic := '0';
   signal gamma_start_2 : std_logic := '0';
   signal gamma_start_3 : std_logic := '0';
   
   signal x_min         :unsigned(9 downto 0) := (others => '0');
   signal x_max         :unsigned(9 downto 0) := (others => '0');
   
   signal gamma_in      : unsigned(13 downto 0);
   signal gamma_sqrt    : unsigned(7 downto 0);

begin 

   outprocIdle <= '1' when (state = IDLE) else '0';

   GUARD_START <= GUARD_START_PAL when (ISPAL = '1') else GUARD_START_NTSC;
   GUARD_STOP  <= GUARD_STOP_PAL  when (ISPAL = '1') else GUARD_STOP_NTSC;
   
   filterAddr <= fetchLine & (x_accu(19 downto 10) + 2) when (state = FETCH1 or state = FETCH2) else fetchLine & (x_accu(19 downto 10) + 1);
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         lfsr(22 downto 1) <= lfsr(21 downto 0);
         lfsr(0) <= not(lfsr(22) xor lfsr(18));
         
         out_pixel    <= '0';
         bi_start     <= '0';
         gamma_start  <= '0';
         
         error_outProcess <= '0';
         if (state /= IDLE and (newFrame = '1' or startOut = '1')) then
            error_outProcess <= '1';
         end if;
         
         H_GUARD_START <= VI_H_VIDEO_START;
         if (VI_H_VIDEO_START >= GUARD_START) then
            H_GUARD_START <= VI_H_VIDEO_START + 8;
         end if;              

         H_GUARD_STOP <= VI_H_VIDEO_END;
         if (VI_H_VIDEO_END <= GUARD_STOP and VI_H_VIDEO_END >= 7) then
            H_GUARD_STOP <= VI_H_VIDEO_END - 7;
         end if;         
         
         case (state) is
         
            when IDLE =>
               if (newFrame = '1') then
                  fetch_y   <= (others => '0');
               end if;
               if (startOut = '1') then
                  state       <= STARTFETCH;
                  fetch_x     <= (others => '0');    
                  dx          <= VI_H_VIDEO_START;
                  x_accu      <= 8x"0" & VI_X_SCALE_OFFSET;
                  fetchLine   <= not filter_y;
                  line_x_min  <= x_min;
                  line_x_max  <= x_max;
                  x_min       <= (others => '1');
                  x_max       <= (others => '0');
               end if;
               
            when STARTFETCH =>
               state     <= FETCH0;
               fetchLine <= not fetchLine;
         
            when FETCH0 =>
               state       <= FETCH1;
               fetchLine   <= not fetchLine;
               topleft(0)  <= filterData( 7 downto  0);
               topleft(1)  <= filterData(15 downto  8);
               topleft(2)  <= filterData(23 downto 16);
               
               if (bi_guard = '0') then
                  if (x_accu(19 downto 10) < x_min) then x_min <= x_accu(19 downto 10); end if;
                  if (x_accu(19 downto 10) > x_max) then x_max <= x_accu(19 downto 10); end if;
               end if;
               
            when FETCH1 =>
               state          <= FETCH2;
               fetchLine      <= not fetchLine;
               bottomleft(0)  <= filterData( 7 downto  0);
               bottomleft(1)  <= filterData(15 downto  8);
               bottomleft(2)  <= filterData(23 downto 16);
               
            when FETCH2 =>
               state     <= FETCH3;
               fetchLine <= not fetchLine;
               topright(0)  <= filterData( 7 downto  0);
               topright(1)  <= filterData(15 downto  8);
               topright(2)  <= filterData(23 downto 16);
               
               x_accu         <= x_accu + VI_X_SCALE_FACTOR;
               bi_xfrac       <= x_accu(9 downto 5);
               
            when FETCH3 =>
               state          <= FETCH0;
               fetchLine      <= not fetchLine;
               bottomright(0) <= filterData( 7 downto  0);
               bottomright(1) <= filterData(15 downto  8);
               bottomright(2) <= filterData(23 downto 16);

               dx             <= dx + 1;
               fetch_x        <= fetch_x + 1;
               if (fetch_x >= 639) then
                  state      <= IDLE;
                  fetch_y    <= fetch_y + 1;
                  line_x_end <= x_accu(19 downto 10);
               end if;
               
               bi_start       <= '1';
               bi_x           <= fetch_x;
               bi_y           <= fetch_y;
               bi_guard       <= '0';
               if (dx < H_GUARD_START or dx >= H_GUARD_STOP) then
                  bi_guard    <= '1';
               end if;
               -- synthesis translate_off
               bi_clear       <= '0';
               if (dx >= VI_H_VIDEO_END) then
                  bi_clear    <= '1';
               end if;
               -- synthesis translate_on
         
         end case;
            
         if (reset = '1') then
            state <= IDLE;
         end if;
         
         -- bilinear store
         if (state = FETCH3) then
            bi_left <= bi_result;
         end if;
         
         bi_start_1 <= bi_start;
         if (bi_start = '1') then
            bi_right <= bi_result;
         end if;
         
         if (bi_start_1 = '1') then
            bi_out      <= bi_result;
            gamma_start <= '1';
            gamma_guard <= bi_guard;
         end if;
         
         -- gamma
         gamma_start_1 <= gamma_start;
         gamma_start_2 <= gamma_start_1;
         gamma_start_3 <= gamma_start_2;
         
         if (gamma_start = '1') then
            out_x     <= bi_x;
            out_y     <= bi_y;
         end if;
        
         if (gamma_start_1 = '1') then out_color( 7 downto  0) <= gamma_sqrt; end if;
         if (gamma_start_2 = '1') then out_color(15 downto  8) <= gamma_sqrt; end if;
         if (gamma_start_3 = '1') then out_color(23 downto 16) <= gamma_sqrt; end if;
         
         if (gamma_start_3 = '1') then
            out_pixel <= '1';
         end if;
            
         if (VI_GAMMAOFF = '1' or VI_CTRL_GAMMA_ENABLE = '0') then
            out_color <= bi_out(2) & bi_out(1) & bi_out(0);
         end if;
         
         if (VI_CTRL_GAMMA_DITHER_ENABLE = '1' and VI_NOISEOFF = '0') then
            out_color( 0) <= lfsr(0);
            out_color( 8) <= lfsr(1);
            out_color(16) <= lfsr(2);
         end if;
         
         if (gamma_guard = '1' or VI_X_SCALE_FACTOR = 0) then
            out_color <= (others => '0');
         end if;
       
      end if;
   end process;
   
   
   -- bilinear calc
   process (all)
   begin
      
      if (state = FETCH3) then
         bi_a     <= topleft;
         bi_b     <= bottomleft;
         bi_frac  <= fracYout;
      elsif (bi_start = '1') then
         bi_a     <= topright;
         bi_b     <= bottomright;
         bi_frac  <= fracYout;
      else
         bi_a     <= bi_left; 
         bi_b     <= bi_right;
         bi_frac  <= bi_xfrac;
      end if;
      
      if (VI_BILINEAROFF = '1' or VI_CTRL_AA_MODE = "11") then
         bi_frac <= (others => '0');
      end if;
   
      for i in 0 to 2 loop
         bi_sub(i)    <= signed('0' & bi_b(i)) - signed('0' & bi_a(i));
         bi_mul(i)    <= bi_sub(i) * ('0' & signed(bi_frac));
         bi_add(i)    <= bi_mul(i) + 16;
         bi_shift(i)  <= resize(bi_add(i)(14 downto 5), 9);
         bi_result(i) <= resize(unsigned(bi_shift(i)) + bi_a(i), 8); 
      end loop;
      
   end process;
   
   -- gamma sqrt
   gamma_in(13 downto 6) <= bi_out(0) when (gamma_start   = '1') else
                            bi_out(1) when (gamma_start_1 = '1') else
                            bi_out(2);
                            
   gamma_in(5 downto 0) <=  lfsr(5 downto 0) when (VI_CTRL_GAMMA_DITHER_ENABLE = '1' and VI_NOISEOFF = '0') else 6x"0";                     
   
   iVI_sqrt : entity work.VI_sqrt
   port map
   (
      clk        => clk1x,
      start      => gamma_start,
      val_in     => gamma_in,
      val_out    => gamma_sqrt
   );   
   
--##############################################################
--############################### export
--##############################################################
   
   -- synthesis translate_off
   goutput : if 1 = 1 generate
      signal tracecounts3 : integer := 0;
   begin
   
      process
         file outfile      : text;
         variable f_status : FILE_OPEN_STATUS;
         variable line_out : line;
         variable color32  : unsigned(31 downto 0);         
      begin
   
         file_open(f_status, outfile, "R:\\vi_n64_3_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\vi_n64_3_sim.txt", append_mode);

         while (true) loop
            
            wait until rising_edge(clk1x);
            
            if (gamma_start = '1' and bi_clear = '0') then
               write(line_out, string'(" X ")); 
               write(line_out, to_string_len(to_integer(bi_x), 5));
               write(line_out, string'(" Y ")); 
               write(line_out, to_string_len(to_integer(bi_y), 5));
               write(line_out, string'(" C "));
               color32 := 8x"0" & bi_out(2) & bi_out(1) & bi_out(0);
               write(line_out, to_hstring(color32));
               writeline(outfile, line_out);
               tracecounts3 <= tracecounts3 + 1;
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;

   -- synthesis translate_on  
   
end architecture;





