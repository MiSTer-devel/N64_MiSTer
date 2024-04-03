library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;
use work.pFunctions.all;
use work.pRDP.all;

entity RDP is
   port 
   (
      clk1x                : in  std_logic;
      clk2x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      command_error        : out std_logic;
      errorCombine         : out std_logic;
      error_combineAlpha   : out std_logic;
      error_texMode        : out std_logic; 
      error_drawMode       : out std_logic; 
      error_RDPMEMMUX      : out std_logic; 
      
      CICTYPE              : in  std_logic_vector(3 downto 0);
      
      DISABLEFILTER        : in  std_logic;
      DISABLEDITHER        : in  std_logic;
      DISABLELOD           : in  std_logic;
      write9               : in  std_logic;
      read9                : in  std_logic;
      wait9                : in  std_logic;
      writeZ               : in  std_logic;
      readZ                : in  std_logic;
            
      irq_out              : out std_logic := '0';
            
      bus_addr             : in  unsigned(19 downto 0); 
      bus_dataWrite        : in  std_logic_vector(31 downto 0);
      bus_read             : in  std_logic;
      bus_write            : in  std_logic;
      bus_dataRead         : out std_logic_vector(31 downto 0) := (others => '0');
      bus_done             : out std_logic := '0';
            
      rdram_request        : out std_logic := '0';
      rdram_rnw            : out std_logic := '0'; 
      rdram_address        : out unsigned(27 downto 0):= (others => '0');
      rdram_burstcount     : out unsigned(9 downto 0):= (others => '0');
      rdram_writeMask      : out std_logic_vector(7 downto 0) := (others => '0'); 
      rdram_dataWrite      : out std_logic_vector(63 downto 0) := (others => '0');
      rdram_granted        : in  std_logic;
      rdram_done           : in  std_logic;
      ddr3_DOUT            : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY      : in  std_logic;
            
      fifoout_Din          : out std_logic_vector(91 downto 0) := (others => '0'); -- 64bit data + 20 bit address + 8 byte enables
      fifoout_Wr           : out std_logic := '0';  
      fifoout_nearfull     : in  std_logic;   
      fifoout_empty        : in  std_logic;        
      
      fifooutZ_Din         : out std_logic_vector(91 downto 0) := (others => '0'); -- 64bit data + 20 bit address + 8 byte enables
      fifooutZ_Wr          : out std_logic := '0';  
      fifooutZ_nearfull    : in  std_logic;   
      fifooutZ_empty       : in  std_logic;  
      
      sdram_request        : out std_logic := '0';
      sdram_rnw            : out std_logic := '0'; 
      sdram_address        : out unsigned(26 downto 0):= (others => '0');
      sdram_burstcount     : out unsigned(7 downto 0):= (others => '0');
      sdram_writeMask      : out std_logic_vector(3 downto 0) := (others => '0'); 
      sdram_dataWrite      : out std_logic_vector(31 downto 0) := (others => '0');
      sdram_granted        : in  std_logic;
      sdram_done           : in  std_logic;
      sdram_dataRead       : in  std_logic_vector(31 downto 0);
      sdram_valid          : in  std_logic;
      
      rdp9fifo_Din         : out std_logic_vector(53 downto 0) := (others => '0'); -- 32bit data + 18 bit address + 4bit byte enable
      rdp9fifo_Wr          : out std_logic := '0';  
      rdp9fifo_nearfull    : in  std_logic;  
      rdp9fifo_empty       : in  std_logic;
      
      rdp9fifoZ_Din        : out std_logic_vector(49 downto 0) := (others => '0'); -- 32bit data + 18 bit address
      rdp9fifoZ_Wr         : out std_logic := '0';  
      rdp9fifoZ_nearfull   : in  std_logic;  
      rdp9fifoZ_empty      : in  std_logic;
            
      RSP_RDP_reg_addr     : in  unsigned(4 downto 0);
      RSP_RDP_reg_dataOut  : in  unsigned(31 downto 0);
      RSP_RDP_reg_read     : in  std_logic;
      RSP_RDP_reg_write    : in  std_logic;
      RSP_RDP_reg_dataIn   : out unsigned(31 downto 0) := (others => '0'); 
      
      RSP2RDP_rdaddr       : out unsigned(11 downto 0) := (others => '0'); 
      RSP2RDP_len          : out unsigned(4 downto 0) := (others => '0'); 
      RSP2RDP_req          : out std_logic := '0';
      RSP2RDP_data         : in  std_logic_vector(63 downto 0);
      RSP2RDP_we           : in  std_logic;
      RSP2RDP_done         : in  std_logic;
      
      -- synthesis translate_off
      commandIsIdle        : out std_logic;
      -- synthesis translate_on
      
      SS_reset             : in  std_logic;
      SS_DataWrite         : in  std_logic_vector(63 downto 0);
      SS_Adr               : in  unsigned(0 downto 0);
      SS_wren              : in  std_logic;
      SS_rden              : in  std_logic;
      SS_DataRead          : out std_logic_vector(63 downto 0);
      SS_idle              : out std_logic
   );
end entity;

architecture arch of RDP is

   signal DPC_START_NEXT            : unsigned(23 downto 0) := (others => '0'); -- 0x04100000 (RW): [23:0] DMEM/RDRAM start address
   signal DPC_END_NEXT              : unsigned(23 downto 0) := (others => '0'); -- 0x04100004 (RW): [23:0] DMEM/RDRAM end address
   signal DPC_CURRENT               : unsigned(23 downto 0) := (others => '0'); -- 0x04100008 (R): [23:0] DMEM/RDRAM current address
   signal DPC_STATUS_xbus_dmem_dma  : std_logic := '0';
   signal DPC_STATUS_freeze         : std_logic := '0';
   signal DPC_STATUS_flush          : std_logic := '0';
   signal DPC_STATUS_start_gclk     : std_logic := '0';
   signal DPC_STATUS_cbuf_ready     : std_logic := '0';
   signal DPC_STATUS_dma_busy       : std_logic := '0';
   signal DPC_STATUS_end_pending    : std_logic := '0';
   signal DPC_STATUS_start_pending  : std_logic := '0';
   signal DPC_CLOCK                 : unsigned(23 downto 0) := (others => '0'); -- 0x04100010 (R): [23:0] clock counter
   signal DPC_BUFBUSY               : unsigned(23 downto 0) := (others => '0'); -- 0x04100014 (R): [23:0] clock counter
   signal DPC_PIPEBUSY              : unsigned(23 downto 0) := (others => '0'); -- 0x04100018 (R): [23:0] clock counter
   signal DPC_TMEM                  : unsigned(23 downto 0) := (others => '0'); -- 0x0410001C (R): [23:0] clock counter

   -- bus/mem multiplexing
   signal bus_read_latched          : std_logic := '0';
   signal bus_write_latched         : std_logic := '0';
   signal reg_addr                  : unsigned(19 downto 0); 
   signal reg_dataWrite             : std_logic_vector(31 downto 0);

   -- Command RAM
   signal DPC_END                   : unsigned(23 downto 0) := (others => '0');
   
   signal RDRAM_fillAddr            : unsigned(9 downto 0) := (others => '0');
   signal SDRAM_fillAddr            : unsigned(7 downto 0) := (others => '0');
   
   signal commandRAMstore           : std_logic := '0';
   signal commandRAMMux             : std_logic := '0';
   signal commandCntNext            : unsigned(4 downto 0) := (others => '0');
   signal commandReqData            : std_logic;
   signal commandSyncFull           : std_logic;
   
   signal cmdDDR3copy_Addr          : unsigned(4 downto 0) := (others => '0');
   signal cmdDDR3copy_Data          : std_logic_vector(63 downto 0);
   signal cmdDDR3copy_We            : std_logic := '0';
   signal cmdDDR3copy_active        : std_logic := '0';
   
   signal cmdRSPcopy_active         : std_logic := '0';
   
   signal cmdfifo_Din               : std_logic_vector(63 downto 0);
   signal cmdfifo_wr                : std_logic := '0';
   signal cmdfifo_wr_1              : std_logic := '0';
   signal cmdfifo_nearfull          : std_logic;
   
   -- Texture request ram
   signal TextureReqRAMreq          : std_logic;
   signal TextureReqRAMaddr         : unsigned(25 downto 0);
   signal TextureReqRAMstore        : std_logic := '0';
   signal TextureReqRAMReady        : std_logic := '0';
   signal TextureReqRAMData         : std_logic_vector(63 downto 0);
   signal TextureReqRAMPtr          : unsigned(4 downto 0);
   
   -- Framebuffer request
   signal FBreq                     : std_logic;
   signal FBRAMgrant                : std_logic;
   signal FBRAMZgrant               : std_logic;
   signal rdram_finished            : std_logic;
   signal sdram_finished            : std_logic;   
   signal rdramZ_finished           : std_logic;
   signal sdramZ_finished           : std_logic;
   signal FB_req_addr               : unsigned(25 downto 0);
   signal FB_reqZ_addr              : unsigned(25 downto 0);
   signal FBaddr                    : unsigned(25 downto 0);
   signal FBZaddr                   : unsigned(25 downto 0);
   signal FBsize                    : unsigned(11 downto 0);
   signal FBodd                     : std_logic := '0';
   signal FBoddSaved                : std_logic := '0';
   signal FBdone                    : std_logic := '0';
   signal FBRAMstore                : std_logic := '0';
   signal FBRAMstoreZ               : std_logic := '0';
   signal FBRAM9store               : std_logic := '0';
   signal FBRAM9storeZ              : std_logic := '0';
   signal FBReadAddr                : unsigned(10 downto 0);
   signal FBReadAddr9               : unsigned(7 downto 0);
   signal FBReadAddrZ               : unsigned(11 downto 0);
   signal FBReadData                : std_logic_vector(31 downto 0);
   signal FBReadDataZ               : std_logic_vector(15 downto 0);
   signal FBReadData9               : std_logic_vector(31 downto 0);
   signal FBReadData9Z              : std_logic_vector(31 downto 0);
   
   type tmemState is 
   (  
      MEMIDLE, 
      WAITCOMMANDDATA,
      WAITTEXTUREDATA,
      WAITFBDATA
   ); 
   signal memState  : tmemState := MEMIDLE;

   -- Command Eval    
   signal settings_poly             : tsettings_poly;
   signal poly_start                : std_logic;
   signal poly_loading_mode         : std_logic;
   signal poly_done                 : std_logic;
   signal settings_KEYRGB           : tsettings_KEYRGB;
   signal settings_Convert          : tsettings_Convert;
   signal settings_scissor          : tsettings_scissor;
   signal settings_Z                : tsettings_Z;
   signal settings_otherModes       : tsettings_otherModes;
   signal settings_fillcolor        : tsettings_fillcolor;
   signal settings_fogcolor         : tsettings_fogcolor;
   signal settings_blendcolor       : tsettings_blendcolor;
   signal settings_primcolor        : tsettings_primcolor;
   signal settings_envcolor         : tsettings_envcolor;
   signal settings_combineMode      : tsettings_combineMode;
   signal settings_colorImage       : tsettings_colorImage;
   signal settings_textureImage     : tsettings_textureImage;
   signal settings_Z_base           : unsigned(24 downto 0);
   signal settings_tile             : tsettings_tile := SETTINGSTILEINIT;
   signal settings_loadtype         : tsettings_loadtype;
   
   -- tile settings
   signal tile_RdAddr               : std_logic_vector(2 downto 0);
   signal tile_Command              : std_logic_vector(2 downto 0);
   signal tile_usePipe              : std_logic;
   signal tile_pipe                 : std_logic_vector(2 downto 0);
                                    
   signal tileSettings_WrAddr       : std_logic_vector(2 downto 0);
   signal tileSettings_WrData       : std_logic_vector(46 downto 0);
   signal tileSettings_we           : std_logic;
   signal tileSettings_RdData       : std_logic_vector(46 downto 0);  
                                    
   -- tile size                     
   signal tileSize_WrAddr           : std_logic_vector(2 downto 0);
   signal tileSize_WrData           : std_logic_vector(47 downto 0);
   signal tileSize_we               : std_logic;
   signal tileSize_RdData           : std_logic_vector(47 downto 0);
   
   -- Texture RAM
   signal TextureRamAddr            : unsigned(7 downto 0) := (others => '0');    
   signal TextureRam0Data           : std_logic_vector(15 downto 0) := (others => '0');
   signal TextureRam1Data           : std_logic_vector(15 downto 0) := (others => '0');
   signal TextureRam2Data           : std_logic_vector(15 downto 0) := (others => '0');
   signal TextureRam3Data           : std_logic_vector(15 downto 0) := (others => '0');
   signal TextureRam4Data           : std_logic_vector(15 downto 0) := (others => '0');
   signal TextureRam5Data           : std_logic_vector(15 downto 0) := (others => '0');
   signal TextureRam6Data           : std_logic_vector(15 downto 0) := (others => '0');
   signal TextureRam7Data           : std_logic_vector(15 downto 0) := (others => '0');
   signal TextureRamWE              : std_logic_vector(7 downto 0)  := (others => '0');
   signal TextureRamDataIn          : tTextureRamData;
   signal TextureReadData           : tTextureRamData;
   signal TextureReadAddr           : tTextureRamAddr;    
   signal TextureReadEna            : std_logic;    
   
   -- Fill line
   signal stall_raster              : std_logic := '0';
   
   signal fillWrite                 : std_logic;
   signal fillBE                    : unsigned(7 downto 0);
   signal fillColor                 : unsigned(63 downto 0);
   signal fillAddr                  : unsigned(25 downto 0) := (others => '0');

   -- pipeline
   signal pipe_busy                 : std_logic;
   
   signal pipeIn_trigger            : std_logic;
   signal pipeIn_valid              : std_logic;
   signal pipeIn_Addr               : unsigned(25 downto 0);
   signal pipeIn_AddrZ              : unsigned(25 downto 0);
   signal pipeIn_xIndexPx           : unsigned(11 downto 0);
   signal pipeIn_xIndexPxZ          : unsigned(11 downto 0);
   signal pipeIn_xIndex9            : unsigned(11 downto 0);
   signal pipeIn_X                  : unsigned(11 downto 0);
   signal pipeIn_Y                  : unsigned(11 downto 0);
   signal pipeIn_cvgValue           : unsigned(7 downto 0);
   signal pipeIn_offX               : unsigned(1 downto 0);
   signal pipeIn_offY               : unsigned(1 downto 0);
   signal pipeInColorFull           : tcolor4_s32;
   signal pipeIn_S                  : signed(15 downto 0);
   signal pipeIn_T                  : signed(15 downto 0);
   signal pipeInWCarry              : std_logic;
   signal pipeInWShift              : integer range 0 to 14;
   signal pipeInWNormLow            : unsigned(7 downto 0);
   signal pipeInWtemppoint          : signed(15 downto 0);
   signal pipeInWtempslope          : unsigned(7 downto 0);   
   signal pipeIn_S_next             : signed(15 downto 0);
   signal pipeIn_T_next             : signed(15 downto 0);
   signal pipeInWCarry_next         : std_logic;
   signal pipeInWShift_next         : integer range 0 to 14;
   signal pipeInWNormLow_next       : unsigned(7 downto 0);
   signal pipeInWtemppoint_next     : signed(15 downto 0);
   signal pipeInWtempslope_next     : unsigned(7 downto 0);
   signal pipeIn_Z                  : signed(21 downto 0);
   signal pipeIn_dzPix              : unsigned(15 downto 0);
   signal pipeIn_copySize           : unsigned(3 downto 0);
   
   signal writePixel                : std_logic;
   signal writePixelAddr            : unsigned(25 downto 0);
   signal writePixelColor           : tcolor3_u8;
   signal writePixelCvg             : unsigned(2 downto 0);
   signal writePixelFBData9         : unsigned(31 downto 0);
   
   signal writePixelData8           : unsigned(7 downto 0);
   signal writePixelData16          : unsigned(15 downto 0);
   signal writePixelData32          : unsigned(31 downto 0);
   
   signal writePixelZ               : std_logic;
   signal writePixelAddrZ           : unsigned(25 downto 0);
   signal writePixelDataZ           : unsigned(17 downto 0);
   signal writePixelFBData9Z        : unsigned(31 downto 0);
   
   signal copyPixel                 : std_logic;
   signal copyAddr                  : unsigned(25 downto 0);
   signal copyData                  : unsigned(63 downto 0);
   signal copyBE                    : unsigned(7 downto 0);
   signal copyPixelFBData9          : unsigned(31 downto 0);
   signal copyPixelData9            : unsigned(31 downto 0);

   -- Pixel merging
   signal pixel64data               : std_logic_vector(63 downto 0) := (others => '0');
   signal pixel64BE                 : std_logic_vector(7 downto 0) := (others => '0');
   signal pixel64addr               : std_logic_vector(19 downto 0) := (others => '0');
   signal pixel64filled             : std_logic := '0';
   
   -- Z Buffer
   signal pixel64Zdata              : std_logic_vector(63 downto 0) := (others => '0');
   signal pixel64ZBE                : std_logic_vector(7 downto 0) := (others => '0');
   signal pixel64Zaddr              : std_logic_vector(19 downto 0) := (others => '0');
   signal pixel64Zfilled            : std_logic := '0';
   
   -- FB Bit 9 writing
   signal pixel9data                : std_logic_vector(31 downto 0) := (others => '0');
   signal pixel9addr                : std_logic_vector(17 downto 0) := (others => '0');
   signal pixel9BE                  : std_logic_vector(3 downto 0) := (others => '0');
   signal pixel9filled              : std_logic := '0';
   
   -- Z Buffer Bit 9 
   signal pixel9Zdata               : std_logic_vector(31 downto 0) := (others => '0');
   signal pixel9Zaddr               : std_logic_vector(17 downto 0) := (others => '0');
   signal pixel9Zfilled             : std_logic := '0';

   signal writePixelsDone           : std_logic;

   -- savestates
   type t_ssarray is array(0 to 1) of unsigned(63 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
   signal ss_out : t_ssarray := (others => (others => '0')); 

   --export
   -- synthesis translate_off
   signal export_command_done       : std_logic; 
   signal export_command_data       : unsigned(63 downto 0); 
   signal export_command_array      : rdp_export_type;
   
   signal export_line_done          : std_logic; 
   signal export_line_list          : rdp_export_type; 
   
   signal export_load_done          : std_logic; 
   signal export_loadFetch          : rdp_export_type; 
   signal export_loadData           : rdp_export_type; 
   signal export_loadValue          : rdp_export_type; 
   
   signal export_fillX              : unsigned(11 downto 0);
   signal export_fillY              : unsigned(11 downto 0);
   
   signal export_pipeDone           : std_logic;       
   signal export_writePixelX        : unsigned(11 downto 0);
   signal export_writePixelY        : unsigned(11 downto 0);
   signal export_pipeO              : rdp_export_type;
   signal export_Color              : rdp_export_type;
   signal export_RGBA               : rdp_export_type;
   signal export_LOD                : rdp_export_type;
   signal export_LODP               : rdp_export_type;
   signal export_TexCoord           : rdp_export_type;
   signal export_TexFetch0          : rdp_export_type;
   signal export_TexFetch1          : rdp_export_type;
   signal export_TexFetch2          : rdp_export_type;
   signal export_TexFetch3          : rdp_export_type;
   signal export_texmode            : unsigned(1 downto 0);
   signal export_TexColor0          : rdp_export_type;
   signal export_TexColor1          : rdp_export_type;
   signal export_TexColor2          : rdp_export_type;
   signal export_TexColor3          : rdp_export_type;
   signal export2_TexFetch0         : rdp_export_type;
   signal export2_TexFetch1         : rdp_export_type;
   signal export2_TexFetch2         : rdp_export_type;
   signal export2_TexFetch3         : rdp_export_type;
   signal export2_texmode           : unsigned(1 downto 0);
   signal export2_TexColor0         : rdp_export_type;
   signal export2_TexColor1         : rdp_export_type;
   signal export2_TexColor2         : rdp_export_type;
   signal export2_TexColor3         : rdp_export_type;
   signal export_Comb               : rdp_export_type;
   signal export_FBMem              : rdp_export_type;
   signal export_Z                  : rdp_export_type;
   signal export_copy               : std_logic;
   signal export_copyFetch          : rdp_export_type;
   signal export_copyBytes          : rdp_export_type;
   
   signal pipeIn_cvg16              : unsigned(15 downto 0);
   signal pipeInSTWZ                : tcolor4_s32;
   -- synthesis translate_on   

begin 

   reg_addr      <= 15x"0" & RSP_RDP_reg_addr when (RSP_RDP_reg_read = '1' or RSP_RDP_reg_write = '1') else bus_addr;     
   reg_dataWrite <= std_logic_vector(RSP_RDP_reg_dataOut) when (RSP_RDP_reg_write = '1') else bus_dataWrite;

   rdram_rnw       <= '1';
   rdram_writeMask <= (others => '0');
   rdram_dataWrite <= (others => '0');
   
   FB_req_addr  <= settings_colorImage.FB_base + FBaddr;
   FB_reqZ_addr <= settings_Z_base + FBZaddr;

   process (clk1x)
      variable var_dataRead         : std_logic_vector(31 downto 0) := (others => '0');
      variable rdram_finished_new   : std_logic;
      variable sdram_finished_new   : std_logic;      
      variable rdramZ_finished_new  : std_logic;
      variable sdramZ_finished_new  : std_logic;
   begin
      if rising_edge(clk1x) then
      
         irq_out             <= '0';
         RSP2RDP_req         <= '0';
         rdram_request       <= '0';
         sdram_request       <= '0';
         TextureReqRAMReady  <= '0';
         FBdone              <= '0';
         cmdDDR3copy_We      <= '0';
         error_RDPMEMMUX     <= '0';
         
         cmdfifo_wr_1 <= cmdfifo_wr;
      
         if (reset = '1') then
            
            bus_done                 <= '0';
            
            DPC_START_NEXT           <= ss_in(0)(23 downto 0); --(others => '0');
            DPC_END_NEXT             <= ss_in(0)(47 downto 24); --(others => '0');
            DPC_CURRENT              <= ss_in(1)(23 downto 0); --(others => '0');
            DPC_STATUS_xbus_dmem_dma <= ss_in(0)(48); --'0';
            DPC_STATUS_freeze        <= ss_in(0)(49); --'0';
            DPC_STATUS_flush         <= ss_in(0)(50); --'0';
            DPC_STATUS_start_gclk    <= ss_in(0)(51); --'0';
            DPC_STATUS_cbuf_ready    <= ss_in(0)(52); --'1';
            DPC_STATUS_dma_busy      <= ss_in(0)(53); --'0';
            DPC_STATUS_end_pending   <= ss_in(0)(54); --'0';
            DPC_STATUS_start_pending <= ss_in(0)(55); --'0';
            DPC_CLOCK                <= (others => '0');
            DPC_BUFBUSY              <= (others => '0');
            DPC_PIPEBUSY             <= (others => '0');
            DPC_TMEM                 <= (others => '0');
            
            bus_read_latched         <= '0';
            bus_write_latched        <= '0';
            
            DPC_END                  <= ss_in(0)(47 downto 24); --(others => '0');
            memState                 <= MEMIDLE;
            
         else
            if (ce = '1') then
         
               bus_done     <= '0';
               bus_dataRead <= (others => '0');
   
               if (commandSyncFull = '1') then
                  irq_out               <= '1';
                  DPC_BUFBUSY           <= (others => '0');
                  DPC_PIPEBUSY          <= (others => '0');
                  DPC_STATUS_start_gclk <= '0';
               end if;
   
               -- some games like NBA JAM just need the clock timer ticking up and some games like OOT depend on them being either zero or very accurate
               -- as timing is not yet accurate enough, only activate it outside of CIC 6105 here
               if (CICTYPE(2) = '0') then
                  DPC_CLOCK <= DPC_CLOCK + 1;
               end if;
   
               -- bus read
               if (bus_read = '1') then
                  bus_read_latched <= '1';
               end if;
               
               var_dataRead := (others => '0');
               case (reg_addr(19 downto 0)) is   
                  when x"00000" => var_dataRead(23 downto 0) := std_logic_vector(DPC_START_NEXT);  
                  when x"00004" => var_dataRead(23 downto 0) := std_logic_vector(DPC_END_NEXT);
                  when x"00008" => var_dataRead(23 downto 0) := std_logic_vector(DPC_CURRENT);
                  when x"0000C" =>
                     var_dataRead(0)  := DPC_STATUS_xbus_dmem_dma;
                     var_dataRead(1)  := DPC_STATUS_freeze;
                     var_dataRead(2)  := DPC_STATUS_flush;
                     var_dataRead(3)  := DPC_STATUS_start_gclk;
                     if (DPC_TMEM > 0) then var_dataRead(4)      := '1'; end if;
                     if (DPC_PIPEBUSY > 0) then var_dataRead(5)  := '1'; end if;
                     --if (DPC_BUFBUSY > 0) then var_dataRead(6)  := '1'; end if;
                     var_dataRead(7)  := DPC_STATUS_cbuf_ready;
                     var_dataRead(8)  := DPC_STATUS_dma_busy;
                     var_dataRead(9)  := DPC_STATUS_end_pending;
                     var_dataRead(10) := DPC_STATUS_start_pending;
                  
                  when x"00010" => var_dataRead(23 downto 0) := std_logic_vector(DPC_CLOCK);  
                  when x"00014" => var_dataRead(23 downto 0) := std_logic_vector(DPC_BUFBUSY);  
                  when x"00018" => var_dataRead(23 downto 0) := std_logic_vector(DPC_PIPEBUSY);  
                  when x"0001C" => var_dataRead(23 downto 0) := std_logic_vector(DPC_TMEM);  
                  when others   => null;             
               end case;
               
               if (bus_read_latched = '1' and RSP_RDP_reg_write = '0' and RSP_RDP_reg_read = '0') then
                  bus_done         <= '1';
                  bus_dataRead     <= var_dataRead;
                  bus_read_latched <= '0';
               end if;
               
               RSP_RDP_reg_dataIn <= unsigned(var_dataRead);
               
               -- bus write
               if (bus_write = '1') then
                  bus_write_latched <= '1';
               end if;
               
               if (cmdfifo_wr = '1') then
                  DPC_CURRENT   <= DPC_CURRENT + 8;
               end if;
               
               if (bus_write_latched = '1' and RSP_RDP_reg_write = '0' and RSP_RDP_reg_read = '0') then
                  bus_write_latched <= '0';
                  bus_done          <= '1';
               end if;
               
               if ((bus_write_latched = '1' and RSP_RDP_reg_read = '0') or RSP_RDP_reg_write = '1') then
 
                  case (reg_addr(19 downto 0)) is
                     when x"00000" =>
                        if (DPC_STATUS_start_pending = '0') then -- wrong according to n64brew, should always update, systemtest proves otherwise!
                           DPC_START_NEXT <= unsigned(reg_dataWrite(23 downto 3)) & "000";
                        end if;
                        DPC_STATUS_start_pending <= '1';
                     
                     when x"00004" => 
                        DPC_END_NEXT <= unsigned(reg_dataWrite(23 downto 3)) & "000";
                        
                        if (DPC_STATUS_start_pending = '0') then
                           DPC_STATUS_dma_busy <= '1';
                           DPC_END             <= unsigned(reg_dataWrite(23 downto 3)) & "000";
                        else
                           if (DPC_STATUS_dma_busy = '0') then
                              DPC_STATUS_start_pending <= '0';
                              DPC_STATUS_dma_busy      <= '1';
                              DPC_CURRENT              <= DPC_START_NEXT;
                              DPC_END                  <= unsigned(reg_dataWrite(23 downto 3)) & "000";
                           else
                              DPC_STATUS_end_pending <= '1';
                           end if;
                        end if;
                        
                        if (DPC_STATUS_freeze = '0') then
                           DPC_STATUS_start_gclk <= '1';
                           DPC_BUFBUSY           <= x"000001"; -- hack
                           DPC_PIPEBUSY          <= x"000001"; -- hack
                        end if;
                     
                     when x"0000C" => 
                        if (reg_dataWrite(0) = '1') then DPC_STATUS_xbus_dmem_dma <= '0'; end if;
                        if (reg_dataWrite(1) = '1') then DPC_STATUS_xbus_dmem_dma <= '1'; end if;
                        if (reg_dataWrite(2) = '1') then 
                           DPC_STATUS_freeze     <= '0'; 
                           DPC_STATUS_start_gclk <= '1';
                           DPC_BUFBUSY           <= x"000001"; -- hack
                           DPC_PIPEBUSY          <= x"000001"; -- hack
                        end if;
                        if (reg_dataWrite(3) = '1') then DPC_STATUS_freeze        <= '1'; end if;
                        if (reg_dataWrite(4) = '1') then DPC_STATUS_flush         <= '0'; end if;
                        if (reg_dataWrite(5) = '1') then DPC_STATUS_flush         <= '1'; end if;
                        if (reg_dataWrite(6) = '1') then DPC_TMEM     <= (others => '0'); end if;
                        if (reg_dataWrite(7) = '1') then DPC_PIPEBUSY <= (others => '0'); end if;
                        if (reg_dataWrite(8) = '1') then DPC_BUFBUSY  <= (others => '0'); end if;
                        if (reg_dataWrite(9) = '1') then DPC_CLOCK    <= (others => '0'); end if;
                     
                     when others   => null; 

                  end case;
                  
               elsif (DPC_STATUS_dma_busy = '1' and DPC_CURRENT >= DPC_END) then
               
                  if (DPC_STATUS_end_pending = '1') then
                     DPC_STATUS_start_pending <= '0';
                     DPC_STATUS_end_pending   <= '0';
                     DPC_CURRENT              <= DPC_START_NEXT;
                     DPC_END                  <= DPC_END_NEXT;
                  else
                     DPC_STATUS_dma_busy <= '0';
                  end if;
                  
               end if;

            end if; -- ce
         
         end if; -- no reset
         
         if (cmdDDR3copy_active = '1') then
            cmdDDR3copy_Addr <= cmdDDR3copy_Addr + 1;
            if (cmdDDR3copy_Addr >= commandCntNext) then
               cmdDDR3copy_active <= '0';
            else
               cmdDDR3copy_We     <= '1';
            end if;
         end if;
         
         if (RSP2RDP_done = '1') then
            cmdRSPcopy_active <= '0';
         end if;
         
         if (memState /= MEMIDLE and (TextureReqRAMreq = '1' or FBreq = '1')) then
            error_RDPMEMMUX <= '1';
         end if;
            
         -- memory statemachine
         case (memState) is
         
            when MEMIDLE =>
               if (TextureReqRAMreq = '1') then
                  memState          <= WAITTEXTUREDATA;
                  rdram_request     <= '1';
                  rdram_address     <= "00" & TextureReqRAMaddr;
                  rdram_burstcount  <= to_unsigned(32, 10);
               elsif (FBreq = '1') then
                  memState          <= WAITFBDATA;
                  FBoddSaved        <= FBodd;
                  
                  sdram_finished    <= (not wait9) or (not read9); --'0';
                  sdramZ_finished   <= (not wait9) or (not read9); --'0';
                  
                  -- todo: must increase line size if games really use more than 2048 pixels in 16bit mode or 1024 pixels in 32 bit mode
                  -- todo: fetching could be optimized to only read 1 additional word when border between words was really crossed
                  if (settings_colorImage.FB_size = SIZE_4BIT or settings_colorImage.FB_size = SIZE_8BIT) then
                     rdram_burstcount  <= '0' & to_unsigned((to_integer(FBsize) + 15) / 8,9);
                  elsif (settings_colorImage.FB_size = SIZE_16BIT) then
                     rdram_burstcount  <= '0' & to_unsigned((to_integer(FBsize) + 7) / 4,9);
                  else
                     rdram_burstcount  <= '0' & to_unsigned((to_integer(FBsize) + 3) / 2,9);
                  end if;
                  
                  if (settings_otherModes.imageRead = '1' and settings_otherModes.cycleType /= "10") then
                     rdram_request     <= '1';
                     rdram_address     <= "00" & FB_req_addr(25 downto 3) & "000";
                     rdram_finished    <= '0';
                     FBRAMgrant        <= '0';
                  else
                     rdram_finished    <= '1';
                     FBRAMgrant        <= '1';
                     if (settings_otherModes.zCompare = '1' and settings_otherModes.cycleType /= "10") then
                        rdram_request     <= '1';
                        rdram_address     <= "00" & FB_reqZ_addr(25 downto 3) & "000";
                        rdram_burstcount  <= '0' & to_unsigned((to_integer(FBsize) + 7) / 4,9);
                     end if;
                  end if;

                  if (settings_otherModes.zCompare = '1' and settings_otherModes.cycleType /= "10") then
                     rdramZ_finished   <= '0';
                     FBRAMZgrant       <= '0';
                  else
                     rdramZ_finished   <= '1';
                     FBRAMZgrant       <= '1';
                  end if;

                  sdram_request     <= read9; --'1';
                  sdram_address     <= 7x"0" & FB_req_addr(22 downto 5) & "00";
                  sdram_burstcount  <=  '0' & to_unsigned((to_integer(FBsize) + 31) / 16,7);
                  
               elsif (DPC_STATUS_freeze = '0' and cmdfifo_nearfull = '0' and commandReqData = '1' and cmdDDR3copy_active = '0' and cmdRSPcopy_active = '0' and cmdfifo_wr_1 = '0' and DPC_STATUS_dma_busy = '1') then
                  if (DPC_CURRENT < DPC_END) then
                     memState          <= WAITCOMMANDDATA;
                     commandRAMMux     <= DPC_STATUS_xbus_dmem_dma;
                     RSP2RDP_req       <= DPC_STATUS_xbus_dmem_dma;
                     rdram_request     <= not DPC_STATUS_xbus_dmem_dma;
                     RSP2RDP_rdaddr    <= DPC_CURRENT(11 downto 0);
                     rdram_address     <= x"0" & DPC_CURRENT;
                     if ((DPC_END(23 downto 3) - DPC_CURRENT(23 downto 3)) > 22) then
                        commandCntNext    <= to_unsigned(22, 5);
                        rdram_burstcount  <= to_unsigned(22, 10); -- max length for tri with all options on
                     else
                        commandCntNext    <= resize(DPC_END(23 downto 3) - DPC_CURRENT(23 downto 3), 5);
                        rdram_burstcount  <= "00000" & resize(DPC_END(23 downto 3) - DPC_CURRENT(23 downto 3), 5);
                     end if;
                     -- synthesis translate_off
                     export_command_array.addr <= x"00" & DPC_CURRENT;
                     -- synthesis translate_on
                  end if;
               end if;
               
            when WAITCOMMANDDATA =>
               if (RSP2RDP_we = '1') then
                  memState           <= MEMIDLE;
                  cmdRSPcopy_active  <= not RSP2RDP_done;
               elsif (rdram_done = '1') then
                  memState           <= MEMIDLE;
                  cmdDDR3copy_active <= '1';
                  cmdDDR3copy_Addr   <= (others => '0');
               end if;
               
            when WAITTEXTUREDATA =>
               if (rdram_done = '1') then
                  TextureReqRAMReady   <= '1';
                  memState             <= MEMIDLE;
               end if;            
               
            when WAITFBDATA =>
               rdram_finished_new  := rdram_finished;
               sdram_finished_new  := sdram_finished;
               rdramZ_finished_new := rdramZ_finished;
               sdramZ_finished_new := sdramZ_finished;
               
               if (rdram_granted = '1' and rdram_finished = '0') then FBRAMgrant  <= '1'; end if;
               if (rdram_granted = '1' and rdram_finished = '1') then FBRAMZgrant <= '1'; end if;
               
               if (rdram_done = '1' and FBRAMgrant = '1' and rdram_finished = '0') then 
                  rdram_finished_new := '1'; 
                  if (settings_otherModes.zCompare = '1' and readZ = '1' and settings_otherModes.cycleType /= "10") then
                     rdram_request     <= '1';
                     rdram_address     <= "00" & FB_reqZ_addr(25 downto 3) & "000";
                     rdram_burstcount  <= '0' & to_unsigned((to_integer(FBsize) + 7) / 4,9);
                  else
                     rdramZ_finished_new := '1';
                  end if;
               end if;
               if (rdram_done = '1' and FBRAMZgrant = '1') then rdramZ_finished_new := '1'; end if;
               
               if (sdram_done = '1' and FBRAM9store = '1') then 
                  sdram_finished_new := '1'; 
                  if ((settings_otherModes.zCompare = '1' or settings_otherModes.zUpdate = '1') and read9 = '1' and settings_otherModes.cycleType /= "10") then
                     sdram_request     <= '1';
                     sdram_address     <= 7x"0" & FB_reqZ_addr(22 downto 5) & "00";
                  else
                     sdramZ_finished_new := '1';
                  end if;
               end if;
               
               if (sdram_done = '1' and FBRAM9storeZ = '1') then sdramZ_finished_new := '1'; end if;
               
               rdram_finished  <= rdram_finished_new;
               sdram_finished  <= sdram_finished_new;
               rdramZ_finished <= rdramZ_finished_new;
               sdramZ_finished <= sdramZ_finished_new;
               
               if (rdram_finished_new = '1' and sdram_finished_new = '1' and rdramZ_finished_new = '1' and sdramZ_finished_new = '1') then
                  FBdone   <= '1';
                  memState <= MEMIDLE;
               end if;
         
         end case;

      end if;
   end process;
   
   RSP2RDP_len <= commandCntNext;
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         
         if (rdram_granted = '1') then
            RDRAM_fillAddr <= (others => '0');
            if (memState = WAITCOMMANDDATA) then
               commandRAMstore <= '1';
            elsif (memState = WAITTEXTUREDATA) then
               TextureReqRAMstore <= '1';            
            elsif (memState = WAITFBDATA and rdram_finished = '0') then
               FBRAMstore        <= '1';
               RDRAM_fillAddr(9) <= FBoddSaved;
            elsif (memState = WAITFBDATA and rdram_finished = '1') then
               FBRAMstoreZ       <= '1';
               RDRAM_fillAddr(9) <= FBoddSaved;
            end if;
         elsif (ddr3_DOUT_READY = '1') then
            RDRAM_fillAddr(8 downto 0) <= RDRAM_fillAddr(8 downto 0) + 1;
         end if;
         
         if (rdram_done = '1') then
            commandRAMstore    <= '0';
            TextureReqRAMstore <= '0';
            FBRAMstore         <= '0';
            FBRAMstoreZ        <= '0';
         end if;
         
      end if;
   end process; 
   
   iCommandCopyRAM: entity mem.dpram
   generic map 
   ( 
      addr_width  => 5,
      data_width  => 64
   )
   port map
   (
      clock_a     => clk2x,
      address_a   => std_logic_vector(RDRAM_fillAddr(4 downto 0)),
      data_a      => byteswap64(ddr3_DOUT),
      wren_a      => (ddr3_DOUT_READY and commandRAMstore),
      
      clock_b     => clk1x,
      address_b   => std_logic_vector(cmdDDR3copy_Addr),
      data_b      => 64x"0",
      wren_b      => '0',
      q_b         => cmdDDR3copy_Data
   );   
    
   cmdfifo_Din <= RSP2RDP_data when (commandRAMMux = '1') else cmdDDR3copy_Data;
   cmdfifo_wr  <= RSP2RDP_we   when (commandRAMMux = '1') else cmdDDR3copy_We;

   iRDP_command : entity work.RDP_command
   port map
   (
      clk1x                   => clk1x,          
      reset                   => reset,          
   
      error                   => command_error,
      
      cmdfifo_Din             => cmdfifo_Din,
      cmdfifo_wr              => cmdfifo_wr,
      cmdfifo_nearfull        => cmdfifo_nearfull,
                                           
      commandReqData          => commandReqData,  
         
      poly_done               => poly_done,       
      writePixelsDone         => writePixelsDone,       
      settings_poly           => settings_poly,       
      poly_start              => poly_start,     
      poly_loading_mode       => poly_loading_mode,     
      sync_full               => commandSyncFull,     

      -- synthesis translate_off
      export_command_done     => export_command_done, 
      export_command_data     => export_command_data, 
      commandIsIdle           => commandIsIdle,
      -- synthesis translate_on      
                              
      tile_Command            => tile_Command,         
      tile_usePipe            => tile_usePipe,
      tileSettings_WrAddr     => tileSettings_WrAddr,                
      tileSettings_WrData     => tileSettings_WrData,                
      tileSettings_we         => tileSettings_we,                    
      tileSize_WrAddr         => tileSize_WrAddr,                    
      tileSize_WrData         => tileSize_WrData,                    
      tileSize_we             => tileSize_we,                                        
                              
      settings_KEYRGB         => settings_KEYRGB, 
      settings_Convert        => settings_Convert,                            
      settings_scissor        => settings_scissor,   
      settings_Z              => settings_Z,   
      settings_otherModes     => settings_otherModes, 
      settings_fillcolor      => settings_fillcolor,  
      settings_fogcolor       => settings_fogcolor, 
      settings_blendcolor     => settings_blendcolor, 
      settings_primcolor      => settings_primcolor, 
      settings_envcolor       => settings_envcolor, 
      settings_combineMode    => settings_combineMode,
      settings_textureImage   => settings_textureImage,
      settings_Z_base         => settings_Z_base,
      settings_colorImage     => settings_colorImage,  
      settings_loadtype       => settings_loadtype      
   );
   
   tile_RdAddr <= tile_pipe when (tile_usePipe = '1') else tile_Command;
   
   itileSettings : entity mem.RamMLAB
	GENERIC MAP 
   (
      width      => 47, -- 56 - 1 - 8 = 47
      widthad    => 3
	)
	PORT MAP (
      inclock    => clk1x,
      wren       => tileSettings_we,
      data       => tileSettings_WrData,
      wraddress  => tileSettings_WrAddr,
      rdaddress  => tile_RdAddr,
      q          => tileSettings_RdData
	);
   
   itileSize : entity mem.RamMLAB
	GENERIC MAP 
   (
      width      => 48, -- 56 - 8 = 48
      widthad    => 3
	)
	PORT MAP (
      inclock    => clk1x,
      wren       => tileSize_we,
      data       => tileSize_WrData,
      wraddress  => tileSize_WrAddr,
      rdaddress  => tile_RdAddr,
      q          => tileSize_RdData
	);
   
   settings_tile.Tile_sl <= unsigned(tileSize_RdData(47 downto 36));
   settings_tile.Tile_tl <= unsigned(tileSize_RdData(35 downto 24));
   settings_tile.Tile_sh <= unsigned(tileSize_RdData(23 downto 12));
   settings_tile.Tile_th <= unsigned(tileSize_RdData(11 downto  0));
   
   settings_tile.Tile_format   <= unsigned(tileSettings_RdData(46 downto 44));
   settings_tile.Tile_size     <= unsigned(tileSettings_RdData(43 downto 42));
   settings_tile.Tile_line     <= unsigned(tileSettings_RdData(41 downto 33));
   settings_tile.Tile_TmemAddr <= unsigned(tileSettings_RdData(32 downto 24));
   settings_tile.Tile_palette  <= unsigned(tileSettings_RdData(23 downto 20));
   settings_tile.Tile_clampT   <= tileSettings_RdData(19);
   settings_tile.Tile_mirrorT  <= tileSettings_RdData(18);
   settings_tile.Tile_maskT    <= unsigned(tileSettings_RdData(17 downto 14));
   settings_tile.Tile_shiftT   <= unsigned(tileSettings_RdData(13 downto 10));
   settings_tile.Tile_clampS   <= tileSettings_RdData(9);
   settings_tile.Tile_mirrorS  <= tileSettings_RdData(8);
   settings_tile.Tile_maskS    <= unsigned(tileSettings_RdData( 7 downto  4));
   settings_tile.Tile_shiftS   <= unsigned(tileSettings_RdData( 3 downto  0));
   
   iTextureReceiveRAM: entity mem.dpram
   generic map 
   ( 
      addr_width  => 5,
      data_width  => 64
   )
   port map
   (
      clock_a     => clk2x,
      address_a   => std_logic_vector(RDRAM_fillAddr(4 downto 0)),
      data_a      => byteswap64(ddr3_DOUT),
      wren_a      => (ddr3_DOUT_READY and TextureReqRAMstore),
      
      clock_b     => clk1x,
      address_b   => std_logic_vector(textureReqRAMPtr),
      data_b      => 64x"0",
      wren_b      => '0',
      q_b         => TextureReqRAMData
   );
   
   iRDP_raster : entity work.RDP_raster
   port map
   (
      clk1x                   => clk1x,        
      reset                   => reset,       
      
      error_drawMode          => error_drawMode,

      stall_raster            => stall_raster,
                              
      settings_poly           => settings_poly,      
      settings_scissor        => settings_scissor,   
      settings_Z              => settings_Z,   
      settings_otherModes     => settings_otherModes, 
      settings_fillcolor      => settings_fillcolor,  
      settings_colorImage     => settings_colorImage, 
      settings_textureImage   => settings_textureImage,
      settings_Z_base         => settings_Z_base,
      settings_tile           => settings_tile,    
      settings_loadtype       => settings_loadtype,    
      poly_start              => poly_start,   
      loading_mode            => poly_loading_mode,
      poly_done               => poly_done,
      
      TextureReqRAMreq        => TextureReqRAMreq,   
      TextureReqRAMaddr       => TextureReqRAMaddr,  
      TextureReqRAMPtr        => TextureReqRAMPtr,   
      TextureReqRAMData       => TextureReqRAMData,  
      TextureReqRAMReady      => TextureReqRAMReady, 
      
      TextureRamAddr          => TextureRamAddr, 
      TextureRam0Data         => TextureRam0Data,
      TextureRam1Data         => TextureRam1Data,
      TextureRam2Data         => TextureRam2Data,
      TextureRam3Data         => TextureRam3Data,
      TextureRam4Data         => TextureRam4Data,
      TextureRam5Data         => TextureRam5Data,
      TextureRam6Data         => TextureRam6Data,
      TextureRam7Data         => TextureRam7Data,
      TextureRamWE            => TextureRamWE,   
      
      FBreq                   => FBreq, 
      FBaddr                  => FBaddr,
      FBZaddr                 => FBZaddr,
      FBsize                  => FBsize,
      FBodd                   => FBodd, 
      FBdone                  => FBdone,
      
      -- synthesis translate_off
      export_line_done        => export_line_done,
      export_line_list        => export_line_list,
         
      export_load_done        => export_load_done,
      export_loadFetch        => export_loadFetch,
      export_loadData         => export_loadData, 
      export_loadValue        => export_loadValue,
      -- synthesis translate_on
      
      pipe_busy               => pipe_busy,
      
      pipeIn_trigger          => pipeIn_trigger,
      pipeIn_valid            => pipeIn_valid,  
      pipeIn_Addr             => pipeIn_Addr,   
      pipeIn_AddrZ            => pipeIn_AddrZ,   
      pipeIn_xIndexPx         => pipeIn_xIndexPx,      
      pipeIn_xIndexPxZ        => pipeIn_xIndexPxZ,      
      pipeIn_xIndex9          => pipeIn_xIndex9,      
      pipeIn_X                => pipeIn_X,      
      pipeIn_Y                => pipeIn_Y, 
      pipeIn_cvgValue         => pipeIn_cvgValue, 
      pipeIn_offX             => pipeIn_offX, 
      pipeIn_offY             => pipeIn_offY, 
      pipeInColorFull         => pipeInColorFull,
      pipeIn_S                => pipeIn_S,
      pipeIn_T                => pipeIn_T,
      pipeInWCarry            => pipeInWCarry,   
      pipeInWShift            => pipeInWShift,   
      pipeInWNormLow          => pipeInWNormLow, 
      pipeInWtemppoint        => pipeInWtemppoint,
      pipeInWtempslope        => pipeInWtempslope,
      pipeIn_S_next           => pipeIn_S_next,        
      pipeIn_T_next           => pipeIn_T_next,        
      pipeInWCarry_next       => pipeInWCarry_next,    
      pipeInWShift_next       => pipeInWShift_next,    
      pipeInWNormLow_next     => pipeInWNormLow_next,  
      pipeInWtemppoint_next   => pipeInWtemppoint_next,
      pipeInWtempslope_next   => pipeInWtempslope_next,
      pipeIn_Z                => pipeIn_Z,
      pipeIn_dzPix            => pipeIn_dzPix,
      pipeIn_copySize         => pipeIn_copySize,

      -- synthesis translate_off
      pipeIn_cvg16            => pipeIn_cvg16, 
      pipeInSTWZ              => pipeInSTWZ,
      fillX                   => export_fillX,   
      fillY                   => export_fillY, 
      -- synthesis translate_on

      fillWrite               => fillWrite,
      fillBE                  => fillBE,   
      fillColor               => fillColor,
      fillAddr                => fillAddr 
   );
   
   TextureRamDataIn(0) <= TextureRam0Data;
   TextureRamDataIn(1) <= TextureRam1Data;
   TextureRamDataIn(2) <= TextureRam2Data;
   TextureRamDataIn(3) <= TextureRam3Data;
   TextureRamDataIn(4) <= TextureRam4Data;
   TextureRamDataIn(5) <= TextureRam5Data;
   TextureRamDataIn(6) <= TextureRam6Data;
   TextureRamDataIn(7) <= TextureRam7Data;
   
   gTextureRam: for i in 0 to 7 generate
   begin
   
      iTextureRAM: entity mem.dpram
      generic map 
      ( 
         addr_width  => 8,
         data_width  => 16
      )
      port map
      (
         clock_a     => clk1x,
         address_a   => std_logic_vector(TextureRamAddr),
         data_a      => TextureRamDataIn(i),
         wren_a      => TextureRamWE(i),
         
         clock_b     => clk1x,
         clken_b     => TextureReadEna,
         address_b   => TextureReadAddr(i),
         data_b      => 16x"0",
         wren_b      => '0',
         q_b         => TextureReadData(i)
      );
      
   end generate;
   
   iFBRAM: entity mem.dpram_dif
   generic map 
   ( 
      addr_width_a => 10,
      data_width_a => 64,
      addr_width_b => 11,
      data_width_b => 32
   )
   port map
   (
      clock_a     => clk2x,
      address_a   => std_logic_vector(RDRAM_fillAddr),
      data_a      => ddr3_DOUT,
      wren_a      => (ddr3_DOUT_READY and FBRAMstore),
      
      clock_b     => clk1x,
      clken_b     => pipeIn_trigger,
      address_b   => std_logic_vector(FBReadAddr),
      data_b      => 32x"0",
      wren_b      => '0',
      q_b         => FBReadData
   );
   
   iFBRAMZ: entity mem.dpram_dif
   generic map 
   ( 
      addr_width_a => 10,
      data_width_a => 64,
      addr_width_b => 12,
      data_width_b => 16
   )
   port map
   (
      clock_a     => clk2x,
      address_a   => std_logic_vector(RDRAM_fillAddr),
      data_a      => ddr3_DOUT,
      wren_a      => (ddr3_DOUT_READY and FBRAMstoreZ),
      
      clock_b     => clk1x,
      clken_b     => pipeIn_trigger,
      address_b   => std_logic_vector(FBReadAddrZ),
      data_b      => 16x"0",
      wren_b      => '0',
      q_b         => FBReadDataZ
   );
   
   iFBRAM9: entity mem.dpram_dif
   generic map 
   ( 
      addr_width_a => 8,
      data_width_a => 32,
      addr_width_b => 8,
      data_width_b => 32
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => std_logic_vector(SDRAM_fillAddr),
      data_a      => sdram_dataRead,
      wren_a      => (sdram_valid and FBRAM9store),
      
      clock_b     => clk1x,
      clken_b     => pipeIn_trigger,
      address_b   => std_logic_vector(FBReadAddr9),
      data_b      => 32x"0",
      wren_b      => '0',
      q_b         => FBReadData9
   );
   
   iFBRAM9Z: entity mem.dpram_dif
   generic map 
   ( 
      addr_width_a => 8,
      data_width_a => 32,
      addr_width_b => 8,
      data_width_b => 32
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => std_logic_vector(SDRAM_fillAddr),
      data_a      => sdram_dataRead,
      wren_a      => (sdram_valid and FBRAM9storeZ),
      
      clock_b     => clk1x,
      clken_b     => pipeIn_trigger,
      address_b   => std_logic_vector(FBReadAddr9),
      data_b      => 32x"0",
      wren_b      => '0',
      q_b         => FBReadData9Z
   );
   
   sdram_rnw       <= '1';  
   sdram_writeMask <= x"0";
   sdram_dataWrite <= (others => '0');
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         
         if (sdram_granted = '1') then
            SDRAM_fillAddr <= FBoddSaved & 7x"0";
            if (memState = WAITFBDATA and sdram_finished = '0') then
               FBRAM9store       <= '1';
            elsif (memState = WAITFBDATA and sdram_finished = '1') then
               FBRAM9storeZ      <= '1';
            end if;
         elsif (sdram_valid = '1') then
            SDRAM_fillAddr(6 downto 0) <= SDRAM_fillAddr(6 downto 0) + 1;
         end if;
         
         if (sdram_done = '1') then
            FBRAM9store  <= '0';
            FBRAM9storeZ <= '0';
         end if;
         
      end if;
   end process;

   iRDP_pipeline : entity work.RDP_pipeline
   port map
   (
      clk1x                   => clk1x,                
      reset                   => reset,   
      
      DISABLEFILTER           => DISABLEFILTER,
      DISABLEDITHER           => DISABLEDITHER,
      DISABLELOD              => DISABLELOD,

      errorCombine            => errorCombine,
      error_combineAlpha      => error_combineAlpha,
      error_texMode           => error_texMode,
      
      pipe_busy               => pipe_busy,
                                                      
      settings_poly           => settings_poly,  
      settings_otherModes     => settings_otherModes,  
      settings_fogcolor       => settings_fogcolor, 
      settings_blendcolor     => settings_blendcolor, 
      settings_primcolor      => settings_primcolor, 
      settings_envcolor       => settings_envcolor,  
      settings_colorImage     => settings_colorImage,  
      settings_textureImage   => settings_textureImage,
      settings_tile           => settings_tile,        
      settings_combineMode    => settings_combineMode, 
      settings_KEYRGB         => settings_KEYRGB, 
      settings_Convert        => settings_Convert,       
                                                      
      pipeIn_trigger          => pipeIn_trigger,
      pipeIn_valid            => pipeIn_valid,  
      pipeIn_Addr             => pipeIn_Addr,   
      pipeIn_AddrZ            => pipeIn_AddrZ,   
      pipeIn_xIndexPx         => pipeIn_xIndexPx,      
      pipeIn_xIndexPxZ        => pipeIn_xIndexPxZ,      
      pipeIn_xIndex9          => pipeIn_xIndex9,      
      pipeIn_X                => pipeIn_X,      
      pipeIn_Y                => pipeIn_Y,      
      pipeIn_cvgValue         => pipeIn_cvgValue,  
      pipeIn_offX             => pipeIn_offX,  
      pipeIn_offY             => pipeIn_offY,  
      pipeInColorFull         => pipeInColorFull,
      pipeIn_S                => pipeIn_S,
      pipeIn_T                => pipeIn_T,    
      pipeInWCarry            => pipeInWCarry,   
      pipeInWShift            => pipeInWShift,   
      pipeInWNormLow          => pipeInWNormLow, 
      pipeInWtemppoint        => pipeInWtemppoint,
      pipeInWtempslope        => pipeInWtempslope,
      pipeIn_S_next           => pipeIn_S_next,        
      pipeIn_T_next           => pipeIn_T_next,        
      pipeInWCarry_next       => pipeInWCarry_next,    
      pipeInWShift_next       => pipeInWShift_next,    
      pipeInWNormLow_next     => pipeInWNormLow_next,  
      pipeInWtemppoint_next   => pipeInWtemppoint_next,
      pipeInWtempslope_next   => pipeInWtempslope_next,
      pipeIn_Z                => pipeIn_Z,
      pipeIn_dzPix            => pipeIn_dzPix,
      pipeIn_copySize         => pipeIn_copySize,
      
      pipe_tile               => tile_pipe,

      TextureReadEna          => TextureReadEna,
      TextureAddr             => TextureReadAddr,
      TextureRamData          => TextureReadData,
      
      FBAddr                  => FBReadAddr,
      FBData                  => FBReadData,
      
      FBAddr9                 => FBReadAddr9,
      FBData9                 => FBReadData9,
      FBData9Z                => FBReadData9Z,
      
      FBAddrZ                 => FBReadAddrZ,
      FBDataZ                 => FBReadDataZ,
     
      -- synthesis translate_off
      pipeIn_cvg16            => pipeIn_cvg16,  
      pipeInSTWZ              => pipeInSTWZ,
      
      export_pipeDone         => export_pipeDone,
      export_writePixelX      => export_writePixelX,    
      export_writePixelY      => export_writePixelY, 
      export_pipeO            => export_pipeO,   
      export_Color            => export_Color,   
      export_RGBA             => export_RGBA,   
      export_LOD              => export_LOD,   
      export_LODP             => export_LODP,   
      export_TexCoord         => export_TexCoord,   
      export_TexFetch0        => export_TexFetch0,   
      export_TexFetch1        => export_TexFetch1,   
      export_TexFetch2        => export_TexFetch2,   
      export_TexFetch3        => export_TexFetch3,   
      export_texmode          => export_texmode,   
      export_TexColor0        => export_TexColor0,   
      export_TexColor1        => export_TexColor1,   
      export_TexColor2        => export_TexColor2,   
      export_TexColor3        => export_TexColor3,        
      export2_TexFetch0       => export2_TexFetch0,   
      export2_TexFetch1       => export2_TexFetch1,   
      export2_TexFetch2       => export2_TexFetch2,   
      export2_TexFetch3       => export2_TexFetch3,   
      export2_texmode         => export2_texmode,   
      export2_TexColor0       => export2_TexColor0,   
      export2_TexColor1       => export2_TexColor1,   
      export2_TexColor2       => export2_TexColor2,   
      export2_TexColor3       => export2_TexColor3,   
      export_Comb             => export_Comb,   
      export_FBMem            => export_FBMem,   
      export_Z                => export_Z,   
      export_copy             => export_copy,   
      export_copyFetch        => export_copyFetch,   
      export_copyBytes        => export_copyBytes,   
      -- synthesis translate_on
      
      writePixel              => writePixel,     
      writePixelAddr          => writePixelAddr,      
      writePixelColorOut      => writePixelColor,
      writePixelCvg           => writePixelCvg,
      writePixelFBData9       => writePixelFBData9,
      
      writePixelZ             => writePixelZ,      
      writePixelAddrZ         => writePixelAddrZ,   
      writePixelDataZ         => writePixelDataZ,   
      writePixelFBData9Z      => writePixelFBData9Z,
      
      copyPixelOut            => copyPixel,
      copyAddrOut             => copyAddr,
      copyDataOut             => copyData,
      copyBEOut               => copyBE,
      copyPixelFBData9Out     => copyPixelFBData9
   );
   
   writePixelData8  <= writePixelColor(1) when (writePixelAddr(0) = '1') else writePixelColor(0);
   writePixelData16 <= writePixelColor(0)(7 downto 3) & writePixelColor(1)(7 downto 3) & writePixelColor(2)(7 downto 3) & writePixelCvg(2);
   writePixelData32 <= writePixelColor(0) & writePixelColor(1) & writePixelColor(2) & writePixelCvg & "00000";
   
   -- normal pixels
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         stall_raster <= fifoout_nearfull or rdp9fifo_nearfull or fifooutZ_nearfull or rdp9fifoZ_nearfull;
      
         fifoOut_Wr   <= '0';
         fifoOut_Din  <= pixel64BE & pixel64Addr & pixel64data;
         
         if (fillWrite = '1') then
         
            fifoOut_Wr   <= '1';
            fifoOut_Din(91 downto 84) <= std_logic_vector(fillBE sll to_integer(fillAddr(2 downto 0)));
            fifoOut_Din(83 downto 64) <= std_logic_vector(fillAddr(22 downto 3));
            fifoOut_Din(63 downto  0) <= std_logic_vector(fillColor);
            
         elsif (copyPixel = '1') then
         
            fifoOut_Wr   <= '1';
            fifoOut_Din(91 downto 84) <= std_logic_vector(copyBE);
            fifoOut_Din(83 downto 64) <= std_logic_vector(copyAddr(22 downto 3));
            fifoOut_Din(63 downto  0) <= std_logic_vector(copyData);  
         
         elsif (writePixel = '1' and writePixelAddr(25 downto 23) = 0) then -- todo: move max ram check to ddr3mux
         
            if (pixel64filled = '0' or writePixelAddr(22 downto 3) /= unsigned(pixel64Addr)) then
               fifoOut_Wr  <= pixel64filled;
               pixel64Addr <= std_logic_vector(writePixelAddr(22 downto 3));
               pixel64BE   <= (others => '0');
               pixel64filled <= '1';
            end if;
            
            if (settings_colorImage.FB_size = SIZE_8BIT) then
               case (writePixelAddr(2 downto 0)) is
                  when "000" => pixel64data( 7 downto  0) <= std_logic_vector(writePixelData8); pixel64BE(0) <= '1';
                  when "001" => pixel64data(15 downto  8) <= std_logic_vector(writePixelData8); pixel64BE(1) <= '1';
                  when "010" => pixel64data(23 downto 16) <= std_logic_vector(writePixelData8); pixel64BE(2) <= '1';
                  when "011" => pixel64data(31 downto 24) <= std_logic_vector(writePixelData8); pixel64BE(3) <= '1';
                  when "100" => pixel64data(39 downto 32) <= std_logic_vector(writePixelData8); pixel64BE(4) <= '1';
                  when "101" => pixel64data(47 downto 40) <= std_logic_vector(writePixelData8); pixel64BE(5) <= '1';
                  when "110" => pixel64data(55 downto 48) <= std_logic_vector(writePixelData8); pixel64BE(6) <= '1';
                  when "111" => pixel64data(63 downto 56) <= std_logic_vector(writePixelData8); pixel64BE(7) <= '1';
                  when others => null;
               end case;
            elsif (settings_colorImage.FB_size = SIZE_16BIT) then
               case (writePixelAddr(2 downto 1)) is
                  when "00" => pixel64data(15 downto  0) <= std_logic_vector(byteswap16(writePixelData16)); pixel64BE(1 downto 0) <= "11";
                  when "01" => pixel64data(31 downto 16) <= std_logic_vector(byteswap16(writePixelData16)); pixel64BE(3 downto 2) <= "11";
                  when "10" => pixel64data(47 downto 32) <= std_logic_vector(byteswap16(writePixelData16)); pixel64BE(5 downto 4) <= "11";
                  when "11" => pixel64data(63 downto 48) <= std_logic_vector(byteswap16(writePixelData16)); pixel64BE(7 downto 6) <= "11";
                  when others => null;
               end case;
            elsif (settings_colorImage.FB_size = SIZE_32BIT) then     
               case (writePixelAddr(2)) is
                  when '0' => pixel64data(31 downto  0) <= std_logic_vector(byteswap32(writePixelData32)); pixel64BE(3 downto 0) <= "1111";
                  when '1' => pixel64data(63 downto 32) <= std_logic_vector(byteswap32(writePixelData32)); pixel64BE(7 downto 4) <= "1111";
                  when others => null;
               end case;
            end if;
         
         elsif (poly_done = '1') then
         
            pixel64filled  <= '0';
            fifoOut_Wr     <= pixel64filled;
            
         end if;

      end if;
   end process;
   
   -- Z pixels
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         fifoOutZ_Wr   <= '0';
         fifoOutZ_Din  <= pixel64ZBE & pixel64ZAddr & pixel64Zdata;
         
         if (writePixelZ = '1' and writePixelAddrZ(25 downto 23) = 0) then
         
            if (pixel64Zfilled = '0' or writePixelAddrZ(22 downto 3) /= unsigned(pixel64ZAddr)) then
               fifoOutZ_Wr    <= pixel64Zfilled and writeZ;
               pixel64ZAddr   <= std_logic_vector(writePixelAddrZ(22 downto 3));
               pixel64ZBE     <= (others => '0');
               pixel64Zfilled <= '1';
            end if;
            
            case (writePixelAddrZ(2 downto 1)) is
               when "00" => pixel64Zdata(15 downto  0) <= std_logic_vector(byteswap16(writePixelDataZ(15 downto 0))); pixel64ZBE(1 downto 0) <= "11";
               when "01" => pixel64Zdata(31 downto 16) <= std_logic_vector(byteswap16(writePixelDataZ(15 downto 0))); pixel64ZBE(3 downto 2) <= "11";
               when "10" => pixel64Zdata(47 downto 32) <= std_logic_vector(byteswap16(writePixelDataZ(15 downto 0))); pixel64ZBE(5 downto 4) <= "11";
               when "11" => pixel64Zdata(63 downto 48) <= std_logic_vector(byteswap16(writePixelDataZ(15 downto 0))); pixel64ZBE(7 downto 6) <= "11";
               when others => null;
            end case;
         
         elsif (poly_done = '1') then

            pixel64Zfilled  <= '0';
            fifoOutZ_Wr     <= pixel64Zfilled and writeZ;
            
         end if;

      end if;
   end process;
   
   -- bit 9 framebuffer
   process (all)
   begin
      copyPixelData9 <= (others => '0');
      if (copyBE(1) = '1' and copyData(8) = '1') then 
         copyPixelData9((to_integer(copyAddr(4 downto 3)) * 8) + 0) <= '1';
         copyPixelData9((to_integer(copyAddr(4 downto 3)) * 8) + 1) <= '1';
      end if;
      if (copyBE(3) = '1' and copyData(24) = '1') then 
         copyPixelData9((to_integer(copyAddr(4 downto 3)) * 8) + 2) <= '1';
         copyPixelData9((to_integer(copyAddr(4 downto 3)) * 8) + 3) <= '1';
      end if;
      if (copyBE(5) = '1' and copyData(40) = '1') then 
         copyPixelData9((to_integer(copyAddr(4 downto 3)) * 8) + 4) <= '1';
         copyPixelData9((to_integer(copyAddr(4 downto 3)) * 8) + 5) <= '1';
      end if;
      if (copyBE(7) = '1' and copyData(56) = '1') then 
         copyPixelData9((to_integer(copyAddr(4 downto 3)) * 8) + 6) <= '1';
         copyPixelData9((to_integer(copyAddr(4 downto 3)) * 8) + 7) <= '1';
      end if;
   end process; 
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         rdp9fifo_Wr   <= '0';
         rdp9fifo_Din  <= pixel9BE & pixel9Addr & pixel9data;
         
         if (fillWrite = '1') then
         
            -- assume that fill start from 4(16?) pixel aligned address. If that is not the case, old data must be read back first to prefill
         
            if (pixel9filled = '0' or fillAddr(22 downto 5) /= unsigned(pixel9Addr)) then
               rdp9fifo_Wr  <= pixel9filled and write9;
               pixel9Addr   <= std_logic_vector(fillAddr(22 downto 5));
               pixel9filled <= '1';
               pixel9data   <= (others => '0');
               pixel9BE     <= (others => '0');
            end if;
            
            case (fillAddr(4 downto 3)) is
               when "00" => 
                  pixel9BE(0)              <= '1';
                  pixel9data( 7 downto  0) <= fillColor(56) & fillColor(56) & fillColor(40) & fillColor(40) & fillColor(24) & fillColor(24) & fillColor(8) & fillColor(8);
                  
               when "01" => 
                  pixel9BE(1)              <= '1';
                  pixel9data(15 downto  8) <= fillColor(56) & fillColor(56) & fillColor(40) & fillColor(40) & fillColor(24) & fillColor(24) & fillColor(8) & fillColor(8);
                  
               when "10" => 
                  pixel9BE(2)              <= '1';
                  pixel9data(23 downto 16) <= fillColor(56) & fillColor(56) & fillColor(40) & fillColor(40) & fillColor(24) & fillColor(24) & fillColor(8) & fillColor(8);
                  
               when "11" =>
                  pixel9BE(3)              <= '1';
                  pixel9data(31 downto 24) <= fillColor(56) & fillColor(56) & fillColor(40) & fillColor(40) & fillColor(24) & fillColor(24) & fillColor(8) & fillColor(8);
                  
               when others => null;
            end case;
            
         elsif (copyPixel = '1' and copyAddr(25 downto 23) = 0) then
         
            pixel9BE <= x"F";
         
            if (pixel9filled = '0' or copyAddr(22 downto 5) /= unsigned(pixel9Addr)) then
               pixel9data   <= std_logic_vector(copyPixelFBData9) or std_logic_vector(copyPixelData9); -- must fill in old data because only some bits are updated, byte enable not possible
               rdp9fifo_Wr  <= pixel9filled and write9;
               pixel9Addr   <= std_logic_vector(copyAddr(22 downto 5));
               pixel9filled <= '1';
            else
               pixel9data   <= pixel9data or std_logic_vector(copyPixelData9);
            end if;
         
         elsif (writePixel = '1' and writePixelAddr(25 downto 23) = 0 and settings_colorImage.FB_size = SIZE_16BIT) then
         
            pixel9BE <= x"F";
         
            if (pixel9filled = '0' or writePixelAddr(22 downto 5) /= unsigned(pixel9Addr)) then
               pixel9data   <= std_logic_vector(writePixelFBData9); -- must fill in old data because only 2 bits are updated, byte enable not possible
               rdp9fifo_Wr  <= pixel9filled and write9;
               pixel9Addr   <= std_logic_vector(writePixelAddr(22 downto 5));
               pixel9filled <= '1';
            end if;
            
            pixel9data((to_integer(writePixelAddr(4 downto 1)) * 2) + 1) <= writePixelCvg(1);
            pixel9data((to_integer(writePixelAddr(4 downto 1)) * 2) + 0) <= writePixelCvg(0);
         
         elsif (poly_done = '1') then

            pixel9filled  <= '0';
            rdp9fifo_Wr   <= pixel9filled and write9;
            
         end if;

      end if;
   end process;
   
   -- bit 9 Z Buffer
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         rdp9fifoZ_Wr   <= '0';
         rdp9fifoZ_Din  <= pixel9ZAddr & pixel9Zdata;
         
         if (writePixelZ = '1' and writePixelAddrZ(25 downto 23) = 0) then -- todo: move max ram check to ddr3mux
         
            if (pixel9Zfilled = '0' or writePixelAddrZ(22 downto 5) /= unsigned(pixel9ZAddr)) then
               pixel9Zdata   <= std_logic_vector(writePixelFBData9Z); -- must fill in old data because only 2 bits are updated, byte enable not possible
               rdp9fifoZ_Wr  <= pixel9Zfilled and write9;
               pixel9ZAddr   <= std_logic_vector(writePixelAddrZ(22 downto 5));
               pixel9Zfilled <= '1';
            end if;
            
            pixel9Zdata((to_integer(writePixelAddrZ(4 downto 1)) * 2) + 1) <= writePixelDataZ(17);
            pixel9Zdata((to_integer(writePixelAddrZ(4 downto 1)) * 2) + 0) <= writePixelDataZ(16);
         
         elsif (poly_done = '1') then

            pixel9Zfilled  <= '0';
            rdp9fifoZ_Wr   <= pixel9Zfilled and write9;
            
         end if;

      end if;
   end process;
   
   writePixelsDone <= '1' when (fifoout_empty = '1' and fifooutZ_empty = '1' and rdp9fifo_empty = '1' and rdp9fifoZ_empty = '1' and
                                pixel64filled = '0' and pixel64Zfilled = '0' and pixel9filled   = '0' and pixel9Zfilled   = '0' and
                                fifoOut_Wr    = '0' and fifoOutZ_Wr    = '0' and rdp9fifo_Wr    = '0' and rdp9fifoZ_Wr    = '0') else '0';
                                
   
--##############################################################
--############################### savestates
--##############################################################

   SS_idle <= '1';

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         if (SS_reset = '1') then
         
            for i in 0 to 1 loop
               ss_in(i) <= (others => '0');
            end loop;
            
            ss_in(0)(52) <= '1'; -- DPC_STATUS_cbuf_ready = 1
            
         elsif (SS_wren = '1') then
            ss_in(to_integer(SS_Adr)) <= unsigned(SS_DataWrite);
         end if;
         
         if (SS_rden = '1') then
            SS_DataRead <= std_logic_vector(ss_out(to_integer(SS_Adr)));
         end if;
      
      end if;
   end process;
   
--##############################################################
--############################### export
--##############################################################
   
   -- synthesis translate_off
   goutput : if 1 = 1 generate
      type ttracecounts_out is array(0 to 29) of integer;
      signal tracecounts_out : ttracecounts_out;
   begin
   
      process
         file outfile               : text;
         variable f_status          : FILE_OPEN_STATUS;
         variable line_out          : line;
         variable stringbuffer      : string(1 to 31);
         variable export_fillAddr   : unsigned(25 downto 0);
         variable export_fillColor  : unsigned(63 downto 0);
         variable export_fillBE     : unsigned(7 downto 0);
         variable export_fillX_mod  : unsigned(11 downto 0);
         variable export_fillIndex  : integer;
         variable export_copyIndex  : integer;
         variable export_copyAddr   : unsigned(31 downto 0);
         variable export_copyData   : unsigned(63 downto 0);
         variable useTexture        : std_logic;
         variable useTexture2       : std_logic;
         variable useLOD            : std_logic;
         variable texfetch_count    : integer;
         variable texcolor_count    : integer;
      begin
   
         file_open(f_status, outfile, "R:\\rdp_n64_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\rdp_n64_sim.txt", append_mode);
         
         for i in 0 to 29 loop
            tracecounts_out(i) <= 0;
         end loop;
         
         while (true) loop
            
            wait until rising_edge(clk1x);
            
            if (export_command_done = '1') then
               write(line_out, string'("Command: I ")); 
               write(line_out, to_string_len(tracecounts_out(2) + 1, 8));
               write(line_out, string'(" A ")); 
               write(line_out, to_hstring(to_unsigned(0, 32)));
               write(line_out, string'(" D "));
               write(line_out, to_hstring(export_command_data));
               writeline(outfile, line_out);
               tracecounts_out(2) <= tracecounts_out(2) + 1;
            end if;
            
            --if (export_line_done = '1') then
            --   write(line_out, string'("LINE: I ")); 
            --   write(line_out, to_string_len(tracecounts_out(20) + 1, 8));
            --   write(line_out, string'(" A 00000000 D 00000000 X    0 Y ")); 
            --   write(line_out, to_string_len(to_integer(export_line_list.y), 4));
            --   write(line_out, string'(" D1 "));
            --   write(line_out, to_hstring(export_line_list.debug1));
            --   write(line_out, string'(" D2 "));
            --   write(line_out, to_hstring(export_line_list.debug2));
            --   write(line_out, string'(" D3 "));
            --   write(line_out, to_hstring(export_line_list.debug3));
            --   writeline(outfile, line_out);
            --   tracecounts_out(20) <= tracecounts_out(20) + 1;
            --end if;
            
            if (export_load_done = '1') then
               export_gpu32(16, tracecounts_out(16), export_loadFetch, outfile); tracecounts_out(16) <= tracecounts_out(16) + 1;
               export_gpu64(17, tracecounts_out(17), export_LoadData,  outfile); tracecounts_out(17) <= tracecounts_out(17) + 1;
               export_gpu32(18, tracecounts_out(18), export_LoadValue, outfile); tracecounts_out(18) <= tracecounts_out(18) + 1;
            end if;
            
            if (export_pipeDone = '1') then
            
               useTexture := '0';
               case (to_integer(settings_combineMode.combine_sub_a_R_1)) is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_b_R_1)) is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_mul_R_1))   is  when 1 | 2 | 8 | 9 | 13 | 14 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_add_R_1))   is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_a_A_1)) is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_b_A_1)) is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_mul_A_1))   is  when 1 | 2 | 6 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_add_A_1))   is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
               
               case (to_integer(settings_combineMode.combine_sub_a_R_0)) is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_b_R_0)) is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_mul_R_0))   is  when 1 | 2 | 8 | 9 | 13 | 14 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_add_R_0))   is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_a_A_0)) is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_b_A_0)) is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_mul_A_0))   is  when 1 | 2 | 6 => useTexture := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_add_A_0))   is  when 1 | 2 => useTexture := '1'; when others => null;  end case;
            
               export_gpu32( 3, tracecounts_out( 3), export_pipeO,    outfile); tracecounts_out( 3) <= tracecounts_out( 3) + 1;
               export_gpu32( 4, tracecounts_out( 4), export_color,    outfile); tracecounts_out( 4) <= tracecounts_out( 4) + 1;
               --export_gpu32(25, tracecounts_out(25), export_RGBA,     outfile); tracecounts_out(25) <= tracecounts_out(25) + 1;
               
               texfetch_count := tracecounts_out(7);
               texcolor_count := tracecounts_out(13);
               
               if (useTexture = '1') then
               
                  useLOD := settings_otherModes.texLod;
                  if (settings_combineMode.combine_mul_R_1 = 13)                                          then useLOD := '1'; end if;
                  if (settings_combineMode.combine_mul_A_1 = 0)                                           then useLOD := '1'; end if;
                  if (settings_otherModes.cycleType = "01" and settings_combineMode.combine_mul_R_0 = 13) then useLOD := '1'; end if;
                  if (settings_otherModes.cycleType = "01" and settings_combineMode.combine_mul_A_0 = 0)  then useLOD := '1'; end if;
                  if (useLOD = '1') then
                     --export_gpu32(19, tracecounts_out(19), export_LOD,      outfile); tracecounts_out(19) <= tracecounts_out(19) + 1;
                     --export_gpu32(26, tracecounts_out(26), export_LODP,     outfile); tracecounts_out(26) <= tracecounts_out(26) + 1;
                  end if;
                  
                  export_gpu32(11, tracecounts_out(11), export_TexCoord, outfile); tracecounts_out(11) <= tracecounts_out(11) + 1;
                  --if (settings_otherModes.bilerp0 = '1' and (settings_otherModes.sampleType = '1' or settings_otherModes.enTlut = '1')) then
                  --   export_gpu32(7, texfetch_count + 0, export_TexFetch0, outfile);
                  --   export_gpu32(7, texfetch_count + 1, export_TexFetch1, outfile);
                  --   export_gpu32(7, texfetch_count + 2, export_TexFetch2, outfile);
                  --   export_gpu32(7, texfetch_count + 3, export_TexFetch3, outfile);
                  --   texfetch_count := texfetch_count + 4;
                  --else
                  --   export_gpu32(7, texfetch_count, export_TexFetch0, outfile);
                  --   texfetch_count := texfetch_count + 1;
                  --end if;
                  --
                  --if (export_texmode = TEXMODE_UNFILTERED) then                 
                  --   export_gpu32(13, texcolor_count, export_TexColor0, outfile); 
                  --   texcolor_count := texcolor_count + 1;
                  --elsif (export_texmode = TEXMODE_UPPER) then 
                  --   export_gpu32(13, texcolor_count + 0, export_TexColor1, outfile);
                  --   export_gpu32(13, texcolor_count + 1, export_TexColor2, outfile);
                  --   export_gpu32(13, texcolor_count + 2, export_TexColor3, outfile);
                  --   texcolor_count := texcolor_count + 3;
                  --elsif (export_texmode = TEXMODE_LOWER) then 
                  --   export_gpu32(13, texcolor_count + 0, export_TexColor1, outfile);
                  --   export_gpu32(13, texcolor_count + 1, export_TexColor2, outfile);
                  --   export_gpu32(13, texcolor_count + 2, export_TexColor0, outfile);
                  --   texcolor_count := texcolor_count + 3;
                  --end if;
               end if;
               
               useTexture2 := '0';
               case (to_integer(settings_combineMode.combine_sub_a_R_1)) is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_b_R_1)) is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_mul_R_1))   is  when 2 | 9 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_add_R_1))   is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_a_A_1)) is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_b_A_1)) is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_mul_A_1))   is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_add_A_1))   is  when 2 => useTexture2 := '1'; when others => null;  end case;
               
               case (to_integer(settings_combineMode.combine_sub_a_R_0)) is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_b_R_0)) is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_mul_R_0))   is  when 2 | 9 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_add_R_0))   is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_a_A_0)) is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_sub_b_A_0)) is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_mul_A_0))   is  when 2 => useTexture2 := '1'; when others => null;  end case;
               case (to_integer(settings_combineMode.combine_add_A_0))   is  when 2 => useTexture2 := '1'; when others => null;  end case;
               
               if (useTexture2 = '1') then
                  --if (settings_otherModes.sampleType = '1' or settings_otherModes.enTlut = '1') then
                  --   export_gpu32(7, texfetch_count + 0, export2_TexFetch0, outfile);
                  --   export_gpu32(7, texfetch_count + 1, export2_TexFetch1, outfile);
                  --   export_gpu32(7, texfetch_count + 2, export2_TexFetch2, outfile);
                  --   export_gpu32(7, texfetch_count + 3, export2_TexFetch3, outfile);
                  --   texfetch_count := texfetch_count + 4;
                  --else
                  --   export_gpu32(7, texfetch_count, export2_TexFetch0, outfile);
                  --   texfetch_count := texfetch_count + 1;
                  --end if;
                  --
                  --if (export2_texmode = TEXMODE_UNFILTERED) then                 
                  --   export_gpu32(13, texcolor_count, export2_TexColor0, outfile); 
                  --   texcolor_count := texcolor_count + 1;
                  --elsif (export2_texmode = TEXMODE_UPPER) then 
                  --   export_gpu32(13, texcolor_count + 0, export2_TexColor1, outfile);
                  --   export_gpu32(13, texcolor_count + 1, export2_TexColor2, outfile);
                  --   export_gpu32(13, texcolor_count + 2, export2_TexColor3, outfile);
                  --   texcolor_count := texcolor_count + 3;
                  --elsif (export2_texmode = TEXMODE_LOWER) then 
                  --   export_gpu32(13, texcolor_count + 0, export2_TexColor1, outfile);
                  --   export_gpu32(13, texcolor_count + 1, export2_TexColor2, outfile);
                  --   export_gpu32(13, texcolor_count + 2, export2_TexColor0, outfile);
                  --   texcolor_count := texcolor_count + 3;
                  --end if;
               end if;
               
               tracecounts_out(7)  <= texfetch_count;
               tracecounts_out(13) <= texcolor_count;
               
               export_gpu64(23, tracecounts_out(23), export_Comb    , outfile); tracecounts_out(23) <= tracecounts_out(23) + 1;
               if (settings_otherModes.imageRead = '1') then
                  export_gpu32(24, tracecounts_out(24), export_FBMem   , outfile); tracecounts_out(24) <= tracecounts_out(24) + 1;
               end if;               
               if (settings_otherModes.zCompare = '1') then
                  export_gpu32(12, tracecounts_out(12), export_Z       , outfile); tracecounts_out(12) <= tracecounts_out(12) + 1;
               end if;
            end if;
            
            if (writePixel = '1') then
               write(line_out, string'("Pixel: I ")); 
               write(line_out, to_string_len(tracecounts_out(1) + 1, 8));
               write(line_out, string'(" A ")); 
               write(line_out, to_hstring(resize(writePixelAddr, 32)));
               write(line_out, string'(" D ")); 
               if (settings_colorImage.FB_size = SIZE_8BIT) then
                  write(line_out, to_hstring(x"000000" & writePixelData8));
               elsif (settings_colorImage.FB_size = SIZE_16BIT) then
                  write(line_out, to_hstring(x"0000" & writePixelData16));
               else
                  write(line_out, to_hstring(writePixelData32));
               end if;
               write(line_out, string'(" X ")); 
               write(line_out, to_string_len(to_integer(export_writePixelX), 5));
               write(line_out, string'(" Y ")); 
               write(line_out, to_string_len(to_integer(export_writePixelY), 5));
               if (settings_colorImage.FB_size = SIZE_8BIT) then
                  write(line_out, string'(" D1 00000000 D2 00000000 D3 00000001"));
               else
                  write(line_out, string'(" D1 "));
                  if (settings_colorImage.FB_size = SIZE_16BIT) then
                     write(line_out, to_hstring(to_unsigned(0, 30) & writePixelCvg(1 downto 0)));
                  else
                     write(line_out, to_hstring(to_unsigned(0, 32)));
                  end if;
                  write(line_out, string'(" D2 "));
                  write(line_out, to_hstring(to_unsigned(0, 32)));
                  write(line_out, string'(" D3 "));
                  write(line_out, to_hstring(resize(writePixelData32(31 downto 8), 32)));
               end if;
               writeline(outfile, line_out);
               tracecounts_out(1) <= tracecounts_out(1) + 1;
            end if;
            
            if (export_copy = '1') then
               export_gpu64(14, tracecounts_out(14), export_copyFetch, outfile); tracecounts_out(14) <= tracecounts_out(14) + 1;
               
               export_copyIndex := tracecounts_out(15);
               export_copyAddr  := export_copyBytes.addr;
               export_copyData  := export_copyBytes.data;
               for i in 0 to to_integer(export_copyBytes.debug2(3 downto 0) - 1) loop
                  write(line_out, string'("CopyByte: I ")); 
                  write(line_out, to_string_len(export_copyIndex + 1, 8));
                  write(line_out, string'(" A ")); 
                  write(line_out, to_hstring(export_copyAddr));
                  write(line_out, string'(" D ")); 
                  write(line_out, to_hstring(24x"0" & export_copyData(7 downto 0)));
                  write(line_out, string'(" X     ")); 
                  if (export_copyBytes.debug1(i) = '1') then
                     write(line_out, string'("1")); 
                  else
                     write(line_out, string'("0"));
                  end if;
                  write(line_out, string'(" Y ")); 
                  write(line_out, to_string_len(to_integer(export_copyBytes.y), 5));
                  write(line_out, string'(" D1 "));
                  write(line_out, to_hstring(to_unsigned(0, 32)));
                  write(line_out, string'(" D2 "));
                  write(line_out, to_hstring(to_unsigned(0, 32)));
                  write(line_out, string'(" D3 "));
                  write(line_out, to_hstring(to_unsigned(0, 32)));
                  writeline(outfile, line_out);
                  export_copyIndex := export_copyIndex + 1;
                  if (export_copyBytes.debug3(0) = '1') then 
                     export_copyAddr  := export_copyAddr + 1;
                  else
                     export_copyAddr  := export_copyAddr - 1;
                  end if;
                  export_copyData := x"00" & export_copyData(63 downto 8);
               end loop;
               tracecounts_out(15) <= export_copyIndex;
            end if;
            
            if (fillWrite = '1') then
               case (settings_colorImage.FB_size) is
                  when SIZE_8BIT  => report "8 Bit Fill mode export not implemented" severity failure; 
                  
                  when SIZE_16BIT => 
                     export_fillAddr  := fillAddr(25 downto 3) & "000";
                     export_fillColor := fillColor;
                     export_fillBE    := fillBE sll to_integer(fillAddr(2 downto 0));
                     export_fillX_mod := export_fillX;
                     export_fillIndex := tracecounts_out(1);
                     while (export_fillBE(1 downto 0) /= "11") loop
                        export_fillAddr  := export_fillAddr + 2;
                        export_fillColor := x"0000" & export_fillColor(63 downto 16);
                        export_fillBE    := "00" & export_fillBE(7 downto 2);
                     end loop;
                     for i in 0 to 3 loop
                        if (export_fillBE(1 downto 0) = "11") then
                           write(line_out, string'("Pixel: I ")); 
                           write(line_out, to_string_len(export_fillIndex + 1, 8));
                           write(line_out, string'(" A ")); 
                           write(line_out, to_hstring(resize(export_fillAddr, 32)));
                           write(line_out, string'(" D ")); 
                           write(line_out, to_hstring(x"0000" & byteswap16(export_fillColor(15 downto 0))));
                           write(line_out, string'(" X ")); 
                           write(line_out, to_string_len(to_integer(export_fillX_mod), 5));
                           write(line_out, string'(" Y ")); 
                           write(line_out, to_string_len(to_integer(export_fillY), 5));
                           write(line_out, string'(" D1 "));
                           write(line_out, to_hstring(to_unsigned(0, 30) & export_fillColor(8) & export_fillColor(8)));
                           write(line_out, string'(" D2 "));
                           write(line_out, to_hstring(to_unsigned(0, 32)));
                           write(line_out, string'(" D3 "));
                           write(line_out, to_hstring(to_unsigned(0, 32)));
                           writeline(outfile, line_out);
                           export_fillIndex := export_fillIndex + 1;
                        end if;
                        export_fillAddr  := export_fillAddr + 2;
                        export_fillColor := x"0000" & export_fillColor(63 downto 16);
                        export_fillBE    := "00" & export_fillBE(7 downto 2);
                        export_fillX_mod := export_fillX_mod + 1;
                     end loop;
                     tracecounts_out(1) <= export_fillIndex;

                  when SIZE_32BIT => 
                     export_fillAddr  := fillAddr(25 downto 3) & "000";
                     export_fillColor := fillColor;
                     export_fillBE    := fillBE sll to_integer(fillAddr(2 downto 0));
                     export_fillX_mod := export_fillX;
                     export_fillIndex := tracecounts_out(1);
                     while (export_fillBE(3 downto 0) /= "1111") loop
                        export_fillAddr  := export_fillAddr + 4;
                        export_fillColor := x"00000000" & export_fillColor(63 downto 32);
                        export_fillBE    := "0000" & export_fillBE(7 downto 4);
                     end loop;
                     for i in 0 to 1 loop
                        if (export_fillBE(3 downto 0) = "1111") then
                           write(line_out, string'("Pixel: I ")); 
                           write(line_out, to_string_len(export_fillIndex + 1, 8));
                           write(line_out, string'(" A ")); 
                           write(line_out, to_hstring(resize(export_fillAddr, 32)));
                           write(line_out, string'(" D ")); 
                           write(line_out, to_hstring(byteswap32(export_fillColor(31 downto 0))));
                           write(line_out, string'(" X ")); 
                           write(line_out, to_string_len(to_integer(export_fillX_mod), 5));
                           write(line_out, string'(" Y ")); 
                           write(line_out, to_string_len(to_integer(export_fillY), 5));
                           write(line_out, string'(" D1 "));
                           write(line_out, to_hstring(to_unsigned(0, 32)));
                           write(line_out, string'(" D2 "));
                           write(line_out, to_hstring(to_unsigned(0, 32)));
                           write(line_out, string'(" D3 "));
                           write(line_out, to_hstring(to_unsigned(0, 32)));
                           writeline(outfile, line_out);
                           export_fillIndex := export_fillIndex + 1;
                        end if;
                        export_fillAddr  := export_fillAddr + 4;
                        export_fillColor := x"00000000" & export_fillColor(63 downto 32);
                        export_fillBE    := "0000" & export_fillBE(7 downto 4);
                        export_fillX_mod := export_fillX_mod + 1;
                     end loop;
                     tracecounts_out(1) <= export_fillIndex;
                  
                  when others => null; 
               end case;
            end if;
            
            
         end loop;
         
      end process;
   
   end generate goutput;
   
   goutput_fb : if 1 = 1 generate
   begin
   
      process
      
         file outfile: text;
         variable f_status: FILE_OPEN_STATUS;
         variable line_out : line;
         variable addr     : unsigned(25 downto 0);
         variable be       : unsigned(7 downto 0);
         variable data     : unsigned(63 downto 0);
         
         variable calcaddr : integer;
         variable linesize : integer;
         variable xpos     : integer;
         variable ypos     : integer;
         variable color    : unsigned(31 downto 0) := (others => '0');
         
      begin
   
         file_open(f_status, outfile, "gra_fb_out_fb.gra", write_mode);
         file_close(outfile);
         
         file_open(f_status, outfile, "gra_fb_out_fb.gra", append_mode);
         write(line_out, string'("640#480#2")); 
         writeline(outfile, line_out);
         
         while (true) loop
            wait until rising_edge(clk1x);
            if (fifoout_Wr = '1') then
            
               if (settings_colorImage.FB_size = SIZE_8BIT) then
               
                  null;
               
               elsif (settings_colorImage.FB_size = SIZE_16BIT) then
                  
                  be   := unsigned(fifoout_Din(91 downto 84));
                  addr := "000" & unsigned(fifoout_Din(83 downto 64)) & "000";
                  data := unsigned(fifoout_Din(63 downto 0));
                  
                  -- resize(settings_colorImage.FB_base + ((line_posY * (settings_colorImage.FB_width_m1 + 1)) + line_posX) * 2, 26)
                  linesize := (to_integer(settings_colorImage.FB_width_m1) + 1) * 2;                
                  calcaddr := to_integer(addr) - to_integer(settings_colorImage.FB_base);
                  
                  for i in 0 to 3 loop
                     ypos := calcaddr / linesize;
                     xpos := (calcaddr - (ypos * linesize)) / 2;
                     if (be(1 downto 0) = "11") then
                        data(15 downto 0) := byteswap16(data(15 downto 0));                  
                        color(23 downto 16) := data(15 downto 11) & "000";
                        color(15 downto  8) := data(10 downto  6) & "000";
                        color( 7 downto  0) := data( 5 downto  1) & "000";
                        write(line_out, to_integer(color));
                        write(line_out, string'("#"));
                        write(line_out, xpos);
                        write(line_out, string'("#")); 
                        write(line_out, ypos);
                        writeline(outfile, line_out);
                     end if;
                     calcaddr := calcaddr + 2;
                     data := 16x"0" & data(63 downto 16);
                     be := "00" & be(7 downto 2);
                  end loop;
   
               elsif (settings_colorImage.FB_size = SIZE_32BIT) then     
               
                  be   := unsigned(fifoout_Din(91 downto 84));
                  addr := "000" & unsigned(fifoout_Din(83 downto 64)) & "000";
                  data := unsigned(fifoout_Din(63 downto 0));
                  
                  -- resize(settings_colorImage.FB_base + ((line_posY * (settings_colorImage.FB_width_m1 + 1)) + line_posX) * 4, 26)
                  linesize := (to_integer(settings_colorImage.FB_width_m1) + 1) * 4;                
                  calcaddr := to_integer(addr) - to_integer(settings_colorImage.FB_base);
                  
                  for i in 0 to 1 loop
                     ypos     := calcaddr / linesize;
                     xpos     := (calcaddr - (ypos * linesize)) / 4;
                     if (be(3 downto 0) = "1111") then
                        data(31 downto 0) := byteswap32(data(31 downto 0));                  
                        color(23 downto 16) := data(31 downto 24);
                        color(15 downto  8) := data(23 downto 16);
                        color( 7 downto  0) := data(15 downto  8);
                        write(line_out, to_integer(color));
                        write(line_out, string'("#"));
                        write(line_out, xpos);
                        write(line_out, string'("#")); 
                        write(line_out, ypos);
                        writeline(outfile, line_out);
                     end if;
                     calcaddr := calcaddr + 4;
                     data := 32x"0" & data(63 downto 32);
                     be := "0000" & be(7 downto 4);
                  end loop;
                  
               end if;
               
            end if;
            
            if (poly_done = '1') then
               file_close(outfile);
               file_open(f_status, outfile, "gra_fb_out_fb.gra", append_mode);
            end if;
             
         end loop;
         
      end process;
   
   end generate goutput_fb;

   -- synthesis translate_on   


end architecture;





