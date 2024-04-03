library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;
use STD.textio.all;     

use work.pFunctions.all;

package pRDP is

   type tsettings_poly is record
      lft            : std_logic;
      maxLODlevel    : unsigned(2 downto 0);
      tile           : unsigned(2 downto 0);
      YL             : signed(13 downto 0);
      YM             : signed(13 downto 0);
      YH             : signed(13 downto 0);
      XL             : signed(31 downto 0);
      DXLDy          : signed(29 downto 0);
      XH             : signed(31 downto 0);
      DXHDy          : signed(29 downto 0);
      XM             : signed(31 downto 0);
      DXMDy          : signed(29 downto 0);
      shade_Color_R  : signed(31 downto 0);
      shade_Color_G  : signed(31 downto 0);
      shade_Color_B  : signed(31 downto 0);
      shade_Color_A  : signed(31 downto 0);
      shade_DrDx     : signed(31 downto 0);
      shade_DgDx     : signed(31 downto 0);
      shade_DbDx     : signed(31 downto 0);
      shade_DaDx     : signed(31 downto 0);
      shade_DrDe     : signed(31 downto 0);
      shade_DgDe     : signed(31 downto 0);
      shade_DbDe     : signed(31 downto 0);
      shade_DaDe     : signed(31 downto 0);
      shade_DrDy     : signed(31 downto 0);
      shade_DgDy     : signed(31 downto 0);
      shade_DbDy     : signed(31 downto 0);
      shade_DaDy     : signed(31 downto 0);
      tex_Texture_S  : signed(31 downto 0);
      tex_Texture_T  : signed(31 downto 0);
      tex_Texture_W  : signed(31 downto 0);
      tex_DsDx       : signed(31 downto 0);
      tex_DtDx       : signed(31 downto 0);
      tex_DwDx       : signed(31 downto 0);
      tex_DsDe       : signed(31 downto 0);
      tex_DtDe       : signed(31 downto 0);
      tex_DwDe       : signed(31 downto 0);
      tex_DsDy       : signed(31 downto 0);
      tex_DtDy       : signed(31 downto 0);
      tex_DwDy       : signed(31 downto 0);
      zBuffer_Z      : signed(31 downto 0);
      zBuffer_DzDx   : signed(31 downto 0);
      zBuffer_DzDe   : signed(31 downto 0);
      zBuffer_DzDy   : signed(31 downto 0);
   end record;    

   constant SETTINGSPOLYINIT : tsettings_poly := 
   (
      lft            => '0',
      maxLODlevel    => (others => '0'),
      tile           => (others => '0'),
      others => (others => '0')
   );  
   
   type tsettings_KEYRGB is record
      center_R  : unsigned(7 downto 0);
      center_G  : unsigned(7 downto 0);
      center_B  : unsigned(7 downto 0);      
      scale_R   : unsigned(7 downto 0);
      scale_G   : unsigned(7 downto 0);
      scale_B   : unsigned(7 downto 0);      
      width_R   : unsigned(11 downto 0);
      width_G   : unsigned(11 downto 0);
      width_B   : unsigned(11 downto 0);
   end record; 

   type tsettings_Convert is record
      K0  : signed(8 downto 0);
      K1  : signed(8 downto 0);
      K2  : signed(8 downto 0);
      K3  : signed(8 downto 0);
      K4  : signed(8 downto 0);
      K5  : signed(8 downto 0);
   end record;

   type tsettings_scissor is record
      ScissorXL     : unsigned(11 downto 0);
      ScissorXH     : unsigned(11 downto 0);
      ScissorYL     : unsigned(11 downto 0);
      ScissorYH     : unsigned(11 downto 0);
      ScissorField  : std_logic;
      ScissorOdd    : std_logic;
   end record;   

   constant SETTINGSSCISSORINIT : tsettings_scissor := 
   (
      ScissorField   => '0',
      ScissorOdd     => '0',
      others => (others => '0')
   );   

   type tsettings_Z is record
      Delta_Z     : unsigned(15 downto 0);
      Primitive_Z : unsigned(14 downto 0);
   end record;      
   
   type tsettings_otherModes is record
      alphaCompare       : std_logic;
      ditherAlpha        : std_logic;
      zSourceSel         : std_logic;
      AntiAlias          : std_logic;
      zCompare           : std_logic;
      zUpdate            : std_logic;
      imageRead          : std_logic;
      colorOnCvg         : std_logic;
      cvgDest            : unsigned(1 downto 0);
      zMode              : unsigned(1 downto 0);
      cvgTimesAlpha      : std_logic;
      alphaCvgSelect     : std_logic;
      forceBlend         : std_logic;
      blend_m2b1         : unsigned(1 downto 0);
      blend_m2b0         : unsigned(1 downto 0);
      blend_m2a1         : unsigned(1 downto 0);
      blend_m2a0         : unsigned(1 downto 0);
      blend_m1b1         : unsigned(1 downto 0);
      blend_m1b0         : unsigned(1 downto 0);
      blend_m1a1         : unsigned(1 downto 0);
      blend_m1a0         : unsigned(1 downto 0);
      alphaDitherSel     : unsigned(1 downto 0);
      rgbDitherSel       : unsigned(1 downto 0);
      key                : std_logic;
      convertOne         : std_logic;
      biLerp1            : std_logic;
      biLerp0            : std_logic;
      midTexel           : std_logic;
      sampleType         : std_logic;
      tlutType           : std_logic;
      enTlut             : std_logic;
      texLod             : std_logic;
      sharpenTex         : std_logic;
      detailTex          : std_logic;
      perspTex           : std_logic;
      cycleType          : unsigned(1 downto 0);
      atomicPrim         : std_logic;
   end record;   

   constant SETTINGSOTHERMODESINIT : tsettings_otherModes := 
   (
      alphaCompare       => '0',
      ditherAlpha        => '0',
      zSourceSel         => '0',
      AntiAlias          => '0',
      zCompare           => '0',
      zUpdate            => '0',
      imageRead          => '0',
      colorOnCvg         => '0',
      cvgTimesAlpha      => '0',
      alphaCvgSelect     => '0',
      forceBlend         => '0',
      key                 => '0',
      convertOne          => '0',
      biLerp1             => '0',
      biLerp0             => '0',
      midTexel            => '0',
      sampleType          => '0',
      tlutType            => '0',
      enTlut              => '0',
      texLod              => '0',
      sharpenTex          => '0',
      detailTex           => '0',
      perspTex            => '0',
      atomicPrim          => '0',
      others => (others => '0')
   );    
   
   type tsettings_fillcolor is record
      color     : unsigned(31 downto 0);
   end record;        
   
   type tsettings_fogcolor is record
      fog_A     : unsigned(7 downto 0);
      fog_B     : unsigned(7 downto 0);
      fog_G     : unsigned(7 downto 0);
      fog_R     : unsigned(7 downto 0);
   end record;   
   
   type tsettings_blendcolor is record
      blend_A     : unsigned(7 downto 0);
      blend_B     : unsigned(7 downto 0);
      blend_G     : unsigned(7 downto 0);
      blend_R     : unsigned(7 downto 0);
   end record;    

   type tsettings_primcolor is record
      prim_A            : unsigned(7 downto 0);
      prim_B            : unsigned(7 downto 0);
      prim_G            : unsigned(7 downto 0);
      prim_R            : unsigned(7 downto 0);
      prim_levelFrac    : unsigned(7 downto 0);
      prim_minLevel     : unsigned(4 downto 0);
   end record;    
   
   type tsettings_envcolor is record
      env_A     : unsigned(7 downto 0);
      env_B     : unsigned(7 downto 0);
      env_G     : unsigned(7 downto 0);
      env_R     : unsigned(7 downto 0);
   end record;   
   
   type tsettings_combineMode is record
      combine_add_A_1   : unsigned(2 downto 0);
      combine_sub_b_A_1 : unsigned(2 downto 0);
      combine_add_R_1   : unsigned(2 downto 0);
      combine_add_A_0   : unsigned(2 downto 0);
      combine_sub_b_A_0 : unsigned(2 downto 0);
      combine_add_R_0   : unsigned(2 downto 0);
      combine_mul_A_1   : unsigned(2 downto 0);
      combine_sub_a_A_1 : unsigned(2 downto 0);
      combine_sub_b_R_1 : unsigned(3 downto 0);
      combine_sub_b_R_0 : unsigned(3 downto 0);
      combine_mul_R_1   : unsigned(4 downto 0);
      combine_sub_a_R_1 : unsigned(3 downto 0);
      combine_mul_A_0   : unsigned(2 downto 0);
      combine_sub_a_A_0 : unsigned(2 downto 0);
      combine_mul_R_0   : unsigned(4 downto 0);
      combine_sub_a_R_0 : unsigned(3 downto 0);
   end record;  
   
   type tsettings_textureImage is record
      tex_base      : unsigned(24 downto 0);
      tex_width_m1  : unsigned(9 downto 0);
      tex_size      : unsigned(1 downto 0);
      tex_format    : unsigned(2 downto 0);
   end record; 
   
   type tsettings_colorImage is record
      FB_base      : unsigned(24 downto 0);
      FB_width_m1  : unsigned(9 downto 0);
      FB_size      : unsigned(1 downto 0);
      FB_format    : unsigned(2 downto 0);
   end record; 

   type tsettings_tile is record
      Tile_sh        : unsigned(11 downto 0);
      Tile_sl        : unsigned(11 downto 0);
      Tile_th        : unsigned(11 downto 0);
      Tile_tl        : unsigned(11 downto 0);
      Tile_format    : unsigned(2 downto 0);
      Tile_size      : unsigned(1 downto 0);
      Tile_line      : unsigned(8 downto 0);
      Tile_TmemAddr  : unsigned(8 downto 0);
      Tile_palette   : unsigned(3 downto 0);
      Tile_clampT    : std_logic;
      Tile_mirrorT   : std_logic;
      Tile_maskT     : unsigned(3 downto 0);
      Tile_shiftT    : unsigned(3 downto 0);
      Tile_clampS    : std_logic;
      Tile_mirrorS   : std_logic;
      Tile_maskS     : unsigned(3 downto 0);
      Tile_shiftS    : unsigned(3 downto 0);
   end record; 
   
   constant SETTINGSTILEINIT : tsettings_tile := 
   (
      Tile_clampT      => '0',
      Tile_mirrorT     => '0',
      Tile_clampS      => '0',
      Tile_mirrorS     => '0',
      others => (others => '0')
   );  

   type tsettings_loadtype is
   (
      LOADTYPE_TLUT,
      LOADTYPE_BLOCK,
      LOADTYPE_TILE
   ); 
   
   type tcolor3_u8  is array(0 to 2) of unsigned(7 downto 0);
   type tcolor3_u9  is array(0 to 2) of unsigned(8 downto 0);
   type tcolor3_u13 is array(0 to 2) of unsigned(12 downto 0);
   type tcolor3_u14 is array(0 to 2) of unsigned(13 downto 0);
   type tcolor3_u30 is array(0 to 2) of unsigned(29 downto 0);
   type tcolor3_s10 is array(0 to 2) of signed(9 downto 0);
   type tcolor3_s12 is array(0 to 2) of signed(11 downto 0);
   type tcolor3_s16 is array(0 to 2) of signed(15 downto 0);
   type tcolor3_s20 is array(0 to 2) of signed(19 downto 0);
   type tcolor3_s32 is array(0 to 2) of signed(31 downto 0);
   
   type tcolor4_u8  is array(0 to 3) of unsigned(7 downto 0);
   type tcolor4_u9  is array(0 to 3) of unsigned(8 downto 0);
   type tcolor4_u12 is array(0 to 3) of unsigned(11 downto 0);
   type tcolor4_u32 is array(0 to 3) of unsigned(31 downto 0);
   type tcolor4_s16 is array(0 to 3) of signed(15 downto 0);
   type tcolor4_s32 is array(0 to 3) of signed(31 downto 0);
   
   type tcolor44_u9 is array(0 to 3) of tcolor4_u9;
   
   type tTextureRamAddr is array(0 to 7) of std_logic_vector(7 downto 0);
   type tTextureRamData is array(0 to 7) of std_logic_vector(15 downto 0);

   constant SIZE_4BIT  : unsigned(1 downto 0) := "00";
   constant SIZE_8BIT  : unsigned(1 downto 0) := "01";
   constant SIZE_16BIT : unsigned(1 downto 0) := "10";
   constant SIZE_32BIT : unsigned(1 downto 0) := "11";

   constant FORMAT_RGBA : unsigned(2 downto 0) := "000";
   constant FORMAT_YUV  : unsigned(2 downto 0) := "001";
   constant FORMAT_CI   : unsigned(2 downto 0) := "010";
   constant FORMAT_IA   : unsigned(2 downto 0) := "011";
   constant FORMAT_I    : unsigned(2 downto 0) := "100";
   
   constant TEXMODE_UNFILTERED : unsigned(1 downto 0) := "00";
   constant TEXMODE_UPPER      : unsigned(1 downto 0) := "10";
   constant TEXMODE_LOWER      : unsigned(1 downto 0) := "11";

   -- export
   -- synthesis translate_off
   type rdp_export_type is record
      addr           : unsigned(31 downto 0);
      data           : unsigned(63 downto 0);
      x              : unsigned(15 downto 0);
      y              : unsigned(15 downto 0);
      debug1         : unsigned(31 downto 0);
      debug2         : unsigned(31 downto 0);
      debug3         : unsigned(31 downto 0);
   end record; 
   
   procedure export_gpu32(id : integer; count: integer; item : rdp_export_type; file outfile : text);
   procedure export_gpu64(id : integer; count: integer; item : rdp_export_type; file outfile : text);
   -- synthesis translate_on

end package;

package body pRDP is
   
   -- synthesis translate_off
   procedure export_gpu32(id : integer; count: integer; item : rdp_export_type; file outfile : text) is
      variable line_out : line;
   begin
      case (id) is
         when  3 => write(line_out, string'("PipeO: I ")); 
         when  4 => write(line_out, string'("Color: I ")); 
         when  7 => write(line_out, string'("TexFt: I ")); 
         when 11 => write(line_out, string'("TexCoord: I ")); 
         when 12 => write(line_out, string'("ZBuffer: I ")); 
         when 13 => write(line_out, string'("TexColor: I ")); 
         when 15 => write(line_out, string'("CopyByte: I ")); 
         when 16 => write(line_out, string'("LoadFetch: I ")); 
         when 18 => write(line_out, string'("LoadValue: I "));  
         when 19 => write(line_out, string'("LOD: I ")); 
         when 24 => write(line_out, string'("FBMem: I ")); 
         when 25 => write(line_out, string'("RGBA: I ")); 
         when 26 => write(line_out, string'("LODP: I ")); 
         when others => null;
      end case;
      
      write(line_out, to_string_len(count + 1, 8));
      write(line_out, string'(" A ")); 
      write(line_out, to_hstring(item.addr));
      write(line_out, string'(" D ")); 
      write(line_out, to_hstring(item.data(31 downto 0)));
      write(line_out, string'(" X ")); 
      write(line_out, to_string_len(to_integer(item.x), 5));
      write(line_out, string'(" Y ")); 
      write(line_out, to_string_len(to_integer(item.y), 5));
      write(line_out, string'(" D1 "));
      write(line_out, to_hstring(item.debug1));
      write(line_out, string'(" D2 "));
      write(line_out, to_hstring(item.debug2));
      write(line_out, string'(" D3 "));
      write(line_out, to_hstring(item.debug3));
      writeline(outfile, line_out);
   end procedure export_gpu32;
   
   procedure export_gpu64(id : integer; count: integer; item : rdp_export_type; file outfile : text) is
      variable line_out : line;
   begin
      case (id) is
         when 14 => write(line_out, string'("CopyFetch: I ")); 
         when 17 => write(line_out, string'("LoadData: I ")); 
         when 23 => write(line_out, string'("Comb: I ")); 
         when others => null;
      end case;
      
      write(line_out, to_string_len(count + 1, 8));
      write(line_out, string'(" A ")); 
      write(line_out, to_hstring(item.addr));
      write(line_out, string'(" D ")); 
      write(line_out, to_hstring(item.data));
      write(line_out, string'(" X ")); 
      write(line_out, to_string_len(to_integer(item.x), 5));
      write(line_out, string'(" Y ")); 
      write(line_out, to_string_len(to_integer(item.y), 5));
      write(line_out, string'(" D1 "));
      write(line_out, to_hstring(item.debug1));
      write(line_out, string'(" D2 "));
      write(line_out, to_hstring(item.debug2));
      write(line_out, string'(" D3 "));
      write(line_out, to_hstring(item.debug3));
      writeline(outfile, line_out);
   end procedure export_gpu64;
   -- synthesis translate_on

end pRDP;