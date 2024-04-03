library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pRDP.all;

entity RDP_command is
   port 
   (
      clk1x                   : in  std_logic;
      reset                   : in  std_logic;
         
      error                   : out std_logic := '0';
      
      cmdfifo_Din             : in  std_logic_vector(63 downto 0);
      cmdfifo_wr              : in  std_logic := '0';
      cmdfifo_nearfull        : out std_logic := '0';
               
      commandReqData          : out std_logic;
               
      poly_done               : in  std_logic;
      writePixelsDone         : in  std_logic;
      settings_poly           : out tsettings_poly := SETTINGSPOLYINIT;
      poly_start              : out std_logic := '0';
      poly_loading_mode       : out std_logic := '0';
      sync_full               : out std_logic := '0';  
      
      -- synthesis translate_off
      export_command_done     : out std_logic := '0'; 
      export_command_data     : out unsigned(63 downto 0); 
      commandIsIdle           : out std_logic;
      -- synthesis translate_on
      
      tile_Command            : out std_logic_vector(2 downto 0) := (others => '0');
      tile_usePipe            : out std_logic := '0';
      tileSettings_WrAddr     : out std_logic_vector(2 downto 0) := (others => '0');
      tileSettings_WrData     : out std_logic_vector(46 downto 0) := (others => '0');
      tileSettings_we         : out std_logic := '0';
      tileSize_WrAddr         : out std_logic_vector(2 downto 0) := (others => '0');
      tileSize_WrData         : out std_logic_vector(47 downto 0) := (others => '0');
      tileSize_we             : out std_logic := '0';
      
      settings_KEYRGB         : out tsettings_KEYRGB := (others => (others => '0'));
      settings_Convert        : out tsettings_Convert := (others => (others => '0'));
      settings_scissor        : out tsettings_scissor := SETTINGSSCISSORINIT;
      settings_Z              : out tsettings_Z := (others => (others => '0'));
      settings_otherModes     : out tsettings_otherModes := SETTINGSOTHERMODESINIT;
      settings_fillcolor      : out tsettings_fillcolor := (others => (others => '0'));
      settings_fogcolor       : out tsettings_fogcolor := (others => (others => '0'));
      settings_blendcolor     : out tsettings_blendcolor := (others => (others => '0'));
      settings_primcolor      : out tsettings_primcolor := (others => (others => '0'));
      settings_envcolor       : out tsettings_envcolor := (others => (others => '0'));
      settings_combineMode    : out tsettings_combineMode := (others => (others => '0'));
      settings_textureImage   : out tsettings_textureImage := (others => (others => '0'));
      settings_Z_base         : out unsigned(24 downto 0) := (others => '0');
      settings_colorImage     : out tsettings_colorImage := (others => (others => '0'));
      settings_loadtype       : out tsettings_loadtype
   );
end entity;

architecture arch of RDP_command is

   type tState is 
   (  
      IDLE, 
      EVALCOMMAND,
      EVALTEXRECTANGLE,
      EVALTEXRECTANGLEFLIP,
      EVALTRIANGLE,
      EVALSHADE,
      EVALTEXTURE,
      EVALZBUFFER,
      WAITRASTER,
      WAITPIXELWRITE
   ); 
   signal state  : tState := IDLE;
   
   signal cmdFifo_count    : unsigned(5 downto 0) := (others => '0');
   signal cmdfifo_Dout     : std_logic_vector(63 downto 0);
   signal cmdfifo_Rd       : std_logic := '0';
   signal cmdfifo_Empty    : std_logic;
   
   signal CommandData      : unsigned(63 downto 0) := (others => '0');
   
   -- EVALTRIANGLE
   signal triCnt  : unsigned(2 downto 0);
   signal shade   : std_logic;             
   signal texture : std_logic;             
   signal zbuffer : std_logic;     

begin 

   iCommandFifo: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 64,
      DATAWIDTH        => 64,
      NEARFULLDISTANCE => 32
   )
   port map
   ( 
      clk      => clk1x,
      reset    => reset,  
      Din      => cmdfifo_Din,     
      Wr       => cmdfifo_wr,      
      Full     => open,    
      NearFull => cmdfifo_nearfull,
      Dout     => cmdfifo_Dout,    
      Rd       => cmdfifo_Rd,      
      Empty    => cmdfifo_Empty   
   );

   cmdfifo_Rd <= not cmdfifo_Empty when (state = EVALCOMMAND) else
                 not cmdfifo_Empty when (state = EVALTEXRECTANGLE) else
                 not cmdfifo_Empty when (state = EVALTEXRECTANGLEFLIP) else
                 not cmdfifo_Empty when (state = EVALTRIANGLE) else
                 not cmdfifo_Empty when (state = EVALSHADE) else
                 not cmdfifo_Empty when (state = EVALTEXTURE) else
                 not cmdfifo_Empty when (state = EVALZBUFFER) else
                 '0';
   
   commandReqData <= cmdfifo_Empty when (state = IDLE) else 
                     cmdfifo_Empty when (state = EVALCOMMAND) else 
                     cmdfifo_Empty when (state = EVALTEXRECTANGLE) else 
                     cmdfifo_Empty when (state = EVALTEXRECTANGLEFLIP) else 
                     cmdfifo_Empty when (state = EVALTRIANGLE) else 
                     cmdfifo_Empty when (state = EVALSHADE) else 
                     cmdfifo_Empty when (state = EVALTEXTURE) else 
                     cmdfifo_Empty when (state = EVALZBUFFER) else 
                     '0';
   
   CommandData <= unsigned(cmdfifo_Dout);

   -- synthesis translate_off
   export_command_done <=  '1' when (state = EVALCOMMAND) else '0';                 
   export_command_data <= CommandData;
   commandIsIdle       <= '1' when (state = IDLE) else '0';
   -- synthesis translate_on
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         error           <= '0';
         poly_start      <= '0';
         sync_full       <= '0';
         tileSettings_we <= '0';
         tileSize_we     <= '0';
         
         if (reset = '1') then
            
            state         <= IDLE;
            cmdFifo_count <= (others => '0');
            
         else
         
            if (cmdfifo_wr = '1' and cmdfifo_Rd = '0') then
               cmdFifo_count <= cmdFifo_count + 1;
            elsif (cmdfifo_wr = '0' and cmdfifo_Rd = '1') then
               cmdFifo_count <= cmdFifo_count - 1;
            end if;
               
            case (state) is
            
               when IDLE =>
                  if (cmdfifo_Empty = '0') then
                     state         <= EVALCOMMAND;
                  end if;                  
               
               when EVALCOMMAND =>
                  state             <= IDLE;
                  settings_poly     <= SETTINGSPOLYINIT;
                  poly_loading_mode <= '0';

                  case (CommandData(61 downto 56)) is
                  
                     when 6x"00" => -- NOP
                        null;                        
                        
                     -- triangle commands
                     when 6x"08" | 6x"09" | 6x"0A" | 6x"0B" | 6x"0C" | 6x"0D" | 6x"0E" | 6x"0F" =>
                        shade                     <= CommandData(58); 
                        texture                   <= CommandData(57); 
                        zbuffer                   <= CommandData(56); 
                        tile_Command              <= std_logic_vector(CommandData(50 downto 48));
                        tile_usePipe              <= '1';
                        state                     <= EVALTRIANGLE;
                        triCnt                    <= (others => '0');
                        settings_poly.lft         <= CommandData(55);
                        settings_poly.maxLODlevel <= CommandData(53 downto 51);
                        settings_poly.tile        <= CommandData(50 downto 48);
                        settings_poly.YL          <= signed(CommandData(45 downto 32));
                        settings_poly.YM          <= signed(CommandData(29 downto 16));
                        settings_poly.YH          <= signed(CommandData(13 downto  0));
                        
                     when 6x"24" | 6x"25" => -- texture rectangle
                        state           <= EVALTEXRECTANGLE;  
                        if (CommandData(56) = '1') then
                           state        <= EVALTEXRECTANGLEFLIP; 
                        end if;
                     
                        tile_Command           <= std_logic_vector(CommandData(26 downto 24));
                        tile_usePipe           <= '1';
                        settings_poly.tile     <= CommandData(26 downto 24);
                        settings_poly.lft      <= '1';
                        settings_poly.YL       <= "00"  & signed(CommandData(43 downto 32));
                        settings_poly.YM       <= "00"  & signed(CommandData(43 downto 32));
                        settings_poly.YH       <= "00"  & signed(CommandData(11 downto  0));     
                        settings_poly.XL       <= 6x"0" & signed(CommandData(23 downto 12)) & 14x"0";
                        settings_poly.XH       <= 6x"0" & signed(CommandData(23 downto 12)) & 14x"0";
                        settings_poly.XM       <= 6x"0" & signed(CommandData(55 downto 44)) & 14x"0";
                        settings_poly.DXLDy    <= (others => '0');
                        settings_poly.DXHDy    <= (others => '0');
                        settings_poly.DXMDy    <= (others => '0');
                        if (settings_otherModes.cycleType >= 2) then
                           settings_poly.YL(1 downto 0) <= "11";
                           settings_poly.YM(1 downto 0) <= "11";
                        end if;
                        
                     when 6x"26" => -- sync load
                        null; -- todo   
                        
                     when 6x"27" => -- sync pipe
                        null; -- todo                       
                        
                     when 6x"28" => -- sync tile
                        null; -- todo                     
                        
                     when 6x"29" => -- sync full
                        sync_full       <= '1'; -- todo
                        
                     when 6x"2A" => -- set key GB
                        settings_KEYRGB.scale_B  <= CommandData( 7 downto  0);
                        settings_KEYRGB.center_B <= CommandData(15 downto  8);
                        settings_KEYRGB.scale_G  <= CommandData(23 downto 16);
                        settings_KEYRGB.center_G <= CommandData(31 downto 24);
                        settings_KEYRGB.width_B  <= CommandData(43 downto 32);
                        settings_KEYRGB.width_G  <= CommandData(55 downto 44);
                        
                     when 6x"2B" => -- set key R
                        settings_KEYRGB.scale_R  <= CommandData( 7 downto  0);
                        settings_KEYRGB.center_R <= CommandData(15 downto  8);
                        settings_KEYRGB.width_R  <= CommandData(27 downto 16);
                        
                     when 6x"2C" => -- set convert
                        settings_Convert.K5 <= signed(CommandData( 8 downto  0));
                        settings_Convert.K4 <= signed(CommandData(17 downto  9));
                        settings_Convert.K3 <= signed(CommandData(26 downto 18));
                        settings_Convert.K2 <= signed(CommandData(35 downto 27));
                        settings_Convert.K1 <= signed(CommandData(44 downto 36));
                        settings_Convert.K0 <= signed(CommandData(53 downto 45));
                  
                     when 6x"2D" => -- set scissor
                        settings_scissor.ScissorXL    <= CommandData(23 downto 12);
                        settings_scissor.ScissorXH    <= CommandData(55 downto 44);
                        settings_scissor.ScissorYL    <= CommandData(11 downto  0);
                        settings_scissor.ScissorYH    <= CommandData(43 downto 32);
                        settings_scissor.ScissorField <= CommandData(25);
                        settings_scissor.ScissorOdd   <= CommandData(24);
                        
                     when 6x"2E" => -- set primitive depth
                        settings_Z.Delta_Z        <= CommandData(15 downto 0);
                        settings_Z.Primitive_Z    <= CommandData(30 downto 16);
                  
                     when 6x"2F" => -- set other modes
                        settings_otherModes.alphaCompare    <= CommandData(0);
                        settings_otherModes.ditherAlpha     <= CommandData(1);
                        settings_otherModes.zSourceSel      <= CommandData(2);
                        settings_otherModes.AntiAlias       <= CommandData(3);
                        settings_otherModes.zCompare        <= CommandData(4);
                        settings_otherModes.zUpdate         <= CommandData(5);
                        settings_otherModes.imageRead       <= CommandData(6);
                        settings_otherModes.colorOnCvg      <= CommandData(7);
                        settings_otherModes.cvgDest         <= CommandData(9 downto 8);
                        settings_otherModes.zMode           <= CommandData(11 downto 10);
                        settings_otherModes.cvgTimesAlpha   <= CommandData(12);
                        settings_otherModes.alphaCvgSelect  <= CommandData(13);
                        settings_otherModes.forceBlend      <= CommandData(14);
                        settings_otherModes.blend_m2b1      <= CommandData(17 downto 16);
                        settings_otherModes.blend_m2b0      <= CommandData(19 downto 18);
                        settings_otherModes.blend_m2a1      <= CommandData(21 downto 20);
                        settings_otherModes.blend_m2a0      <= CommandData(23 downto 22);
                        settings_otherModes.blend_m1b1      <= CommandData(25 downto 24);
                        settings_otherModes.blend_m1b0      <= CommandData(27 downto 26);
                        settings_otherModes.blend_m1a1      <= CommandData(29 downto 28);
                        settings_otherModes.blend_m1a0      <= CommandData(31 downto 30);
                        settings_otherModes.alphaDitherSel  <= CommandData(37 downto 36);
                        settings_otherModes.rgbDitherSel    <= CommandData(39 downto 38);
                        settings_otherModes.key             <= CommandData(40);
                        settings_otherModes.convertOne      <= CommandData(41);
                        settings_otherModes.biLerp1         <= CommandData(42);
                        settings_otherModes.biLerp0         <= CommandData(43);
                        settings_otherModes.midTexel        <= CommandData(44);
                        settings_otherModes.sampleType      <= CommandData(45);
                        settings_otherModes.tlutType        <= CommandData(46);
                        settings_otherModes.enTlut          <= CommandData(47);
                        settings_otherModes.texLod          <= CommandData(48);
                        settings_otherModes.sharpenTex      <= CommandData(49);
                        settings_otherModes.detailTex       <= CommandData(50);
                        settings_otherModes.perspTex        <= CommandData(51);
                        settings_otherModes.cycleType       <= CommandData(53 downto 52);
                        settings_otherModes.atomicPrim      <= CommandData(55);
                     
                     when 6x"30" | 6x"34" => -- load tlut and load tile 
                        poly_start             <= '1';
                        poly_loading_mode      <= '1';
                        state                  <= WAITRASTER;                          
                        tile_Command           <= std_logic_vector(CommandData(26 downto 24));
                        tile_usePipe           <= '0';
                        tileSize_WrAddr        <= std_logic_vector(CommandData(26 downto 24));
                        tileSize_WrData        <= std_logic_vector(CommandData(55 downto 32)) & std_logic_vector(CommandData(23 downto 0));
                        tileSize_we            <= '1'; 
                        if (CommandData(61 downto 56) = 6x"30") then
                           settings_loadtype   <= LOADTYPE_TLUT;
                        else                   
                           settings_loadtype   <= LOADTYPE_TILE;
                        end if;
                        settings_poly.lft             <= '1';
                        settings_poly.YL              <= "00"  & signed(CommandData(11 downto 2)) & "11";
                        settings_poly.YM              <= "00"  & signed(CommandData(11 downto 2)) & "11";
                        settings_poly.YH              <= "00"  & signed(CommandData(43 downto 32));
                        settings_poly.XL              <= 6x"0" & signed(CommandData(23 downto 14)) & 16x"0";
                        settings_poly.XH              <= 6x"0" & signed(CommandData(55 downto 46)) & 16x"0";
                        settings_poly.XM              <= 6x"0" & signed(CommandData(23 downto 14)) & 16x"0";
                        settings_poly.DXLDy           <= (others => '0');
                        settings_poly.DXHDy           <= (others => '0');
                        settings_poly.DXMDy           <= (others => '0');
                        settings_poly.tex_Texture_S   <= '0' & signed(CommandData(55 downto 44)) & 19x"0";
                        settings_poly.tex_Texture_T   <= '0' & signed(CommandData(43 downto 32)) & 19x"0";
                        case (settings_textureImage.tex_size) is
                           when SIZE_4BIT  => settings_poly.tex_DsDx  <= x"02000000";
                           when SIZE_8BIT  => settings_poly.tex_DsDx  <= x"01000000";
                           when SIZE_16BIT => settings_poly.tex_DsDx  <= x"00800000";
                           when SIZE_32BIT => settings_poly.tex_DsDx  <= x"00400000";
                           when others => null;
                        end case;
                        settings_poly.tex_DtDx        <= (others => '0');     
                        settings_poly.tex_DsDe        <= (others => '0');
                        settings_poly.tex_DtDe        <= x"00200000";   
                        settings_poly.tex_DsDy        <= (others => '0');
                        settings_poly.tex_DtDy        <= x"00200000";
                        
                     when 6x"32" => -- set tile size      
                        tileSize_WrAddr        <= std_logic_vector(CommandData(26 downto 24));
                        tileSize_WrData        <= std_logic_vector(CommandData(55 downto 32)) & std_logic_vector(CommandData(23 downto 0));
                        tileSize_we            <= '1'; 
                     
                     when 6x"33" => -- load block  
                        poly_start             <= '1';
                        poly_loading_mode      <= '1';
                        state                  <= WAITRASTER;                         
                        tile_Command           <= std_logic_vector(CommandData(26 downto 24));
                        tile_usePipe           <= '0';
                        tileSize_WrAddr        <= std_logic_vector(CommandData(26 downto 24));
                        tileSize_WrData        <= std_logic_vector(CommandData(55 downto 32)) & std_logic_vector(CommandData(23 downto 0));
                        tileSize_we            <= '1'; 
                        settings_loadtype      <= LOADTYPE_BLOCK;
                        settings_poly.lft             <= '1';
                        settings_poly.YL              <= "00"  & signed(CommandData(41 downto 32)) & "11";
                        settings_poly.YM              <= "00"  & signed(CommandData(41 downto 32)) & "11";
                        settings_poly.YH              <= "00"  & signed(CommandData(41 downto 32)) & "00";
                        settings_poly.XL              <= 4x"0" & signed(CommandData(23 downto 12)) & 16x"0";
                        settings_poly.XH              <= 4x"0" & signed(CommandData(55 downto 44)) & 16x"0";
                        settings_poly.XM              <= 4x"0" & signed(CommandData(23 downto 12)) & 16x"0";
                        settings_poly.DXLDy           <= (others => '0');
                        settings_poly.DXHDy           <= (others => '0');
                        settings_poly.DXMDy           <= (others => '0');
                        settings_poly.tex_Texture_S   <= '0' & signed(CommandData(55 downto 44)) & 19x"0";
                        settings_poly.tex_Texture_T   <= '0' & signed(CommandData(43 downto 32)) & 19x"0";
                        case (settings_textureImage.tex_size) is
                           when SIZE_4BIT  => settings_poly.tex_DsDx  <= x"0080000" & signed(CommandData(11 downto 8));
                           when SIZE_8BIT  => settings_poly.tex_DsDx  <= x"0040000" & signed(CommandData(11 downto 8));
                           when SIZE_16BIT => settings_poly.tex_DsDx  <= x"0020000" & signed(CommandData(11 downto 8));
                           when SIZE_32BIT => settings_poly.tex_DsDx  <= x"0010000" & signed(CommandData(11 downto 8));
                           when others => null;
                        end case;
                        settings_poly.tex_DtDx        <= x"000" & signed(CommandData(11 downto 0)) & x"00";     
                        settings_poly.tex_DsDe        <= (others => '0');
                        settings_poly.tex_DtDe        <= x"00200000";   
                        settings_poly.tex_DsDy        <= (others => '0');
                        settings_poly.tex_DtDy        <= x"00200000";
                     
                     when 6x"35" => -- set tile      
                        tileSettings_WrAddr    <= std_logic_vector(CommandData(26 downto 24));
                        tileSettings_WrData    <= std_logic_vector(CommandData(55 downto 51)) & std_logic_vector(CommandData(49 downto 32)) & std_logic_vector(CommandData(23 downto 0));
                        tileSettings_we        <= '1';                          
                        
                     when 6x"36" => -- fill rectangle
                        poly_start                 <= '1';
                        state                      <= WAITRASTER;
                        tile_Command               <= (others => '0');
                        tile_usePipe               <= '0';
                        settings_poly.lft          <= '1';
                        settings_poly.maxLODlevel  <= (others => '0');
                        settings_poly.YL           <= "00"  & signed(CommandData(43 downto 32));
                        settings_poly.YM           <= "00"  & signed(CommandData(43 downto 32));
                        settings_poly.YH           <= "00"  & signed(CommandData(11 downto  0));     
                        settings_poly.XL           <= 6x"0" & signed(CommandData(23 downto 12)) & 14x"0";
                        settings_poly.XH           <= 6x"0" & signed(CommandData(23 downto 12)) & 14x"0";
                        settings_poly.XM           <= 6x"0" & signed(CommandData(55 downto 44)) & 14x"0";
                        settings_poly.DXLDy        <= (others => '0');
                        settings_poly.DXHDy        <= (others => '0');
                        settings_poly.DXMDy        <= (others => '0');
                        if (settings_otherModes.cycleType >= 2) then
                           settings_poly.YL(1 downto 0) <= "11";
                           settings_poly.YM(1 downto 0) <= "11";
                        end if;
                        
                     when 6x"37" => -- set fill color
                        settings_fillcolor.color    <= CommandData(31 downto 0);                      
                        
                     when 6x"38" => -- set fog color
                        settings_fogcolor.fog_A  <= CommandData( 7 downto  0);
                        settings_fogcolor.fog_B  <= CommandData(15 downto  8);
                        settings_fogcolor.fog_G  <= CommandData(23 downto 16);
                        settings_fogcolor.fog_R  <= CommandData(31 downto 24);
                        
                     when 6x"39" => -- set blend color
                        settings_blendcolor.blend_A  <= CommandData( 7 downto  0);
                        settings_blendcolor.blend_B  <= CommandData(15 downto  8);
                        settings_blendcolor.blend_G  <= CommandData(23 downto 16);
                        settings_blendcolor.blend_R  <= CommandData(31 downto 24);
                        
                     when 6x"3A" => -- set prim color
                        settings_primcolor.prim_A          <= CommandData( 7 downto  0);
                        settings_primcolor.prim_B          <= CommandData(15 downto  8);
                        settings_primcolor.prim_G          <= CommandData(23 downto 16);
                        settings_primcolor.prim_R          <= CommandData(31 downto 24);
                        settings_primcolor.prim_levelFrac  <= CommandData(39 downto 32);
                        settings_primcolor.prim_minLevel   <= CommandData(44 downto 40);
                        
                     when 6x"3B" => -- set environment color
                        settings_envcolor.env_A  <= CommandData( 7 downto  0);
                        settings_envcolor.env_B  <= CommandData(15 downto  8);
                        settings_envcolor.env_G  <= CommandData(23 downto 16);
                        settings_envcolor.env_R  <= CommandData(31 downto 24);
                        
                     when 6x"3C" => -- set combine mode
                        settings_combineMode.combine_add_A_1      <= CommandData( 2 downto  0);                     
                        settings_combineMode.combine_sub_b_A_1    <= CommandData( 5 downto  3);                     
                        settings_combineMode.combine_add_R_1      <= CommandData( 8 downto  6);                     
                        settings_combineMode.combine_add_A_0      <= CommandData(11 downto  9);                     
                        settings_combineMode.combine_sub_b_A_0    <= CommandData(14 downto 12);                     
                        settings_combineMode.combine_add_R_0      <= CommandData(17 downto 15);                     
                        settings_combineMode.combine_mul_A_1      <= CommandData(20 downto 18);                     
                        settings_combineMode.combine_sub_a_A_1    <= CommandData(23 downto 21);                     
                        settings_combineMode.combine_sub_b_R_1    <= CommandData(27 downto 24);                     
                        settings_combineMode.combine_sub_b_R_0    <= CommandData(31 downto 28);                     
                        settings_combineMode.combine_mul_R_1      <= CommandData(36 downto 32);                     
                        settings_combineMode.combine_sub_a_R_1    <= CommandData(40 downto 37);                     
                        settings_combineMode.combine_mul_A_0      <= CommandData(43 downto 41);                     
                        settings_combineMode.combine_sub_a_A_0    <= CommandData(46 downto 44);                     
                        settings_combineMode.combine_mul_R_0      <= CommandData(51 downto 47);                     
                        settings_combineMode.combine_sub_a_R_0    <= CommandData(55 downto 52);                     
                        
                     when 6x"3D" => -- set texture image
                        settings_textureImage.tex_base      <= CommandData(24 downto 0);
                        settings_textureImage.tex_width_m1  <= CommandData(41 downto 32);
                        settings_textureImage.tex_size      <= CommandData(52 downto 51);
                        settings_textureImage.tex_format    <= CommandData(55 downto 53);
                        
                     when 6x"3E" => -- set Z image
                        settings_Z_base <= CommandData(24 downto 0);
                        
                     when 6x"3F" => -- set color image
                        settings_colorImage.FB_base      <= CommandData(24 downto 0);
                        settings_colorImage.FB_width_m1  <= CommandData(41 downto 32);
                        settings_colorImage.FB_size      <= CommandData(52 downto 51);
                        settings_colorImage.FB_format    <= CommandData(55 downto 53);
                     
                     when others => 
                        error <= '1';
                        -- synthesis translate_off
                        report to_hstring(CommandData(61 downto 56));
                        -- synthesis translate_on
                        report "Unknown RDP command" severity warning; 
                  
                  end case; -- command
                  
               when EVALTEXRECTANGLE | EVALTEXRECTANGLEFLIP =>
                  if (cmdfifo_Empty = '0') then
                     state                  <= WAITRASTER;
                     poly_start             <= '1';
                  end if;
                  
                  settings_poly.tex_Texture_S   <= signed(CommandData(63 downto 48)) & 16x"0";
                  settings_poly.tex_Texture_T   <= signed(CommandData(47 downto 32)) & 16x"0";

                  if (state = EVALTEXRECTANGLE) then
                     settings_poly.tex_DsDx <= resize(signed(CommandData(31 downto 16)), 21) & 11x"0";
                     settings_poly.tex_DtDe <= resize(signed(CommandData(15 downto  0)), 21) & 11x"0";
                     settings_poly.tex_DtDy <= resize(signed(CommandData(15 downto  0)), 21) & 11x"0";
                  else
                     settings_poly.tex_DtDx <= resize(signed(CommandData(15 downto  0)), 21) & 11x"0";
                     settings_poly.tex_DsDe <= resize(signed(CommandData(31 downto 16)), 21) & 11x"0";
                     settings_poly.tex_DsDy <= resize(signed(CommandData(31 downto 16)), 21) & 11x"0";
                  end if;   
            
               when EVALTRIANGLE =>
                  if (cmdfifo_Empty = '0') then
                     triCnt <= triCnt + 1;
                  end if;
                     
                  case (to_integer(triCnt)) is
                     when 0 =>
                        settings_poly.XL       <= signed(CommandData(63 downto 32));
                        settings_poly.DXLDy    <= signed(CommandData(29 downto  0));
                     when 1 =>
                        settings_poly.XH       <= signed(CommandData(63 downto 32));
                        settings_poly.DXHDy    <= signed(CommandData(29 downto  0));
                     when 2 =>
                        settings_poly.XM       <= signed(CommandData(63 downto 32));
                        settings_poly.DXMDy    <= signed(CommandData(29 downto  0));
                        if (cmdfifo_Empty = '0') then
                           if (shade = '1') then 
                              state  <= EVALSHADE;
                              triCnt <= (others => '0');
                           elsif (texture = '1') then
                              state  <= EVALTEXTURE;
                              triCnt <= (others => '0');
                           elsif (zbuffer = '1') then
                              state  <= EVALZBUFFER;
                              triCnt <= (others => '0');
                           else
                              state                  <= WAITRASTER;
                              poly_start             <= '1';
                           end if;
                        end if;
                        
                     when others => null;
                  end case;
                  
               when EVALSHADE =>
                  if (cmdfifo_Empty = '0') then
                     triCnt <= triCnt + 1;
                  end if;
                  
                  case (to_integer(triCnt)) is
                     when 0 =>
                        settings_poly.shade_Color_R(31 downto 16) <= signed(CommandData(63 downto 48));
                        settings_poly.shade_Color_G(31 downto 16) <= signed(CommandData(47 downto 32));
                        settings_poly.shade_Color_B(31 downto 16) <= signed(CommandData(31 downto 16));
                        settings_poly.shade_Color_A(31 downto 16) <= signed(CommandData(15 downto  0));
                     when 1 =>
                        settings_poly.shade_DrDx(31 downto 16) <= signed(CommandData(63 downto 48));
                        settings_poly.shade_DgDx(31 downto 16) <= signed(CommandData(47 downto 32));
                        settings_poly.shade_DbDx(31 downto 16) <= signed(CommandData(31 downto 16));
                        settings_poly.shade_DaDx(31 downto 16) <= signed(CommandData(15 downto  0));                   
                     when 2 =>
                        settings_poly.shade_Color_R(15 downto 0) <= signed(CommandData(63 downto 48));
                        settings_poly.shade_Color_G(15 downto 0) <= signed(CommandData(47 downto 32));
                        settings_poly.shade_Color_B(15 downto 0) <= signed(CommandData(31 downto 16));
                        settings_poly.shade_Color_A(15 downto 0) <= signed(CommandData(15 downto  0));                     
                     when 3 =>
                        settings_poly.shade_DrDx(15 downto 0) <= signed(CommandData(63 downto 48));
                        settings_poly.shade_DgDx(15 downto 0) <= signed(CommandData(47 downto 32));
                        settings_poly.shade_DbDx(15 downto 0) <= signed(CommandData(31 downto 16));
                        settings_poly.shade_DaDx(15 downto 0) <= signed(CommandData(15 downto  0));
                     when 4 =>
                        settings_poly.shade_DrDe(31 downto 16) <= signed(CommandData(63 downto 48));
                        settings_poly.shade_DgDe(31 downto 16) <= signed(CommandData(47 downto 32));
                        settings_poly.shade_DbDe(31 downto 16) <= signed(CommandData(31 downto 16));
                        settings_poly.shade_DaDe(31 downto 16) <= signed(CommandData(15 downto  0));
                     when 5 =>
                        settings_poly.shade_DrDy(31 downto 16) <= signed(CommandData(63 downto 48));
                        settings_poly.shade_DgDy(31 downto 16) <= signed(CommandData(47 downto 32));
                        settings_poly.shade_DbDy(31 downto 16) <= signed(CommandData(31 downto 16));
                        settings_poly.shade_DaDy(31 downto 16) <= signed(CommandData(15 downto  0));                   
                     when 6 =>
                        settings_poly.shade_DrDe(15 downto 0) <= signed(CommandData(63 downto 48));
                        settings_poly.shade_DgDe(15 downto 0) <= signed(CommandData(47 downto 32));
                        settings_poly.shade_DbDe(15 downto 0) <= signed(CommandData(31 downto 16));
                        settings_poly.shade_DaDe(15 downto 0) <= signed(CommandData(15 downto  0));                     
                     when 7 =>
                        settings_poly.shade_DrDy(15 downto 0) <= signed(CommandData(63 downto 48));
                        settings_poly.shade_DgDy(15 downto 0) <= signed(CommandData(47 downto 32));
                        settings_poly.shade_DbDy(15 downto 0) <= signed(CommandData(31 downto 16));
                        settings_poly.shade_DaDy(15 downto 0) <= signed(CommandData(15 downto  0));
                        if (cmdfifo_Empty = '0') then
                           if (texture = '1') then
                              state  <= EVALTEXTURE;
                              triCnt <= (others => '0');
                           elsif (zbuffer = '1') then
                              state  <= EVALZBUFFER;
                              triCnt <= (others => '0');
                           else
                              state                  <= WAITRASTER;
                              poly_start             <= '1';
                           end if;
                        end if;
                        
                     when others => null;
                  end case;
               
               when EVALTEXTURE =>
                  if (cmdfifo_Empty = '0') then
                     triCnt <= triCnt + 1;
                  end if;
                  
                  case (to_integer(triCnt)) is
                     when 0 =>
                        settings_poly.tex_Texture_S(31 downto 16) <= signed(CommandData(63 downto 48));
                        settings_poly.tex_Texture_T(31 downto 16) <= signed(CommandData(47 downto 32));
                        settings_poly.tex_Texture_W(31 downto 16) <= signed(CommandData(31 downto 16));
                     when 1 =>
                        settings_poly.tex_DsDx(31 downto 16) <= signed(CommandData(63 downto 48));
                        settings_poly.tex_DtDx(31 downto 16) <= signed(CommandData(47 downto 32));
                        settings_poly.tex_DwDx(31 downto 16) <= signed(CommandData(31 downto 16));                   
                     when 2 =>
                        settings_poly.tex_Texture_S(15 downto 0) <= signed(CommandData(63 downto 48));
                        settings_poly.tex_Texture_T(15 downto 0) <= signed(CommandData(47 downto 32));
                        settings_poly.tex_Texture_W(15 downto 0) <= signed(CommandData(31 downto 16));                   
                     when 3 =>
                        settings_poly.tex_DsDx(15 downto 0) <= signed(CommandData(63 downto 48));
                        settings_poly.tex_DtDx(15 downto 0) <= signed(CommandData(47 downto 32));
                        settings_poly.tex_DwDx(15 downto 0) <= signed(CommandData(31 downto 16));
                     when 4 =>
                        settings_poly.tex_DsDe(31 downto 16) <= signed(CommandData(63 downto 48));
                        settings_poly.tex_DtDe(31 downto 16) <= signed(CommandData(47 downto 32));
                        settings_poly.tex_DwDe(31 downto 16) <= signed(CommandData(31 downto 16));
                     when 5 =>
                        settings_poly.tex_DsDy(31 downto 16) <= signed(CommandData(63 downto 48));
                        settings_poly.tex_DtDy(31 downto 16) <= signed(CommandData(47 downto 32));
                        settings_poly.tex_DwDy(31 downto 16) <= signed(CommandData(31 downto 16));                  
                     when 6 =>
                        settings_poly.tex_DsDe(15 downto 0) <= signed(CommandData(63 downto 48));
                        settings_poly.tex_DtDe(15 downto 0) <= signed(CommandData(47 downto 32));
                        settings_poly.tex_DwDe(15 downto 0) <= signed(CommandData(31 downto 16));                   
                     when 7 =>
                        settings_poly.tex_DsDy(15 downto 0) <= signed(CommandData(63 downto 48));
                        settings_poly.tex_DtDy(15 downto 0) <= signed(CommandData(47 downto 32));
                        settings_poly.tex_DwDy(15 downto 0) <= signed(CommandData(31 downto 16));
                        if (cmdfifo_Empty = '0') then
                           if (zbuffer = '1') then
                              state  <= EVALZBUFFER;
                              triCnt <= (others => '0');
                           else
                              state                  <= WAITRASTER;
                              poly_start             <= '1';
                           end if;
                        end if;
                        
                     when others => null;
                  end case;

               when EVALZBUFFER =>
                  if (cmdfifo_Empty = '0') then
                     triCnt <= triCnt + 1;
                  end if;
                  
                  case (to_integer(triCnt)) is
                     when 0 =>
                        settings_poly.zBuffer_Z    <= signed(CommandData(63 downto 32));
                        settings_poly.zBuffer_DzDx <= signed(CommandData(31 downto  0));
                     when 1 =>
                        settings_poly.zBuffer_DzDe <= signed(CommandData(63 downto 32));
                        settings_poly.zBuffer_DzDy <= signed(CommandData(31 downto  0));       
                        if (cmdfifo_Empty = '0') then                        
                           state                  <= WAITRASTER;
                           poly_start             <= '1';
                        end if;
                        
                     when others => null;
                  end case;
                  
               when WAITRASTER =>
                  if (poly_done = '1') then
                     state <= WAITPIXELWRITE;
                  end if;
                  
               when WAITPIXELWRITE =>
                  if (writePixelsDone = '1') then
                     state <= IDLE;
                  end if;
            
            end case; -- state
            
         end if;
      end if;
   end process;

end architecture;





