library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;
use work.pVI.all;
use work.pFunctions.all;

entity vi_videoout_async is
   generic
   (
      VITEST               : in  std_logic
   );
   port 
   (
      clk1x                   : in  std_logic;
      clkvid                  : in  std_logic;
      ce_1x                   : in  std_logic;
      reset_1x                : in  std_logic;
      
      videoout_settings_1x    : in  tvideoout_settings;
      videoout_reports_1x     : out tvideoout_reports;
      videoout_request_1x     : out tvideoout_request := ('0', '0', (others => '0'), 0, (others => '0'));
      
      videoout_readAddr       : out unsigned(10 downto 0) := (others => '0');
      videoout_pixelRead      : in  std_logic_vector(23 downto 0);
      
      overlay_xpos            : out unsigned(9 downto 0);
      overlay_ypos            : out unsigned(8 downto 0);
      overlay_data            : in  std_logic_vector(23 downto 0);
      overlay_ena             : in  std_logic;
         
      videoout_out            : buffer tvideoout_out;
      
      SS_VI_CURRENT           : in unsigned(9 downto 0);
      SS_nextHCount           : in unsigned(11 downto 0)
   );
end entity;

architecture arch of vi_videoout_async is

   constant OFFSET_Y : integer := 1;
   constant OFFSET_X : integer := 6;

   -- clk1x -> clkvid
   signal videoout_settings_s2   : tvideoout_settings;
   signal videoout_settings_s1   : tvideoout_settings;
   signal videoout_settings      : tvideoout_settings;
      
   signal ce_s2                  : std_logic;        
   signal ce_s1                  : std_logic;        
   signal ce                     : std_logic;              
      
   signal reset_s2               : std_logic;        
   signal reset_s1               : std_logic;        
   signal reset                  : std_logic;       
      
   -- clkvid -> clk1x   
   signal videoout_reports_s3    : tvideoout_reports;
   signal videoout_reports_s2    : tvideoout_reports;
   signal videoout_reports_s1    : tvideoout_reports;
   signal videoout_reports       : tvideoout_reports;
      
   signal videoout_request_s3    : tvideoout_request := ('0', '0', (others => '0'), 0, (others => '0'));
   signal videoout_request_s2    : tvideoout_request := ('0', '0', (others => '0'), 0, (others => '0'));
   signal videoout_request_s1    : tvideoout_request := ('0', '0', (others => '0'), 0, (others => '0'));
   signal videoout_request       : tvideoout_request := ('0', '0', (others => '0'), 0, (others => '0'));
   
   -- settings
   signal VIDEO_V_START          : unsigned(8 downto 0);
   signal VIDEO_V_END            : unsigned(8 downto 0);
   signal VIDEO_H_START          : unsigned(9 downto 0);
   signal VIDEO_H_END            : unsigned(9 downto 0);
   
   signal vpos_min               : integer range 0 to 511;
   signal vpos_max               : integer range 0 to 511;   
                  
   signal hpos_min               : integer range 0 to 1023;
   signal hpos_max               : integer range 0 to 1023;
   
   signal v_start_last           : unsigned(8 downto 0) := (others => '0');
   signal yInterlaceOffset       : integer range 0 to 1;
            
   -- timing            
   signal vpos_half              : unsigned(9 downto 0) := (others => '0');
   signal vpos                   : unsigned(8 downto 0);
   signal hpos                   : unsigned(11 downto 0) := (others => '0');
   signal clkdiv                 : unsigned(1 downto 0) := (others => '0');
               
   -- request           
   signal lineIn                 : unsigned(8 downto 0) := (others => '0');
   
   -- data
   signal pixelData_R            : std_logic_vector(7 downto 0) := (others => '0');
   signal pixelData_G            : std_logic_vector(7 downto 0) := (others => '0');
   signal pixelData_B            : std_logic_vector(7 downto 0) := (others => '0');
   
begin 
   
   -- clk1x -> clkvid
   process (clkvid)
   begin
      if rising_edge(clkvid) then
   
         videoout_settings_s2 <= videoout_settings_1x;
         videoout_settings_s1 <= videoout_settings_s2;
         videoout_settings    <= videoout_settings_s1;
         
         ce_s2                <= ce_1x;
         ce_s1                <= ce_s2;
         ce                   <= ce_s1;
         
         reset_s2             <= reset_1x;
         reset_s1             <= reset_s2;
         reset                <= reset_s1; 
   
      end if;
   end process;

   -- clkvid -> clk1x
   process (clk1x)
   begin
      if rising_edge(clk1x) then
   
         videoout_reports_s1  <= videoout_reports;
         videoout_reports_s2  <= videoout_reports_s1;
         videoout_reports_s3  <= videoout_reports_s2;
         videoout_reports_1x  <= videoout_reports_s3;   
         
         videoout_reports_1x.newLine  <= '0';
         if (videoout_reports_s3.newLine = '0' and videoout_reports_s2.newLine = '1') then
            videoout_reports_1x.newLine  <= '1';
         end if;

         videoout_request_s1  <= videoout_request;
         videoout_request_s2  <= videoout_request_s1;
         videoout_request_s3  <= videoout_request_s2;
         videoout_request_1x  <= videoout_request_s3;
         
         videoout_request_1x.newFrame <= '0';
         if (videoout_request_s3.newFrame = '0' and videoout_request_s2.newFrame = '1') then
            videoout_request_1x.newFrame  <= '1';
         end if;         
         
         videoout_request_1x.fetch <= '0';
         if (videoout_request_s3.fetch = '0' and videoout_request_s2.fetch = '1') then
            videoout_request_1x.fetch  <= '1';
         end if;

      end if;
   end process;
   
   videoout_reports.VI_CURRENT <= vpos;
   
   pixelData_B  <= videoout_pixelRead( 7 downto  0);
   pixelData_G  <= videoout_pixelRead(15 downto  8);
   pixelData_R  <= videoout_pixelRead(23 downto 16);
   
   VIDEO_V_START <= videoout_settings.VI_V_VIDEO_START(9 downto 1) + OFFSET_Y;
   VIDEO_V_END   <= videoout_settings.VI_V_VIDEO_END(9 downto 1) + OFFSET_Y;
   VIDEO_H_START <= videoout_settings.VI_H_VIDEO_START + OFFSET_X;
   VIDEO_H_END   <= videoout_settings.VI_H_VIDEO_END + OFFSET_X;
   
   vpos_min <= to_integer(VIDEO_V_START) when (videoout_settings.fixedBlanks = '0') else
               22 + OFFSET_Y when (videoout_settings.isPAL = '1' and videoout_settings.CROPVERTICAL = "00") else
               30 + OFFSET_Y when (videoout_settings.isPAL = '1' and videoout_settings.CROPVERTICAL = "01") else
               34 + OFFSET_Y when (videoout_settings.isPAL = '1' and videoout_settings.CROPVERTICAL = "10") else
               17 + OFFSET_Y when (videoout_settings.isPAL = '0' and videoout_settings.CROPVERTICAL = "00") else
               25 + OFFSET_Y when (videoout_settings.isPAL = '0' and videoout_settings.CROPVERTICAL = "01") else
               29 + OFFSET_Y;-- when (videoout_settings.isPAL = '0' and videoout_settings.CROPVERTICAL = "10")
               
   vpos_max <= to_integer(VIDEO_V_END) when (videoout_settings.fixedBlanks = '0') else
               310 + OFFSET_Y when (videoout_settings.isPAL = '1' and videoout_settings.CROPVERTICAL = "00") else
               302 + OFFSET_Y when (videoout_settings.isPAL = '1' and videoout_settings.CROPVERTICAL = "01") else
               298 + OFFSET_Y when (videoout_settings.isPAL = '1' and videoout_settings.CROPVERTICAL = "10") else
               257 + OFFSET_Y when (videoout_settings.isPAL = '0' and videoout_settings.CROPVERTICAL = "00") else
               249 + OFFSET_Y when (videoout_settings.isPAL = '0' and videoout_settings.CROPVERTICAL = "01") else
               245 + OFFSET_Y;-- when (videoout_settings.isPAL = '0' and videoout_settings.CROPVERTICAL = "10")
               

   hpos_min <= to_integer(VIDEO_H_START) when (videoout_settings.fixedBlanks = '0') else
               128 + OFFSET_X when (videoout_settings.isPAL = '1') else
               108 + OFFSET_X;
               
   hpos_max <= to_integer(VIDEO_H_END) when (videoout_settings.fixedBlanks = '0') else
               768 + OFFSET_X when (videoout_settings.isPAL = '1') else
               748 + OFFSET_X;

   process (clkvid)
   begin
      if rising_edge(clkvid) then
             
         videoout_reports.newLine  <= '0';
         videoout_request.newFrame <= '0';
         videoout_request.fetch    <= '0';
         videoout_out.ce           <= '0';

         if (reset = '1') then

            videoout_out.hsync     <= '1';
            videoout_out.vsync     <= '1';
            videoout_out.hblank    <= '1';
            videoout_out.vblank    <= '1';
            
            videoout_reports.interlacedDisplayField     <= '0';
            hpos                                        <= SS_nextHCount(11 downto 0);
            if (VITEST = '1') then
               vpos_half                                <= (others => '0');
               vpos                                     <= (others => '0');
            else
               vpos_half                                <= SS_VI_CURRENT(9 downto 1) & '0';
               vpos                                     <= SS_VI_CURRENT(9 downto 1);
            end if;
                  
         elsif (ce = '1') then
         
            clkdiv <= clkdiv + 1;
            
            -- timing sync
            videoout_out.vsync <= '0';
            if (vpos_half <= videoout_settings.VI_VSYNC_WIDTH) then
               videoout_out.vsync <= '1';
            end if;            
            
            videoout_out.hsync <= '0';
            if (hpos(11 downto 2) <= "00" & videoout_settings.VI_HSYNC_WIDTH) then
               videoout_out.hsync <= '1';
            end if;
            
            -- timing blanks
            if (hpos = 0) then
               videoout_out.vblank <= '0';
               if (vpos < (vpos_min + yInterlaceOffset) or vpos >= (vpos_max + yInterlaceOffset)) then 
                  videoout_out.vblank <= '1'; 
               end if;
            end if;
            
            yInterlaceOffset <= 0;
            if (videoout_settings.fixedBlanks = '1' and videoout_settings.CTRL_SERRATE = '1' and videoout_settings.VI_V_VIDEO_START(9 downto 1) > v_start_last) then
               yInterlaceOffset <= 1;
            end if;
               
            videoout_out.hblank <= '0';
            if (hpos(11 downto 2) < hpos_min or hpos(11 downto 2) >= hpos_max) then 
               videoout_out.hblank <= '1'; 
            end if;
            
            -- timing h/vpos
            if (hpos >= videoout_settings.VI_H_SYNC_LENGTH) then
               hpos               <= (others => '0');
               clkdiv             <= (others => '0');
               vpos               <= vpos + 1; 
            else
               hpos <= hpos + 1;
            end if;
            
            if (hpos = videoout_settings.VI_H_SYNC_LENGTH or hpos = videoout_settings.VI_H_SYNC_LENGTH(11 downto 1)) then
               if (vpos_half >= videoout_settings.VI_V_SYNC) then
                  vpos_half          <= (others => '0');
                  vpos               <= (others => '0');
                  clkdiv             <= (others => '0');
                  v_start_last       <= videoout_settings.VI_V_VIDEO_START(9 downto 1);
                  if (videoout_settings.CTRL_SERRATE = '1') then 
                     videoout_reports.interlacedDisplayField <= not videoout_reports.interlacedDisplayField;
                  else 
                     videoout_reports.interlacedDisplayField <= '0';
                     hpos                                    <= (others => '0');
                  end if;
               else
                  vpos_half <= vpos_half + 1;
               end if;
            end if;
           
            -- request
            if (hpos = 0) then
               if (vpos <= VIDEO_V_START) then
                  lineIn <= (others => '0');
               else
                  lineIn <= lineIn + 1;
               end if;
            end if;
            
            if (hpos >= 4 and hpos < 8) then

               videoout_reports.newLine <= '1';

               if (vpos = VIDEO_V_START - 3) then
                  videoout_request.newFrame   <= '1'; 
               end if;
            
               if (vpos >= VIDEO_V_START and vpos < VIDEO_V_END) then
                  videoout_request.fetch <= '1';
               end if;
               
            end if;
            
            -- data
            if (clkdiv = 3) then
               videoout_out.ce <= '1';
               
               if (hpos(11 downto 2) >= VIDEO_H_START) then
                  videoout_readAddr     <= videoout_readAddr + 1;
               end if;
               
               if ((videoout_settings.isPAL = '1' and hpos(11 downto 2) >= (128 + OFFSET_X)) or 
                   (videoout_settings.isPAL = '0' and hpos(11 downto 2) >= (108 + OFFSET_X))) then
                  overlay_xpos <= overlay_xpos + 1;
               end if;
            
               if (overlay_ena = '1') then
                  videoout_out.r      <= overlay_data( 7 downto 0);
                  videoout_out.g      <= overlay_data(15 downto 8);
                  videoout_out.b      <= overlay_data(23 downto 16);
               elsif (videoout_settings.CTRL_TYPE(1) = '0' or 
                      hpos(11 downto 2) < VIDEO_H_START or hpos(11 downto 2) >= VIDEO_H_END or 
                      vpos < VIDEO_V_START or vpos >= VIDEO_V_END) then
                  videoout_out.r      <= (others => '0');
                  videoout_out.g      <= (others => '0');
                  videoout_out.b      <= (others => '0');
               else
                  videoout_out.r      <= pixelData_R;
                  videoout_out.g      <= pixelData_G;
                  videoout_out.b      <= pixelData_B;
               end if;
            
            end if;
            
            if (hpos = 1) then
               videoout_readAddr <= lineIn(0) & 10x"00";
               overlay_xpos      <= (others => '0');
            end if; 
            
         
         end if;
      end if;
   end process;
   
   overlay_ypos <= lineIn;
   
   -- timing generation reading
   videoout_out.interlace      <= videoout_reports.interlacedDisplayField;    
   
--##############################################################
--############################### export
--##############################################################
   
   -- synthesis translate_off
   goutput : if 1 = 1 generate
      signal tracecounts4    : integer := 0;
      signal export_x        : integer := 0;
      signal export_y        : integer := 0;
      signal export_hblank_1 : std_logic := '0';
   begin
   
      process
         file outfile      : text;
         variable f_status : FILE_OPEN_STATUS;
         variable line_out : line;
         variable color32  : unsigned(31 downto 0);          
      begin
   
         file_open(f_status, outfile, "R:\\vi_n64_4_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\vi_n64_4_sim.txt", append_mode);

         wait for 100 us;

         while (true) loop
            
            wait until rising_edge(clkvid);
            
            if (videoout_out.vsync = '1') then
               export_y <= 0;
            end if;
            if (videoout_out.hblank = '1') then
               export_x <= 0;
            end if;
            
            export_hblank_1 <= videoout_out.hblank;
            if (videoout_out.vblank = '0' and videoout_out.hblank = '1' and export_hblank_1 = '0') then
               export_y <= export_y + 1;
            end if;
            
            if (videoout_out.ce = '1' and videoout_out.hblank = '0' and videoout_out.vblank = '0') then
               write(line_out, string'(" X ")); 
               write(line_out, to_string_len(export_x, 5));
               write(line_out, string'(" Y ")); 
               write(line_out, to_string_len(export_y, 5));
               write(line_out, string'(" C "));
               color32 := 8x"0" & unsigned(videoout_out.r) & unsigned(videoout_out.g) & unsigned(videoout_out.b);
               write(line_out, to_hstring(color32));
               writeline(outfile, line_out);
               tracecounts4 <= tracecounts4 + 1;
               export_x     <= export_x + 1;
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;

   -- synthesis translate_on  

end architecture;





