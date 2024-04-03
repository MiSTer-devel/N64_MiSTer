library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;
use work.pFunctions.all;

entity RDP_raster is
   port 
   (
      clk1x                   : in  std_logic;
      reset                   : in  std_logic;
   
      error_drawMode          : out std_logic := '0';
   
      stall_raster            : in  std_logic;
   
      settings_poly           : in  tsettings_poly := SETTINGSPOLYINIT;
      settings_scissor        : in  tsettings_scissor := SETTINGSSCISSORINIT;
      settings_Z              : in  tsettings_Z;
      settings_otherModes     : in  tsettings_otherModes;
      settings_fillcolor      : in  tsettings_fillcolor;
      settings_colorImage     : in  tsettings_colorImage;
      settings_textureImage   : in  tsettings_textureImage;
      settings_Z_base         : in  unsigned(24 downto 0);
      settings_tile           : in  tsettings_tile;
      settings_loadtype       : in  tsettings_loadtype;
      poly_start              : in  std_logic;
      loading_mode            : in  std_logic;
      poly_done               : out std_logic := '0';
      
      TextureReqRAMreq        : out std_logic := '0';
      TextureReqRAMaddr       : out unsigned(25 downto 0) := (others => '0');
      TextureReqRAMPtr        : out unsigned(4 downto 0) := (others => '0');
      TextureReqRAMData       : in  std_logic_vector(63 downto 0);
      TextureReqRAMReady      : in  std_logic;
      
      TextureRamAddr          : out unsigned(7 downto 0) := (others => '0');    
      TextureRam0Data         : out std_logic_vector(15 downto 0) := (others => '0');
      TextureRam1Data         : out std_logic_vector(15 downto 0) := (others => '0');
      TextureRam2Data         : out std_logic_vector(15 downto 0) := (others => '0');
      TextureRam3Data         : out std_logic_vector(15 downto 0) := (others => '0');
      TextureRam4Data         : out std_logic_vector(15 downto 0) := (others => '0');
      TextureRam5Data         : out std_logic_vector(15 downto 0) := (others => '0');
      TextureRam6Data         : out std_logic_vector(15 downto 0) := (others => '0');
      TextureRam7Data         : out std_logic_vector(15 downto 0) := (others => '0');
      TextureRamWE            : out std_logic_vector(7 downto 0)  := (others => '0');
     
      FBreq                   : out std_logic := '0';
      FBaddr                  : out unsigned(25 downto 0) := (others => '0');
      FBZaddr                 : out unsigned(25 downto 0) := (others => '0');
      FBsize                  : out unsigned(11 downto 0) := (others => '0');
      FBodd                   : out std_logic := '0';
      FBdone                  : in  std_logic;
     
      -- synthesis translate_off
      export_line_done        : out std_logic := '0'; 
      export_line_list        : out rdp_export_type := (others => (others => '0')); 
         
      export_load_done        : out std_logic := '0'; 
      export_loadFetch        : out rdp_export_type := (others => (others => '0')); 
      export_loadData         : out rdp_export_type := (others => (others => '0')); 
      export_loadValue        : out rdp_export_type := (others => (others => '0')); 
      -- synthesis translate_on
      
      pipe_busy               : in  std_logic;
      
      pipeIn_trigger          : out std_logic := '0';
      pipeIn_valid            : out std_logic := '0';
      pipeIn_Addr             : out unsigned(25 downto 0) := (others => '0');
      pipeIn_AddrZ            : out unsigned(25 downto 0) := (others => '0');
      pipeIn_xIndexPx         : out unsigned(11 downto 0) := (others => '0');
      pipeIn_xIndexPxZ        : out unsigned(11 downto 0) := (others => '0');
      pipeIn_xIndex9          : out unsigned(11 downto 0) := (others => '0');
      pipeIn_X                : out unsigned(11 downto 0) := (others => '0');
      pipeIn_Y                : out unsigned(11 downto 0) := (others => '0');
      pipeIn_cvgValue         : out unsigned(7 downto 0) := (others => '0');
      pipeIn_offX             : out unsigned(1 downto 0) := (others => '0');
      pipeIn_offY             : out unsigned(1 downto 0) := (others => '0');
      pipeInColorFull         : out tcolor4_s32 := (others => (others => '0'));
      pipeIn_S                : out signed(15 downto 0) := (others => '0');
      pipeIn_T                : out signed(15 downto 0) := (others => '0');
      pipeInWCarry            : out std_logic := '0';
      pipeInWShift            : out integer range 0 to 14 := 0;
      pipeInWNormLow          : out unsigned(7 downto 0) := (others => '0');
      pipeInWtemppoint        : out signed(15 downto 0) := (others => '0');
      pipeInWtempslope        : out unsigned(7 downto 0) := (others => '0');
      pipeIn_S_next           : out signed(15 downto 0) := (others => '0');
      pipeIn_T_next           : out signed(15 downto 0) := (others => '0');
      pipeInWCarry_next       : out std_logic := '0';
      pipeInWShift_next       : out integer range 0 to 14 := 0;
      pipeInWNormLow_next     : out unsigned(7 downto 0) := (others => '0');
      pipeInWtemppoint_next   : out signed(15 downto 0) := (others => '0');
      pipeInWtempslope_next   : out unsigned(7 downto 0) := (others => '0');
      pipeIn_Z                : out signed(21 downto 0) := (others => '0');
      pipeIn_dzPix            : out unsigned(15 downto 0) := (others => '0');
      pipeIn_copySize         : out unsigned(3 downto 0) := (others => '0');
      
      -- synthesis translate_off
      pipeIn_cvg16            : out unsigned(15 downto 0) := (others => '0');
      pipeInSTWZ              : out tcolor4_s32;
      fillX                   : out unsigned(11 downto 0) := (others => '0');
      fillY                   : out unsigned(11 downto 0) := (others => '0');
      -- synthesis translate_on

      fillWrite               : out std_logic := '0';
      fillBE                  : out unsigned(7 downto 0) := (others => '0');
      fillColor               : out unsigned(63 downto 0) := (others => '0');
      fillAddr                : out unsigned(25 downto 0) := (others => '0')
   );
end entity;

architecture arch of RDP_raster is

   type tpolyState is 
   (  
      POLYIDLE, 
      EVALLINE,
      REQUESTFB,
      WAITREADRAM,
      WAITLINE,
      POLYFINISH
   ); 
   signal polystate  : tpolyState := POLYIDLE;    

   signal xleft_inc     : signed(27 downto 0) := (others => '0');
   signal xright_inc    : signed(27 downto 0);
   signal xright        : signed(31 downto 0) := (others => '0');
   signal xleft         : signed(31 downto 0) := (others => '0');
   signal do_offset     : std_logic;
   signal ycur          : signed(13 downto 0) := (others => '0');
   signal ldflag        : unsigned(1 downto 0) := (others => '0');
   signal yLLimitMux    : signed(13 downto 0);
   signal yHLimitMux    : signed(13 downto 0);
   signal ylfar         : signed(13 downto 0) := (others => '0');
   signal yllimit       : signed(13 downto 0) := (others => '0');
   signal yhlimit       : signed(13 downto 0) := (others => '0');
   signal yhclose       : signed(13 downto 0);
   signal clipxlshift   : unsigned(12 downto 0);
   signal clipxhshift   : unsigned(12 downto 0);
      
   signal secondHalf    : std_logic := '0';
   signal allover       : std_logic := '0';
   signal allunder      : std_logic := '0';
   signal allinval      : std_logic := '0';
   signal unscrx        : signed(12 downto 0) := (others => '0');
   signal maxxmx        : unsigned(11 downto 0) := (others => '0');
   signal minxmx        : unsigned(11 downto 0) := (others => '0');
   signal scissorNow    : std_logic;
      
   type t_majorminor is array(0 to 3) of unsigned(12 downto 0);
   signal majorx        : t_majorminor := (others => (others => '0'));
   signal minorx        : t_majorminor := (others => (others => '0'));
   signal invalidLine   : std_logic_vector(3 downto 0) := (others => '0');
   
   signal poly_dzPix_baseX : unsigned(15 downto 0);
   signal poly_dzPix_baseY : unsigned(15 downto 0);
   signal poly_dzPix_sum   : unsigned(15 downto 0);
   
   -- offset calc
   signal offset_Re     : signed(22 downto 0);
   signal offset_Ge     : signed(22 downto 0);
   signal offset_Be     : signed(22 downto 0);
   signal offset_Ae     : signed(22 downto 0);
   signal offset_Se     : signed(22 downto 0);
   signal offset_Te     : signed(22 downto 0);
   signal offset_We     : signed(22 downto 0);
   signal offset_Ze     : signed(22 downto 0); 
   
   signal offset_Ry     : signed(22 downto 0);
   signal offset_Gy     : signed(22 downto 0);
   signal offset_By     : signed(22 downto 0);
   signal offset_Ay     : signed(22 downto 0);
   signal offset_Sy     : signed(22 downto 0);
   signal offset_Ty     : signed(22 downto 0);
   signal offset_Wy     : signed(22 downto 0);
   signal offset_Zy     : signed(22 downto 0); 
   
   signal offset_R      : signed(31 downto 0) := (others => '0');
   signal offset_G      : signed(31 downto 0) := (others => '0');
   signal offset_B      : signed(31 downto 0) := (others => '0');
   signal offset_A      : signed(31 downto 0) := (others => '0');
   signal offset_S      : signed(31 downto 0) := (others => '0');
   signal offset_T      : signed(31 downto 0) := (others => '0');
   signal offset_W      : signed(31 downto 0) := (others => '0');
   signal offset_Z      : signed(31 downto 0) := (others => '0');
   
   signal mul_R         : signed(23 downto 0);
   signal mul_G         : signed(23 downto 0);
   signal mul_B         : signed(23 downto 0);
   signal mul_A         : signed(23 downto 0);
   signal mul_S         : signed(23 downto 0);
   signal mul_T         : signed(23 downto 0);
   signal mul_W         : signed(23 downto 0);
   signal mul_Z         : signed(23 downto 0);
   
   signal xfrac         : signed(8 downto 0);
   
   signal lineFrac_R    : signed(31 downto 0);
   signal lineFrac_G    : signed(31 downto 0);
   signal lineFrac_B    : signed(31 downto 0);
   signal lineFrac_A    : signed(31 downto 0);
   signal lineFrac_S    : signed(31 downto 0);
   signal lineFrac_T    : signed(31 downto 0);
   signal lineFrac_W    : signed(31 downto 0);
   signal lineFrac_Z    : signed(31 downto 0);
   
   -- comb calculation
   signal sticky_r      : std_logic := '0';  
   signal sticky_l      : std_logic := '0';  
   signal xrsc_sticky   : unsigned(13 downto 0) := (others => '0');
   signal xlsc_sticky   : unsigned(13 downto 0) := (others => '0');   
   signal xrsc_under    : unsigned(14 downto 0) := (others => '0');
   signal xlsc_under    : unsigned(14 downto 0) := (others => '0');   
   signal xrsc          : unsigned(14 downto 0) := (others => '0');
   signal xlsc          : unsigned(14 downto 0) := (others => '0');
   signal curover_r     : std_logic := '0';
   signal curover_l     : std_logic := '0';
   signal curunder_r    : std_logic := '0';
   signal curunder_l    : std_logic := '0';  
   signal xright_cross  : unsigned(13 downto 0) := (others => '0');
   signal xleft_cross   : unsigned(13 downto 0) := (others => '0');   
   signal curcross      : std_logic := '0';
   signal invaly        : std_logic := '0'; 
   signal calcFBAddr    : unsigned(25 downto 0);   
   signal calcZAddr     : unsigned(25 downto 0);   
   
   -- poly accu
   signal poly_Color_R     : signed(31 downto 0) := (others => '0');
   signal poly_Color_G     : signed(31 downto 0) := (others => '0');
   signal poly_Color_B     : signed(31 downto 0) := (others => '0');
   signal poly_Color_A     : signed(31 downto 0) := (others => '0');
   signal poly_Texture_S   : signed(31 downto 0) := (others => '0');
   signal poly_Texture_T   : signed(31 downto 0) := (others => '0');
   signal poly_Texture_W   : signed(31 downto 0) := (others => '0');
   signal poly_Z           : signed(31 downto 0) := (others => '0');   
   
   type tlineInfo is record
      y           : unsigned(11 downto 0);
      xStart      : unsigned(11 downto 0); 
      xEnd        : unsigned(11 downto 0);
      unscrx      : signed(12 downto 0);
      Color_R     : signed(31 downto 0);
      Color_G     : signed(31 downto 0);
      Color_B     : signed(31 downto 0);
      Color_A     : signed(31 downto 0);
      Texture_S   : signed(31 downto 0);
      Texture_T   : signed(31 downto 0);
      Texture_W   : signed(31 downto 0);
      Z           : signed(31 downto 0);
   end record;
   signal lineInfo      : tlineInfo := (y => (others => '0'), xStart => (others => '0'), xEnd => (others => '0'), others => (others => '0'));
   signal startLine     : std_logic := '0';
   
   -- line drawing
   type tlineState is 
   (  
      LINEIDLE, 
      PREPARELINE,
      DRAWLINE,
      DRAWLINESTEP2,
      STALLDRAW,
      FILLLINE,
      STALLFILL
   ); 
   signal linestate  : tlineState := LINEIDLE;    
   
   signal cycle2calc       : std_logic := '0';
   signal drawLineDone     : std_logic;
   signal line_posY        : unsigned(11 downto 0) := (others => '0');
   signal line_posX        : unsigned(11 downto 0) := (others => '0');
   signal line_endX        : unsigned(11 downto 0) := (others => '0');
   signal calcIndex        : unsigned(11 downto 0);
   signal line_indexX      : unsigned(11 downto 0) := (others => '0');
   signal line_indexXZ     : unsigned(11 downto 0) := (others => '0');
   signal line_indexX9     : unsigned(11 downto 0) := (others => '0');
   signal line_offsetPx    : unsigned(2 downto 0) := (others => '0');
   signal line_offsetPxZ   : unsigned(1 downto 0) := (others => '0');
   signal line_stepsize    : integer range 1 to 4 := 1;
   
   signal xDiff            : signed(11 downto 0);
   
   type tlineCVGInfo is record
      majorx      : t_majorminor;
      minorx      : t_majorminor;
      invalidLine : std_logic_vector(3 downto 0);
   end record;
   signal lineCVGInfo      : tlineCVGInfo;
   
   type tcvg is array(0 to 3) of unsigned(3 downto 0);
   signal leftMasked       : tcvg;
   signal rightMasked      : tcvg;
   signal cvg              : tcvg;
   signal maskx            : unsigned(3 downto 0);
   signal masky            : unsigned(3 downto 0);
   signal offx             : unsigned(1 downto 0);
   signal offy             : unsigned(1 downto 0);
   
   type tCVGtable is array(0 to 15) of unsigned(1 downto 0);
   constant cvgOffYTable : tCVGtable := ( 2x"0",2x"0",2x"1",2x"0",2x"2",2x"0",2x"1",2x"0",2x"3",2x"0",2x"1",2x"0",2x"2",2x"0",2x"1",2x"0" );
   constant cvgOffXTable : tCVGtable := ( 2x"0",2x"3",2x"2",2x"2",2x"1",2x"1",2x"1",2x"1",2x"0",2x"0",2x"0",2x"0",2x"0",2x"0",2x"0",2x"0" );
   
   signal pixel_Color_R    : signed(31 downto 0) := (others => '0');
   signal pixel_Color_G    : signed(31 downto 0) := (others => '0');
   signal pixel_Color_B    : signed(31 downto 0) := (others => '0');
   signal pixel_Color_A    : signed(31 downto 0) := (others => '0');
   signal pixel_Texture_S  : signed(31 downto 0) := (others => '0');
   signal pixel_Texture_T  : signed(31 downto 0) := (others => '0');
   signal pixel_Texture_W  : signed(31 downto 0) := (others => '0');
   signal pixel_Z          : signed(31 downto 0) := (others => '0');   
   
   signal line_DrDx        : signed(31 downto 0) := (others => '0');
   signal line_DgDx        : signed(31 downto 0) := (others => '0');
   signal line_DbDx        : signed(31 downto 0) := (others => '0');
   signal line_DaDx        : signed(31 downto 0) := (others => '0');
   signal line_DsDx        : signed(31 downto 0) := (others => '0');
   signal line_DtDx        : signed(31 downto 0) := (others => '0');
   signal line_DwDx        : signed(31 downto 0) := (others => '0');
   signal line_DzDx        : signed(31 downto 0) := (others => '0'); 
   
   signal pixel_next_S     : signed(31 downto 0) := (others => '0');
   signal pixel_next_T     : signed(31 downto 0) := (others => '0');
   signal pixel_next_W     : signed(31 downto 0) := (others => '0');
   
   -- perspective correction
   signal WCarry_current     : std_logic;
   signal WShift_current     : integer range 0 to 14;
   signal WNormLow_current   : unsigned(7 downto 0);
   signal Wtemppoint_current : signed(15 downto 0);
   signal Wtempslope_current : unsigned(7 downto 0);

   signal pixel_next_S_Y     : signed(31 downto 0) := (others => '0');
   signal pixel_next_T_Y     : signed(31 downto 0) := (others => '0');
   signal pixel_next_W_Y     : signed(31 downto 0) := (others => '0');   
   
   signal pixel_W_muxed      : signed(31 downto 0) := (others => '0');   
   
   signal WCarry_next        : std_logic;
   signal WShift_next        : integer range 0 to 14;
   signal WNormLow_next      : unsigned(7 downto 0);
   signal Wtemppoint_next    : signed(15 downto 0);
   signal Wtempslope_next    : unsigned(7 downto 0);
   
   -- comb calculation
   signal calcPixelAddr    : unsigned(25 downto 0);
   signal calcPixelAddrZ   : unsigned(25 downto 0);
   signal calcPixelStart   : unsigned(25 downto 0);
   signal calcPixelStartZ  : unsigned(25 downto 0);
   
   signal calcCopySizeFlip : unsigned(11 downto 0);
   signal calcCopySize     : unsigned(11 downto 0);
   
   -- line loading
   type tloadState is 
   (  
      LOADIDLE,
      LOADRAM,   
      LOADRAM2,      
      LOADLINE
   ); 
   signal loadState  : tloadState := LOADIDLE;  
   
   signal loadLineDone        : std_logic;
   signal load_posX           : unsigned(11 downto 0) := (others => '0');
   signal load_endX           : unsigned(11 downto 0) := (others => '0');
   signal loadTexture_S       : signed(31 downto 0);
   signal loadTexture_T       : signed(31 downto 0);
   signal load_memAddr        : unsigned(25 downto 0) := (others => '0');
   
   signal TextureReqRAM_index : unsigned(4 downto 0) := (others => '0');

   -- comb calculation
   signal load_length         : unsigned(11 downto 0) := (others => '0');
   signal spanAdvance         : integer range 0 to 8;
   signal memAdvance          : integer range 0 to 8;
   signal load_S_sub          : signed(15 downto 0);
   signal load_T_sub          : signed(15 downto 0);   
   signal load_S_corrected    : signed(12 downto 0);
   signal load_T_corrected    : signed(12 downto 0);   
   signal load_S_shifted      : unsigned(10 downto 0);
   signal load_bit3flipped    : std_logic;
   signal load_linesize       : unsigned(22 downto 0);
   signal load_tbase_mul      : unsigned(21 downto 0);
   signal load_tbase          : unsigned(8 downto 0);
   signal load_tmemAddr0      : unsigned(10 downto 0);
   signal load_Ram0Addr       : unsigned(10 downto 0) := (others => '0');  
   signal load_Ram0Data       : std_logic_vector(15 downto 0) := (others => '0');
   signal load_Ram1Data       : std_logic_vector(15 downto 0) := (others => '0');
   signal load_Ram2Data       : std_logic_vector(15 downto 0) := (others => '0');
   signal load_Ram3Data       : std_logic_vector(15 downto 0) := (others => '0');
   signal TextureRAMData_1    : std_logic_vector(63 downto 0);
   signal TextureRAMDataMuxed : std_logic_vector(63 downto 0);
   
   -- export only
   -- synthesis translate_off
   signal load_posY           : unsigned(11 downto 0) := (others => '0');
   signal load_hibit          : std_logic;
   signal load_tmemAddr1      : unsigned(10 downto 0);
   signal load_tmemAddr2      : unsigned(10 downto 0);
   signal load_tmemAddr3      : unsigned(10 downto 0);
   signal load_Ram1Addr       : unsigned(10 downto 0) := (others => '0');
   signal load_Ram2Addr       : unsigned(10 downto 0) := (others => '0');
   signal load_Ram3Addr       : unsigned(10 downto 0) := (others => '0');    
   -- synthesis translate_on

begin 

   -- offset
   offset_Re <= settings_poly.shade_DrDe(31 downto 9);
   offset_Ge <= settings_poly.shade_DgDe(31 downto 9);
   offset_Be <= settings_poly.shade_DbDe(31 downto 9);
   offset_Ae <= settings_poly.shade_DaDe(31 downto 9);         
   offset_Se <= settings_poly.tex_DsDe(31 downto 9);        
   offset_Te <= settings_poly.tex_DtDe(31 downto 9);         
   offset_We <= settings_poly.tex_DwDe(31 downto 9);         
   offset_Ze <= settings_poly.zBuffer_DzDe(31 downto 9);

   offset_Ry <= settings_poly.shade_DrDy(31 downto 9);
   offset_Gy <= settings_poly.shade_DgDy(31 downto 9);
   offset_By <= settings_poly.shade_DbDy(31 downto 9);
   offset_Ay <= settings_poly.shade_DaDy(31 downto 9);         
   offset_Sy <= settings_poly.tex_DsDy(31 downto 9);        
   offset_Ty <= settings_poly.tex_DtDy(31 downto 9);         
   offset_Wy <= settings_poly.tex_DwDy(31 downto 9);         
   offset_Zy <= settings_poly.zBuffer_DzDy(31 downto 9);
   
   mul_R <= settings_poly.shade_DrDx(31 downto 9) & '0';
   mul_G <= settings_poly.shade_DgDx(31 downto 9) & '0';
   mul_B <= settings_poly.shade_DbDx(31 downto 9) & '0';
   mul_A <= settings_poly.shade_DaDx(31 downto 9) & '0';        
   mul_S <= settings_poly.tex_DsDx(31 downto 9) & '0';        
   mul_T <= settings_poly.tex_DtDx(31 downto 9) & '0';         
   mul_W <= settings_poly.tex_DwDx(31 downto 9) & '0';         
   mul_Z <= settings_poly.zBuffer_DzDx(31 downto 9) & '0';
   
   xfrac <= '0' & xright(15 downto 8) when (settings_otherModes.cycleType /= "10") else (others => '0');
   
   lineFrac_R <= (poly_Color_R(31 downto 9)   & 9x"0") + offset_R - resize(xfrac * mul_R,32);
   lineFrac_G <= (poly_Color_G(31 downto 9)   & 9x"0") + offset_G - resize(xfrac * mul_G,32);
   lineFrac_B <= (poly_Color_B(31 downto 9)   & 9x"0") + offset_B - resize(xfrac * mul_B,32);
   lineFrac_A <= (poly_Color_A(31 downto 9)   & 9x"0") + offset_A - resize(xfrac * mul_A,32);
   lineFrac_S <= (poly_Texture_S(31 downto 9) & 9x"0") + offset_S - resize(xfrac * mul_S,32);
   lineFrac_T <= (poly_Texture_T(31 downto 9) & 9x"0") + offset_T - resize(xfrac * mul_T,32);
   lineFrac_W <= (poly_Texture_W(31 downto 9) & 9x"0") + offset_W - resize(xfrac * mul_W,32);
   lineFrac_Z <= (poly_Z(31 downto 9)         & 9x"0") + offset_Z - resize(xfrac * mul_Z,32);

   -- comb calculation
   xright_inc     <= settings_poly.DXHDy(29 downto 3) & '0';
   xleft_inc      <= settings_poly.DXMDy(29 downto 3) & '0' when (secondhalf = '0') else settings_poly.DXLDy(29 downto 3) & '0';
      
   do_offset      <= not (settings_poly.DXHDy(29) xor settings_poly.lft);
   
   yLLimitMux     <= settings_poly.YL                          when (loading_mode = '1' or settings_poly.YL(13) = '1') else
                     "00" & signed(settings_scissor.ScissorYL) when (settings_poly.YL(12) = '1') else
                     settings_poly.YL                          when (unsigned(settings_poly.YL(11 downto 0)) < settings_scissor.ScissorYL) else
                     "00" & signed(settings_scissor.ScissorYL);   
                  
   yHLimitMux     <= settings_poly.YH                          when (loading_mode = '1') else
                     "00" & signed(settings_scissor.ScissorYH) when (settings_poly.YH(13) = '1') else
                     settings_poly.YH                          when (settings_poly.YH(12) = '1') else
                     settings_poly.YH                          when (settings_poly.YH >= to_integer(settings_scissor.ScissorYH)) else
                     "00" & signed(settings_scissor.ScissorYH);
   
   yhclose        <= yHLimitMux(13 downto 2) & "00";
   
   clipxlshift    <= settings_scissor.ScissorXL & '0';
   clipxhshift    <= settings_scissor.ScissorXH & '0';
   
   sticky_r       <= '1' when (xright(13 downto 1) /= 0) else '0';
   sticky_l       <= '1' when (xleft(13 downto 1) /= 0) else '0';
   
   xrsc_sticky    <= unsigned(xright(26 downto 14)) & sticky_r;
   xlsc_sticky    <= unsigned(xleft(26 downto 14))  & sticky_l;
   
   curunder_r     <= '1' when (xright(27) = '1' or (xrsc_sticky < clipxhshift and xright(26) = '0')) else '0';
   curunder_l     <= '1' when (xleft(27)  = '1' or (xlsc_sticky < clipxhshift and xleft(26)  = '0')) else '0';
   
   xrsc_under     <= "00" & clipxhshift when (curunder_r = '1') else unsigned(xright(27 downto 14)) & sticky_r;
   xlsc_under     <= "00" & clipxhshift when (curunder_l = '1') else unsigned(xleft(27 downto 14))  & sticky_l;
   
   curover_r      <= '1' when (xrsc_under(13) = '1' or xrsc_under >= clipxlshift) else '0';
   curover_l      <= '1' when (xlsc_under(13) = '1' or xlsc_under >= clipxlshift) else '0';
   
   xrsc           <= unsigned(xright(27 downto 14) & '0') when (loading_mode = '1') else
                     "00" & clipxlshift                   when (curover_r = '1') else 
                     xrsc_under(14 downto 0);
   
   xlsc           <= unsigned(xleft(27 downto 14) & '0') when (loading_mode = '1') else 
                     "00" & clipxlshift                  when (curover_l = '1') else 
                     xlsc_under(14 downto 0);
   
   xright_cross   <= not xright(27) & unsigned(xright(26 downto 14));
   xleft_cross    <= not xleft(27)  & unsigned(xleft(26 downto 14));
   
   curcross       <= '1' when (settings_poly.lft = '1' and xleft_cross < xright_cross) else
                     '1' when (settings_poly.lft = '0' and xright_cross < xleft_cross) else
                     '0';
   
   invaly         <= '1' when (ycur < yhlimit) else
                     '1' when (ycur >= yllimit) else
                     '1' when (loading_mode = '0' and curcross = '1') else
                     '0';
                     
   scissorNow     <= '0' when (settings_scissor.ScissorField = '0') else
                     '0' when (settings_scissor.ScissorOdd /= ycur(2)) else
                     '1';
                   
   calcFBAddr     <= resize(((lineInfo.y * (settings_colorImage.FB_width_m1 + 1)) + lineInfo.xStart) * 1, 26) when (settings_colorImage.FB_size = SIZE_8BIT) else
                     resize(((lineInfo.y * (settings_colorImage.FB_width_m1 + 1)) + lineInfo.xStart) * 2, 26) when (settings_colorImage.FB_size = SIZE_16BIT) else
                     resize(((lineInfo.y * (settings_colorImage.FB_width_m1 + 1)) + lineInfo.xStart) * 4, 26);
   
   calcZAddr      <= resize(((lineInfo.y * (settings_colorImage.FB_width_m1 + 1)) + lineInfo.xStart) * 2, 26);
   
   -- z values
   poly_dzPix_baseX <= '0' & (not unsigned(settings_poly.zBuffer_DzDx(30 downto 16))) when (settings_poly.zBuffer_DzDx(31) = '1') else '0' & unsigned(settings_poly.zBuffer_DzDx(30 downto 16));
   poly_dzPix_baseY <= '0' & (not unsigned(settings_poly.zBuffer_DzDy(30 downto 16))) when (settings_poly.zBuffer_DzDy(31) = '1') else '0' & unsigned(settings_poly.zBuffer_DzDy(30 downto 16));
   
   
   process (clk1x)
      variable unscrx_new : signed(12 downto 0) := (others => '0');
      variable maxxmx_new : unsigned(11 downto 0) := (others => '0');
      variable minxmx_new : unsigned(11 downto 0) := (others => '0');
   begin
      if rising_edge(clk1x) then
      
         unscrx_new := unscrx;
         maxxmx_new := maxxmx;
         minxmx_new := minxmx;
      
         poly_done  <= '0';
         FBreq      <= '0';
         
         poly_dzPix_sum <= poly_dzPix_baseX + poly_dzPix_baseY;
         
         if (settings_otherModes.zSourceSel = '1') then
            pipeIn_dzPix <= settings_Z.Delta_Z;
         else
            if (poly_dzPix_sum(15 downto 14) > 0) then pipeIn_dzPix <= x"8000";
            elsif (poly_dzPix_sum(13) = '1')      then pipeIn_dzPix <= x"4000";
            elsif (poly_dzPix_sum(12) = '1')      then pipeIn_dzPix <= x"2000";
            elsif (poly_dzPix_sum(11) = '1')      then pipeIn_dzPix <= x"1000";
            elsif (poly_dzPix_sum(10) = '1')      then pipeIn_dzPix <= x"0800";
            elsif (poly_dzPix_sum( 9) = '1')      then pipeIn_dzPix <= x"0400";
            elsif (poly_dzPix_sum( 8) = '1')      then pipeIn_dzPix <= x"0200";
            elsif (poly_dzPix_sum( 7) = '1')      then pipeIn_dzPix <= x"0100";
            elsif (poly_dzPix_sum( 6) = '1')      then pipeIn_dzPix <= x"0080";
            elsif (poly_dzPix_sum( 5) = '1')      then pipeIn_dzPix <= x"0040";
            elsif (poly_dzPix_sum( 4) = '1')      then pipeIn_dzPix <= x"0020";
            elsif (poly_dzPix_sum( 3) = '1')      then pipeIn_dzPix <= x"0010";
            elsif (poly_dzPix_sum( 2) = '1')      then pipeIn_dzPix <= x"0008";
            elsif (poly_dzPix_sum( 1) = '1')      then pipeIn_dzPix <= x"0004";
            elsif (poly_dzPix_sum( 0) = '1')      then pipeIn_dzPix <= x"0003";
            else                                       pipeIn_dzPix <= x"0001";
            end if;
         end if;

         if (reset = '1') then
            
            polystate <= POLYIDLE;
            startLine <= '0';
            
         else
            
            case (polystate) is
            
               when POLYIDLE =>
                  if (poly_start = '1') then
                     polystate <= EVALLINE;
                     
                     xright         <= settings_poly.XH(31 downto 1) & '0';
                     if (settings_poly.YH(13 downto 2) & "00" = settings_poly.YM) then
                        secondHalf <= '1';
                        xleft      <= settings_poly.XL(31 downto 1) & '0';
                     else
                        secondHalf  <= '0';
                        xleft       <= settings_poly.XM(31 downto 1) & '0';
                     end if;
                     ycur           <= settings_poly.YH(13 downto 2) & "00";
                     ldflag         <= (others => do_offset);
                     yllimit        <= yLLimitMux;
                     if (settings_poly.YL(13 downto 2) > yLLimitMux(13 downto 2)) then
                        ylfar       <= (yLLimitMux(13 downto 2) + 1) & "11";
                     else
                        ylfar       <= yLLimitMux(13 downto 2) & "11";
                     end if;
                     yhlimit        <= yHLimitMux;
                     allover        <= '1';
                     allunder       <= '1';
                     allinval       <= '1';
                     maxxmx         <= (others => '0');
                     minxmx         <= (others => '0');
                     
                     poly_Color_R   <= settings_poly.shade_Color_R;
                     poly_Color_G   <= settings_poly.shade_Color_G;
                     poly_Color_B   <= settings_poly.shade_Color_B;
                     poly_Color_A   <= settings_poly.shade_Color_A;
                     poly_Texture_S <= settings_poly.tex_Texture_S;
                     poly_Texture_T <= settings_poly.tex_Texture_T;
                     poly_Texture_W <= settings_poly.tex_Texture_W;
                     poly_Z         <= settings_poly.zBuffer_Z;
                     
                     if (do_offset = '1') then
                        offset_S    <= ((offset_Se & x"00") + resize(offset_Se & 7x"00", 32)) - ((offset_Sy & x"00") + resize(offset_Sy & 7x"00", 32));
                        offset_T    <= ((offset_Te & x"00") + resize(offset_Te & 7x"00", 32)) - ((offset_Ty & x"00") + resize(offset_Ty & 7x"00", 32));
                        offset_W    <= ((offset_We & x"00") + resize(offset_We & 7x"00", 32)) - ((offset_Wy & x"00") + resize(offset_Wy & 7x"00", 32));
                        offset_R    <= ((offset_Re & x"00") + resize(offset_Re & 7x"00", 32)) - ((offset_Ry & x"00") + resize(offset_Ry & 7x"00", 32));
                        offset_G    <= ((offset_Ge & x"00") + resize(offset_Ge & 7x"00", 32)) - ((offset_Gy & x"00") + resize(offset_Gy & 7x"00", 32));
                        offset_B    <= ((offset_Be & x"00") + resize(offset_Be & 7x"00", 32)) - ((offset_By & x"00") + resize(offset_By & 7x"00", 32));
                        offset_A    <= ((offset_Ae & x"00") + resize(offset_Ae & 7x"00", 32)) - ((offset_Ay & x"00") + resize(offset_Ay & 7x"00", 32));
                        offset_Z    <= ((offset_Ze & x"00") + resize(offset_Ze & 7x"00", 32)) - ((offset_Zy & x"00") + resize(offset_Zy & 7x"00", 32));
                     else
                        offset_S    <= (others => '0');
                        offset_T    <= (others => '0');
                        offset_W    <= (others => '0');
                        offset_R    <= (others => '0');
                        offset_G    <= (others => '0');
                        offset_B    <= (others => '0');
                        offset_A    <= (others => '0');
                        offset_Z    <= (others => '0');
                     end if;
                  end if;                  
               
               when EVALLINE =>
                  ycur <= ycur + 1;
                  if (ycur >= ylfar) then
                     polystate <= POLYFINISH;
                  end if;
                  
                  if ((loading_mode = '1' and ycur(13 downto 12) = "00") or (loading_mode = '0' and ycur >= yhclose)) then

                     if (ycur(1 downto 0) = 0) then
                        maxxmx_new     := (others => '0');
                        minxmx_new     := (others => '1');
                        allover        <= '1';
                        allunder       <= '1';
                        allinval       <= '1';
                     end if;
                
                     if (loading_mode = '1') then
                        allover        <= '0';
                        allunder       <= '0';
                     else
                        if (curover_r  = '0' or curover_l  = '0') then allover  <= '0'; end if;
                        if (curunder_r = '0' or curunder_l = '0') then allunder <= '0'; end if;
                     end if;
                     
                     if (settings_poly.lft = '1') then
                        minorx(to_integer(unsigned(ycur(1 downto 0)))) <= xrsc(12 downto 0);
                        majorx(to_integer(unsigned(ycur(1 downto 0)))) <= xlsc(12 downto 0);  
                     else
                        majorx(to_integer(unsigned(ycur(1 downto 0)))) <= xrsc(12 downto 0);
                        minorx(to_integer(unsigned(ycur(1 downto 0)))) <= xlsc(12 downto 0);
                     end if;
                     
                     invalidLine(to_integer(unsigned(ycur(1 downto 0)))) <= invaly;
                     if (invaly = '0') then allinval <= '0'; end if;
                     
                     if (invaly = '0') then
                        if (settings_poly.lft = '1') then
                           if (xlsc(14 downto 3) > maxxmx_new) then maxxmx_new := xlsc(14 downto 3); end if;
                           if (xrsc(14 downto 3) < minxmx_new) then minxmx_new := xrsc(14 downto 3); end if;
                        else
                           if (xlsc(14 downto 3) < minxmx_new) then minxmx_new := xlsc(14 downto 3); end if;
                           if (xrsc(14 downto 3) > maxxmx_new) then maxxmx_new := xrsc(14 downto 3); end if;
                        end if;
                     end if;
                
                     if (unsigned(ycur(1 downto 0)) = ldflag) then
                        unscrx_new := xright(28 downto 16);
                        lineInfo.Color_R     <= lineFrac_R(31 downto 10) & 10x"0";
                        lineInfo.Color_G     <= lineFrac_G(31 downto 10) & 10x"0";
                        lineInfo.Color_B     <= lineFrac_B(31 downto 10) & 10x"0";
                        lineInfo.Color_A     <= lineFrac_A(31 downto 10) & 10x"0";
                        lineInfo.Texture_S   <= lineFrac_S(31 downto 10) & 10x"0";
                        lineInfo.Texture_T   <= lineFrac_T(31 downto 10) & 10x"0";
                        lineInfo.Texture_W   <= lineFrac_W(31 downto 10) & 10x"0";
                        lineInfo.Z           <= lineFrac_Z(31 downto 10) & 10x"0";
     
                     end if;
                     
                     unscrx <= unscrx_new;
                     maxxmx <= maxxmx_new;
                     minxmx <= minxmx_new;
                     
                     if (unsigned(ycur(1 downto 0)) = 3) then
                        lineInfo.y                   <= unsigned(ycur(13 downto 2)); 
                        lineInfo.xStart              <= minxmx_new;
                        lineInfo.xEnd                <= maxxmx_new;
                        lineInfo.unscrx              <= unscrx_new;
                        if (loading_mode = '0') then
                           polystate <= REQUESTFB;
                        else
                           startLine <= '1';
                           if (startLine = '1') then
                              polystate <= WAITLINE;
                           end if;
                        end if;
                     end if;
                
                  end if;
                  
                  if (unsigned(ycur(1 downto 0)) = 3) then
                     poly_Color_R   <= poly_Color_R   + settings_poly.shade_DrDe;
                     poly_Color_G   <= poly_Color_G   + settings_poly.shade_DgDe;
                     poly_Color_B   <= poly_Color_B   + settings_poly.shade_DbDe;
                     poly_Color_A   <= poly_Color_A   + settings_poly.shade_DaDe;
                     poly_Texture_S <= poly_Texture_S + settings_poly.tex_DsDe;
                     poly_Texture_T <= poly_Texture_T + settings_poly.tex_DtDe;
                     poly_Texture_W <= poly_Texture_W + settings_poly.tex_DwDe;
                     poly_Z         <= poly_Z         + settings_poly.zBuffer_DzDe;
                  end if;
            
                  xleft  <= xleft + xleft_inc;
                  xright <= xright + xright_inc;
                  
                  if (ycur + 1 = settings_poly.YM) then
                     secondHalf <= '1';
                     xleft      <= settings_poly.XL(31 downto 1) & '0';
                  end if;
                  
               when REQUESTFB =>
                  if (allinval = '0' and allover = '0' and allunder = '0' and scissorNow = '0') then
                     polystate <= WAITREADRAM;
                     FBreq     <= '1';
                     FBaddr    <= calcFBAddr;
                     FBZaddr   <= calcZAddr;
                     FBsize    <= lineInfo.xEnd - lineInfo.xStart;
                     FBodd     <= lineInfo.y(0);
                  else
                     startLine <= '1';
                     if (startLine = '1') then
                        polystate <= WAITLINE;
                     end if;
                  end if;
                  
               when WAITREADRAM =>
                  if (FBdone = '1') then
                     polystate <= EVALLINE;
                     startLine <= '1';
                     if (startLine = '1') then
                        polystate <= WAITLINE;
                     end if;
                  end if;
                  
               when WAITLINE =>
                  if (startLine = '0') then
                     polystate <= EVALLINE;
                     startLine <= '1';
                  end if;
                  
               when POLYFINISH =>
                  if (startLine = '0' and linestate = LINEIDLE and loadstate = LOADIDLE and pipe_busy = '0' and pipeIn_trigger = '0') then
                     polystate <= POLYIDLE;
                     poly_done <= '1'; 
                  end if;
            
            end case; -- polystate
            
            if (drawLineDone = '1' or loadLineDone = '1') then
               startLine <= '0';
            end if;
            
            if (startLine = '1' and linestate = LINEIDLE and (allinval = '1' or allover = '1' or allunder = '1' or scissorNow = '1')) then
               startLine <= '0';
            end if;
            
         end if;
      end if;
   end process;
   
   -- drawing
   drawLineDone <= '1' when (linestate = DRAWLINE and settings_otherModes.cycleType(1) = '0' and line_posX = line_endX) else 
                   '1' when (linestate = DRAWLINE and settings_otherModes.cycleType = "10" and settings_poly.lft = '1' and line_posX > line_endX) else 
                   '1' when (linestate = DRAWLINE and settings_otherModes.cycleType = "10" and settings_poly.lft = '0' and line_posX < line_endX) else 
                   '1' when (linestate = FILLLINE and line_posX > line_endX) else 
                   '0';
   
   calcPixelAddr <= resize(settings_colorImage.FB_base + ((line_posY * (settings_colorImage.FB_width_m1 + 1)) + line_posX) * 1, 26) when (settings_colorImage.FB_size = SIZE_8BIT) else
                    resize(settings_colorImage.FB_base + ((line_posY * (settings_colorImage.FB_width_m1 + 1)) + line_posX) * 2, 26) when (settings_colorImage.FB_size = SIZE_16BIT) else
                    resize(settings_colorImage.FB_base + ((line_posY * (settings_colorImage.FB_width_m1 + 1)) + line_posX) * 4, 26);
   
   calcPixelAddrZ  <= resize(settings_Z_base + ((line_posY * (settings_colorImage.FB_width_m1 + 1)) + line_posX) * 2, 26);
   
   calcPixelStart  <= resize(settings_colorImage.FB_base + ((line_posY * (settings_colorImage.FB_width_m1 + 1)) + lineInfo.xStart) * 1, 26) when (settings_colorImage.FB_size = SIZE_8BIT) else
                      resize(settings_colorImage.FB_base + ((line_posY * (settings_colorImage.FB_width_m1 + 1)) + lineInfo.xStart) * 2, 26) when (settings_colorImage.FB_size = SIZE_16BIT) else
                      resize(settings_colorImage.FB_base + ((line_posY * (settings_colorImage.FB_width_m1 + 1)) + lineInfo.xStart) * 4, 26);
                      
   calcPixelStartZ <= resize(settings_Z_base + ((line_posY * (settings_colorImage.FB_width_m1 + 1)) + lineInfo.xStart) * 2, 26);
  
   calcIndex      <= lineInfo.xEnd - lineInfo.xStart;
   
   calcCopySizeFlip <= (line_endX + 1 - line_posX);
   calcCopySize     <= (line_posX + 1 - line_endX);
   
   -- cvg
   process (all)
      variable fmask       : unsigned(3 downto 0);
      variable minorShift  : unsigned(3 downto 0);
      variable majorShift  : unsigned(3 downto 0);
      variable leftcvg     : unsigned(3 downto 0);
      variable rightcvg    : unsigned(7 downto 0);
   begin
   
      for i in 0 to 3 loop
      
         if (i = 0 or i = 2) then fmask := x"A"; else fmask := x"5"; end if;
         
         minorShift := ('0' & lineCVGInfo.minorx(i)(2 downto 0)) + 1;
         majorShift := ('0' & lineCVGInfo.majorx(i)(2 downto 0)) + 1;
      
         leftcvg  := shift_right(to_unsigned(16#F#,4),  to_integer(minorShift(3 downto 1)));
         rightcvg := shift_right(to_unsigned(16#F0#,8), to_integer(majorShift(3 downto 1)));
         
         leftMasked(i)  <= leftcvg and fmask;
         rightMasked(i) <= rightcvg(3 downto 0) and fmask;
      
         cvg(i) <= x"0";
      
         if (lineCVGInfo.invalidLine(i) = '0') then
         
            if (line_posX > lineCVGInfo.minorx(i)(12 downto 3) and line_posX < lineCVGInfo.majorx(i)(12 downto 3)) then
               cvg(i) <= fmask;
            elsif (line_posX = lineCVGInfo.minorx(i)(12 downto 3) and line_posX = lineCVGInfo.majorx(i)(12 downto 3)) then
               cvg(i) <= leftMasked(i) and rightMasked(i);   
            elsif (lineCVGInfo.majorx(i)(12 downto 3) > lineCVGInfo.minorx(i)(12 downto 3)) then
               if (line_posX = lineCVGInfo.minorx(i)(12 downto 3)) then cvg(i) <= leftMasked(i);  end if;
               if (line_posX = lineCVGInfo.majorx(i)(12 downto 3)) then cvg(i) <= rightMasked(i); end if;
            end if;
            
         end if;
      end loop;
   
   end process;
   
   masky(0) <= '1' when (cvg(0) > 0) else '0';
   masky(1) <= '1' when (cvg(1) > 0) else '0';
   masky(2) <= '1' when (cvg(2) > 0) else '0';
   masky(3) <= '1' when (cvg(3) > 0) else '0';
   
   offy <= cvgOffYTable(to_integer(masky));
   
   maskx <= cvg(to_integer(offy));
   
   offx <= cvgOffXTable(to_integer(maskx));
   
   -- perspective correction
   pixel_next_S <= pixel_Texture_S + line_DsDx;
   pixel_next_T <= pixel_Texture_T + line_DtDx;
   pixel_next_W <= pixel_Texture_W + line_DwDx;
   
   iRDP_raster_perspcorr_current : entity work.RDP_raster_perspcorr
   port map 
   (         
      pixel_Texture_W    => pixel_Texture_W,                  
      WCarry             => WCarry_current,    
      WShift             => WShift_current,    
      WNormLow           => WNormLow_current,  
      Wtemppoint         => Wtemppoint_current,
      Wtempslope         => Wtempslope_current
   );       

   pixel_W_muxed <= pixel_next_W when (linestate = DRAWLINE) else pixel_next_W_Y;

   iRDP_raster_perspcorr_next : entity work.RDP_raster_perspcorr
   port map 
   (        
      pixel_Texture_W    => pixel_W_muxed,                  
      WCarry             => WCarry_next,    
      WShift             => WShift_next,    
      WNormLow           => WNormLow_next,  
      Wtemppoint         => Wtemppoint_next,
      Wtempslope         => Wtempslope_next
   );

   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         pipeIn_trigger <= '0';
         fillWrite      <= '0';
         error_drawMode <= '0';
         cycle2calc     <= '0';
         
         if (reset = '1') then
            
            linestate <= LINEIDLE;
            
         else
            
            case (linestate) is
            
               when LINEIDLE =>
                  if (polystate = POLYFINISH and pipe_busy = '1') then
                     pipeIn_trigger  <= '1';
                     pipeIn_valid    <= '0';
                     if (settings_otherModes.cycleType = "01" and pipeIn_trigger = '1') then
                        pipeIn_trigger <= '0';
                     end if;
                  end if;
               
                  if (startLine = '1' and allinval = '0' and allover = '0' and allunder = '0' and scissorNow = '0') then
                     if (loading_mode = '0') then
                        if (settings_otherModes.cycleType = "11") then
                           linestate <= FILLLINE;
                        else
                           linestate <= PREPARELINE;
                        end if;
                     end if;
                  end if;
                  
                  line_stepsize <= 1;
                  if (settings_otherModes.cycleType = "10") then
                     case (settings_colorImage.FB_size) is
                        when SIZE_16BIT => line_stepsize <= 4;
                        when others     => error_drawMode <= '1';
                     end case;
                  end if;
                  
                  lineCVGInfo.majorx      <= majorx;
                  lineCVGInfo.minorx      <= minorx;
                  lineCVGInfo.invalidLine <= invalidLine;
                  
                  line_posY   <= lineInfo.Y;
                  
                  if (settings_poly.lft = '1' or settings_otherModes.cycleType = "11") then
                     line_posX      <= lineInfo.xStart;
                     line_endX      <= lineInfo.xEnd;
                     line_offsetPx  <= (others => '0');
                     line_offsetPxZ <= (others => '0');
                     line_indexX    <= (others => '0');
                     case (settings_colorImage.FB_size) is
                        when SIZE_8BIT  => line_indexX(2 downto 0) <= calcPixelStart(2 downto 0);              
                        when SIZE_16BIT => line_indexX(1 downto 0) <= calcPixelStart(2 downto 1);              
                        when SIZE_32BIT => line_indexX(0)          <= calcPixelStart(2);              
                        when others => null;
                     end case;
                     line_indexXZ <= (others => '0');
                     line_indexXZ(1 downto 0) <= calcPixelStartZ(2 downto 1);
                     line_indexX9 <= (others => '0');
                     line_indexX9(3 downto 0) <= calcPixelStartZ(4 downto 1);
                  else
                     line_posX    <= lineInfo.xEnd;
                     line_endX    <= lineInfo.xStart;
                     line_indexX  <= calcIndex;
                     line_indexXZ <= calcIndex;
                     line_indexX9 <= calcIndex + to_integer(calcPixelStartZ(4 downto 1));
                     case (settings_colorImage.FB_size) is
                        when SIZE_8BIT  => line_offsetPx <= calcPixelStart(2 downto 0);          
                        when SIZE_16BIT => line_offsetPx <= "0" & calcPixelStart(2 downto 1);
                        when SIZE_32BIT => line_offsetPx <= "00" & calcPixelStart(2);  
                        when others => null;
                     end case;
                     line_offsetPxZ <= calcPixelStartZ(2 downto 1);
                  end if;
                  
                  if (settings_poly.lft = '1') then
                     xDiff       <= signed(lineInfo.xStart) - lineInfo.unscrx(11 downto 0);
                     line_DrDx   <= settings_poly.shade_DrDx(31 downto 5) & "00000";
                     line_DgDx   <= settings_poly.shade_DgDx(31 downto 5) & "00000";
                     line_DbDx   <= settings_poly.shade_DbDx(31 downto 5) & "00000";
                     line_DaDx   <= settings_poly.shade_DaDx(31 downto 5) & "00000";
                     line_DsDx   <= settings_poly.tex_DsDx(31 downto 5) & "00000";
                     line_DtDx   <= settings_poly.tex_DtDx(31 downto 5) & "00000";
                     line_DwDx   <= settings_poly.tex_DwDx(31 downto 5) & "00000";
                     line_DzDx   <= settings_poly.zBuffer_DzDx(31 downto 5) & "00000";
                  else
                     xDiff       <= lineInfo.unscrx(11 downto 0) - signed(lineInfo.xEnd);
                     line_DrDx   <= -(settings_poly.shade_DrDx(31 downto 5) & "00000");
                     line_DgDx   <= -(settings_poly.shade_DgDx(31 downto 5) & "00000");
                     line_DbDx   <= -(settings_poly.shade_DbDx(31 downto 5) & "00000");
                     line_DaDx   <= -(settings_poly.shade_DaDx(31 downto 5) & "00000");
                     line_DsDx   <= -(settings_poly.tex_DsDx(31 downto 5) & "00000");
                     line_DtDx   <= -(settings_poly.tex_DtDx(31 downto 5) & "00000");
                     line_DwDx   <= -(settings_poly.tex_DwDx(31 downto 5) & "00000");
                     line_DzDx   <= -(settings_poly.zBuffer_DzDx(31 downto 5) & "00000");
                  end if;
                  
                  pixel_Color_R   <= lineInfo.Color_R;  
                  pixel_Color_G   <= lineInfo.Color_G;  
                  pixel_Color_B   <= lineInfo.Color_B;  
                  pixel_Color_A   <= lineInfo.Color_A;  
                  pixel_Texture_S <= lineInfo.Texture_S;
                  pixel_Texture_T <= lineInfo.Texture_T;
                  pixel_Texture_W <= lineInfo.Texture_W;
                  pixel_Z         <= lineInfo.Z; 
               
               when PREPARELINE =>
                  linestate <= DRAWLINE;
                  pixel_Color_R   <= pixel_Color_R   + resize(xDiff * line_DrDx,32);  
                  pixel_Color_G   <= pixel_Color_G   + resize(xDiff * line_DgDx,32);  
                  pixel_Color_B   <= pixel_Color_B   + resize(xDiff * line_DbDx,32);  
                  pixel_Color_A   <= pixel_Color_A   + resize(xDiff * line_DaDx,32);  
                  pixel_Texture_S <= pixel_Texture_S + resize(xDiff * line_DsDx,32);
                  pixel_Texture_T <= pixel_Texture_T + resize(xDiff * line_DtDx,32);
                  pixel_Texture_W <= pixel_Texture_W + resize(xDiff * line_DwDx,32);
                  pixel_Z         <= pixel_Z         + resize(xDiff * line_DzDx,32);        
               
               when DRAWLINE =>
                  if (stall_raster = '1') then
                     linestate <= STALLDRAW;
                  end if;
               
                  if (settings_poly.lft = '1') then
                     line_posX    <= line_posX + line_stepsize;
                     line_indexX  <= line_indexX + line_stepsize;
                     line_indexXZ <= line_indexXZ + line_stepsize;
                     line_indexX9 <= line_indexX9 + line_stepsize;
                  else
                     line_posX    <= line_posX - line_stepsize;
                     line_indexX  <= line_indexX - line_stepsize;
                     line_indexXZ <= line_indexXZ - line_stepsize;
                     line_indexX9 <= line_indexX9 - line_stepsize;
                  end if;

                  pipeIn_trigger    <= '1';
                  pipeIn_valid      <= '1';
                  pipeIn_Addr       <= calcPixelAddr;
                  pipeIn_AddrZ      <= calcPixelAddrZ;
                  pipeIn_xIndexPx   <= line_indexX + line_offsetPx;
                  pipeIn_xIndexPxZ  <= line_indexXZ + line_offsetPxZ;
                  pipeIn_xIndex9    <= line_indexX9;
                  pipeIn_X          <= line_posX;
                  pipeIn_Y          <= line_posY;
                  pipeIn_cvgValue   <= (cvg(0) or cvg(1)) & (cvg(2) or cvg(3));
                  pipeIn_offX       <= offx;
                  pipeIn_offY       <= offy;
                     
                  pipeInColorFull(0) <= pixel_Color_R;
                  pipeInColorFull(1) <= pixel_Color_G;
                  pipeInColorFull(2) <= pixel_Color_B;
                  pipeInColorFull(3) <= pixel_Color_A;
                     
                  pipeIn_S          <= pixel_Texture_S(31 downto 16);
                  pipeIn_T          <= pixel_Texture_T(31 downto 16);
                  pipeInWCarry      <= WCarry_current;    
                  pipeInWShift      <= WShift_current;    
                  pipeInWNormLow    <= WNormLow_current;  
                  pipeInWtemppoint  <= Wtemppoint_current;
                  pipeInWtempslope  <= Wtempslope_current;
                  
                  pipeIn_S_next         <= pixel_next_S(31 downto 16);
                  pipeIn_T_next         <= pixel_next_T(31 downto 16);
                  pipeInWCarry_next     <= WCarry_next;    
                  pipeInWShift_next     <= WShift_next;    
                  pipeInWNormLow_next   <= WNormLow_next;  
                  pipeInWtemppoint_next <= Wtemppoint_next;
                  pipeInWtempslope_next <= Wtempslope_next;

                  pipeIn_Z          <= pixel_Z(31 downto 10);
                  if (settings_otherModes.zSourceSel = '1') then
                     pipeIn_Z       <= '0' & signed(settings_Z.Primitive_Z) & 6x"0";
                  end if;
                  
                  if (settings_poly.lft = '1') then -- todo: different handling for FB size != 16 bit;
                     pipeIn_copySize <= calcCopySizeFlip(2 downto 0) & '0';
                     if (calcCopySizeFlip > 4) then
                        pipeIn_copySize <= x"8";
                     end if;
                  else
                     pipeIn_copySize <= calcCopySize(2 downto 0) & '0';
                     if (calcCopySize > 4) then
                        pipeIn_copySize <= x"8";
                     end if;
                  end if;
                  
                  if (settings_otherModes.cycleType = "01") then
                     linestate  <= DRAWLINESTEP2;
                     cycle2calc <= '1';
                  end if;
                  
                  if (drawLineDone = '1') then
                     linestate <= LINEIDLE;
                     if (settings_otherModes.cycleType = "10") then
                        pipeIn_valid <= '0';
                     end if;
                  end if;

                  -- synthesis translate_off
                  pipeIn_cvg16      <= cvg(0) & cvg(1) & cvg(2) & cvg(3);     
                  
                  pipeInSTWZ(0)      <= pixel_Texture_S;
                  pipeInSTWZ(1)      <= pixel_Texture_T;
                  pipeInSTWZ(2)      <= pixel_Texture_W;
                  pipeInSTWZ(3)      <= pixel_Z;
                  -- synthesis translate_on

                  pixel_Color_R     <= pixel_Color_R   + line_DrDx;
                  pixel_Color_G     <= pixel_Color_G   + line_DgDx;
                  pixel_Color_B     <= pixel_Color_B   + line_DbDx;
                  pixel_Color_A     <= pixel_Color_A   + line_DaDx;
                  pixel_Texture_S   <= pixel_next_S; --pixel_Texture_S + line_DsDx; -> precalc above
                  pixel_Texture_T   <= pixel_next_T; --pixel_Texture_T + line_DtDx; -> precalc above
                  pixel_Texture_W   <= pixel_next_W; --pixel_Texture_W + line_DwDx; -> precalc above
                  pixel_Z           <= pixel_Z         + line_DzDx;
                  
                  pixel_next_S_Y    <= pixel_Texture_S + (settings_poly.tex_DsDy(31 downto 15) & 15x"0");       
                  pixel_next_T_Y    <= pixel_Texture_T + (settings_poly.tex_DtDy(31 downto 15) & 15x"0");       
                  pixel_next_W_Y    <= pixel_Texture_W + (settings_poly.tex_DwDy(31 downto 15) & 15x"0");
                  
               when DRAWLINESTEP2 =>
                  if (stall_raster = '0') then
                     linestate      <= DRAWLINE;
                  end if;
                  
               when STALLDRAW =>
                  if (stall_raster = '0') then
                     linestate <= DRAWLINE;
                  end if;
                  
               when FILLLINE =>
                  if (stall_raster = '1') then
                     linestate <= STALLFILL;
                  end if;
               
                  fillWrite      <= '1';
                  fillAddr       <= calcPixelAddr;
                  fillColor      <= byteswap32(settings_fillcolor.color) & byteswap32(settings_fillcolor.color);
                  fillBE         <= (others => '1');
                  -- synthesis translate_off
                  fillX          <= line_posX;
                  fillY          <= line_posY;
                  -- synthesis translate_on
                  
                  case (settings_colorImage.FB_size) is
                     when SIZE_8BIT  => 
                        line_posX <= line_posX + 8 - calcPixelAddr(2 downto 0);
                        case (to_integer(line_endX - line_posX)) is
                           when 0 => fillBE(7 downto 1) <= (others => '0');
                           when 1 => fillBE(7 downto 2) <= (others => '0');
                           when 2 => fillBE(7 downto 3) <= (others => '0');
                           when 3 => fillBE(7 downto 4) <= (others => '0');
                           when 4 => fillBE(7 downto 5) <= (others => '0');
                           when 5 => fillBE(7 downto 6) <= (others => '0');
                           when 6 => fillBE(7 downto 7) <= (others => '0');
                           when others => null;
                        end case;
                        
                     when SIZE_16BIT => 
                        line_posX <= line_posX + 4 - calcPixelAddr(2 downto 1);
                        case (to_integer(line_endX - line_posX)) is
                           when 0 => fillBE(7 downto 2) <= (others => '0');
                           when 1 => fillBE(7 downto 4) <= (others => '0');
                           when 2 => fillBE(7 downto 6) <= (others => '0');
                           when others => null;
                        end case;
                        
                     when SIZE_32BIT => 
                        line_posX <= line_posX + 2 - ('0' & calcPixelAddr(2));
                        if (line_endX = line_posX) then
                           fillBE(7 downto 4) <= (others => '0');
                        end if;
                        
                     when others => report "4 Bit Fill mode, RDP will crash" severity failure; 
                  end case;
                  
                  if (drawLineDone = '1') then
                     linestate <= LINEIDLE;
                     fillWrite <= '0';
                  end if;
                  
               when STALLFILL =>
                  if (stall_raster = '0') then
                     linestate <= FILLLINE;
                  end if;

            end case; -- linestate
            
            if (cycle2calc = '1') then
               pipeIn_S_next         <= pixel_next_S_Y(31 downto 16);
               pipeIn_T_next         <= pixel_next_T_Y(31 downto 16);
               pipeInWCarry_next     <= WCarry_next;    
               pipeInWShift_next     <= WShift_next;    
               pipeInWNormLow_next   <= WNormLow_next;  
               pipeInWtemppoint_next <= Wtemppoint_next;
               pipeInWtempslope_next <= Wtempslope_next;
            end if;
            
         end if;
      end if;
   end process;
   
   -- loading
   load_length <= load_endX - load_posX + 1;
   
   loadLineDone <= '1' when (loadstate = LOADLINE and (to_integer(load_posX) + spanAdvance) > to_integer(load_endX)) else 
                   '1' when (loadstate = LOADRAM2 and (load_length = 0)) else
                   '0';
   
   spanAdvance <= 4 when (settings_textureImage.tex_size = SIZE_16BIT and settings_loadtype /= LOADTYPE_TLUT) else
                  1 when (settings_textureImage.tex_size = SIZE_16BIT and settings_loadtype = LOADTYPE_TLUT) else
                  2 when (settings_textureImage.tex_size = SIZE_32BIT) else
                  8;
   
   memAdvance  <= 2 when (settings_textureImage.tex_size = SIZE_16BIT and settings_loadtype = LOADTYPE_TLUT) else
                  8;
                  
   load_S_sub  <= loadTexture_S(31 downto 16) - ('0' & signed(settings_tile.Tile_sl) & "000");  
   load_T_sub  <= loadTexture_T(31 downto 16) - ('0' & signed(settings_tile.Tile_tl) & "000");    

   load_S_corrected <= resize(load_S_sub(15 downto 5), 13) when (settings_loadtype = LOADTYPE_TILE) else load_S_sub(15 downto 3);     
   load_T_corrected <= resize(load_T_sub(15 downto 5), 13) when (settings_loadtype = LOADTYPE_TILE) else load_T_sub(15 downto 3);     
   
   load_S_shifted <= unsigned(load_S_corrected(11 downto 1)) when (settings_tile.Tile_size = SIZE_8BIT or settings_tile.Tile_format = FORMAT_YUV) else
                     unsigned(load_S_corrected(10 downto 0)) when (settings_tile.Tile_size = SIZE_16BIT or settings_tile.Tile_size = SIZE_32BIT) else
                     unsigned(load_S_corrected(12 downto 2));
   
   load_bit3flipped <= load_S_shifted(1) xor load_T_corrected(0);
   
   load_linesize <= lineInfo.Y * (('0' & settings_textureImage.tex_width_m1) + 1);
   
   load_tbase_mul <= settings_tile.Tile_line * unsigned(load_T_corrected);
   load_tbase     <= load_tbase_mul(8 downto 0) + settings_tile.Tile_TmemAddr;
   
   -- todo: sorting required?
   load_tmemAddr0 <= (load_tbase & "00") + (load_s_shifted(10 downto 2) & "0" & load_s_shifted(0));
-- synthesis translate_off
   load_tmemAddr1 <= load_tmemAddr0 + 1;
   load_tmemAddr2 <= load_tmemAddr0 + 2;
   load_tmemAddr3 <= load_tmemAddr0 + 3;
   load_hibit       <= load_tmemAddr0(10);
-- synthesis translate_on
   
   TextureReqRAMaddr <= load_MemAddr;
   TextureReqRAMPtr  <= TextureReqRAM_index when (loadstate = LOADRAM or memAdvance = 2) else (TextureReqRAM_index + 1);
   
   load_Ram0Addr <= load_tmemAddr0(10 downto 1) & '1';
-- synthesis translate_off
   load_Ram1Addr <= load_tmemAddr0(10 downto 1) & '0';
   load_Ram2Addr <= load_tmemAddr0(10 downto 2) & "11";
   load_Ram3Addr <= load_tmemAddr0(10 downto 2) & "10";
-- synthesis translate_on
   
   TextureRAMDataMuxed <= TextureReqRAMData(63 downto 48) & TextureReqRAMData(63 downto 48) & TextureReqRAMData(63 downto 48) & TextureReqRAMData(63 downto 48) when (memAdvance = 2 and load_MemAddr(2 downto 0) = "000") else
                          TextureReqRAMData(47 downto 32) & TextureReqRAMData(47 downto 32) & TextureReqRAMData(47 downto 32) & TextureReqRAMData(47 downto 32) when (memAdvance = 2 and load_MemAddr(2 downto 0) = "010") else
                          TextureReqRAMData(31 downto 16) & TextureReqRAMData(31 downto 16) & TextureReqRAMData(31 downto 16) & TextureReqRAMData(31 downto 16) when (memAdvance = 2 and load_MemAddr(2 downto 0) = "100") else
                          TextureReqRAMData(15 downto  0) & TextureReqRAMData(15 downto  0) & TextureReqRAMData(15 downto  0) & TextureReqRAMData(15 downto  0) when (memAdvance = 2 and load_MemAddr(2 downto 0) = "110") else
                          TextureRAMData_1                                                 when (load_MemAddr(2 downto 0) = "000") else
                          TextureRAMData_1(55 downto  0) & TextureReqRAMData(63 downto 56) when (load_MemAddr(2 downto 0) = "001") else 
                          TextureRAMData_1(47 downto  0) & TextureReqRAMData(63 downto 48) when (load_MemAddr(2 downto 0) = "010") else 
                          TextureRAMData_1(39 downto  0) & TextureReqRAMData(63 downto 40) when (load_MemAddr(2 downto 0) = "011") else 
                          TextureRAMData_1(31 downto  0) & TextureReqRAMData(63 downto 32) when (load_MemAddr(2 downto 0) = "100") else 
                          TextureRAMData_1(23 downto  0) & TextureReqRAMData(63 downto 24) when (load_MemAddr(2 downto 0) = "101") else 
                          TextureRAMData_1(15 downto  0) & TextureReqRAMData(63 downto 16) when (load_MemAddr(2 downto 0) = "110") else 
                          TextureRAMData_1( 7 downto  0) & TextureReqRAMData(63 downto  8);
   
   load_Ram0Data <= TextureRAMDataMuxed(63 downto 56) & TextureRAMDataMuxed(47 downto 40) when (settings_tile.Tile_format = FORMAT_YUV) else 
                    TextureRAMDataMuxed(63 downto 48) when (load_T_corrected(0) = '0' or settings_textureImage.tex_size = SIZE_32BIT) else 
                    TextureRAMDataMuxed(31 downto 16);
   
   load_Ram1Data <= TextureRAMDataMuxed(55 downto 48) & TextureRAMDataMuxed(39 downto 32) when (settings_tile.Tile_format = FORMAT_YUV) else 
                    TextureRAMDataMuxed(47 downto 32) when (load_T_corrected(0) = '0' or settings_textureImage.tex_size = SIZE_32BIT) else 
                    TextureRAMDataMuxed(15 downto  0);
   
   load_Ram2Data <= TextureRAMDataMuxed(31 downto 24) & TextureRAMDataMuxed(15 downto 8) when (settings_tile.Tile_format = FORMAT_YUV) else 
                    TextureRAMDataMuxed(31 downto 16) when (load_T_corrected(0) = '0' or settings_textureImage.tex_size = SIZE_32BIT) else 
                    TextureRAMDataMuxed(63 downto 48);
   
   load_Ram3Data <= TextureRAMDataMuxed(23 downto 16) & TextureRAMDataMuxed(7 downto 0) when (settings_tile.Tile_format = FORMAT_YUV) else 
                    TextureRAMDataMuxed(15 downto  0) when (load_T_corrected(0) = '0' or settings_textureImage.tex_size = SIZE_32BIT) else 
                    TextureRAMDataMuxed(47 downto 32);
  
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         -- synthesis translate_off
         export_load_done  <= '0'; 
         -- synthesis translate_on
      
         TextureReqRAMreq <= '0';
         TextureRamWE     <= (others => '0');
      
         if (reset = '1') then
            
            loadstate <= LOADIDLE;
            
         else
            
            case (loadstate) is
            
               when LOADIDLE =>
                  if (startLine = '1' and allinval = '0' and allover = '0' and allunder = '0') then
                     if (loading_mode = '1') then
                        TextureReqRAMreq <= '1';
                        loadstate        <= LOADRAM;
                     end if;
                     -- synthesis translate_off
                     load_posY      <= lineInfo.Y;
                     -- synthesis translate_on
                     load_posX      <= lineInfo.xStart;
                     load_endX      <= lineInfo.xEnd;
                     loadTexture_S  <= lineInfo.Texture_S;
                     loadTexture_T  <= lineInfo.Texture_T;
                     case (settings_textureImage.tex_size) is
                        when SIZE_16BIT => load_MemAddr <= resize(settings_textureImage.tex_base + ((load_linesize + lineInfo.xStart) * 2), 26);
                        when SIZE_32BIT => load_MemAddr <= resize(settings_textureImage.tex_base + ((load_linesize + lineInfo.xStart) * 4), 26);
                        when others     => load_MemAddr <= resize(settings_textureImage.tex_base + ((load_linesize + lineInfo.xStart) * 1), 26);
                     end case;
                     
                  end if;  
                    
               when LOADRAM =>
                  TextureReqRAM_index <= (others => '0');
                  if (TextureReqRAMReady = '1') then
                     loadstate <= LOADRAM2;
                  end if;
                  
               when LOADRAM2 =>
                  loadstate           <= LOADLINE;
                  TextureRAMData_1    <= TextureReqRAMData;
                  if (memAdvance /= 2 or load_MemAddr(2 downto 1) = 3) then 
                     TextureReqRAM_index <= TextureReqRAM_index + 1;
                  end if;
                  if (load_length = 0) then
                     loadstate <= LOADIDLE;
                  end if;
               
               when LOADLINE =>
                  load_posX    <= load_posX + spanAdvance;
                  load_MemAddr <= load_MemAddr + memAdvance;
                  
                  TextureRAMData_1    <= TextureReqRAMData;
                  if (memAdvance /= 2 or load_MemAddr(2 downto 1) = 2) then 
                     TextureReqRAM_index <= TextureReqRAM_index + 1;
                  end if;
                  
                  if (TextureReqRAM_index /= 31) then
                     load_MemAddr <= load_MemAddr + memAdvance;
                  end if;
                 
                  if (loadLineDone = '1') then
                     loadstate <= LOADIDLE;
                  elsif (TextureReqRAM_index = 31 and (memAdvance /= 2 or load_MemAddr(2 downto 1) = 3)) then
                     loadstate        <= LOADRAM;
                     TextureReqRAMreq <= '1';
                  end if;
                  
                  loadTexture_S <= loadTexture_S + (settings_poly.tex_DsDx(31 downto 5) & "00000");
                  loadTexture_T <= loadTexture_T + (settings_poly.tex_DtDx(31 downto 5) & "00000");
                  
                  TextureRamAddr  <= load_Ram0Addr(9 downto 2);
                  
                  if (settings_tile.Tile_format = FORMAT_YUV or (settings_tile.Tile_format = FORMAT_RGBA and settings_textureImage.tex_size = SIZE_32BIT)) then
                     TextureRam0Data <= load_Ram2Data;
                     TextureRam1Data <= load_Ram0Data;
                     TextureRam2Data <= load_Ram2Data;
                     TextureRam3Data <= load_Ram0Data;
                     TextureRam4Data <= load_Ram3Data;
                     TextureRam5Data <= load_Ram1Data;
                     TextureRam6Data <= load_Ram3Data;
                     TextureRam7Data <= load_Ram1Data;
                     if (load_bit3flipped = '1') then
                        TextureRamWE(0) <= '0';
                        TextureRamWE(1) <= '0';
                        TextureRamWE(2) <= '1';
                        TextureRamWE(3) <= '1';
                        TextureRamWE(4) <= '0';
                        TextureRamWE(5) <= '0';
                        TextureRamWE(6) <= '1';
                        TextureRamWE(7) <= '1';
                     else
                        TextureRamWE(0) <= '1';
                        TextureRamWE(1) <= '1';
                        TextureRamWE(2) <= '0';
                        TextureRamWE(3) <= '0';
                        TextureRamWE(4) <= '1';
                        TextureRamWE(5) <= '1';
                        TextureRamWE(6) <= '0';
                        TextureRamWE(7) <= '0';
                     end if;
                  else
                     TextureRam0Data <= load_Ram1Data;
                     TextureRam1Data <= load_Ram0Data;
                     TextureRam2Data <= load_Ram3Data;
                     TextureRam3Data <= load_Ram2Data;
                     TextureRam4Data <= load_Ram1Data;
                     TextureRam5Data <= load_Ram0Data;
                     TextureRam6Data <= load_Ram3Data;
                     TextureRam7Data <= load_Ram2Data;
                     TextureRamWE(0) <= not load_Ram0Addr(10);
                     TextureRamWE(1) <= not load_Ram0Addr(10);
                     TextureRamWE(2) <= not load_Ram0Addr(10);
                     TextureRamWE(3) <= not load_Ram0Addr(10);
                     TextureRamWE(4) <= load_Ram0Addr(10);
                     TextureRamWE(5) <= load_Ram0Addr(10);
                     TextureRamWE(6) <= load_Ram0Addr(10);
                     TextureRamWE(7) <= load_Ram0Addr(10);
                  end if;

                  -- synthesis translate_off
                  export_load_done        <= '1'; 
                  export_loadFetch.addr   <= resize(load_MemAddr, 32);
                  export_loadFetch.data   <= (others => '0');
                  export_loadFetch.x      <= resize(load_posX, 16);
                  export_loadFetch.y      <= resize(load_posY, 16);
                  export_loadFetch.debug1 <= (others => '0');
                  export_loadFetch.debug2 <= 19x"0" & unsigned(load_S_corrected);
                  export_loadFetch.debug3 <= 19x"0" & unsigned(load_T_corrected);
                  
                  export_loadData.addr   <= resize(load_tmemAddr0(9 downto 0), 32);
                  export_loadData.data   <= unsigned(TextureRAMDataMuxed);
                  export_loadData.x      <= 15x"0" & load_bit3flipped;
                  export_loadData.y      <= 15x"0" & load_hibit;
                  export_loadData.debug1 <= resize(load_tmemAddr1(9 downto 0), 32);
                  export_loadData.debug2 <= resize(load_tmemAddr2(9 downto 0), 32);
                  export_loadData.debug3 <= resize(load_tmemAddr3(9 downto 0), 32);
                  
                  export_loadValue.x      <= (others => '0');
                  export_loadValue.y      <= (others => '0');
                  if (settings_tile.Tile_format = FORMAT_YUV or (settings_tile.Tile_format = FORMAT_RGBA and settings_textureImage.tex_size = SIZE_32BIT)) then
                     if (load_bit3flipped = '1') then
                        export_loadValue.addr   <= 22x"0" & load_Ram2Addr(9 downto 0);
                     else
                        export_loadValue.addr   <= 22x"0" & load_Ram0Addr(9 downto 0);
                     end if;
                     export_loadValue.data   <= 48x"0" & unsigned(load_Ram0Data);
                     export_loadValue.debug1 <= 16x"0" & unsigned(load_Ram2Data);
                     export_loadValue.debug2 <= 16x"0" & unsigned(load_Ram1Data);
                     export_loadValue.debug3 <= 16x"0" & unsigned(load_Ram3Data);
                  else
                     export_loadValue.addr   <= 21x"0" & load_Ram0Addr;
                     export_loadValue.data   <= 48x"0" & unsigned(load_Ram0Data);
                     export_loadValue.debug1 <= 16x"0" & unsigned(load_Ram1Data);
                     export_loadValue.debug2 <= 16x"0" & unsigned(load_Ram2Data);
                     export_loadValue.debug3 <= 16x"0" & unsigned(load_Ram3Data);
                  end if;
                  -- synthesis translate_on
            
            end case; -- loadstate
            
         end if;
      end if;
   end process;
   
   
   -------- line export
   
   -- synthesis translate_off
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         export_line_done  <= '0'; 
         
         if (linestate = LINEIDLE and loadstate = LOADIDLE) then
            if (startLine = '1' and allinval = '0' and allover = '0' and allunder = '0') then
               export_line_done        <= '1'; 
               export_line_list.y      <= resize(lineInfo.y, 16);
               export_line_list.debug1 <= resize(lineInfo.xStart, 32);
               export_line_list.debug2 <= resize(lineInfo.xEnd, 32);
               export_line_list.debug3 <= resize(unsigned(lineInfo.unscrx), 32);
            end if;
         end if;
         
      end if;
    end process;  
   -- synthesis translate_on
   

end architecture;





