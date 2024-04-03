library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library MEM;
use work.pexport.all;
use work.pDDR3.all;
use work.pSDRAM.all;

entity n64top is
   generic
   (
      use2Xclock              : std_logic;
      is_simu                 : std_logic := '0'
   ); 
   port  
   (  
      clk1x                   : in  std_logic;
      clk93                   : in  std_logic;
      clk2x                   : in  std_logic;
      clkvid                  : in  std_logic;
      reset                   : in  std_logic;
      pause                   : in  std_logic;
      errorCodesOn            : in  std_logic;
      fpscountOn              : in  std_logic;
      
      ISPAL                   : in  std_logic;
      FIXEDBLANKS             : in  std_logic;
      CROPVERTICAL            : in  unsigned(1 downto 0);
      VI_BILINEAROFF          : in  std_logic;
      VI_GAMMAOFF             : in  std_logic;
      VI_DEDITHEROFF          : in  std_logic;
      VI_DEDITHERFORCE        : in  std_logic;
      VI_AAOFF                : in  std_logic;
      VI_DIVOTOFF             : in  std_logic;
      VI_NOISEOFF             : in  std_logic;
      VI_7BITPERCOLOR         : in  std_logic;
      VI_DIRECTFBMODE         : in  std_logic;
      
      CICTYPE                 : in  std_logic_vector(3 downto 0);
      RAMSIZE8                : in  std_logic;
      FASTRAM                 : in  std_logic;
      FASTROM                 : in  std_logic;
      INSTRCACHEON            : in  std_logic;
      DATACACHEON             : in  std_logic;
      DATACACHESLOW           : in  std_logic_vector(3 downto 0); 
      DATACACHEFORCEWEB       : in  std_logic; 
      DATACACHETLBON          : in  std_logic; 
      RANDOMMISS              : in  unsigned(3 downto 0);
      DISABLE_BOOTCOUNT       : in  std_logic;
      DISABLE_DTLBMINI        : in  std_logic;
      DDR3SLOW                : in  std_logic_vector(3 downto 0);
      DISABLEFILTER           : in  std_logic;       
      DISABLEDITHER           : in  std_logic;       
      DISABLELOD              : in  std_logic;       
      
      write9                  : in  std_logic;
      read9                   : in  std_logic;
      wait9                   : in  std_logic;
      writeZ                  : in  std_logic;
      readZ                   : in  std_logic;
      
      -- savestates
      increaseSSHeaderCount   : in  std_logic;
      save_state              : in  std_logic;
      load_state              : in  std_logic;
      savestate_number        : in  integer range 0 to 3;
      state_loaded            : out std_logic;
      
      -- PIFROM download port
      pifrom_wraddress        : in std_logic_vector(9 downto 0);
      pifrom_wrdata           : in std_logic_vector(31 downto 0);
      pifrom_wren             : in std_logic;
         
      -- RDRAM 
      ddr3_BUSY               : in  std_logic;                    
      ddr3_DOUT               : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY         : in  std_logic;
      ddr3_BURSTCNT           : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_ADDR               : out std_logic_vector(28 downto 0) := (others => '0');                       
      ddr3_DIN                : out std_logic_vector(63 downto 0) := (others => '0');
      ddr3_BE                 : out std_logic_vector(7 downto 0) := (others => '0'); 
      ddr3_WE                 : out std_logic := '0';
      ddr3_RD                 : out std_logic := '0';    
   
      -- ROM+SRAM+FLASH 
      cartAvailable           : in  std_logic;
      romcopy_start           : in  std_logic;
      romcopy_size            : in  unsigned(26 downto 0);
      
      sdram_ena               : out std_logic;
      sdram_rnw               : out std_logic;
      sdram_Adr               : out std_logic_vector(26 downto 0);
      sdram_be                : out std_logic_vector(3 downto 0);
      sdram_dataWrite         : out std_logic_vector(31 downto 0);
      sdram_reqprocessed      : in  std_logic;  
      sdram_done              : in  std_logic;  
      sdram_dataRead          : in  std_logic_vector(31 downto 0);
      
      -- PAD
      PADTYPE0                : in  std_logic_vector(2 downto 0); -- 000 = normal, 001 = empty, 010 = cpak, 011 = rumble, 100 = snac, 101 = transfer pak
      PADTYPE1                : in  std_logic_vector(2 downto 0);
      PADTYPE2                : in  std_logic_vector(2 downto 0);
      PADTYPE3                : in  std_logic_vector(2 downto 0);
      MOUSETYPE               : in  std_logic_vector(2 downto 0);
      PADDPADSWAP             : in  std_logic;
      rumble                  : out std_logic_vector(3 downto 0);
      pad_A                   : in  std_logic_vector(3 downto 0);
      pad_B                   : in  std_logic_vector(3 downto 0);
      pad_Z                   : in  std_logic_vector(3 downto 0);
      pad_START               : in  std_logic_vector(3 downto 0);
      pad_DPAD_UP             : in  std_logic_vector(3 downto 0);
      pad_DPAD_DOWN           : in  std_logic_vector(3 downto 0);
      pad_DPAD_LEFT           : in  std_logic_vector(3 downto 0);
      pad_DPAD_RIGHT          : in  std_logic_vector(3 downto 0);
      pad_L                   : in  std_logic_vector(3 downto 0);
      pad_R                   : in  std_logic_vector(3 downto 0);
      pad_C_UP                : in  std_logic_vector(3 downto 0);
      pad_C_DOWN              : in  std_logic_vector(3 downto 0);
      pad_C_LEFT              : in  std_logic_vector(3 downto 0);
      pad_C_RIGHT             : in  std_logic_vector(3 downto 0);
      pad_0_analog_h          : in  std_logic_vector(7 downto 0);
      pad_0_analog_v          : in  std_logic_vector(7 downto 0);      
      pad_1_analog_h          : in  std_logic_vector(7 downto 0);
      pad_1_analog_v          : in  std_logic_vector(7 downto 0);      
      pad_2_analog_h          : in  std_logic_vector(7 downto 0);
      pad_2_analog_v          : in  std_logic_vector(7 downto 0);      
      pad_3_analog_h          : in  std_logic_vector(7 downto 0);
      pad_3_analog_v          : in  std_logic_vector(7 downto 0);
      
      MouseEvent              : in  std_logic;
      MouseLeft               : in  std_logic;
      MouseRight              : in  std_logic;
      MouseMiddle             : in  std_logic;
      MouseX                  : in  signed(8 downto 0);
      MouseY                  : in  signed(8 downto 0);

      --snac
      PIFCOMPARE              : in  std_logic;
      snac                    : out std_logic;
      command_startSNAC       : out std_logic := '0';
      command_padindexSNAC    : out unsigned(1 downto 0) := (others => '0');
      command_sendCntSNAC     : out unsigned(5 downto 0) := (others => '0');
      command_receiveCntSNAC  : out unsigned(5 downto 0) := (others => '0');
      toPad_enaSNAC           : out std_logic := '0';
      toPad_dataSNAC          : out std_logic_vector(7 downto 0) := (others => '0');
      toPad_readySNAC         : in  std_logic;
      toPIF_timeoutSNAC       : in  std_logic;
      toPIF_enaSNAC           : in  std_logic;
      toPIF_dataSNAC          : in  std_logic_vector(7 downto 0);
     
      -- audio
      DISABLE_AI              : in  std_logic;
      DISABLE_AI_IRQ          : in  std_logic;
      sound_out_left          : out std_logic_vector(15 downto 0);
      sound_out_right         : out std_logic_vector(15 downto 0);
      
      -- save
      SAVETYPE                : in  std_logic_vector(2 downto 0); -- 0 -> None, 1 -> EEPROM4, 2 -> EEPROM16, 3 -> SRAM32, 4 -> SRAM96, 5 -> Flash
      CONTROLLERPAK           : in  std_logic;
      TRANSFERPAK             : in  std_logic;
      
      save                    : in  std_logic;
      load                    : in  std_logic;
      mounted                 : in  std_logic; 
      changePending           : out std_logic;
      save_ongoing            : out std_logic;
      save_rd                 : out std_logic;
      save_wr                 : out std_logic;
      save_lba                : out std_logic_vector(8 downto 0);
      save_ack                : in  std_logic;
      save_write              : in  std_logic;
      save_addr               : in  std_logic_vector(7 downto 0);
      save_dataIn             : in  std_logic_vector(15 downto 0);
      save_dataOut            : out std_logic_vector(15 downto 0);
   
      -- video out   
      video_hsync             : out std_logic := '0';
      video_vsync             : out std_logic := '0';
      video_hblank            : out std_logic := '0';
      video_vblank            : out std_logic := '0';
      video_ce                : out std_logic;
      video_interlace         : out std_logic;
      video_r                 : out std_logic_vector(7 downto 0);
      video_g                 : out std_logic_vector(7 downto 0);
      video_b                 : out std_logic_vector(7 downto 0);
      
      video_FB_base           : out unsigned(31 downto 0);
      video_FB_sizeX          : out unsigned(9 downto 0);
      video_FB_sizeY          : out unsigned(9 downto 0)
   );
end entity;

architecture arch of n64top is
   
   -- reset and clocks
   signal reset_intern_1x        : std_logic := '0';
   signal reset_intern_93        : std_logic := '0';
   
   signal ce_1x                  : std_logic := '0';
   signal ce_93                  : std_logic := '0';
   
   signal clk1xToggle            : std_logic := '0';
   signal clk1xToggle2X          : std_logic := '0';
   signal clk2xIndex             : std_logic := '0';
   
   signal second_ena             : std_logic;
   
   -- error codes
   signal errorEna               : std_logic;
   signal errorCode              : unsigned(31 downto 0) := (others => '0');
   
   signal errorMEMMUX            : std_logic;
   signal errorCPU_instr         : std_logic;
   signal errorCPU_stall         : std_logic;
   signal errorDDR3              : std_logic;
   signal errorCPU_FPU           : std_logic;
   signal error_PI               : std_logic;
   signal errorCPU_exception     : std_logic;
   signal error_pif              : std_logic;
   signal errorRSP_instr         : std_logic;
   signal errorRSP_stall         : std_logic;
   signal errorRDP_command       : std_logic;
   signal errorRDP_combine       : std_logic;
   signal errorRDP_combineAlpha  : std_logic;
   signal error_sdramMux         : std_logic;
   signal errorRDP_texMode       : std_logic;
   signal errorRDP_drawMode      : std_logic;
   signal errorRSP_FIFO          : std_logic;
   signal errorDDR3_FIFO         : std_logic;
   signal errorRSP_ADDR          : std_logic;
   signal errorDDR3_outReq       : std_logic;
   signal errorDDR3_outRSP       : std_logic;
   signal errorDDR3_outRDP       : std_logic;
   signal errorDDR3_outRDPZ      : std_logic;
   signal errorRSP_PCON          : std_logic;
   signal error_vi               : std_logic;
   signal error_RDPMEMMUX        : std_logic;
   signal errorCPU_fifo          : std_logic;
   signal errorCPU_TLB           : std_logic;
   signal errorDDR3_outPI        : std_logic;
  
   -- irq
   signal irqRequest             : std_logic;
   signal irqVector              : std_logic_vector(5 downto 0);        
   
   -- DDR3/RDRAM mux
   signal rdram_request          : tDDDR3Single;
   signal rdram_rnw              : tDDDR3Single;    
   signal rdram_address          : tDDDR3ReqAddr;
   signal rdram_burstcount       : tDDDR3Burstcount;  
   signal rdram_writeMask        : tDDDR3BwriteMask;  
   signal rdram_dataWrite        : tDDDR3BwriteData;
   signal rdram_granted          : tDDDR3Single;
   signal rdram_granted2x        : tDDDR3Single;
   signal rdram_done             : tDDDR3Single;
   signal rdram_dataRead         : std_logic_vector(63 downto 0);
   
   signal rspfifo_req            : std_logic; 
   signal rspfifo_reset          : std_logic; 
   signal rspfifo_Din            : std_logic_vector(84 downto 0);
   signal rspfifo_Wr             : std_logic;  
   signal rspfifo_nearfull       : std_logic;    
   signal rspfifo_empty          : std_logic;    

   signal rdpfifo_Din            : std_logic_vector(91 downto 0);
   signal rdpfifo_Wr             : std_logic;  
   signal rdpfifo_nearfull       : std_logic;    
   signal rdpfifo_empty          : std_logic;    
   
   signal rdpfifoZ_Din           : std_logic_vector(91 downto 0);
   signal rdpfifoZ_Wr            : std_logic;  
   signal rdpfifoZ_nearfull      : std_logic;    
   signal rdpfifoZ_empty         : std_logic;    
   
   signal PIfifo_Din             : std_logic_vector(92 downto 0);
   signal PIfifo_Wr              : std_logic;  
   signal PIfifo_nearfull        : std_logic;  
   signal PIfifo_empty           : std_logic;  
   
   signal VIFBfifo_Din           : std_logic_vector(87 downto 0);
   signal VIFBfifo_Wr            : std_logic;         

   -- SDRAM Mux
   signal sdrammux_idle          : std_logic;
   signal sdramMux_request       : tSDRAMSingle;
   signal sdramMux_rnw           : tSDRAMSingle;    
   signal sdramMux_address       : tSDRAMReqAddr;
   signal sdramMux_burstcount    : tSDRAMBurstcount;  
   signal sdramMux_writeMask     : tSDRAMBwriteMask;  
   signal sdramMux_dataWrite     : tSDRAMBwriteData;
   signal sdramMux_granted       : tSDRAMSingle;
   signal sdramMux_done          : tSDRAMSingle;
   signal sdramMux_dataRead      : std_logic_vector(31 downto 0);
   
   signal rdp9fifo_Din           : std_logic_vector(53 downto 0);
   signal rdp9fifo_Wr            : std_logic;  
   signal rdp9fifo_nearfull      : std_logic;  
   signal rdp9fifo_empty         : std_logic;
    
   signal rdp9fifoZ_Din          : std_logic_vector(49 downto 0);
   signal rdp9fifoZ_Wr           : std_logic;  
   signal rdp9fifoZ_nearfull     : std_logic;  
   signal rdp9fifoZ_empty        : std_logic;
   
   -- Memory mux
   signal mem_request            : std_logic;
   signal mem_rnw                : std_logic; 
   signal mem_address            : unsigned(31 downto 0); 
   signal mem_req64              : std_logic; 
   signal mem_size               : unsigned(2 downto 0); 
   signal mem_writeMask          : std_logic_vector(7 downto 0);
   signal mem_dataWrite          : std_logic_vector(63 downto 0); 
   signal mem_dataRead           : std_logic_vector(63 downto 0); 
   signal mem_done               : std_logic;
   
   signal bus_RDR_addr           : unsigned(19 downto 0); 
   signal bus_RDR_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_RDR_read           : std_logic;
   signal bus_RDR_write          : std_logic;
   signal bus_RDR_dataRead       : std_logic_vector(31 downto 0);    
   signal bus_RDR_done           : std_logic;       
   
   signal bus_RSP_addr           : unsigned(19 downto 0); 
   signal bus_RSP_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_RSP_read           : std_logic;
   signal bus_RSP_write          : std_logic;
   signal bus_RSP_dataRead       : std_logic_vector(31 downto 0);    
   signal bus_RSP_done           : std_logic;     
   
   signal bus_RDP_addr           : unsigned(19 downto 0); 
   signal bus_RDP_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_RDP_read           : std_logic;
   signal bus_RDP_write          : std_logic;
   signal bus_RDP_dataRead       : std_logic_vector(31 downto 0);    
   signal bus_RDP_done           : std_logic;      
   
   signal bus_MI_addr            : unsigned(19 downto 0); 
   signal bus_MI_dataWrite       : std_logic_vector(31 downto 0);
   signal bus_MI_read            : std_logic;
   signal bus_MI_write           : std_logic;
   signal bus_MI_dataRead        : std_logic_vector(31 downto 0);    
   signal bus_MI_done            : std_logic;   
   
   signal bus_VI_addr            : unsigned(19 downto 0); 
   signal bus_VI_dataWrite       : std_logic_vector(31 downto 0);
   signal bus_VI_read            : std_logic;
   signal bus_VI_write           : std_logic;
   signal bus_VI_dataRead        : std_logic_vector(31 downto 0);    
   signal bus_VI_done            : std_logic;      
   
   signal bus_AI_addr            : unsigned(19 downto 0); 
   signal bus_AI_dataWrite       : std_logic_vector(31 downto 0);
   signal bus_AI_read            : std_logic;
   signal bus_AI_write           : std_logic;
   signal bus_AI_dataRead        : std_logic_vector(31 downto 0);    
   signal bus_AI_done            : std_logic;   
   
   signal bus_PIreg_addr         : unsigned(19 downto 0); 
   signal bus_PIreg_dataWrite    : std_logic_vector(31 downto 0);
   signal bus_PIreg_read         : std_logic;
   signal bus_PIreg_write        : std_logic;
   signal bus_PIreg_dataRead     : std_logic_vector(31 downto 0);    
   signal bus_PIreg_done         : std_logic;
   
   signal bus_RI_addr            : unsigned(19 downto 0); 
   signal bus_RI_dataWrite       : std_logic_vector(31 downto 0);
   signal bus_RI_read            : std_logic;
   signal bus_RI_write           : std_logic;
   signal bus_RI_dataRead        : std_logic_vector(31 downto 0);    
   signal bus_RI_done            : std_logic;      
   
   signal bus_SI_addr            : unsigned(19 downto 0); 
   signal bus_SI_dataWrite       : std_logic_vector(31 downto 0);
   signal bus_SI_read            : std_logic;
   signal bus_SI_write           : std_logic;
   signal bus_SI_dataRead        : std_logic_vector(31 downto 0);    
   signal bus_SI_done            : std_logic;   
   
   signal bus_PIcart_addr        : unsigned(31 downto 0); 
   signal bus_PIcart_dataWrite   : std_logic_vector(31 downto 0);
   signal bus_PIcart_read        : std_logic;
   signal bus_PIcart_write       : std_logic;
   signal bus_PIcart_dataRead    : std_logic_vector(31 downto 0);    
   signal bus_PIcart_done        : std_logic;
   
   signal bus_PIF_addr           : unsigned(10 downto 0); 
   signal bus_PIF_dataWrite      : std_logic_vector(31 downto 0);
   signal bus_PIF_read           : std_logic;
   signal bus_PIF_write          : std_logic;
   signal bus_PIF_dataRead       : std_logic_vector(31 downto 0);  
   signal bus_PIF_done           : std_logic;
   
   -- exchange of PIF and controller module
   signal pif_idle               : std_logic;
   signal PADTYPE_latched        : std_logic_vector(2 downto 0);
   signal PADTYPE_latched0       : std_logic_vector(2 downto 0);
   signal PADTYPE_latched1       : std_logic_vector(2 downto 0);
   signal PADTYPE_latched2       : std_logic_vector(2 downto 0);
   signal PADTYPE_latched3       : std_logic_vector(2 downto 0);
   
   signal command_start          : std_logic;
   signal command_padindex       : unsigned(1 downto 0);
   signal command_sendCnt        : unsigned(5 downto 0);
   signal command_receiveCnt     : unsigned(5 downto 0);
   signal toPad_ena              : std_logic;   
   signal toPad_data             : std_logic_vector(7 downto 0);          
   signal toPad_ready            : std_logic;  
   signal toPIF_timeout          : std_logic;   
   signal toPIF_ena              : std_logic;   
   signal toPIF_data             : std_logic_vector(7 downto 0);

   signal command_startUSB        : std_logic;
   signal command_padindexUSB     : unsigned(1 downto 0);
   signal command_sendCntUSB      : unsigned(5 downto 0);
   signal command_receiveCntUSB   : unsigned(5 downto 0);
   signal toPad_enaUSB            : std_logic;   
   signal toPad_dataUSB           : std_logic_vector(7 downto 0);     
   signal toPad_readyUSB          : std_logic;
   signal toPIF_timeoutUSB        : std_logic;          
   signal toPIF_enaUSB            : std_logic;   
   signal toPIF_dataUSB           : std_logic_vector(7 downto 0);  
   
   -- SI/PIF
   signal SIPIF_ramreq           : std_logic;
   signal SIPIF_addr             : unsigned(5 downto 0);
   signal SIPIF_writeEna         : std_logic; 
   signal SIPIF_writeData        : std_logic_vector(7 downto 0);
   signal SIPIF_ramgrant         : std_logic;
   signal SIPIF_readData         : std_logic_vector(7 downto 0);
                                 
   signal SIPIF_writeProc        : std_logic;
   signal SIPIF_readProc         : std_logic;
   signal SIPIF_ProcDone         : std_logic;
   
   -- RSP/RDP
   signal RSP_RDP_reg_addr       : unsigned(4 downto 0);
   signal RSP_RDP_reg_dataOut    : unsigned(31 downto 0);
   signal RSP_RDP_reg_read       : std_logic;
   signal RSP_RDP_reg_write      : std_logic;
   signal RSP_RDP_reg_dataIn     : unsigned(31 downto 0);
   
   signal RSP2RDP_rdaddr         : unsigned(11 downto 0); 
   signal RSP2RDP_len            : unsigned(4 downto 0); 
   signal RSP2RDP_req            : std_logic;
   signal RSP2RDP_data           : std_logic_vector(63 downto 0);
   signal RSP2RDP_we             : std_logic;
   signal RSP2RDP_done           : std_logic;
   
   -- cpu
   signal ce_intern              : std_logic := '0';
   
   -- savestates
   signal ss_reset_1x            : std_logic;
   signal ss_reset_93            : std_logic;
   signal SS_DataWrite           : std_logic_vector(63 downto 0);
   signal SS_DataWrite_93        : std_logic_vector(63 downto 0);
   signal SS_Adr                 : unsigned(11 downto 0);
   signal SS_Adr_93              : unsigned(11 downto 0);
   signal SS_wren                : std_logic_vector(13 downto 0);
   signal SS_wren_93             : std_logic_vector(13 downto 0);
   signal SS_rden                : std_logic_vector(13 downto 0);
   --signal SS_DataRead_AI         : std_logic_vector(63 downto 0);
   --signal SS_DataRead_RDP        : std_logic_vector(63 downto 0);
   --signal SS_DataRead_RSP        : std_logic_vector(63 downto 0);
   --signal SS_DataRead_MI         : std_logic_vector(63 downto 0);
   --signal SS_DataRead_PI         : std_logic_vector(63 downto 0);
   --signal SS_DataRead_PIF        : std_logic_vector(63 downto 0);
   --signal SS_DataRead_VI         : std_logic_vector(63 downto 0);
   --signal SS_DataRead_CPU        : std_logic_vector(63 downto 0);
   
   signal SS_Idle                : std_logic;  
   --signal SS_idle_cpu            : std_logic;
   
   signal savestate_pause        : std_logic;
   signal loading_savestate      : std_logic;
   
   signal savestate_savestate    : std_logic; 
   signal savestate_loadstate    : std_logic; 
   signal savestate_address      : integer; 
   signal savestate_busy         : std_logic; 
   
   signal romcopy_nearFull       : std_logic;
   signal romcopy_active         : std_logic := '0';
   
   -- save rams
   signal eeprom_addr            : std_logic_vector(8 downto 0);
   signal eeprom_wren            : std_logic;
   signal eeprom_in              : std_logic_vector(31 downto 0);
   signal eeprom_out             : std_logic_vector(31 downto 0);
   signal eeprom_change          : std_logic;
   
   signal change_sram            : std_logic;
   signal change_flash           : std_logic;
   signal cpak_change            : std_logic;
   signal tpak_change            : std_logic;
   signal any_change             : std_logic;
   
   -- synthesis translate_off
   -- export
   signal cpu_done               : std_logic; 
   signal new_export             : std_logic; 
   signal cpu_export             : cpu_export_type;
-- synthesis translate_on
   
begin 

   -- clock index
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         clk1xToggle <= not clk1xToggle;
      end if;
   end process;
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         clk1xToggle2x <= clk1xToggle;
         clk2xIndex    <= not use2Xclock;
         if (clk1xToggle2x = clk1xToggle) then
            clk2xIndex <= '1';
         end if;
      end if;
   end process;

   -- ce
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         ce_1x <= not savestate_pause;
      end if;
   end process;
   
   process (clk93)
   begin
      if rising_edge(clk93) then
         ce_93 <= not savestate_pause;
      end if;
   end process;
   
   -- error codes
   process (reset_intern_1x, errorMEMMUX          ) begin if (errorMEMMUX           = '1') then errorCode( 0) <= '1'; elsif (reset_intern_1x = '1') then errorCode( 0) <= '0'; end if; end process;
   process (reset_intern_1x, errorCPU_instr       ) begin if (errorCPU_instr        = '1') then errorCode( 1) <= '1'; elsif (reset_intern_1x = '1') then errorCode( 1) <= '0'; end if; end process;
   process (reset_intern_1x, errorCPU_stall       ) begin if (errorCPU_stall        = '1') then errorCode( 2) <= '1'; elsif (reset_intern_1x = '1') then errorCode( 2) <= '0'; end if; end process;
   process (reset_intern_1x, errorDDR3            ) begin if (errorDDR3             = '1') then errorCode( 3) <= '1'; elsif (reset_intern_1x = '1') then errorCode( 3) <= '0'; end if; end process;
   process (reset_intern_1x, errorCPU_FPU         ) begin if (errorCPU_FPU          = '1') then errorCode( 4) <= '1'; elsif (reset_intern_1x = '1') then errorCode( 4) <= '0'; end if; end process;
   process (reset_intern_1x, error_PI             ) begin if (error_PI              = '1') then errorCode( 5) <= '1'; elsif (reset_intern_1x = '1') then errorCode( 5) <= '0'; end if; end process;
   process (reset_intern_1x, errorCPU_exception   ) begin if (errorCPU_exception    = '1') then errorCode( 6) <= '1'; elsif (reset_intern_1x = '1') then errorCode( 6) <= '0'; end if; end process;
   process (reset_intern_1x, error_pif            ) begin if (error_pif             = '1') then errorCode( 7) <= '1'; elsif (reset_intern_1x = '1') then errorCode( 7) <= '0'; end if; end process;
   process (reset_intern_1x, errorRSP_instr       ) begin if (errorRSP_instr        = '1') then errorCode( 8) <= '1'; elsif (reset_intern_1x = '1') then errorCode( 8) <= '0'; end if; end process;
   process (reset_intern_1x, errorRSP_stall       ) begin if (errorRSP_stall        = '1') then errorCode( 9) <= '1'; elsif (reset_intern_1x = '1') then errorCode( 9) <= '0'; end if; end process;
   process (reset_intern_1x, errorRDP_command     ) begin if (errorRDP_command      = '1') then errorCode(10) <= '1'; elsif (reset_intern_1x = '1') then errorCode(10) <= '0'; end if; end process;
   process (reset_intern_1x, errorRDP_combine     ) begin if (errorRDP_combine      = '1') then errorCode(11) <= '1'; elsif (reset_intern_1x = '1') then errorCode(11) <= '0'; end if; end process;
   process (reset_intern_1x, errorRDP_combineAlpha) begin if (errorRDP_combineAlpha = '1') then errorCode(12) <= '1'; elsif (reset_intern_1x = '1') then errorCode(12) <= '0'; end if; end process;
   process (reset_intern_1x, error_sdramMux       ) begin if (error_sdramMux        = '1') then errorCode(13) <= '1'; elsif (reset_intern_1x = '1') then errorCode(13) <= '0'; end if; end process;
   process (reset_intern_1x, errorRDP_texMode     ) begin if (errorRDP_texMode      = '1') then errorCode(14) <= '1'; elsif (reset_intern_1x = '1') then errorCode(14) <= '0'; end if; end process;
   process (reset_intern_1x, errorRDP_drawMode    ) begin if (errorRDP_drawMode     = '1') then errorCode(15) <= '1'; elsif (reset_intern_1x = '1') then errorCode(15) <= '0'; end if; end process;
   process (reset_intern_1x, errorRSP_FIFO        ) begin if (errorRSP_FIFO         = '1') then errorCode(16) <= '1'; elsif (reset_intern_1x = '1') then errorCode(16) <= '0'; end if; end process;
   process (reset_intern_1x, errorDDR3_FIFO       ) begin if (errorDDR3_FIFO        = '1') then errorCode(17) <= '1'; elsif (reset_intern_1x = '1') then errorCode(17) <= '0'; end if; end process;
   process (reset_intern_1x, errorRSP_ADDR        ) begin if (errorRSP_ADDR         = '1') then errorCode(18) <= '1'; elsif (reset_intern_1x = '1') then errorCode(18) <= '0'; end if; end process;
   process (reset_intern_1x, errorDDR3_outReq     ) begin if (errorDDR3_outReq      = '1') then errorCode(19) <= '1'; elsif (reset_intern_1x = '1') then errorCode(19) <= '0'; end if; end process;
   process (reset_intern_1x, errorDDR3_outRSP     ) begin if (errorDDR3_outRSP      = '1') then errorCode(20) <= '1'; elsif (reset_intern_1x = '1') then errorCode(20) <= '0'; end if; end process;
   process (reset_intern_1x, errorDDR3_outRDP     ) begin if (errorDDR3_outRDP      = '1') then errorCode(21) <= '1'; elsif (reset_intern_1x = '1') then errorCode(21) <= '0'; end if; end process;
   process (reset_intern_1x, errorDDR3_outRDPZ    ) begin if (errorDDR3_outRDPZ     = '1') then errorCode(22) <= '1'; elsif (reset_intern_1x = '1') then errorCode(22) <= '0'; end if; end process;
   process (reset_intern_1x, errorRSP_PCON        ) begin if (errorRSP_PCON         = '1') then errorCode(23) <= '1'; elsif (reset_intern_1x = '1') then errorCode(23) <= '0'; end if; end process;
   process (reset_intern_1x, error_vi             ) begin if (error_vi              = '1') then errorCode(24) <= '1'; elsif (reset_intern_1x = '1') then errorCode(24) <= '0'; end if; end process;
   process (reset_intern_1x, error_RDPMEMMUX      ) begin if (error_RDPMEMMUX       = '1') then errorCode(25) <= '1'; elsif (reset_intern_1x = '1') then errorCode(25) <= '0'; end if; end process;
   process (reset_intern_1x, errorCPU_fifo        ) begin if (errorCPU_fifo         = '1') then errorCode(26) <= '1'; elsif (reset_intern_1x = '1') then errorCode(26) <= '0'; end if; end process;
   process (reset_intern_1x, errorCPU_TLB         ) begin if (errorCPU_TLB          = '1') then errorCode(27) <= '1'; elsif (reset_intern_1x = '1') then errorCode(27) <= '0'; end if; end process;
   process (reset_intern_1x, errorDDR3_outPI      ) begin if (errorDDR3_outPI       = '1') then errorCode(28) <= '1'; elsif (reset_intern_1x = '1') then errorCode(28) <= '0'; end if; end process;
   
   errorCode(31 downto 29) <= "000";
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         errorEna <= '0';
         if (errorCode /= 0) then
            errorEna <= errorCodesOn; 
         end if;
      end if;
   end process;
   
   -- submodules
   
   iRSP : entity work.RSP
   generic map
   (
      use2Xclock       => use2Xclock
   )
   port map
   (
      clk1x                => clk1x,        
      clk2x                => clk2x,        
      clk2xIndex           => clk2xIndex,        
      ce                   => ce_1x,           
      reset                => reset_intern_1x, 

      irq_out              => irqVector(0),
      
      error_instr          => errorRSP_instr,
      error_stall          => errorRSP_stall,
      error_fifo           => errorRSP_FIFO,
      error_addr           => errorRSP_ADDR,
      error_PCON           => errorRSP_PCON,
                           
      bus_addr             => bus_RSP_addr,     
      bus_dataWrite        => bus_RSP_dataWrite,
      bus_read             => bus_RSP_read,     
      bus_write            => bus_RSP_write,    
      bus_dataRead         => bus_RSP_dataRead, 
      bus_done             => bus_RSP_done,
      
      rdram_request        => rdram_request(DDR3MUX_RSP),   
      rdram_rnw            => rdram_rnw(DDR3MUX_RSP),       
      rdram_address        => rdram_address(DDR3MUX_RSP),   
      rdram_burstcount     => rdram_burstcount(DDR3MUX_RSP),
      rdram_writeMask      => rdram_writeMask(DDR3MUX_RSP),   
      rdram_granted        => rdram_granted(DDR3MUX_RSP),      
      rdram_done           => rdram_done(DDR3MUX_RSP),   
      ddr3_DOUT            => ddr3_DOUT,       
      ddr3_DOUT_READY      => ddr3_DOUT_READY,
      
      RSP_RDP_reg_addr     => RSP_RDP_reg_addr,   
      RSP_RDP_reg_dataOut  => RSP_RDP_reg_dataOut,
      RSP_RDP_reg_read     => RSP_RDP_reg_read,   
      RSP_RDP_reg_write    => RSP_RDP_reg_write,  
      RSP_RDP_reg_dataIn   => RSP_RDP_reg_dataIn, 
      
      RSP2RDP_rdaddr       => RSP2RDP_rdaddr, 
      RSP2RDP_len          => RSP2RDP_len,    
      RSP2RDP_req          => RSP2RDP_req,    
      RSP2RDP_data         => RSP2RDP_data,
      RSP2RDP_we           => RSP2RDP_we,  
      RSP2RDP_done         => RSP2RDP_done, 
      
      fifoout_req          => rspfifo_req,   
      fifoout_reset        => rspfifo_reset,   
      fifoout_Din          => rspfifo_Din,     
      fifoout_Wr           => rspfifo_Wr,      
      fifoout_nearfull     => rspfifo_nearfull,
      fifoout_empty        => rspfifo_empty,
      
      SS_reset             => ss_reset_1x,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(8 downto 0),
      SS_wren_RSP          => SS_wren(7),
      SS_rden_RSP          => SS_rden(7),
      SS_wren_IMEM         => SS_wren(12),
      SS_rden_IMEM         => SS_rden(12),
      SS_wren_DMEM         => SS_wren(11),
      SS_rden_DMEM         => SS_rden(11),
      SS_DataRead          => open, --SS_DataRead_RSP,
      SS_idle              => open
   );
   
   rdram_dataWrite(DDR3MUX_RSP) <= (others => '0');
   
   iRDP : entity work.RDP
   port map
   (
      clk1x                => clk1x,        
      clk2x                => clk2x,        
      ce                   => ce_1x,           
      reset                => reset_intern_1x, 
      
      command_error        => errorRDP_command,
      errorCombine         => errorRDP_combine,
      error_combineAlpha   => errorRDP_combineAlpha,
      error_texMode        => errorRDP_texMode,
      error_drawMode       => errorRDP_drawMode,
      error_RDPMEMMUX      => error_RDPMEMMUX,
      
      CICTYPE              => CICTYPE,
      
      DISABLEFILTER        => DISABLEFILTER,
      DISABLEDITHER        => DISABLEDITHER,
      DISABLELOD           => DISABLELOD,
      write9               => write9,
      read9                => read9,
      wait9                => wait9,
      writeZ               => writeZ,
      readZ                => readZ, 

      irq_out              => irqVector(5),
                           
      bus_addr             => bus_RDP_addr,     
      bus_dataWrite        => bus_RDP_dataWrite,
      bus_read             => bus_RDP_read,     
      bus_write            => bus_RDP_write,    
      bus_dataRead         => bus_RDP_dataRead, 
      bus_done             => bus_RDP_done,
      
      rdram_request        => rdram_request(DDR3MUX_RDP),   
      rdram_rnw            => rdram_rnw(DDR3MUX_RDP),       
      rdram_address        => rdram_address(DDR3MUX_RDP),   
      rdram_burstcount     => rdram_burstcount(DDR3MUX_RDP),
      rdram_writeMask      => rdram_writeMask(DDR3MUX_RDP), 
      rdram_dataWrite      => rdram_dataWrite(DDR3MUX_RDP),     
      rdram_granted        => rdram_granted(DDR3MUX_RDP),      
      rdram_done           => rdram_done(DDR3MUX_RDP),   
      ddr3_DOUT            => ddr3_DOUT,       
      ddr3_DOUT_READY      => ddr3_DOUT_READY, 
      
      fifoout_Din          => rdpfifo_Din,     
      fifoout_Wr           => rdpfifo_Wr,      
      fifoout_nearfull     => rdpfifo_nearfull,
      fifoout_empty        => rdpfifo_empty,      
      
      fifooutZ_Din         => rdpfifoZ_Din,     
      fifooutZ_Wr          => rdpfifoZ_Wr,      
      fifooutZ_nearfull    => rdpfifoZ_nearfull,
      fifooutZ_empty       => rdpfifoZ_empty,
      
      sdram_request        => sdramMux_request(SDRAMMUX_RDP),   
      sdram_rnw            => sdramMux_rnw(SDRAMMUX_RDP),       
      sdram_address        => sdramMux_address(SDRAMMUX_RDP),   
      sdram_burstcount     => sdramMux_burstcount(SDRAMMUX_RDP),
      sdram_writeMask      => sdramMux_writeMask(SDRAMMUX_RDP), 
      sdram_dataWrite      => sdramMux_dataWrite(SDRAMMUX_RDP), 
      sdram_granted        => sdramMux_granted(SDRAMMUX_RDP),      
      sdram_done           => sdramMux_done(SDRAMMUX_RDP),      
      sdram_dataRead       => sdram_dataRead,
      sdram_valid          => (sdram_done and sdram_rnw),    
                              
      rdp9fifo_Din         => rdp9fifo_Din,     
      rdp9fifo_Wr          => rdp9fifo_Wr,      
      rdp9fifo_nearfull    => rdp9fifo_nearfull,
      rdp9fifo_empty       => rdp9fifo_empty,      
      
      rdp9fifoZ_Din        => rdp9fifoZ_Din,     
      rdp9fifoZ_Wr         => rdp9fifoZ_Wr,      
      rdp9fifoZ_nearfull   => rdp9fifoZ_nearfull,
      rdp9fifoZ_empty      => rdp9fifoZ_empty,
      
      RSP_RDP_reg_addr     => RSP_RDP_reg_addr,   
      RSP_RDP_reg_dataOut  => RSP_RDP_reg_dataOut,
      RSP_RDP_reg_read     => RSP_RDP_reg_read,   
      RSP_RDP_reg_write    => RSP_RDP_reg_write,  
      RSP_RDP_reg_dataIn   => RSP_RDP_reg_dataIn, 
      
      RSP2RDP_rdaddr       => RSP2RDP_rdaddr, 
      RSP2RDP_len          => RSP2RDP_len,    
      RSP2RDP_req          => RSP2RDP_req,    
      RSP2RDP_data         => RSP2RDP_data,
      RSP2RDP_we           => RSP2RDP_we,  
      RSP2RDP_done         => RSP2RDP_done, 
      
      SS_reset             => ss_reset_1x,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(0 downto 0),
      SS_wren              => SS_wren(4),
      SS_rden              => SS_rden(4),
      SS_DataRead          => open --SS_DataRead_RDP
   );
   
   iRDRAMRegs : entity work.RDRAMRegs
   port map
   (
      clk1x                => clk1x,        
      ce                   => ce_1x,           
      reset                => reset_intern_1x, 
                           
      bus_addr             => bus_RDR_addr,     
      bus_dataWrite        => bus_RDR_dataWrite,
      bus_read             => bus_RDR_read,     
      bus_write            => bus_RDR_write,    
      bus_dataRead         => bus_RDR_dataRead, 
      bus_done             => bus_RDR_done
   );
   
   iMI : entity work.MI
   port map
   (
      clk1x                => clk1x,        
      ce                   => ce_1x,           
      reset                => reset_intern_1x, 

      irq_in               => irqVector,
      irq_out              => irqRequest,
                           
      bus_addr             => bus_MI_addr,     
      bus_dataWrite        => bus_MI_dataWrite,
      bus_read             => bus_MI_read,     
      bus_write            => bus_MI_write,    
      bus_dataRead         => bus_MI_dataRead, 
      bus_done             => bus_MI_done,
      
      SS_reset             => ss_reset_1x,
      SS_DataWrite         => SS_DataWrite,
      SS_wren              => SS_wren(1),
      SS_rden              => SS_rden(1),
      SS_DataRead          => open --SS_DataRead_MI
   );    
   
   iVI : entity work.VI
   generic map
   (
      use2Xclock       => use2Xclock
   )
   port map
   (
      clk1x                => clk1x,        
      clk2x                => clk2x,        
      clkvid               => clkvid,        
      ce                   => ce_1x,           
      reset_1x             => reset_intern_1x, 
      
      error_vi             => error_vi,
      
      irq_out              => irqVector(3),
      
      second_ena           => second_ena,
      
      ISPAL                => ISPAL,
      FIXEDBLANKS          => FIXEDBLANKS,
      CROPVERTICAL         => CROPVERTICAL,
      VI_BILINEAROFF       => VI_BILINEAROFF,
      VI_GAMMAOFF          => VI_GAMMAOFF,
      VI_NOISEOFF          => VI_NOISEOFF,
      VI_DEDITHEROFF       => VI_DEDITHEROFF,
      VI_DEDITHERFORCE     => VI_DEDITHERFORCE,
      VI_AAOFF             => VI_AAOFF,
      VI_DIVOTOFF          => VI_DIVOTOFF,
      VI_7BITPERCOLOR      => VI_7BITPERCOLOR,
      VI_DIRECTFBMODE      => VI_DIRECTFBMODE,
     
      errorEna             => errorEna, 
      errorCode            => errorCode,
      fpscountOn           => fpscountOn,
                           
      rdram_request        => rdram_request(DDR3MUX_VI),   
      rdram_rnw            => rdram_rnw(DDR3MUX_VI),       
      rdram_address        => rdram_address(DDR3MUX_VI),   
      rdram_burstcount     => rdram_burstcount(DDR3MUX_VI),
      rdram_granted        => rdram_granted(DDR3MUX_VI),      
      rdram_done           => rdram_done(DDR3MUX_VI),     
      ddr3_DOUT            => ddr3_DOUT,       
      ddr3_DOUT_READY      => ddr3_DOUT_READY,   

      VIFBfifo_Din         => VIFBfifo_Din,
      VIFBfifo_Wr          => VIFBfifo_Wr,       
      
      sdram_request        => sdramMux_request(SDRAMMUX_VI),   
      sdram_rnw            => sdramMux_rnw(SDRAMMUX_VI),       
      sdram_address        => sdramMux_address(SDRAMMUX_VI),   
      sdram_burstcount     => sdramMux_burstcount(SDRAMMUX_VI),
      sdram_granted        => sdramMux_granted(SDRAMMUX_VI),      
      sdram_done           => sdramMux_done(SDRAMMUX_VI),      
      sdram_dataRead       => sdram_dataRead,
      sdram_valid          => (sdram_done and sdram_rnw),   
      
      video_hsync          => video_hsync, 
      video_vsync          => video_vsync,  
      video_hblank         => video_hblank, 
      video_vblank         => video_vblank, 
      video_ce             => video_ce,     
      video_interlace      => video_interlace,     
      video_r              => video_r,      
      video_g              => video_g,      
      video_b              => video_b,
      
      video_FB_base        => video_FB_base,
      video_FB_sizeX       => video_FB_sizeX,
      video_FB_sizeY       => video_FB_sizeY,

      bus_addr             => bus_VI_addr,     
      bus_dataWrite        => bus_VI_dataWrite,
      bus_read             => bus_VI_read,     
      bus_write            => bus_VI_write,    
      bus_dataRead         => bus_VI_dataRead, 
      bus_done             => bus_VI_done,
      
      SS_reset             => ss_reset_1x,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(2 downto 0),
      SS_wren              => SS_wren(9),
      SS_rden              => SS_rden(9),
      SS_DataRead          => open --SS_DataRead_VI
   );   
   
   iAI : entity work.AI
   port map
   (
      clk1x                => clk1x,        
      clkvid               => clkvid,        
      ce                   => ce_1x,           
      reset                => reset_intern_1x, 
      
      DISABLE_AI           => DISABLE_AI,    
      DISABLE_AI_IRQ       => DISABLE_AI_IRQ,

      irq_out              => irqVector(2),
      
      sound_out_left       => sound_out_left, 
      sound_out_right      => sound_out_right,
                           
      bus_addr             => bus_AI_addr,     
      bus_dataWrite        => bus_AI_dataWrite,
      bus_read             => bus_AI_read,     
      bus_write            => bus_AI_write,    
      bus_dataRead         => bus_AI_dataRead, 
      bus_done             => bus_AI_done,
      
      rdram_request        => rdram_request(DDR3MUX_AI),   
      rdram_rnw            => rdram_rnw(DDR3MUX_AI),       
      rdram_address        => rdram_address(DDR3MUX_AI),   
      rdram_burstcount     => rdram_burstcount(DDR3MUX_AI),
      rdram_writeMask      => rdram_writeMask(DDR3MUX_AI), 
      rdram_dataWrite      => rdram_dataWrite(DDR3MUX_AI), 
      rdram_done           => rdram_done(DDR3MUX_AI),      
      rdram_dataRead       => rdram_dataRead,

      SS_reset             => ss_reset_1x,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(1 downto 0),   
      SS_wren              => SS_wren(0),     
      SS_rden              => SS_rden(0),            
      SS_DataRead          => open --SS_DataRead_AI      
   );   
   
   iRI : entity work.RI
   port map
   (
      clk1x                => clk1x,        
      ce                   => ce_1x,           
      reset                => reset_intern_1x, 
 
      bus_addr             => bus_RI_addr,     
      bus_dataWrite        => bus_RI_dataWrite,
      bus_read             => bus_RI_read,     
      bus_write            => bus_RI_write,    
      bus_dataRead         => bus_RI_dataRead, 
      bus_done             => bus_RI_done
   );
      
   iSI : entity work.SI
   port map
   (
      clk1x                => clk1x,        
      ce                   => ce_1x,           
      reset                => reset_intern_1x, 

      irq_out              => irqVector(1),
      
      SIPIF_ramreq         => SIPIF_ramreq,   
      SIPIF_addr           => SIPIF_addr,     
      SIPIF_writeEna       => SIPIF_writeEna, 
      SIPIF_writeData      => SIPIF_writeData,
      SIPIF_ramgrant       => SIPIF_ramgrant, 
      SIPIF_readData       => SIPIF_readData, 
                                          
      SIPIF_writeProc      => SIPIF_writeProc,
      SIPIF_readProc       => SIPIF_readProc, 
      SIPIF_ProcDone       => SIPIF_ProcDone, 
                           
      bus_addr             => bus_SI_addr,     
      bus_dataWrite        => bus_SI_dataWrite,
      bus_read             => bus_SI_read,     
      bus_write            => bus_SI_write,    
      bus_dataRead         => bus_SI_dataRead, 
      bus_done             => bus_SI_done,
      
      rdram_request        => rdram_request(DDR3MUX_SI),   
      rdram_rnw            => rdram_rnw(DDR3MUX_SI),       
      rdram_address        => rdram_address(DDR3MUX_SI),   
      rdram_burstcount     => rdram_burstcount(DDR3MUX_SI),
      rdram_writeMask      => rdram_writeMask(DDR3MUX_SI), 
      rdram_dataWrite      => rdram_dataWrite(DDR3MUX_SI), 
      rdram_done           => rdram_done(DDR3MUX_SI),      
      rdram_dataRead       => rdram_dataRead 
   );
   
   iPI : entity work.PI
   port map
   (
      clk1x                => clk1x,        
      ce                   => ce_1x,           
      reset                => reset_intern_1x, 
      
      FASTROM              => FASTROM,
      SAVETYPE             => SAVETYPE,
      fastDecay            => is_simu,
      cartAvailable        => cartAvailable,

      irq_out              => irqVector(4),
      
      error_PI             => error_PI,
      
      change_sram          => change_sram, 
      change_flash         => change_flash,
                           
      sdram_request        => sdramMux_request(SDRAMMUX_PI),   
      sdram_rnw            => sdramMux_rnw(SDRAMMUX_PI),       
      sdram_address        => sdramMux_address(SDRAMMUX_PI),   
      sdram_burstcount     => sdramMux_burstcount(SDRAMMUX_PI),
      sdram_writeMask      => sdramMux_writeMask(SDRAMMUX_PI), 
      sdram_dataWrite      => sdramMux_dataWrite(SDRAMMUX_PI), 
      sdram_done           => sdramMux_done(SDRAMMUX_PI),      
      sdram_dataRead       => sdramMux_dataRead,
                             
      rdram_request        => rdram_request(DDR3MUX_PI),   
      rdram_rnw            => rdram_rnw(DDR3MUX_PI),       
      rdram_address        => rdram_address(DDR3MUX_PI),   
      rdram_burstcount     => rdram_burstcount(DDR3MUX_PI),
      rdram_done           => rdram_done(DDR3MUX_PI),      
      rdram_dataRead       => rdram_dataRead,      
      
      PIfifo_Din           => PIfifo_Din,    
      PIfifo_Wr            => PIfifo_Wr,   
      PIfifo_nearfull      => PIfifo_nearfull,  
      PIfifo_empty         => PIfifo_empty,  
      
      bus_reg_addr         => bus_PIreg_addr,     
      bus_reg_dataWrite    => bus_PIreg_dataWrite,
      bus_reg_read         => bus_PIreg_read,     
      bus_reg_write        => bus_PIreg_write,    
      bus_reg_dataRead     => bus_PIreg_dataRead, 
      bus_reg_done         => bus_PIreg_done,      
         
      bus_cart_addr        => bus_PIcart_addr,     
      bus_cart_dataWrite   => bus_PIcart_dataWrite,
      bus_cart_read        => bus_PIcart_read,     
      bus_cart_write       => bus_PIcart_write,    
      bus_cart_dataRead    => bus_PIcart_dataRead, 
      bus_cart_done        => bus_PIcart_done,
      
      SS_reset             => ss_reset_1x,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(2 downto 0),
      SS_wren              => SS_wren(2),
      SS_rden              => SS_rden(2),
      SS_DataRead          => open --SS_DataRead_PI
   );
   
   process(clk1x)
   begin
      if rising_edge(clk1x) then
         if (pif_idle = '1' and pause = '0') then
            PADTYPE_latched0 <= PADTYPE0;
            PADTYPE_latched1 <= PADTYPE1;
            PADTYPE_latched2 <= PADTYPE2;
            PADTYPE_latched3 <= PADTYPE3;
         end if;
      end if;
   end process;
   
   PADTYPE_latched        <= PADTYPE_latched0 when (command_padindex = "00") else 
                             PADTYPE_latched1 when (command_padindex = "01") else 
                             PADTYPE_latched2 when (command_padindex = "10") else 
                             PADTYPE_latched3;
                             
   snac                   <= '1' when (PADTYPE_latched = "100") else '0';
   
   command_startSNAC      <= command_start and (snac or PIFCOMPARE);
   command_padindexSNAC   <= command_padindex;
   command_sendCntSNAC    <= command_sendCnt;
   command_receiveCntSNAC <= command_receiveCnt;
   
   toPad_enaSNAC          <= toPad_ena and (snac or PIFCOMPARE);
   toPad_dataSNAC         <= toPad_data;
           
   command_startUSB       <= command_start and (not snac or PIFCOMPARE);
   command_padindexUSB    <= command_padindex;
   command_sendCntUSB     <= command_sendCnt;
   command_receiveCntUSB  <= command_receiveCnt;
   
   toPad_enaUSB           <= toPad_ena and (not snac or PIFCOMPARE);
   toPad_dataUSB          <= toPad_data;        
   
   toPad_ready            <= (toPad_readySNAC and toPad_readyUSB) when (PIFCOMPARE = '1') else toPad_readySNAC when (snac = '1') else toPad_readyUSB;
   
   toPIF_timeout          <= toPIF_timeoutSNAC when (snac = '1') else toPIF_timeoutUSB;
   toPIF_ena              <= toPIF_enaSNAC     when (snac = '1') else toPIF_enaUSB;
   toPIF_data             <= toPIF_dataSNAC    when (snac = '1') else toPIF_dataUSB;
   
   iPIF : entity work.PIF
   port map
   (
      clk1x                => clk1x,        
      ce                   => ce_1x,           
      reset                => reset_intern_1x,   
      
      second_ena           => second_ena,

      PIFCOMPARE           => PIFCOMPARE,
      ISPAL                => ISPAL,
      CICTYPE              => CICTYPE,
      SAVETYPE             => SAVETYPE,
      
      error                => error_pif,
      isIdle               => pif_idle,
      
      command_start        => command_start,     
      command_padindex     => command_padindex,  
      command_sendCnt      => command_sendCnt,   
      command_receiveCnt   => command_receiveCnt,                
      toPad_ena            => toPad_ena,         
      toPad_data           => toPad_data,        
      toPad_ready          => toPad_ready,                              
      toPIF_timeout        => toPIF_timeout,         
      toPIF_ena            => toPIF_ena,         
      toPIF_data           => toPIF_data,  
      
      toPIF_timeout1       => toPIF_timeoutUSB,         
      toPIF_ena1           => toPIF_enaUSB,         
      toPIF_data1          => toPIF_dataUSB,       
      toPIF_timeout2       => toPIF_timeoutSNAC,         
      toPIF_ena2           => toPIF_enaSNAC,         
      toPIF_data2          => toPIF_dataSNAC,  
      
      pifrom_wraddress     => pifrom_wraddress,
      pifrom_wrdata        => pifrom_wrdata,   
      pifrom_wren          => pifrom_wren,   
      
      SIPIF_ramreq         => SIPIF_ramreq,   
      SIPIF_addr           => SIPIF_addr,     
      SIPIF_writeEna       => SIPIF_writeEna, 
      SIPIF_writeData      => SIPIF_writeData,
      SIPIF_ramgrant       => SIPIF_ramgrant, 
      SIPIF_readData       => SIPIF_readData, 
                                          
      SIPIF_writeProc      => SIPIF_writeProc,
      SIPIF_readProc       => SIPIF_readProc, 
      SIPIF_ProcDone       => SIPIF_ProcDone, 
                           
      bus_addr             => bus_PIF_addr,     
      bus_dataWrite        => bus_PIF_dataWrite,
      bus_read             => bus_PIF_read,     
      bus_write            => bus_PIF_write,    
      bus_dataRead         => bus_PIF_dataRead, 
      bus_done             => bus_PIF_done,
      
      eeprom_addr          => eeprom_addr,  
      eeprom_wren          => eeprom_wren,  
      eeprom_in            => eeprom_in,    
      eeprom_out           => eeprom_out,   
      eeprom_change        => eeprom_change,

      SS_reset             => ss_reset_1x,
      loading_savestate    => loading_savestate,
      SS_DataWrite         => SS_DataWrite,
      SS_Adr               => SS_Adr(6 downto 0),   
      SS_wren              => SS_wren(3),     
      SS_rden              => SS_rden(3),            
      SS_DataRead          => open --SS_DataRead_PIF
   );
   
   iGamepad : entity work.Gamepad
   port map
   (
      clk1x                => clk1x,                
      reset                => reset_intern_1x, 
      
      second_ena           => second_ena,
      
      PADTYPE              => PADTYPE_latched,
      MOUSETYPE            => MOUSETYPE,
      PADDPADSWAP          => PADDPADSWAP,
      
      command_start        => command_startUSB,     
      command_padindex     => command_padindexUSB,  
      command_sendCnt      => command_sendCntUSB,   
      command_receiveCnt   => command_receiveCntUSB,
                       
      toPad_ena            => toPad_enaUSB,         
      toPad_data           => toPad_dataUSB,        
      toPad_ready          => toPad_readyUSB,        
                                
      toPIF_timeout        => toPIF_timeoutUSB,         
      toPIF_ena            => toPIF_enaUSB,         
      toPIF_data           => toPIF_dataUSB, 
      
      rumble               => rumble,        

      pad_A                => pad_A,         
      pad_B                => pad_B,         
      pad_Z                => pad_Z,         
      pad_START            => pad_START,     
      pad_DPAD_UP          => pad_DPAD_UP,   
      pad_DPAD_DOWN        => pad_DPAD_DOWN, 
      pad_DPAD_LEFT        => pad_DPAD_LEFT,
      pad_DPAD_RIGHT       => pad_DPAD_RIGHT,
      pad_L                => pad_L,         
      pad_R                => pad_R,         
      pad_C_UP             => pad_C_UP,      
      pad_C_DOWN           => pad_C_DOWN,    
      pad_C_LEFT           => pad_C_LEFT,    
      pad_C_RIGHT          => pad_C_RIGHT,   
      pad_0_analog_h       => pad_0_analog_h,
      pad_0_analog_v       => pad_0_analog_v,
      pad_1_analog_h       => pad_1_analog_h,
      pad_1_analog_v       => pad_1_analog_v,
      pad_2_analog_h       => pad_2_analog_h,
      pad_2_analog_v       => pad_2_analog_v,
      pad_3_analog_h       => pad_3_analog_h,
      pad_3_analog_v       => pad_3_analog_v,
      
      MouseEvent           => MouseEvent,
      MouseLeft            => MouseLeft, 
      MouseRight           => MouseRight,
      MouseMiddle          => MouseMiddle,
      MouseX               => MouseX,    
      MouseY               => MouseY,         
      
      cpak_change          => cpak_change,
      tpak_change          => tpak_change,
      
      sdram_request        => sdramMux_request(SDRAMMUX_PIF),   
      sdram_rnw            => sdramMux_rnw(SDRAMMUX_PIF),       
      sdram_address        => sdramMux_address(SDRAMMUX_PIF),   
      sdram_burstcount     => sdramMux_burstcount(SDRAMMUX_PIF),
      sdram_writeMask      => sdramMux_writeMask(SDRAMMUX_PIF), 
      sdram_dataWrite      => sdramMux_dataWrite(SDRAMMUX_PIF), 
      sdram_done           => sdramMux_done(SDRAMMUX_PIF),      
      sdram_dataRead       => sdramMux_dataRead
   );

   rdram_writeMask(DDR3MUX_VI) <= (others => '-');
   rdram_dataWrite(DDR3MUX_VI) <= (others => '-');

   iDDR3Mux : entity work.DDR3Mux
   generic map
   (
      use2Xclock       => use2Xclock
   )
   port map
   (
      clk1x            => clk1x,           
      clk2x            => clk2x,  
      clk2xIndex       => clk2xIndex, 
      
      RAMSIZE8         => RAMSIZE8,
      slow_in          => DDR3SLOW,
      
      error            => errorDDR3,
      error_fifo       => errorDDR3_FIFO,
      error_outReq     => errorDDR3_outReq,
      error_outRSP     => errorDDR3_outRSP,
      error_outRDP     => errorDDR3_outRDP,
      error_outRDPZ    => errorDDR3_outRDPZ,
      error_outPI      => errorDDR3_outPI,
                                          
      ddr3_BUSY        => ddr3_BUSY,       
      ddr3_DOUT        => ddr3_DOUT,       
      ddr3_DOUT_READY  => ddr3_DOUT_READY, 
      ddr3_BURSTCNT    => ddr3_BURSTCNT,   
      ddr3_ADDR        => ddr3_ADDR,                           
      ddr3_DIN         => ddr3_DIN,        
      ddr3_BE          => ddr3_BE,         
      ddr3_WE          => ddr3_WE,         
      ddr3_RD          => ddr3_RD,         
                                          
      rdram_request    => rdram_request,   
      rdram_rnw        => rdram_rnw,       
      rdram_address    => rdram_address,   
      rdram_burstcount => rdram_burstcount,
      rdram_writeMask  => rdram_writeMask, 
      rdram_dataWrite  => rdram_dataWrite, 
      rdram_granted    => rdram_granted,      
      rdram_granted2x  => rdram_granted2x,      
      rdram_done       => rdram_done,      
      rdram_dataRead   => rdram_dataRead,
   
      rspfifo_req      => rspfifo_req,   
      rspfifo_reset    => rspfifo_reset,   
      rspfifo_Din      => rspfifo_Din,     
      rspfifo_Wr       => rspfifo_Wr,      
      rspfifo_nearfull => rspfifo_nearfull,
      rspfifo_empty    => rspfifo_empty,
      
      rdpfifo_Din      => rdpfifo_Din,     
      rdpfifo_Wr       => rdpfifo_Wr,      
      rdpfifo_nearfull => rdpfifo_nearfull,
      rdpfifo_empty    => rdpfifo_empty,      
      
      rdpfifoZ_Din     => rdpfifoZ_Din,     
      rdpfifoZ_Wr      => rdpfifoZ_Wr,      
      rdpfifoZ_nearfull=> rdpfifoZ_nearfull,
      rdpfifoZ_empty   => rdpfifoZ_empty,
      
      PIfifo_Din       => PIfifo_Din,    
      PIfifo_Wr        => PIfifo_Wr,   
      PIfifo_nearfull  => PIfifo_nearfull,   
      PIfifo_empty     => PIfifo_empty,
      
      VIFBfifo_Din     => VIFBfifo_Din,
      VIFBfifo_Wr      => VIFBfifo_Wr
   );
   
   sdramMux_writeMask(SDRAMMUX_VI) <= (others => '0');
   sdramMux_dataWrite(SDRAMMUX_VI) <= (others => '0');
   
   iSDRamMux : entity work.SDRamMux
   generic map
   (
      FASTSIM => is_simu
   )
   port map
   (
      clk1x                => clk1x,
      ss_reset             => ss_reset_1x,
                           
      error                => error_sdramMux,
      
      isIdle               => sdrammux_idle,
                           
      sdram_ena            => sdram_ena,      
      sdram_rnw            => sdram_rnw,      
      sdram_Adr            => sdram_Adr,      
      sdram_be             => sdram_be,       
      sdram_dataWrite      => sdram_dataWrite,
      sdram_reqprocessed   => sdram_reqprocessed,     
      sdram_done           => sdram_done,     
      sdram_dataRead       => sdram_dataRead, 
                           
      sdramMux_request     => sdramMux_request,   
      sdramMux_rnw         => sdramMux_rnw,       
      sdramMux_address     => sdramMux_address,   
      sdramMux_burstcount  => sdramMux_burstcount,
      sdramMux_writeMask   => sdramMux_writeMask, 
      sdramMux_dataWrite   => sdramMux_dataWrite, 
      sdramMux_granted     => sdramMux_granted,   
      sdramMux_done        => sdramMux_done,      
      sdramMux_dataRead    => sdramMux_dataRead,
      
      romcopy_dataNew      => rdram_done(DDR3MUX_SS),   
      romcopy_dataRead     => rdram_dataRead,         
      romcopy_active       => romcopy_active,  
      romcopy_nearFull     => romcopy_nearFull,
 
      rdp9fifo_Din         => rdp9fifo_Din,     
      rdp9fifo_Wr          => rdp9fifo_Wr,      
      rdp9fifo_nearfull    => rdp9fifo_nearfull,
      rdp9fifo_empty       => rdp9fifo_empty,

      rdp9fifoZ_Din        => rdp9fifoZ_Din,     
      rdp9fifoZ_Wr         => rdp9fifoZ_Wr,      
      rdp9fifoZ_nearfull   => rdp9fifoZ_nearfull,
      rdp9fifoZ_empty      => rdp9fifoZ_empty
   );
   
   imemorymux : entity work.memorymux
   port map
   (
      clk1x                => clk1x,
      ce                   => ce_1x,   
      reset                => reset_intern_1x,
      
      FASTBUS              => '0',
      FASTRAM              => FASTRAM,
      
      error                => errorMEMMUX,
      
      mem_request          => mem_request,  
      mem_rnw              => mem_rnw,       
      mem_address          => mem_address,  
      mem_req64            => mem_req64,  
      mem_size             => mem_size,  
      mem_writeMask        => mem_writeMask,
      mem_dataWrite        => mem_dataWrite,
      mem_dataRead         => mem_dataRead, 
      mem_done             => mem_done,
      
      rdram_request        => rdram_request(DDR3MUX_MEMMUX),   
      rdram_rnw            => rdram_rnw(DDR3MUX_MEMMUX),       
      rdram_address        => rdram_address(DDR3MUX_MEMMUX),   
      rdram_burstcount     => rdram_burstcount(DDR3MUX_MEMMUX),
      rdram_writeMask      => rdram_writeMask(DDR3MUX_MEMMUX), 
      rdram_dataWrite      => rdram_dataWrite(DDR3MUX_MEMMUX), 
      rdram_done           => rdram_done(DDR3MUX_MEMMUX),      
      rdram_dataRead       => rdram_dataRead,      
      
      bus_RDR_addr         => bus_RDR_addr,     
      bus_RDR_dataWrite    => bus_RDR_dataWrite,
      bus_RDR_read         => bus_RDR_read,     
      bus_RDR_write        => bus_RDR_write,    
      bus_RDR_dataRead     => bus_RDR_dataRead,       
      bus_RDR_done         => bus_RDR_done,       
      
      bus_RSP_addr         => bus_RSP_addr,     
      bus_RSP_dataWrite    => bus_RSP_dataWrite,
      bus_RSP_read         => bus_RSP_read,     
      bus_RSP_write        => bus_RSP_write,    
      bus_RSP_dataRead     => bus_RSP_dataRead,       
      bus_RSP_done         => bus_RSP_done,        

      bus_RDP_addr         => bus_RDP_addr,     
      bus_RDP_dataWrite    => bus_RDP_dataWrite,
      bus_RDP_read         => bus_RDP_read,     
      bus_RDP_write        => bus_RDP_write,    
      bus_RDP_dataRead     => bus_RDP_dataRead,       
      bus_RDP_done         => bus_RDP_done,           
      
      bus_MI_addr          => bus_MI_addr,     
      bus_MI_dataWrite     => bus_MI_dataWrite,
      bus_MI_read          => bus_MI_read,     
      bus_MI_write         => bus_MI_write,    
      bus_MI_dataRead      => bus_MI_dataRead,       
      bus_MI_done          => bus_MI_done,        
      
      bus_VI_addr          => bus_VI_addr,     
      bus_VI_dataWrite     => bus_VI_dataWrite,
      bus_VI_read          => bus_VI_read,     
      bus_VI_write         => bus_VI_write,    
      bus_VI_dataRead      => bus_VI_dataRead,       
      bus_VI_done          => bus_VI_done,          
      
      bus_AI_addr          => bus_AI_addr,     
      bus_AI_dataWrite     => bus_AI_dataWrite,
      bus_AI_read          => bus_AI_read,     
      bus_AI_write         => bus_AI_write,    
      bus_AI_dataRead      => bus_AI_dataRead,       
      bus_AI_done          => bus_AI_done,          

      bus_PIreg_addr       => bus_PIreg_addr,     
      bus_PIreg_dataWrite  => bus_PIreg_dataWrite,
      bus_PIreg_read       => bus_PIreg_read,     
      bus_PIreg_write      => bus_PIreg_write,    
      bus_PIreg_dataRead   => bus_PIreg_dataRead, 
      bus_PIreg_done       => bus_PIreg_done,  

      bus_RI_addr          => bus_RI_addr,     
      bus_RI_dataWrite     => bus_RI_dataWrite,
      bus_RI_read          => bus_RI_read,     
      bus_RI_write         => bus_RI_write,    
      bus_RI_dataRead      => bus_RI_dataRead,       
      bus_RI_done          => bus_RI_done,         
      
      bus_SI_addr          => bus_SI_addr,     
      bus_SI_dataWrite     => bus_SI_dataWrite,
      bus_SI_read          => bus_SI_read,     
      bus_SI_write         => bus_SI_write,    
      bus_SI_dataRead      => bus_SI_dataRead,       
      bus_SI_done          => bus_SI_done,    

      bus_PIcart_addr      => bus_PIcart_addr,     
      bus_PIcart_dataWrite => bus_PIcart_dataWrite,
      bus_PIcart_read      => bus_PIcart_read,     
      bus_PIcart_write     => bus_PIcart_write,    
      bus_PIcart_dataRead  => bus_PIcart_dataRead, 
      bus_PIcart_done      => bus_PIcart_done,        
      
      bus_PIF_addr         => bus_PIF_addr,     
      bus_PIF_dataWrite    => bus_PIF_dataWrite,
      bus_PIF_read         => bus_PIF_read,     
      bus_PIF_write        => bus_PIF_write,    
      bus_PIF_dataRead     => bus_PIF_dataRead, 
      bus_PIF_done         => bus_PIF_done 
   );

   icpu : entity work.cpu
   port map
   (
      clk1x                => clk1x,
      clk93                => clk93,
      clk2x                => clk2x,
      ce_1x                => ce_1x,   
      ce_93                => ce_93,   
      reset_1x             => reset_intern_1x,
      reset_93             => reset_intern_93,
      
      INSTRCACHEON         => INSTRCACHEON,
      DATACACHEON          => DATACACHEON,
      DATACACHESLOW        => DATACACHESLOW,
      DATACACHEFORCEWEB    => DATACACHEFORCEWEB,
      DATACACHETLBON       => DATACACHETLBON,
      RANDOMMISS           => RANDOMMISS,
      DISABLE_BOOTCOUNT    => DISABLE_BOOTCOUNT,
      DISABLE_DTLBMINI     => DISABLE_DTLBMINI, 
            
      irqRequest           => irqRequest,
      cpuPaused            => '0',
         
      error_instr          => errorCPU_instr,
      error_stall          => errorCPU_stall,
      error_FPU            => errorCPU_FPU,
      error_exception      => errorCPU_exception,
      error_fifo           => errorCPU_fifo,
      error_TLB            => errorCPU_TLB,
         
      mem_request          => mem_request,  
      mem_rnw              => mem_rnw,         
      mem_address          => mem_address,  
      mem_req64            => mem_req64,  
      mem_size             => mem_size,  
      mem_writeMask        => mem_writeMask,
      mem_dataWrite        => mem_dataWrite,
      mem_dataRead         => mem_dataRead, 
      mem_done             => mem_done,
      rdram_granted2x      => rdram_granted2x(DDR3MUX_MEMMUX),     
      rdram_done           => rdram_done(DDR3MUX_MEMMUX),     
      ddr3_DOUT            => ddr3_DOUT,       
      ddr3_DOUT_READY      => ddr3_DOUT_READY,   
         
      ram_dataRead         => x"00000000",
      ram_rnw              => '0',
      ram_done             => '0',

-- synthesis translate_off
      cpu_done             => cpu_done,  
      cpu_export           => cpu_export,
-- synthesis translate_on

      SS_reset             => SS_reset_93,
      loading_savestate    => loading_savestate,
      SS_DataWrite         => SS_DataWrite_93,
      SS_Adr               => SS_Adr_93(11 downto 0),   
      SS_wren_CPU          => SS_wren_93(10),     
      SS_rden_CPU          => SS_rden(10),            
      SS_DataRead_CPU      => open, --SS_DataRead_CPU,
      SS_idle              => open --SS_idle_cpu
   );
   
   SS_idle <= '1';
   
   isavestates : entity work.savestates
   generic map
   (
      FASTSIM => is_simu
   )
   port map
   (
      clk1x                   => clk1x,
      clk93                   => clk93,
      reset_in                => reset,
      reset_out_1x            => reset_intern_1x,
      reset_out_93            => reset_intern_93,
      ss_reset_1x             => ss_reset_1x,
      ss_reset_93             => ss_reset_93,
      
      RAMSIZE8                => RAMSIZE8,
      
      hps_busy                => '0',
      sdrammux_idle           => sdrammux_idle,
           
      load_done               => state_loaded,
            
      increaseSSHeaderCount   => increaseSSHeaderCount,
      save                    => savestate_savestate,
      load                    => savestate_loadstate,
      savestate_address       => savestate_address,  
      savestate_busy          => savestate_busy,    

      SS_idle                 => SS_idle,
      system_paused           => '1',
      savestate_pause         => savestate_pause,
      
      SS_DataWrite            => SS_DataWrite,   
      SS_Adr                  => SS_Adr,         
      SS_wren                 => SS_wren,       
      SS_rden                 => SS_rden,       
      SS_DataRead_CPU         => (63 downto 0 => '0'),
      
      SS_DataWrite_93         => SS_DataWrite_93,
      SS_Adr_93               => SS_Adr_93,      
      SS_wren_93              => SS_wren_93,     

      loading_savestate       => loading_savestate,
      saving_savestate        => open,
      
      romcopy_start           => romcopy_start,   
      romcopy_size            => romcopy_size,    
      romcopy_nearFull        => romcopy_nearFull,
      romcopy_active          => romcopy_active,  
            
      rdram_request           => rdram_request(DDR3MUX_SS),   
      rdram_rnw               => rdram_rnw(DDR3MUX_SS),       
      rdram_address           => rdram_address(DDR3MUX_SS),   
      rdram_burstcount        => rdram_burstcount(DDR3MUX_SS),
      rdram_writeMask         => rdram_writeMask(DDR3MUX_SS), 
      rdram_dataWrite         => rdram_dataWrite(DDR3MUX_SS), 
      rdram_done              => rdram_done(DDR3MUX_SS),      
      rdram_dataRead          => rdram_dataRead         
   );      

   istatemanager : entity work.statemanager
   generic map
   (
      Softmap_SaveState_ADDR   => 16#C000000#
   )
   port map
   (
      clk                 => clk1x,  
      ce                  => ce_1x,  
      reset               => reset,
                                  
      savestate_number    => savestate_number,
      save                => save_state,
      load                => load_state,
                 
      request_savestate   => savestate_savestate,
      request_loadstate   => savestate_loadstate,
      request_address     => savestate_address,  
      request_busy        => savestate_busy    
   );
   
   any_change <= change_flash or change_sram or eeprom_change or cpak_change or tpak_change;
   
   isavemem : entity work.savemem
   port map
   (
      clk                  => clk1x,  
      reset                => reset,
      
      SAVETYPE             => SAVETYPE,
      CONTROLLERPAK        => CONTROLLERPAK,
      TRANSFERPAK          => TRANSFERPAK,
      
      save                 => save,          
      load                 => load,          
                                            
      mounted              => mounted,       
      anyChange            => any_change,     
                                            
      changePending        => changePending, 
      save_ongoing         => save_ongoing,  
                                            
      eeprom_addr          => eeprom_addr,   
      eeprom_wren          => eeprom_wren,   
      eeprom_in            => eeprom_in,     
      eeprom_out           => eeprom_out,    
      
      sdram_request        => sdramMux_request(SDRAMMUX_SAV),   
      sdram_rnw            => sdramMux_rnw(SDRAMMUX_SAV),       
      sdram_address        => sdramMux_address(SDRAMMUX_SAV),   
      sdram_burstcount     => sdramMux_burstcount(SDRAMMUX_SAV),
      sdram_writeMask      => sdramMux_writeMask(SDRAMMUX_SAV), 
      sdram_dataWrite      => sdramMux_dataWrite(SDRAMMUX_SAV), 
      sdram_done           => sdramMux_done(SDRAMMUX_SAV),      
      sdram_dataRead       => sdramMux_dataRead,
                                            
      save_rd              => save_rd,       
      save_wr              => save_wr,       
      save_lba             => save_lba,      
      save_ack             => save_ack,      
      save_write           => save_write,    
      save_addr            => save_addr,     
      save_dataIn          => save_dataIn,   
      save_dataOut         => save_dataOut  
   );

   -- export
-- synthesis translate_off
   iexport : entity work.export
   port map
   (
      clk               => clk93,
      ce                => ce_93,
      reset             => reset_intern_93,
         
      new_export        => cpu_done,
      export_cpu        => cpu_export
   );
-- synthesis translate_on

end architecture;
