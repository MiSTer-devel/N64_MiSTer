library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

use work.pRDP.all;

entity RDP_TexSingle is
   generic
   (
      hasYUV : std_logic
   );
   port 
   (
      clk1x                : in  std_logic;
      trigger              : in  std_logic;
      step2                : in  std_logic;
      mode2                : in  std_logic;
         
      error_texMode_out    : out std_logic;  

      settings_otherModes  : in  tsettings_otherModes;
      settings_Convert     : in  tsettings_Convert;
      settings_tile_1      : in  tsettings_tile;      
      settings_tile_2      : in  tsettings_tile;      
      
      data4                : in  unsigned(3 downto 0);
      data8                : in  unsigned(7 downto 0);
      data16               : in  unsigned(15 downto 0);
      data32               : in  unsigned(31 downto 0);
      dataY                : in  unsigned(7 downto 0);
      palette16            : in  unsigned(15 downto 0);
      
      -- synthesis translate_off
      addr_base_1          : in  unsigned(11 downto 0);
      tex_palette_addr     : in  std_logic_vector(7 downto 0);
      
      export_TexFt_addr    : out unsigned(31 downto 0);
      export_TexFt_data    : out unsigned(31 downto 0);
      export_TexFt_db1     : out unsigned(31 downto 0);
      export_TexFt_db3     : out unsigned(31 downto 0);
      -- synthesis translate_on
      
      tex_color            : out tcolor4_u9
   );
end entity;

architecture arch of RDP_TexSingle is
  
   signal error_texMode             : std_logic;
   signal tex_color_read            : tcolor3_u8;
   signal tex_alpha_read            : unsigned(7 downto 0);
   
   signal tex_Y                     : unsigned(7 downto 0);
   signal tex_U                     : signed(8 downto 0);
   signal tex_V                     : signed(8 downto 0);
   
   -- second cycle   
   signal tex_color_save            : tcolor3_u8;
   signal tex_alpha_save            : unsigned(7 downto 0);   
   signal tex_color_s1              : tcolor3_u8 := (others => (others => '0'));
   signal tex_alpha_s1              : unsigned(7 downto 0) := (others => '0');   
   signal tex_color_s2              : tcolor3_u8 := (others => (others => '0'));
   signal tex_alpha_s2              : unsigned(7 downto 0) := (others => '0');
   
   signal YUV_MUL_R                 : signed(18 downto 0);
   signal YUV_MUL_G                 : signed(18 downto 0);
   signal YUV_MUL_B                 : signed(18 downto 0);
   signal tex_Y_1                   : unsigned(7 downto 0);
   
   -- YUV calc
   signal YUV_K0                    : signed(9 downto 0);
   signal YUV_K1                    : signed(9 downto 0);
   signal YUV_K2                    : signed(9 downto 0);
   signal YUV_K3                    : signed(9 downto 0);
   signal YUV_ADD80_R               : signed(18 downto 0);
   signal YUV_ADD80_G               : signed(18 downto 0);
   signal YUV_ADD80_B               : signed(18 downto 0);    
   signal YUV_ADDY_R                : signed(8 downto 0);
   signal YUV_ADDY_G                : signed(8 downto 0);
   signal YUV_ADDY_B                : signed(8 downto 0);   
   
   signal YUV_ADDY_R_next           : signed(8 downto 0) := (others => '0');
   signal YUV_ADDY_G_next           : signed(8 downto 0) := (others => '0');
   signal YUV_ADDY_B_next           : signed(8 downto 0) := (others => '0');
   signal YUV_ADDY_A_next           : unsigned(7 downto 0) := (others => '0');
      
   -- synthesis translate_off 
   signal exportNext_TexFt_addr     : unsigned(31 downto 0);
   signal exportNext_TexFt_data     : unsigned(31 downto 0);
   signal exportNext_TexFt_db1      : unsigned(31 downto 0);
   signal exportNext_TexFt_db3      : unsigned(31 downto 0);   
   
   signal exportNextS1_TexFt_addr   : unsigned(31 downto 0) := (others => '0');
   signal exportNextS1_TexFt_data   : unsigned(31 downto 0) := (others => '0');
   signal exportNextS1_TexFt_db1    : unsigned(31 downto 0) := (others => '0');
   signal exportNextS1_TexFt_db3    : unsigned(31 downto 0) := (others => '0');   
   signal exportNextS2_TexFt_addr   : unsigned(31 downto 0) := (others => '0');
   signal exportNextS2_TexFt_data   : unsigned(31 downto 0) := (others => '0');
   signal exportNextS2_TexFt_db1    : unsigned(31 downto 0) := (others => '0');
   signal exportNextS2_TexFt_db3    : unsigned(31 downto 0) := (others => '0');
   -- synthesis translate_on
  
begin 
    
   process (all)
   begin
   
      error_texMode <= '0';
         
      tex_color_read(0) <= (others => '0');
      tex_color_read(1) <= (others => '0');
      tex_color_read(2) <= (others => '0');
      tex_alpha_read    <= (others => '0');
      
      -- synthesis translate_off
      exportNext_TexFt_addr <= (others => '0');
      exportNext_TexFt_data <= (others => '0');
      exportNext_TexFt_db1  <= (others => '0');
      exportNext_TexFt_db3  <= (others => '0');
      -- synthesis translate_on
      
      case (settings_tile_1.Tile_size) is
         
         when SIZE_4BIT =>
            case (settings_tile_1.Tile_format) is
               when FORMAT_YUV => error_texMode <= '1'; -- should not be allowed
               
               when FORMAT_RGBA =>
                  tex_color_read(0) <= data4 & data4;
                  tex_color_read(1) <= data4 & data4;
                  tex_color_read(2) <= data4 & data4;
                  tex_alpha_read    <= data4 & data4;
                  -- synthesis translate_off
                  if (settings_otherModes.enTlut = '1') then
                     exportNext_TexFt_addr <= 20x"0" & '1' & unsigned(tex_palette_addr) & "000";
                     exportNext_TexFt_db1  <= resize(addr_base_1, 32);
                     exportNext_TexFt_db3  <= x"0000000" & data4;
                  else
                     exportNext_TexFt_addr <= 24x"0" & data4 & data4;
                     exportNext_TexFt_data(23 downto 16) <= data4 & data4;
                     exportNext_TexFt_data(15 downto  8) <= data4 & data4;
                     exportNext_TexFt_data( 7 downto  0) <= data4 & data4;
                     exportNext_TexFt_data(31 downto 24) <= data4 & data4;
                     exportNext_TexFt_db1  <= resize(addr_base_1, 32);
                     exportNext_TexFt_db3  <= x"000000" & data8;
                  end if;
                  -- synthesis translate_on
                  
               when FORMAT_CI =>
                  tex_color_read(0) <= settings_tile_1.Tile_palette & data4;
                  tex_color_read(1) <= settings_tile_1.Tile_palette & data4;
                  tex_color_read(2) <= settings_tile_1.Tile_palette & data4;
                  tex_alpha_read    <= settings_tile_1.Tile_palette & data4;
                  -- synthesis translate_off
                  if (settings_otherModes.enTlut = '1') then
                     exportNext_TexFt_addr <= 20x"0" & '1' & unsigned(tex_palette_addr) & "000";
                     exportNext_TexFt_db1  <= resize(addr_base_1, 32);
                     exportNext_TexFt_db3  <= x"0000000" & data4;
                  else
                     exportNext_TexFt_addr <= 24x"0" & data4 & data4;
                     exportNext_TexFt_data(23 downto 16) <= data4 & data4;
                     exportNext_TexFt_data(15 downto  8) <= data4 & data4;
                     exportNext_TexFt_data( 7 downto  0) <= data4 & data4;
                     exportNext_TexFt_data(31 downto 24) <= data4 & data4;
                     exportNext_TexFt_db1  <= resize(addr_base_1, 32);
                     exportNext_TexFt_db3  <= x"000000" & data8;
                  end if;
                  -- synthesis translate_on
                  
               when FORMAT_IA =>
                  tex_color_read(0) <= data4(3 downto 1) & data4(3 downto 1) & data4(3 downto 2);
                  tex_color_read(1) <= data4(3 downto 1) & data4(3 downto 1) & data4(3 downto 2);
                  tex_color_read(2) <= data4(3 downto 1) & data4(3 downto 1) & data4(3 downto 2);
                  tex_alpha_read    <= data4(3 downto 1) & data4(3 downto 1) & data4(3 downto 2);
                  if (data4(0) = '1') then tex_alpha_read <= (others => '1'); else tex_alpha_read <= (others => '0'); end if;
                  -- synthesis translate_off
                  exportNext_TexFt_addr <= 24x"0" & data4(3 downto 1) & data4(3 downto 1) & data4(3 downto 2);
                  exportNext_TexFt_data(23 downto 16) <= data4(3 downto 1) & data4(3 downto 1) & data4(3 downto 2);
                  exportNext_TexFt_data(15 downto  8) <= data4(3 downto 1) & data4(3 downto 1) & data4(3 downto 2);
                  exportNext_TexFt_data( 7 downto  0) <= data4(3 downto 1) & data4(3 downto 1) & data4(3 downto 2);
                  if (data4(0) = '1') then exportNext_TexFt_data(31 downto 24) <= (others => '1'); else exportNext_TexFt_data(31 downto 24) <= (others => '0'); end if;
                  exportNext_TexFt_db1  <= resize(addr_base_1, 32);
                  exportNext_TexFt_db3  <= x"0000000" & data4;
                  -- synthesis translate_on
               
               when FORMAT_I => null;
                  tex_color_read(0) <= data4 & data4;
                  tex_color_read(1) <= data4 & data4;
                  tex_color_read(2) <= data4 & data4;
                  tex_alpha_read    <= data4 & data4;
                  -- synthesis translate_off
                  exportNext_TexFt_addr <= 24x"0" & data4 & data4;
                  exportNext_TexFt_data(23 downto 16) <= data4 & data4;
                  exportNext_TexFt_data(15 downto  8) <= data4 & data4;
                  exportNext_TexFt_data( 7 downto  0) <= data4 & data4;
                  exportNext_TexFt_data(31 downto 24) <= data4 & data4;
                  exportNext_TexFt_db1  <= resize(addr_base_1, 32);
                  exportNext_TexFt_db3  <= x"000000" & data8;
                  -- synthesis translate_on
               
               when others => null;
            end case;
         
         when SIZE_8BIT =>
            case (settings_tile_1.Tile_format) is

               when FORMAT_YUV => error_texMode <= '1'; -- should not be allowed
               
               when FORMAT_RGBA | FORMAT_CI => -- 8 bit RGBA behaves like CI
                  tex_color_read(0) <= data8;
                  tex_color_read(1) <= data8;
                  tex_color_read(2) <= data8;
                  tex_alpha_read    <= data8;
                  -- synthesis translate_off
                  exportNext_TexFt_addr <= 20x"0" & '1' & unsigned(tex_palette_addr) & "000";
                  exportNext_TexFt_db1  <= resize(addr_base_1, 32);
                  exportNext_TexFt_db3  <= x"000000" & data8;
                  -- synthesis translate_on
                  
               when FORMAT_IA =>
                  tex_color_read(0) <= data8(7 downto 4) & data8(7 downto 4);
                  tex_color_read(1) <= data8(7 downto 4) & data8(7 downto 4);
                  tex_color_read(2) <= data8(7 downto 4) & data8(7 downto 4);
                  tex_alpha_read    <= data8(3 downto 0) & data8(3 downto 0);
                  -- synthesis translate_off
                  exportNext_TexFt_addr <= 24x"0" & data8(7 downto 4) & data8(7 downto 4);
                  exportNext_TexFt_data(23 downto 16) <= data8(7 downto 4) & data8(7 downto 4);
                  exportNext_TexFt_data(15 downto  8) <= data8(7 downto 4) & data8(7 downto 4);
                  exportNext_TexFt_data( 7 downto  0) <= data8(7 downto 4) & data8(7 downto 4);
                  exportNext_TexFt_data(31 downto 24) <= data8(3 downto 0) & data8(3 downto 0);
                  exportNext_TexFt_db1  <= resize(addr_base_1, 32);
                  exportNext_TexFt_db3  <= x"000000" & data8;
                  -- synthesis translate_on
               
               when FORMAT_I =>
                  tex_color_read(0) <= data8;
                  tex_color_read(1) <= data8;
                  tex_color_read(2) <= data8;
                  tex_alpha_read    <= data8;
                  -- synthesis translate_off
                  exportNext_TexFt_addr <= 24x"0" & data8;
                  exportNext_TexFt_data(23 downto 16) <= data8;
                  exportNext_TexFt_data(15 downto  8) <= data8;
                  exportNext_TexFt_data( 7 downto  0) <= data8;
                  exportNext_TexFt_data(31 downto 24) <= data8;
                  exportNext_TexFt_db1  <= resize(addr_base_1, 32);
                  exportNext_TexFt_db3  <= x"00000000";
                  -- synthesis translate_on
               
               when others => null;
            end case;
         
         when SIZE_16BIT =>
            case (settings_tile_1.Tile_format) is
               when FORMAT_RGBA | FORMAT_CI => -- FORMAT_CI behaves like RGB? used like that in clayfighter first screen logo
                  tex_color_read(0) <= data16(15 downto 11) & data16(15 downto 13);
                  tex_color_read(1) <= data16(10 downto  6) & data16(10 downto  8);
                  tex_color_read(2) <= data16( 5 downto  1) & data16( 5 downto  3);
                  if (data16(0) = '1') then tex_alpha_read <= (others => '1'); else tex_alpha_read <= (others => '0'); end if;
                  -- synthesis translate_off
                  if (settings_otherModes.enTlut = '1') then
                     exportNext_TexFt_addr <= x"00000" & '1' & data16(15 downto 8) & "000";
                     exportNext_TexFt_db1  <= resize(addr_base_1, 32);
                  else
                     exportNext_TexFt_addr <= (others => '0');
                     exportNext_TexFt_db1  <= resize(addr_base_1 & '0', 32);
                  end if;
                  exportNext_TexFt_data(23 downto 16) <= data16(15 downto 11) & data16(15 downto 13);
                  exportNext_TexFt_data(15 downto  8) <= data16(10 downto  6) & data16(10 downto  8);
                  exportNext_TexFt_data( 7 downto  0) <= data16( 5 downto  1) & data16( 5 downto  3);
                  if (data16(0) = '1') then exportNext_TexFt_data(31 downto 24) <= (others => '1'); else exportNext_TexFt_data(31 downto 24) <= (others => '0'); end if;
                  
                  exportNext_TexFt_db3  <= x"0000" & data16;
                  -- synthesis translate_on
               
               when FORMAT_YUV => 
                  tex_color_read(0) <= data16(15 downto 8);
                  tex_color_read(1) <= data16(7 downto  0);
                  tex_color_read(2) <= dataY;
                  -- synthesis translate_off
                  exportNext_TexFt_addr <= 24x"0" & dataY;
                  exportNext_TexFt_data(23 downto 16) <= data16(15 downto 8);
                  exportNext_TexFt_data( 7 downto  0) <= data16( 7 downto 0);
                  exportNext_TexFt_db1  <= resize(addr_base_1 & '0', 32);
                  exportNext_TexFt_db3  <= x"0000" & data16;
                  -- synthesis translate_on
               
               when FORMAT_IA =>
                  tex_color_read(0) <= data16(15 downto 8);
                  tex_color_read(1) <= data16(15 downto 8);
                  tex_color_read(2) <= data16(15 downto 8);
                  tex_alpha_read    <= data16(7 downto 0);
                  -- synthesis translate_off
                  exportNext_TexFt_addr <= 24x"0" & data16(15 downto 8);
                  exportNext_TexFt_data(23 downto 16) <= data16(15 downto 8);
                  exportNext_TexFt_data(15 downto  8) <= data16(15 downto 8);
                  exportNext_TexFt_data( 7 downto  0) <= data16(15 downto 8);
                  exportNext_TexFt_data(31 downto 24) <= data16(7 downto 0);
                  exportNext_TexFt_db1  <= resize(addr_base_1 & '0', 32);
                  exportNext_TexFt_db3  <= x"0000" & data16;
                  -- synthesis translate_on
               
               when FORMAT_I =>
                  tex_color_read(0) <= data16(15 downto 8);
                  tex_color_read(1) <= data16(7 downto 0);
                  tex_color_read(2) <= data16(15 downto 8);
                  tex_alpha_read    <= data16(7 downto 0);
               
               when others => null;
            end case;
         
         when SIZE_32BIT =>
            case (settings_tile_1.Tile_format) is
               when FORMAT_RGBA =>
                  tex_color_read(0) <= data32(31 downto 24);
                  tex_color_read(1) <= data32(23 downto 16);
                  tex_color_read(2) <= data32(15 downto  8);
                  tex_alpha_read    <= data32( 7 downto  0);
                  -- synthesis translate_off
                  exportNext_TexFt_addr <= (others => '0');
                  exportNext_TexFt_data(31 downto 24) <= data32( 7 downto  0);
                  exportNext_TexFt_data(23 downto 16) <= data32(31 downto 24);
                  exportNext_TexFt_data(15 downto  8) <= data32(23 downto 16);
                  exportNext_TexFt_data( 7 downto  0) <= data32(15 downto  8);
                  exportNext_TexFt_db1  <= resize(addr_base_1 & '0', 32);
                  exportNext_TexFt_db3  <= data32;
                  -- synthesis translate_on
               
               when FORMAT_YUV => error_texMode <= '1'; -- should not be allowed
               when FORMAT_CI => error_texMode <= '1';  -- should not be allowed
               when FORMAT_IA => error_texMode <= '1';  -- should not be allowed
               when FORMAT_I => error_texMode <= '1';   -- should not be allowed
               when others => null;
            end case;
         
         when others => null;
      end case;
            
   end process;
   
   tex_U <= '0' & signed(tex_color_s1(0)) when (settings_otherModes.convertOne = '1' and step2 = '1') else
            not tex_color_read(0)(7) & not tex_color_read(0)(7) & signed(tex_color_read(0)(6 downto 0)) when (settings_tile_1.Tile_format = FORMAT_YUV) else 
            '0' & signed(tex_color_read(0));
   
   tex_V <= '0' & signed(tex_color_s1(1)) when (settings_otherModes.convertOne = '1' and step2 = '1') else
            not tex_color_read(1)(7) & not tex_color_read(1)(7) & signed(tex_color_read(1)(6 downto 0)) when (settings_tile_1.Tile_format = FORMAT_YUV) else 
            '0' & signed(tex_color_read(1));
   
   tex_Y <= tex_color_s1(2) when (settings_otherModes.convertOne = '1' and step2 = '1') else
            tex_color_read(2);
   
   YUV_K0 <= settings_Convert.K0 & '1';
   YUV_K1 <= settings_Convert.K1 & '1';
   YUV_K2 <= settings_Convert.K2 & '1';
   YUV_K3 <= settings_Convert.K3 & '1';
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
   
         error_texMode_out <= '0';
   
         if (trigger = '1') then
            
            error_texMode_out <= error_texMode;
            
            tex_color_s1 <= tex_color_read;
            tex_alpha_s1 <= tex_alpha_read;
            
            -- synthesis translate_off
            exportNextS1_TexFt_addr <= exportNext_TexFt_addr;
            exportNextS1_TexFt_data <= exportNext_TexFt_data;
            exportNextS1_TexFt_db1  <= exportNext_TexFt_db1;
            exportNextS1_TexFt_db3  <= exportNext_TexFt_db3;
            -- synthesis translate_on
         
         end if;
         
         if (step2 = '1') then

            tex_color_s2 <= tex_color_read;
            tex_alpha_s2 <= tex_alpha_read;
            
            -- synthesis translate_off
            exportNextS2_TexFt_addr <= exportNext_TexFt_addr;
            exportNextS2_TexFt_data <= exportNext_TexFt_data;
            exportNextS2_TexFt_db1  <= exportNext_TexFt_db1;
            exportNextS2_TexFt_db3  <= exportNext_TexFt_db3;
            -- synthesis translate_on
         
         end if;
         
         if (hasYUV = '1') then
            if (trigger = '1' or step2 = '1') then      
               YUV_MUL_R <= tex_V * YUV_K0;
               YUV_MUL_G <= (tex_V * YUV_K2) + (tex_U * YUV_K1);
               YUV_MUL_B <= tex_U * YUV_K3;
               tex_Y_1   <= tex_Y;
            end if;
         end if;
         
      end if;
   end process;
   
   YUV_ADD80_R <= YUV_MUL_R + 16x"0080";
   YUV_ADD80_G <= YUV_MUL_G + 16x"0080";
   YUV_ADD80_B <= YUV_MUL_B + 16x"0080";
   
   YUV_ADDY_R <= YUV_ADD80_R(16 downto 8) + ('0' & signed(tex_Y_1));
   YUV_ADDY_G <= YUV_ADD80_G(16 downto 8) + ('0' & signed(tex_Y_1));
   YUV_ADDY_B <= YUV_ADD80_B(16 downto 8) + ('0' & signed(tex_Y_1));
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (hasYUV = '1') then
            if (trigger = '1' or step2 = '1') then      
               YUV_ADDY_R_next <= YUV_ADDY_R;
               YUV_ADDY_G_next <= YUV_ADDY_G;
               YUV_ADDY_B_next <= YUV_ADDY_B;
               YUV_ADDY_A_next <= tex_Y_1;
            end if;
         end if;
         
      end if;
   end process;
   
   tex_color_save <= tex_color_s2 when (step2 = '1') else tex_color_s1;
   tex_alpha_save <= tex_alpha_s2 when (step2 = '1') else tex_alpha_s1;
   
   process (all)
   begin
   
      -- synthesis translate_off
      if (step2 = '1') then
         export_TexFt_addr <= exportNextS2_TexFt_addr;
         export_TexFt_data <= exportNextS2_TexFt_data;
         export_TexFt_db1  <= exportNextS2_TexFt_db1; 
         export_TexFt_db3  <= exportNextS2_TexFt_db3; 
      else
         export_TexFt_addr <= exportNextS1_TexFt_addr;
         export_TexFt_data <= exportNextS1_TexFt_data;
         export_TexFt_db1  <= exportNextS1_TexFt_db1; 
         export_TexFt_db3  <= exportNextS1_TexFt_db3; 
      end if;
      -- synthesis translate_on

      if (hasYUV = '1' and settings_otherModes.cycleType(1) = '0' and (settings_otherModes.biLerp0 = '0' or (settings_otherModes.convertOne = '1' and step2 = '1'))) then
         if (settings_otherModes.cycleType(0) = '1' and settings_otherModes.convertOne = '0') then
            tex_color(0) <= unsigned(YUV_ADDY_R_next);
            tex_color(1) <= unsigned(YUV_ADDY_G_next);
            tex_color(2) <= unsigned(YUV_ADDY_B_next);
            tex_color(3) <= '0' & YUV_ADDY_A_next;
         else
            tex_color(0) <= unsigned(YUV_ADDY_R);
            tex_color(1) <= unsigned(YUV_ADDY_G);
            tex_color(2) <= unsigned(YUV_ADDY_B);
            tex_color(3) <= '0' & tex_Y_1;
         end if;
      elsif (settings_otherModes.enTlut = '1') then
         if (settings_otherModes.tlutType = '1') then
            tex_color(0) <= '0' & palette16(15 downto 8);
            tex_color(1) <= '0' & palette16(15 downto 8);
            tex_color(2) <= '0' & palette16(15 downto 8);
            tex_color(3) <= '0' & palette16(7 downto 0);
            -- synthesis translate_off
            export_TexFt_data(23 downto 16) <= palette16(15 downto 8);
            export_TexFt_data(15 downto  8) <= palette16(15 downto 8);
            export_TexFt_data( 7 downto  0) <= palette16(15 downto 8);
            export_TexFt_data(31 downto 24) <= palette16(7 downto 0);
            if (settings_tile_1.Tile_size = SIZE_4BIT or settings_tile_1.Tile_size = SIZE_8BIT) then
               export_TexFt_db3(31 downto 8)   <= x"00" & palette16;
            else
               export_TexFt_db3(31 downto 16)  <= palette16;
            end if;
            -- synthesis translate_on
         else
            tex_color(0) <= '0' & palette16(15 downto 11) & palette16(15 downto 13);
            tex_color(1) <= '0' & palette16(10 downto  6) & palette16(10 downto  8);
            tex_color(2) <= '0' & palette16( 5 downto  1) & palette16( 5 downto  3);
            if (palette16(0) = '1') then tex_color(3) <= 9x"FF"; else tex_color(3) <= (others => '0'); end if;
            -- synthesis translate_off
            export_TexFt_data(23 downto 16) <= palette16(15 downto 11) & palette16(15 downto 13);
            export_TexFt_data(15 downto  8) <= palette16(10 downto  6) & palette16(10 downto  8);
            export_TexFt_data( 7 downto  0) <= palette16( 5 downto  1) & palette16( 5 downto  3);
            if (palette16(0) = '1') then export_TexFt_data(31 downto 24) <= (others => '1'); else export_TexFt_data(31 downto 24) <= (others => '0'); end if;
            if (settings_tile_1.Tile_size = SIZE_4BIT or settings_tile_1.Tile_size = SIZE_8BIT) then
               export_TexFt_db3(31 downto 8)   <= x"00" & palette16;
            else
               export_TexFt_db3(31 downto 16)  <= palette16;
            end if;
            -- synthesis translate_on
         end if;
      else
         tex_color(0) <= '0' & tex_color_save(0);
         tex_color(1) <= '0' & tex_color_save(1);
         tex_color(2) <= '0' & tex_color_save(2);
         tex_color(3) <= '0' & tex_alpha_save;
      end if;
            
   end process;
   
   
end architecture;





