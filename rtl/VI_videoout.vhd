library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pVI.all;

entity VI_videoout is
   generic
   (
      use2Xclock                       : in  std_logic;
      VITEST                           : in  std_logic
   );          
   port           
   (           
      clk1x                            : in  std_logic;
      clk2x                            : in  std_logic;
      clkvid                           : in  std_logic;
      ce                               : in  std_logic;
      reset_1x                         : in  std_logic;
      
      error_vi                         : out std_logic;
                  
      ISPAL                            : in  std_logic;
      FIXEDBLANKS                      : in  std_logic;
      CROPVERTICAL                     : in  unsigned(1 downto 0);
      VI_BILINEAROFF                   : in  std_logic;
      VI_DEBLUR                        : in  std_logic;
      VI_GAMMAOFF                      : in  std_logic;
      VI_NOISEOFF                      : in  std_logic;
      VI_DEDITHEROFF                   : in  std_logic;
      VI_DEDITHERFORCE                 : in  std_logic;
      VI_AAOFF                         : in  std_logic;
      VI_DIVOTOFF                      : in  std_logic;
      VI_7BITPERCOLOR                  : in  std_logic;
      VI_DIRECTFBMODE                  : in  std_logic;
                  
      errorEna                         : in  std_logic;
      errorCode                        : in  unsigned(31 downto 0);
                  
      fpscountOn                       : in  std_logic;
      fpscountBCD                      : in  unsigned(7 downto 0);  
      VI_EXPERIMENTAL_ENABLE           : in  std_logic;
      VI_EXPERIMENTAL_MODE             : in  unsigned(1 downto 0);
      VI_EXPERIMENTAL_SIGNATURE        : in  unsigned(15 downto 0);
      VI_EXPERIMENTAL_FALLBACKS        : in  unsigned(15 downto 0);
      VI_EXPERIMENTAL_AUTO_COOLDOWN    : in  unsigned(7 downto 0);
      VI_EXPERIMENTAL_AUTO_UNSTABLE    : in  unsigned(2 downto 0);
      VI_SHADOW_ENABLE                 : in  std_logic;
      VI_SHADOW_MODE                   : in  unsigned(1 downto 0);
      VI_SHADOW_FRAME_STROBE           : in  std_logic;
      VI_SHADOW_UNSUPPORTED_CMDS       : in  unsigned(15 downto 0);
      VI_SHADOW_FILLRECT_COUNT         : in  unsigned(15 downto 0);
      VI_SHADOW_FILL_COLOR             : in  unsigned(23 downto 0);
      VI_SHADOW_FILLRECT_VALID         : in  std_logic;
      VI_SHADOW_FILLRECT_X0            : in  unsigned(9 downto 0);
      VI_SHADOW_FILLRECT_X1            : in  unsigned(9 downto 0);
      VI_SHADOW_FILLRECT_Y0            : in  unsigned(8 downto 0);
      VI_SHADOW_FILLRECT_Y1            : in  unsigned(8 downto 0);
      VI_SHADOW_FILLRECT0_VALID        : in  std_logic;
      VI_SHADOW_FILLRECT0_X0           : in  unsigned(9 downto 0);
      VI_SHADOW_FILLRECT0_X1           : in  unsigned(9 downto 0);
      VI_SHADOW_FILLRECT0_Y0           : in  unsigned(8 downto 0);
      VI_SHADOW_FILLRECT0_Y1           : in  unsigned(8 downto 0);
      VI_SHADOW_FILLRECT0_COLOR        : in  unsigned(23 downto 0);
      VI_SHADOW_FILLRECT1_VALID        : in  std_logic;
      VI_SHADOW_FILLRECT1_X0           : in  unsigned(9 downto 0);
      VI_SHADOW_FILLRECT1_X1           : in  unsigned(9 downto 0);
      VI_SHADOW_FILLRECT1_Y0           : in  unsigned(8 downto 0);
      VI_SHADOW_FILLRECT1_Y1           : in  unsigned(8 downto 0);
      VI_SHADOW_FILLRECT1_COLOR        : in  unsigned(23 downto 0);
      VI_SHADOW_FILLRECT_DROPPED       : in  unsigned(15 downto 0);
                  
      VI_CTRL_TYPE                     : in  unsigned(1 downto 0);
      VI_CTRL_AA_MODE                  : in  unsigned(1 downto 0);
      VI_CTRL_SERRATE                  : in  std_logic;
      VI_CTRL_GAMMA_ENABLE             : in  std_logic;
      VI_CTRL_GAMMA_DITHER_ENABLE      : in  std_logic;
      VI_CTRL_DIVOT_ENABLE             : in  std_logic;
      VI_CTRL_DEDITHER_FILTER_ENABLE   : in  std_logic;
      VI_ORIGIN                        : in  unsigned(23 downto 0);
      VI_WIDTH                         : in  unsigned(11 downto 0);
      VI_X_SCALE_FACTOR                : in  unsigned(11 downto 0);
      VI_X_SCALE_OFFSET                : in  unsigned(11 downto 0);
      VI_Y_SCALE_FACTOR                : in  unsigned(11 downto 0);
      VI_Y_SCALE_OFFSET                : in  unsigned(11 downto 0);
      VI_V_SYNC                        : in  unsigned(9 downto 0);
      VI_H_SYNC_LENGTH                 : in  unsigned(11 downto 0);
      VI_H_VIDEO_START                 : in  unsigned(9 downto 0);
      VI_H_VIDEO_END                   : in  unsigned(9 downto 0);
      VI_V_VIDEO_START                 : in  unsigned(9 downto 0);
      VI_V_VIDEO_END                   : in  unsigned(9 downto 0);
      VI_HSYNC_WIDTH                   : in  unsigned(7 downto 0);
      VI_VSYNC_WIDTH                   : in  unsigned(3 downto 0);
          
      newFrame                         : out std_logic;
      newLine                          : out std_logic;
      VI_CURRENT                       : out unsigned(9 downto 0);
                  
      rdram_request                    : out std_logic := '0';
      rdram_rnw                        : out std_logic := '0'; 
      rdram_address                    : out unsigned(27 downto 0):= (others => '0');
      rdram_burstcount                 : out unsigned(9 downto 0):= (others => '0');
      rdram_granted                    : in  std_logic;
      rdram_done                       : in  std_logic;
      ddr3_DOUT                        : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY                  : in  std_logic;
      
      VIFBfifo_Din                     : out std_logic_vector(87 downto 0);
      VIFBfifo_Wr                      : out std_logic := '0'; 
                  
      sdram_request                    : out std_logic := '0';
      sdram_rnw                        : out std_logic := '0'; 
      sdram_address                    : out unsigned(26 downto 0):= (others => '0');
      sdram_burstcount                 : out unsigned(7 downto 0):= (others => '0');
      sdram_granted                    : in  std_logic;
      sdram_done                       : in  std_logic;
      sdram_dataRead                   : in  std_logic_vector(31 downto 0);
      sdram_valid                      : in  std_logic;
                  
      video_hsync                      : out std_logic := '0';
      video_vsync                      : out std_logic := '0';
      video_hblank                     : out std_logic := '0';
      video_vblank                     : out std_logic := '0';
      video_ce                         : out std_logic;
      video_interlace                  : out std_logic;
      video_r                          : out std_logic_vector(7 downto 0);
      video_g                          : out std_logic_vector(7 downto 0);
      video_b                          : out std_logic_vector(7 downto 0);
      
      video_blockVIFB                  : in  std_logic;
      video_FB_en                      : out std_logic;
      video_FB_base                    : out unsigned(31 downto 0);
      video_FB_sizeX                   : out unsigned(9 downto 0);
      video_FB_sizeY                   : out unsigned(9 downto 0);
                  
      SS_VI_CURRENT                    : in unsigned(9 downto 0);
      SS_nextHCount                    : in unsigned(11 downto 0)
   );
end entity;

architecture arch of VI_videoout is

   function to_unsigned(a : string) return unsigned is
      variable ret : unsigned(a'length*8-1 downto 0);
   begin
      for i in 1 to a'length loop
         ret((a'length - i)*8+7 downto (a'length - i)*8) := to_unsigned(character'pos(a(i)), 8);
      end loop;
      return ret;
   end function to_unsigned;
   
   function conv_number(a : unsigned) return unsigned is
      variable ret : unsigned((a'length * 2) -1 downto 0);
   begin
      for i in 0 to (a'length / 4)-1 loop
         if (a(((i * 4) + 3) downto (i * 4)) < 10) then
            ret(((i * 8) + 7) downto (i * 8)) := resize(a(((i * 4) + 3) downto (i * 4)), 8) + 16#30#;
         else
            ret(((i * 8) + 7) downto (i * 8)) := resize(a(((i * 4) + 3) downto (i * 4)), 8) + 16#37#;
         end if;
      end loop;
      return ret;
   end function conv_number;

   signal videoout_settings       : tvideoout_settings;
   signal videoout_reports        : tvideoout_reports;
   signal videoout_out            : tvideoout_out;
   signal videoout_mux_out        : tvideoout_out;
   signal videoout_request        : tvideoout_request;  

   -- processing
   signal error_linefetch     : std_logic;
   signal error_outProcess    : std_logic;
   
   signal rdram_storeAddr     : unsigned(8 downto 0);
   signal rdram_store         : std_logic_vector(2 downto 0);   
   
   signal rdram9_storeAddr    : unsigned(5 downto 0);
   signal rdram9_store        : std_logic_vector(2 downto 0);
   
   signal VI_WIDTH_adjust     : unsigned(11 downto 0);
   signal VIFB_frameindex     : unsigned(1 downto 0) := (others => '0');
   signal VIFB_frameLast      : unsigned(1 downto 0) := (others => '0');
   signal addr9_offset        : taddr9offset;
   signal startProc           : std_logic; 
   signal procPtr             : std_logic_vector(2 downto 0);
   signal procDone            : std_logic; 
   signal startOut            : std_logic; 
   signal outprocIdle         : std_logic; 
   signal fracYout            : unsigned(4 downto 0);
   signal FetchLineCount      : unsigned(9 downto 0);
   
   signal fetchAddr           : unsigned(9 downto 0);
   signal fetchAddr9          : unsigned(9 downto 0);
   type tfetchDataArray is array(0 to 2) of std_logic_vector(31 downto 0);
   signal fetchDataArray      : tfetchDataArray;
   signal fetchdata           : tfetchArray;
   type tfetchDataArray9 is array(0 to 2) of std_logic_vector(1 downto 0);
   signal fetchDataArray9     : tfetchDataArray9;
   signal fetchdata9          : tfetchArray9;
                              
   signal proc_pixel          : std_logic;
   signal proc_border         : std_logic;
   signal proc_x              : unsigned(9 downto 0);        
   signal proc_y              : unsigned(9 downto 0);
   signal proc_pixel_Mid      : tfetchelement;
   signal proc_pixels_AA      : tfetcharray_AA;
   signal proc_pixels_DD      : tfetcharray_DD;

   signal filter_pixel        : std_logic;
   signal filter_x_out        : unsigned(9 downto 0);        
   signal filter_y_out        : unsigned(9 downto 0);
   signal filter_color        : tfetchelement;

   signal filterram_addr_A    : std_logic_vector(10 downto 0);
   signal filterram_addr_B    : std_logic_vector(10 downto 0);
   signal filterram_di_A      : std_logic_vector(23 downto 0);
   signal filterram_do_B      : std_logic_vector(23 downto 0);
   
   signal filterAddr          : unsigned(10 downto 0);
   
   signal line_x_min          : unsigned(9 downto 0);
   signal line_x_max          : unsigned(9 downto 0);
   signal line_x_end          : unsigned(9 downto 0);
      
   signal out_pixel           : std_logic;
   signal out_x               : unsigned(9 downto 0);        
   signal out_y               : unsigned(9 downto 0);
   signal out_color           : unsigned(23 downto 0);
   
   signal outram_addr_A       : std_logic_vector(10 downto 0);
   signal outram_addr_B       : std_logic_vector(10 downto 0);
   signal outram_di_A         : std_logic_vector(23 downto 0);
   signal outram_do_B         : std_logic_vector(23 downto 0);
   
   signal videoout_readAddr   : unsigned(10 downto 0);
   
   signal VI_DEBLUR_2xscale   : std_logic;
   
   signal gotFirstFrame       : std_logic := '0';
   
   -- overlay
   signal overlay_xpos        : unsigned(9 downto 0);
   signal overlay_ypos        : unsigned(8 downto 0);
   
   signal overlay_data        : std_logic_vector(23 downto 0);
   signal overlay_ena         : std_logic;
   
   signal fpstext             : unsigned(15 downto 0);
   signal overlay_fps_data    : std_logic_vector(23 downto 0);
   signal overlay_fps_ena     : std_logic;
   
   signal errortext           : unsigned(63 downto 0);
   signal overlay_error_data  : std_logic_vector(23 downto 0);
   signal overlay_error_ena   : std_logic;

   signal vi_exp_modechar     : unsigned(7 downto 0);
   signal vi_exp_text         : unsigned(199 downto 0);
   signal overlay_vi_exp_data : std_logic_vector(23 downto 0);
   signal overlay_vi_exp_ena  : std_logic;

   signal shadow_modechar       : unsigned(7 downto 0);
   signal shadow_enabled_nibble : unsigned(3 downto 0);
   signal shadow_fillrect_valid_nibble : unsigned(3 downto 0);
   signal shadow_text           : unsigned(423 downto 0);
   signal overlay_shadow_data   : std_logic_vector(23 downto 0);
   signal overlay_shadow_ena    : std_logic;

   signal shadow_runtime_enable   : std_logic;
   signal shadow_guard_unsupported: std_logic;
   signal shadow_output_enable    : std_logic;
   signal shadow_stub_r           : std_logic_vector(7 downto 0);
   signal shadow_stub_g           : std_logic_vector(7 downto 0);
   signal shadow_stub_b           : std_logic_vector(7 downto 0);

   signal shadow_frame_count      : unsigned(15 downto 0) := (others => '0');
   signal shadow_divergence_count : unsigned(15 downto 0) := (others => '0');
   signal shadow_last_unsupported : unsigned(15 downto 0) := (others => '0');
   signal shadow_last_fillrect_count : unsigned(15 downto 0) := (others => '0');
   signal shadow_last_fillrect_valid : std_logic := '0';
   signal shadow_last_fillrect_dropped : unsigned(15 downto 0) := (others => '0');
   signal shadow_fallback_count   : unsigned(7 downto 0) := (others => '0');
   signal shadow_fallback_reason  : unsigned(3 downto 0) := (others => '0');
   signal shadow_no_strobe_frames : unsigned(7 downto 0) := (others => '0');
   signal shadow_overflow_streak  : unsigned(7 downto 0) := (others => '0');
   
begin 

   error_vi             <= error_outProcess or error_linefetch;
  
   video_hsync          <= videoout_mux_out.hsync;         
   video_vsync          <= videoout_mux_out.vsync;         
   video_hblank         <= videoout_mux_out.hblank;        
   video_vblank         <= videoout_mux_out.vblank;        
   video_ce             <= videoout_mux_out.ce;             
   video_interlace      <= videoout_mux_out.interlace;             
   video_r              <= videoout_mux_out.r(7 downto 1) & '0' when (VI_7BITPERCOLOR = '1') else videoout_mux_out.r;             
   video_g              <= videoout_mux_out.g(7 downto 1) & '0' when (VI_7BITPERCOLOR = '1') else videoout_mux_out.g;             
   video_b              <= videoout_mux_out.b(7 downto 1) & '0' when (VI_7BITPERCOLOR = '1') else videoout_mux_out.b;  

   videoout_settings.CTRL_TYPE         <= VI_CTRL_TYPE;
   videoout_settings.CTRL_SERRATE      <= VI_CTRL_SERRATE;
   videoout_settings.isPAL             <= ISPAL;
   videoout_settings.VI_DIRECTFBMODE   <= VI_DIRECTFBMODE and gotFirstFrame;
   videoout_settings.fixedBlanks       <= FIXEDBLANKS or not gotFirstFrame;
   videoout_settings.CROPVERTICAL      <= CROPVERTICAL;
   videoout_settings.videoSizeY        <= VI_V_VIDEO_END - VI_V_VIDEO_START - to_integer(CROPVERTICAL & "0000");
   videoout_settings.VI_V_SYNC         <= VI_V_SYNC;
   videoout_settings.VI_H_SYNC_LENGTH  <= VI_H_SYNC_LENGTH;
   videoout_settings.VI_H_VIDEO_START  <= VI_H_VIDEO_START;
   videoout_settings.VI_H_VIDEO_END    <= VI_H_VIDEO_END;
   videoout_settings.VI_V_VIDEO_START  <= VI_V_VIDEO_START;
   videoout_settings.VI_V_VIDEO_END    <= VI_V_VIDEO_END;
   videoout_settings.VI_HSYNC_WIDTH    <= VI_HSYNC_WIDTH;
   videoout_settings.VI_VSYNC_WIDTH    <= VI_VSYNC_WIDTH;

   shadow_runtime_enable <= '1' when (VI_SHADOW_ENABLE = '1' and (VI_SHADOW_MODE = "01" or VI_SHADOW_MODE = "10") and shadow_fallback_reason = x"0") else '0';
   shadow_output_enable <= shadow_runtime_enable and gotFirstFrame;
   shadow_guard_unsupported <= '1' when (VI_CTRL_TYPE = "00" or VI_WIDTH = 0) else '0';

   process (all)
   begin
      videoout_mux_out <= videoout_out;
      if (shadow_output_enable = '1') then
         -- Phase 5 scaffold: preserve native timing, swap in an obvious shadow stub RGB path.
         videoout_mux_out.r <= shadow_stub_r;
         videoout_mux_out.g <= shadow_stub_g;
         videoout_mux_out.b <= shadow_stub_b;
      end if;
   end process;

   iVI_shadow_stub : entity work.VI_shadow_stub
   port map
   (
      enable      => shadow_output_enable,
      shadow_mode => VI_SHADOW_MODE,
      pixel_in_r  => videoout_out.r,
      pixel_in_g  => videoout_out.g,
      pixel_in_b  => videoout_out.b,
      fillrect_count => VI_SHADOW_FILLRECT_COUNT,
      fill_color  => VI_SHADOW_FILL_COLOR,
      fillrect_valid => VI_SHADOW_FILLRECT_VALID,
      fillrect_x0 => VI_SHADOW_FILLRECT_X0,
      fillrect_x1 => VI_SHADOW_FILLRECT_X1,
      fillrect_y0 => VI_SHADOW_FILLRECT_Y0,
      fillrect_y1 => VI_SHADOW_FILLRECT_Y1,
      fillrect0_valid => VI_SHADOW_FILLRECT0_VALID,
      fillrect0_x0 => VI_SHADOW_FILLRECT0_X0,
      fillrect0_x1 => VI_SHADOW_FILLRECT0_X1,
      fillrect0_y0 => VI_SHADOW_FILLRECT0_Y0,
      fillrect0_y1 => VI_SHADOW_FILLRECT0_Y1,
      fillrect0_color => VI_SHADOW_FILLRECT0_COLOR,
      fillrect1_valid => VI_SHADOW_FILLRECT1_VALID,
      fillrect1_x0 => VI_SHADOW_FILLRECT1_X0,
      fillrect1_x1 => VI_SHADOW_FILLRECT1_X1,
      fillrect1_y0 => VI_SHADOW_FILLRECT1_Y0,
      fillrect1_y1 => VI_SHADOW_FILLRECT1_Y1,
      fillrect1_color => VI_SHADOW_FILLRECT1_COLOR,
      xpos        => overlay_xpos,
      ypos        => overlay_ypos,
      pixel_out_r => shadow_stub_r,
      pixel_out_g => shadow_stub_g,
      pixel_out_b => shadow_stub_b
   );
   
   process (clk1x)
      variable shadow_div_next : unsigned(15 downto 0);
   begin
      if rising_edge(clk1x) then

         if (reset_1x = '1') then
            shadow_frame_count      <= (others => '0');
            shadow_divergence_count <= (others => '0');
            shadow_last_unsupported <= (others => '0');
            shadow_last_fillrect_count <= (others => '0');
            shadow_last_fillrect_valid <= '0';
            shadow_last_fillrect_dropped <= (others => '0');
            shadow_fallback_count   <= (others => '0');
            shadow_fallback_reason  <= (others => '0');
            shadow_no_strobe_frames <= (others => '0');
            shadow_overflow_streak  <= (others => '0');
         else
            if (VI_SHADOW_ENABLE = '0' or (VI_SHADOW_MODE /= "01" and VI_SHADOW_MODE /= "10")) then
               -- Manual disable/mode switch clears sticky fallback latch.
               shadow_fallback_reason <= (others => '0');
               shadow_no_strobe_frames <= (others => '0');
               shadow_overflow_streak <= (others => '0');
            elsif (shadow_guard_unsupported = '1' and shadow_fallback_reason = x"0") then
               if (shadow_fallback_count /= x"FF") then
                  shadow_fallback_count <= shadow_fallback_count + 1;
               end if;
               shadow_fallback_reason <= x"1";
            elsif ((error_linefetch = '1' or error_outProcess = '1') and shadow_fallback_reason = x"0") then
               if (shadow_fallback_count /= x"FF") then
                  shadow_fallback_count <= shadow_fallback_count + 1;
               end if;
               shadow_fallback_reason <= x"2";
            end if;

            if (VI_SHADOW_ENABLE = '1' and (VI_SHADOW_MODE = "01" or VI_SHADOW_MODE = "10")) then
               if (VI_SHADOW_FRAME_STROBE = '1') then
                  shadow_no_strobe_frames <= (others => '0');
                  if (VI_SHADOW_FILLRECT_DROPPED /= 0) then
                     if (shadow_overflow_streak /= x"FF") then
                        shadow_overflow_streak <= shadow_overflow_streak + 1;
                     end if;
                     if (shadow_fallback_reason = x"0" and shadow_overflow_streak >= x"07") then
                        if (shadow_fallback_count /= x"FF") then
                           shadow_fallback_count <= shadow_fallback_count + 1;
                        end if;
                        shadow_fallback_reason <= x"5";
                     end if;
                  else
                     shadow_overflow_streak <= (others => '0');
                  end if;
               elsif (videoout_request.newFrame = '1') then
                  if (shadow_no_strobe_frames /= x"FF") then
                     shadow_no_strobe_frames <= shadow_no_strobe_frames + 1;
                  end if;
                  if (shadow_fallback_reason = x"0" and shadow_no_strobe_frames >= x"07") then
                     if (shadow_fallback_count /= x"FF") then
                        shadow_fallback_count <= shadow_fallback_count + 1;
                     end if;
                     shadow_fallback_reason <= x"4";
                  end if;
               end if;
            end if;

            if (VI_SHADOW_FRAME_STROBE = '1' and VI_SHADOW_ENABLE = '1' and (VI_SHADOW_MODE = "01" or VI_SHADOW_MODE = "10") and VI_SHADOW_UNSUPPORTED_CMDS /= 0) then
               shadow_div_next := shadow_divergence_count;
               if (shadow_div_next > x"FFFF" - VI_SHADOW_UNSUPPORTED_CMDS) then
                  shadow_div_next := x"FFFF";
               else
                  shadow_div_next := shadow_div_next + VI_SHADOW_UNSUPPORTED_CMDS;
               end if;
               shadow_divergence_count <= shadow_div_next;
               shadow_last_unsupported <= VI_SHADOW_UNSUPPORTED_CMDS;
               shadow_last_fillrect_count <= VI_SHADOW_FILLRECT_COUNT;
               shadow_last_fillrect_valid <= VI_SHADOW_FILLRECT_VALID;
               shadow_last_fillrect_dropped <= VI_SHADOW_FILLRECT_DROPPED;

               if (shadow_fallback_reason = x"0") then
                  if (shadow_fallback_count /= x"FF") then
                     shadow_fallback_count <= shadow_fallback_count + 1;
                  end if;
                  shadow_fallback_reason <= x"3";
               end if;
            elsif (VI_SHADOW_FRAME_STROBE = '1' and VI_SHADOW_ENABLE = '1' and (VI_SHADOW_MODE = "01" or VI_SHADOW_MODE = "10")) then
               shadow_last_unsupported <= VI_SHADOW_UNSUPPORTED_CMDS;
               shadow_last_fillrect_count <= VI_SHADOW_FILLRECT_COUNT;
               shadow_last_fillrect_valid <= VI_SHADOW_FILLRECT_VALID;
               shadow_last_fillrect_dropped <= VI_SHADOW_FILLRECT_DROPPED;
            end if;
         end if;
      
         VI_WIDTH_adjust <= VI_WIDTH;
         
         if (VI_CTRL_SERRATE = '1' and videoout_settings.VI_DIRECTFBMODE = '1' and VI_WIDTH >= 512 and VI_X_SCALE_FACTOR <= x"200") then
            VI_WIDTH_adjust <= '0' & VI_WIDTH(11 downto 1);
         end if;         
         
         if (VI_CTRL_SERRATE = '1' and videoout_settings.VI_DIRECTFBMODE = '1' and VI_WIDTH >= 1280 and VI_X_SCALE_FACTOR = x"400") then
            VI_WIDTH_adjust <= '0' & VI_WIDTH(11 downto 1);
         end if;
         
         if (newFrame = '1') then
            if (video_blockVIFB = '1') then
               VIFB_frameLast  <= (others => '0');
               VIFB_frameindex <= (others => '0');
            else
               VIFB_frameLast  <= VIFB_frameindex;
               VIFB_frameindex <= VIFB_frameindex + 1;
            end if;
         end if;
         
         if (newFrame = '1') then
            gotFirstFrame <= '1'; -- Used to activate Fixed Blanks or Direct FB mode
         end if;

         if (videoout_request.newFrame = '1' and shadow_runtime_enable = '1') then
            if (shadow_frame_count /= x"FFFF") then
               shadow_frame_count <= shadow_frame_count + 1;
            end if;
         end if;
         
      end if;
   end process;
   
   video_FB_en    <= videoout_settings.VI_DIRECTFBMODE;
   video_FB_base  <= x"31" & "0" & VIFB_frameLast & "0" & x"00000";
   video_FB_sizeX <= VI_WIDTH_adjust(9 downto 0) when (VI_WIDTH_adjust < line_x_end) else line_x_end;
   video_FB_sizeY <= FetchLineCount(8 downto 0) & '0' when (video_blockVIFB = '1') else FetchLineCount;
   
   newFrame   <= videoout_request.newFrame;
   newLine    <= videoout_reports.newLine;
   VI_CURRENT <= videoout_reports.VI_CURRENT & videoout_reports.interlacedDisplayField; -- todo: need to find when interlace sets bit 0, can't be instant, otherwise Kroms CPU tests would hang in infinite loop  
   
   iVI_linefetch : entity work.VI_linefetch
   port map
   (
      clk1x              => clk1x,              
      clk2x              => clk2x,              
      reset              => reset_1x,    

      error_linefetch    => error_linefetch,
      
      VI_DIRECTFBMODE    => videoout_settings.VI_DIRECTFBMODE,
                                        
      VI_CTRL_TYPE       => VI_CTRL_TYPE,     
      VI_CTRL_SERRATE    => VI_CTRL_SERRATE,  
      VI_ORIGIN          => VI_ORIGIN,        
      VI_WIDTH           => VI_WIDTH_adjust,         
      VI_X_SCALE_FACTOR  => VI_X_SCALE_FACTOR,
      VI_Y_SCALE_FACTOR  => VI_Y_SCALE_FACTOR,
      VI_Y_SCALE_OFFSET  => VI_Y_SCALE_OFFSET,
                        
      newFrame           => videoout_request.newFrame,
      fetch              => videoout_request.fetch,
      interlacedField    => videoout_reports.interlacedDisplayField,
      video_blockVIFB    => video_blockVIFB,
      
      addr9_offset       => addr9_offset,
      startProc          => startProc,
      procPtr            => procPtr,
      procDone           => procDone,
      
      outprocIdle        => outprocIdle,
      startOut           => startOut,
      fracYout           => fracYout,
      FetchLineCount     => FetchLineCount,
      
      rdram_request      => rdram_request,   
      rdram_rnw          => rdram_rnw,       
      rdram_address      => rdram_address,   
      rdram_burstcount   => rdram_burstcount,
      rdram_granted      => rdram_granted,   
      rdram_done         => rdram_done,      
      ddr3_DOUT_READY    => ddr3_DOUT_READY, 
      rdram_store        => rdram_store,     
      rdram_storeAddr    => rdram_storeAddr,
      
      sdram_request      => sdram_request,    
      sdram_rnw          => sdram_rnw,        
      sdram_address      => sdram_address,    
      sdram_burstcount   => sdram_burstcount, 
      sdram_granted      => sdram_granted,    
      sdram_done         => sdram_done,       
      sdram_valid        => sdram_valid,      
      rdram9_store       => rdram9_store,     
      rdram9_storeAddr   => rdram9_storeAddr
   );
   
   glinerams: for i in 0 to 2 generate
      signal addr9_corrected : unsigned(9 downto 0);
   begin
      ilineram: entity mem.dpram_dif
      generic map 
      ( 
         addr_width_a  => 9,
         data_width_a  => 64,
         addr_width_b  => 10,
         data_width_b  => 32
      )
      port map
      (
         clock_a     => clk2x,
         address_a   => std_logic_vector(rdram_storeAddr),
         data_a      => ddr3_DOUT,
         wren_a      => (ddr3_DOUT_READY and rdram_store(i)),
         
         clock_b     => clk1x,
         address_b   => std_logic_vector(fetchAddr),
         data_b      => 32x"0",
         wren_b      => '0',
         q_b         => fetchDataArray(i)
      );   
      
      addr9_corrected <= fetchAddr9 + addr9_offset(i);
      
      ilineram9: entity mem.dpram_dif
      generic map 
      ( 
         addr_width_a  => 6,
         data_width_a  => 32,
         addr_width_b  => 10,
         data_width_b  => 2
      )
      port map
      (
         clock_a     => clk1x,
         address_a   => std_logic_vector(rdram9_storeAddr),
         data_a      => sdram_dataRead,
         wren_a      => (sdram_valid and rdram9_store(i)),
         
         clock_b     => clk1x,
         address_b   => std_logic_vector(addr9_corrected),
         data_b      => 2x"0",
         wren_b      => '0',
         q_b         => fetchDataArray9(i)
      );   
   end generate;
   
   fetchdata(0) <= unsigned(fetchDataArray(0)) when (procPtr(2) = '1') else
                   unsigned(fetchDataArray(1)) when (procPtr(0) = '1') else
                   unsigned(fetchDataArray(2));
                 
   fetchdata(1) <= unsigned(fetchDataArray(1)) when (procPtr(2) = '1') else
                   unsigned(fetchDataArray(2)) when (procPtr(0) = '1') else
                   unsigned(fetchDataArray(0));
              
   fetchdata(2) <= unsigned(fetchDataArray(2)) when (procPtr(2) = '1') else
                   unsigned(fetchDataArray(0)) when (procPtr(0) = '1') else
                   unsigned(fetchDataArray(1));
   
   fetchdata9(0) <= unsigned(fetchDataArray9(0)) when (procPtr(2) = '1') else
                    unsigned(fetchDataArray9(1)) when (procPtr(0) = '1') else
                    unsigned(fetchDataArray9(2));
                 
   fetchdata9(1) <= unsigned(fetchDataArray9(1)) when (procPtr(2) = '1') else
                    unsigned(fetchDataArray9(2)) when (procPtr(0) = '1') else
                    unsigned(fetchDataArray9(0));
              
   fetchdata9(2) <= unsigned(fetchDataArray9(2)) when (procPtr(2) = '1') else
                    unsigned(fetchDataArray9(0)) when (procPtr(0) = '1') else
                    unsigned(fetchDataArray9(1));
   
   iVI_lineProcess : entity work.VI_lineProcess
   port map
   (
      clk1x              => clk1x,         
      reset              => reset_1x,         
                         
      VI_DIRECTFBMODE    => videoout_settings.VI_DIRECTFBMODE,
                         
      VI_CTRL_TYPE       => VI_CTRL_TYPE,  
      VI_CTRL_AA_MODE    => VI_CTRL_AA_MODE,  
      VI_WIDTH           => VI_WIDTH_adjust,      
                         
      newFrame           => videoout_request.newFrame,          
      startProc          => startProc,    
      interlacedField    => videoout_reports.interlacedDisplayField,
      procDone           => procDone,     
                         
      fetchAddr          => fetchAddr,     
      fetchdata          => fetchdata,
      fetchAddr9         => fetchAddr9,
      fetchdata9         => fetchdata9,
                         
      proc_pixel         => proc_pixel,    
      proc_border        => proc_border,    
      proc_x             => proc_x,              
      proc_y             => proc_y,        
      proc_pixel_Mid     => proc_pixel_Mid,
      proc_pixels_AA     => proc_pixels_AA,
      proc_pixels_DD     => proc_pixels_DD,
      
      video_blockVIFB    => video_blockVIFB,
      line_x_min         => line_x_min,
      line_x_max         => line_x_max,
      VIFB_frameindex    => VIFB_frameindex,
      VIFBfifo_Din       => VIFBfifo_Din,
      VIFBfifo_Wr        => VIFBfifo_Wr 
   );
   
   iVI_filter: entity work.VI_filter
   port map
   (
      clk1x                            => clk1x, 
      reset                            => reset_1x,
      
      VI_DEDITHEROFF                   => VI_DEDITHEROFF,
      VI_DEDITHERFORCE                 => VI_DEDITHERFORCE,
      VI_AAOFF                         => VI_AAOFF,
      VI_DIVOTOFF                      => VI_DIVOTOFF,
      
      VI_CTRL_AA_MODE                  => VI_CTRL_AA_MODE,
      VI_CTRL_DEDITHER_FILTER_ENABLE   => VI_CTRL_DEDITHER_FILTER_ENABLE,
      VI_CTRL_DIVOT_ENABLE             => VI_CTRL_DIVOT_ENABLE,
                    
      proc_pixel                       => proc_pixel,    
      proc_border                      => proc_border,    
      proc_x                           => proc_x,         
      proc_y                           => proc_y,        
      proc_pixel_Mid                   => proc_pixel_Mid,
      proc_pixels_AA                   => proc_pixels_AA,
      proc_pixels_DD                   => proc_pixels_DD,
                        
      filter_pixel                     => filter_pixel,
      filter_x_out                     => filter_x_out, 
      filter_y_out                     => filter_y_out, 
      filter_color                     => filter_color
   );
   
   filterram_addr_A <= filter_y_out(0) & std_logic_vector(filter_x_out);
   filterram_di_A   <= std_logic_vector(filter_color.r) & std_logic_vector(filter_color.g) & std_logic_vector(filter_color.b);

   ifilterRAM: entity mem.dpram
   generic map 
   ( 
      addr_width  => 11,
      data_width  => 24
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => filterram_addr_A,
      data_a      => filterram_di_A,
      wren_a      => filter_pixel,
      
      clock_b     => clk1x,
      address_b   => filterram_addr_B,
      data_b      => 24x"0",
      wren_b      => '0',
      q_b         => filterram_do_B
   );   
   
   filterram_addr_B <= std_logic_vector(filterAddr);
   
   VI_DEBLUR_2xscale <= '1' when (VI_DEBLUR = '1' and VI_X_SCALE_FACTOR = x"200") else '0';
   
   iVI_outProcess : entity work.VI_outProcess
   port map
   (
      clk1x                         => clk1x,           
      reset                         => reset_1x,        
            
      error_outProcess              => error_outProcess,
            
      ISPAL                         => ISPAL,
      VI_BILINEAROFF                => VI_BILINEAROFF,
      VI_DEBLUR                     => VI_DEBLUR_2xscale,
      VI_GAMMAOFF                   => VI_GAMMAOFF,
      VI_NOISEOFF                   => VI_NOISEOFF,
      VI_CTRL_AA_MODE               => VI_CTRL_AA_MODE,
                              
      VI_CTRL_GAMMA_ENABLE          => VI_CTRL_GAMMA_ENABLE,
      VI_CTRL_GAMMA_DITHER_ENABLE   => VI_CTRL_GAMMA_DITHER_ENABLE,
      VI_H_VIDEO_START              => VI_H_VIDEO_START,
      VI_H_VIDEO_END                => VI_H_VIDEO_END,  
      VI_X_SCALE_FACTOR             => VI_X_SCALE_FACTOR,
      VI_X_SCALE_OFFSET             => VI_X_SCALE_OFFSET,
                                    
      newFrame                      => videoout_request.newFrame,             
      startOut                      => startOut,        
      fracYout                      => fracYout,        
      outprocIdle                   => outprocIdle,        
                                    
      filter_y                      => filter_y_out(0),
      filterAddr                    => filterAddr,      
      filterData                    => unsigned(filterram_do_B),     

      line_x_min                    => line_x_min,
      line_x_max                    => line_x_max,
      line_x_end                    => line_x_end,
                                    
      out_pixel                     => out_pixel,       
      out_x                         => out_x,               
      out_y                         => out_y,           
      out_color                     => out_color       
   );
   
   outram_addr_A <= out_y(0) & std_logic_vector(out_x);
   outram_di_A   <= std_logic_vector(out_color);

   ioutRAM: entity mem.dpram
   generic map 
   ( 
      addr_width  => 11,
      data_width  => 24
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => outram_addr_A,
      data_a      => outram_di_A,
      wren_a      => out_pixel,
      
      clock_b     => clkvid,
      address_b   => outram_addr_B,
      data_b      => 24x"0",
      wren_b      => '0',
      q_b         => outram_do_B
   );   
   
   outram_addr_B <= std_logic_vector(videoout_readAddr); 
   
   ivi_videoout_async : entity work.vi_videoout_async
   generic map
   (
      VITEST           => VITEST
   )
   port map
   (
      clk1x                   => clk1x,
      clkvid                  => clkvid,
      ce_1x                   => ce,   
      reset_1x                => reset_1x,
               
      videoout_settings_1x    => videoout_settings,
      videoout_reports_1x     => videoout_reports,                                                                    
      videoout_request_1x     => videoout_request, 
      videoout_readAddr       => videoout_readAddr,  
      videoout_pixelRead      => outram_do_B,   
   
      overlay_xpos            => overlay_xpos,
      overlay_ypos            => overlay_ypos,
      overlay_data            => overlay_data,
      overlay_ena             => overlay_ena,                     
                   
      videoout_out            => videoout_out,
   
      SS_VI_CURRENT           => SS_VI_CURRENT,
      SS_nextHCount           => SS_nextHCount
   );  
   
   -- texts
   fpstext( 7 downto 0) <= resize(fpscountBCD(3 downto 0), 8) + 16#30#;
   fpstext(15 downto 8) <= resize(fpscountBCD(7 downto 4), 8) + 16#30#;
   
   ioverlayFPS : entity work.VI_overlay generic map (2, 4, 16, x"0000FF")
   port map
   (
      clk                    => clkvid,
      ce                     => videoout_out.ce,
      ena                    => fpscountOn,                    
      i_pixel_out_x          => to_integer(overlay_xpos),
      i_pixel_out_y          => to_integer(overlay_ypos),
      o_pixel_out_data       => overlay_fps_data,
      o_pixel_out_ena        => overlay_fps_ena,
      textstring             => fpstext
   );
   
   errortext( 7 downto  0) <= resize(errorCode( 3 downto  0), 8) + 16#30# when (errorCode( 3 downto  0) < 10) else resize(errorCode( 3 downto  0), 8) + 16#37#;
   errortext(15 downto  8) <= resize(errorCode( 7 downto  4), 8) + 16#30# when (errorCode( 7 downto  4) < 10) else resize(errorCode( 7 downto  4), 8) + 16#37#;
   errortext(23 downto 16) <= resize(errorCode(11 downto  8), 8) + 16#30# when (errorCode(11 downto  8) < 10) else resize(errorCode(11 downto  8), 8) + 16#37#;
   errortext(31 downto 24) <= resize(errorCode(15 downto 12), 8) + 16#30# when (errorCode(15 downto 12) < 10) else resize(errorCode(15 downto 12), 8) + 16#37#;
   errortext(39 downto 32) <= resize(errorCode(19 downto 16), 8) + 16#30# when (errorCode(19 downto 16) < 10) else resize(errorCode(19 downto 16), 8) + 16#37#;
   errortext(47 downto 40) <= resize(errorCode(23 downto 20), 8) + 16#30# when (errorCode(23 downto 20) < 10) else resize(errorCode(23 downto 20), 8) + 16#37#;
   errortext(55 downto 48) <= resize(errorCode(27 downto 24), 8) + 16#30# when (errorCode(27 downto 24) < 10) else resize(errorCode(27 downto 24), 8) + 16#37#;
   errortext(63 downto 56) <= resize(errorCode(31 downto 28), 8) + 16#30# when (errorCode(31 downto 28) < 10) else resize(errorCode(31 downto 28), 8) + 16#37#;
   ioverlayError : entity work.VI_overlay generic map (9, 4, 44, x"0000FF")
   port map
   (
      clk                    => clkvid,
      ce                     => videoout_out.ce,
      ena                    => errorEna,                    
      i_pixel_out_x          => to_integer(overlay_xpos),
      i_pixel_out_y          => to_integer(overlay_ypos),
      o_pixel_out_data       => overlay_error_data,
      o_pixel_out_ena        => overlay_error_ena,
      textstring             => x"45" & errortext
   ); 

   with VI_EXPERIMENTAL_MODE select
      vi_exp_modechar <= x"41" when "01", -- A (auto)
                         x"42" when "10", -- B (force bob)
                         x"57" when "11", -- W (force weave)
                         x"4F" when others; -- O (off)

   vi_exp_text <= to_unsigned("VIX M") &
                  vi_exp_modechar &
                  to_unsigned(" S") &
                  conv_number(VI_EXPERIMENTAL_SIGNATURE) &
                  to_unsigned(" F") &
                  conv_number(VI_EXPERIMENTAL_FALLBACKS) &
                  to_unsigned(" C") &
                  conv_number(VI_EXPERIMENTAL_AUTO_COOLDOWN) &
                  to_unsigned(" U") &
                  conv_number(resize(VI_EXPERIMENTAL_AUTO_UNSTABLE, 4));

   with VI_SHADOW_MODE select
      shadow_modechar <= x"50" when "01", -- P (fill_only profile)
                        x"43" when "10", -- C (fill_copy profile)
                        x"4F" when others; -- O (off)

   shadow_enabled_nibble <= x"1" when (shadow_output_enable = '1') else x"0";
   shadow_fillrect_valid_nibble <= x"1" when (shadow_last_fillrect_valid = '1') else x"0";

   shadow_text <= to_unsigned("VXS M") &
                  shadow_modechar &
                  to_unsigned(" E") &
                  conv_number(shadow_enabled_nibble) &
                  to_unsigned(" P") &
                  conv_number(shadow_frame_count) &
                  to_unsigned(" D") &
                  conv_number(shadow_divergence_count) &
                  to_unsigned(" U") &
                  conv_number(shadow_last_unsupported) &
                  to_unsigned(" Q") &
                  conv_number(shadow_last_fillrect_count) &
                  to_unsigned(" V") &
                  conv_number(shadow_fillrect_valid_nibble) &
                  to_unsigned(" L") &
                  conv_number(shadow_last_fillrect_dropped) &
                  to_unsigned(" W") &
                  conv_number(shadow_no_strobe_frames) &
                  to_unsigned(" F") &
                  conv_number(shadow_fallback_count) &
                  to_unsigned(" R") &
                  conv_number(shadow_fallback_reason);

   ioverlayVIExp : entity work.VI_overlay generic map (25, 4, 26, x"007000")
   port map
   (
      clk                    => clkvid,
      ce                     => videoout_out.ce,
      ena                    => VI_EXPERIMENTAL_ENABLE,
      i_pixel_out_x          => to_integer(overlay_xpos),
      i_pixel_out_y          => to_integer(overlay_ypos),
      o_pixel_out_data       => overlay_vi_exp_data,
      o_pixel_out_ena        => overlay_vi_exp_ena,
      textstring             => vi_exp_text
   );

   ioverlayVIShadow : entity work.VI_overlay generic map (53, 14, 26, x"007070")
   port map
   (
      clk                    => clkvid,
      ce                     => videoout_out.ce,
      ena                    => VI_SHADOW_ENABLE,
      i_pixel_out_x          => to_integer(overlay_xpos),
      i_pixel_out_y          => to_integer(overlay_ypos),
      o_pixel_out_data       => overlay_shadow_data,
      o_pixel_out_ena        => overlay_shadow_ena,
      textstring             => shadow_text
   );
   
   overlay_ena <= overlay_fps_ena or overlay_error_ena or overlay_vi_exp_ena or overlay_shadow_ena;
   
   overlay_data <= overlay_fps_data   when (overlay_fps_ena = '1') else
                   overlay_error_data when (overlay_error_ena = '1') else
                   overlay_vi_exp_data when (overlay_vi_exp_ena = '1') else
                   overlay_shadow_data when (overlay_shadow_ena = '1') else
                   (others => '0');
   
end architecture;
