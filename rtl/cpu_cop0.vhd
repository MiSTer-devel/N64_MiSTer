library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;    

library mem;

use work.pexport.all;

entity cpu_cop0 is
   port 
   (
      clk93                   : in  std_logic;
      ce                      : in  std_logic;
      stall                   : in  unsigned(4 downto 0);
      stall4Masked            : in  unsigned(4 downto 0);
      executeNew              : in  std_logic;
      reset                   : in  std_logic;
      
      RANDOMMISS              : in  unsigned(3 downto 0);
      DISABLE_BOOTCOUNT       : in  std_logic;
      DISABLE_DTLBMINI        : in  std_logic;
            
      error_exception         : out std_logic := '0';
      error_TLB               : out std_logic := '0';
            
      irqRequest              : in  std_logic;
      irqTrigger              : out std_logic;
      decode_irq              : in  std_logic;

-- synthesis translate_off
      cop0_export             : out tExportRegs := (others => (others => '0'));
-- synthesis translate_on
                    
      eret                    : in  std_logic;
      exception3              : in  std_logic;
      exceptionNewPC          : in  std_logic;
      exceptionPCStore        : in  unsigned(63 downto 0);
      exceptionFPU            : in  std_logic;
      exceptionCode_1         : in  unsigned(3 downto 0);
      exceptionCode_3         : in  unsigned(3 downto 0);
      exception_COP           : in  unsigned(1 downto 0);
      isDelaySlot             : in  std_logic;                   
      nextDelaySlot           : in  std_logic;                   
      pcOld1                  : in  unsigned(63 downto 0);
                  
      eretPC                  : out unsigned(63 downto 0) := (others => '0');
      exceptionPC             : out unsigned(63 downto 0) := (others => '0');
      exception               : out std_logic := '0';
      exceptionStage1         : out std_logic := '0';
            
      COP1_enable             : out std_logic;
      COP2_enable             : out std_logic;
      fpuRegMode              : out std_logic;
      privilegeMode           : out unsigned(1 downto 0) := (others => '0');
      bit64region             : out std_logic;
                              
      writeEnable             : in  std_logic;
      regIndex                : in  unsigned(4 downto 0);
      writeValue              : in  unsigned(63 downto 0);
      readValue               : out unsigned(63 downto 0) := (others => '0');
      
      executeSetLL            : in  std_logic;
      executeLLfromTLB        : in  std_logic;
      executeLLAddr           : in  unsigned(31 downto 0);
      
      TagLo_Valid             : out std_logic;
      TagLo_Dirty             : out std_logic;
      TagLo_Addr              : out unsigned(19 downto 0);
      
      writeDatacacheTagEna    : in  std_logic;
      writeDatacacheTagValue  : in  unsigned(21 downto 0);
            
      TLBR                    : in  std_logic;
      TLBWI                   : in  std_logic;
      TLBWR                   : in  std_logic;
      TLBP                    : in  std_logic;
      TLBDone                 : out std_logic := '0';
            
      TLB_instrReq            : in  std_logic;
      TLB_ss_load             : in  std_logic;
      TLB_instrAddrIn         : in  unsigned(63 downto 0);
      TLB_instrUseCache       : out std_logic;
      TLB_instrStall          : out std_logic;
      TLB_instrUnStall        : out std_logic;
      TLB_instrAddrOutFound   : out unsigned(31 downto 0);
      TLB_instrAddrOutLookup  : out unsigned(31 downto 0);
      
      TLB_dataReq             : in  std_logic;
      TLB_dataIsWrite         : in  std_logic;
      TLB_dataAddrIn          : in  unsigned(63 downto 0);
      TLB_dataUseCacheFound   : out std_logic;
      TLB_dataUseCacheLookup  : out std_logic;
      TLB_dataStall           : out std_logic;
      TLB_dataUnStall         : out std_logic;
      TLB_dataAddrOutFound    : out unsigned(31 downto 0);
      TLB_dataAddrOutLookup   : out unsigned(31 downto 0);
            
      SS_reset                : in  std_logic;
      loading_savestate       : in  std_logic;
      SS_DataWrite            : in  std_logic_vector(63 downto 0);
      SS_Adr                  : in  unsigned(11 downto 0);
      SS_wren_CPU             : in  std_logic;
      SS_rden_CPU             : in  std_logic
   );
end entity;

architecture arch of cpu_cop0 is
     
   signal COP0_0_INDEX_tlbEntry           : unsigned(5 downto 0) := (others => '0');
   signal COP0_0_INDEX_probefailure       : std_logic := '0';
   signal COP0_1_RANDOM                   : unsigned(5 downto 0) := (others => '0');
   signal COP0_2_ENTRYLO0_phyAdr          : unsigned(23 downto 0) := (others => '0');
   signal COP0_2_ENTRYLO0_cache           : unsigned(2 downto 0) := (others => '0');
   signal COP0_2_ENTRYLO0_dirty           : std_logic := '0';
   signal COP0_2_ENTRYLO0_valid           : std_logic := '0';
   signal COP0_2_ENTRYLO0_global          : std_logic := '0';
   signal COP0_3_ENTRYLO1_phyAdr          : unsigned(23 downto 0) := (others => '0');
   signal COP0_3_ENTRYLO1_cache           : unsigned(2 downto 0) := (others => '0');
   signal COP0_3_ENTRYLO1_dirty           : std_logic := '0';
   signal COP0_3_ENTRYLO1_valid           : std_logic := '0';
   signal COP0_3_ENTRYLO1_global          : std_logic := '0';
   signal COP0_4_CONTEXT_PTE              : unsigned(40 downto 0) := (others => '0');
   signal COP0_4_CONTEXT_BADVPN           : unsigned(18 downto 0) := (others => '0');
   signal COP0_5_PAGEMASK                 : unsigned(11 downto 0) := (others => '0');
   signal COP0_6_WIRED                    : unsigned(5 downto 0)  := (others => '0');
   signal COP0_8_BADVIRTUALADDRESS        : unsigned(63 downto 0) := (others => '0');
   signal COP0_9_COUNT                    : unsigned(32 downto 0) := (others => '0');
   signal COP0_10_ENTRYHI_addressSpaceID  : unsigned(7 downto 0) := (others => '0'); 
   signal COP0_10_ENTRYHI_virtualAddress  : unsigned(26 downto 0) := (others => '0'); 
   signal COP0_10_ENTRYHI_region          : unsigned(1 downto 0) := (others => '0'); 
   signal COP0_11_COMPARE                 : unsigned(31 downto 0) := (others => '0');  
   signal COP0_12_SR_interruptEnable      : std_logic := '0';
   signal COP0_12_SR_exceptionLevel       : std_logic := '0';
   signal COP0_12_SR_errorLevel           : std_logic := '0';
   signal COP0_12_SR_privilegeMode        : unsigned(1 downto 0)  := (others => '0');
   signal COP0_12_SR_userExtendedAddr     : std_logic := '0';
   signal COP0_12_SR_supervisorAddr       : std_logic := '0';
   signal COP0_12_SR_kernelExtendedAddr   : std_logic := '0';
   signal COP0_12_SR_interruptMask        : unsigned(7 downto 0)  := (others => '0');
   signal COP0_12_SR_de                   : std_logic := '0';
   signal COP0_12_SR_ce                   : std_logic := '0';
   signal COP0_12_SR_condition            : std_logic := '0';
   signal COP0_12_SR_softReset            : std_logic := '0';
   signal COP0_12_SR_tlbShutdown          : std_logic := '0';
   signal COP0_12_SR_vectorLocation       : std_logic := '0';
   signal COP0_12_SR_instructionTracing   : std_logic := '0';
   signal COP0_12_SR_reverseEndian        : std_logic := '0';
   signal COP0_12_SR_floatingPointMode    : std_logic := '0';
   signal COP0_12_SR_lowPowerMode         : std_logic := '0';
   signal COP0_12_SR_enable_cop0          : std_logic := '0';
   signal COP0_12_SR_enable_cop1          : std_logic := '0';
   signal COP0_12_SR_enable_cop2          : std_logic := '0';
   signal COP0_12_SR_enable_cop3          : std_logic := '0';
   signal COP0_13_CAUSE_exceptionCode     : unsigned(4 downto 0) := (others => '0'); 
   signal COP0_13_CAUSE_interruptPending  : unsigned(7 downto 0) := (others => '0'); 
   signal COP0_13_CAUSE_coprocessorError  : unsigned(1 downto 0) := (others => '0'); 
   signal COP0_13_CAUSE_branchDelay       : std_logic := '0';
   signal COP0_14_EPC                     : unsigned(63 downto 0) := (others => '0'); 
   signal COP0_16_CONFIG_cacheAlgoKSEG0   : unsigned(1 downto 0) := (others => '0'); 
   signal COP0_16_CONFIG_cu               : unsigned(1 downto 0) := (others => '0'); 
   signal COP0_16_CONFIG_bigEndian        : std_logic := '0';
   signal COP0_16_CONFIG_sysadWBPattern   : unsigned(3 downto 0) := (others => '0'); 
   signal COP0_16_CONFIG_systemClockRatio : unsigned(2 downto 0) := (others => '0'); 
   signal COP0_17_LOADLINKEDADDRESS       : unsigned(63 downto 0) := (others => '0'); 
   signal COP0_18_WATCHLO                 : unsigned(31 downto 0) := (others => '0');   
   signal COP0_19_WATCHHI                 : unsigned(3 downto 0) := (others => '0');   
   signal COP0_20_XCONTEXT_PTE            : unsigned(30 downto 0) := (others => '0');
   signal COP0_20_XCONTEXT_Region         : unsigned(1 downto 0) := (others => '0');
   signal COP0_20_XCONTEXT_BadVPN         : unsigned(26 downto 0) := (others => '0');
   signal COP0_26_PARITYERROR             : unsigned(7 downto 0) := (others => '0');  
   signal COP0_28_TAGLO_primaryCacheState : unsigned(1 downto 0) := (others => '0');     
   signal COP0_28_TAGLO_physicalAddress   : unsigned(19 downto 0) := (others => '0');     
   signal COP0_30_EPCERROR                : unsigned(63 downto 0) := (others => '0'); 
      
   signal COP0_LATCH                      : unsigned(63 downto 0) := (others => '0');   
   
   signal bit64mode                       : std_logic := '0';
   signal tlbMiss1                        : std_logic := '0';
   signal tlbMiss3                        : std_logic := '0';
   
   signal nextEPC_1                       : unsigned(63 downto 0) := (others => '0');
   signal isDelaySlot_1                   : std_logic := '0';
   
   signal cop0Written6                    : integer range 0 to 2 := 0;
   signal cop0Written9                    : integer range 0 to 3 := 0;
   signal cop0FirstWrite9                 : std_logic := '0';
   signal DISABLE_BOOTCOUNT_INTERN        : std_logic := '0';
   
   --signal irq_offCount                    : unsigned(13 downto 0);
   
   
   -- tlb
   type tTLBState is
   (
      TLBIDLE,
      TLBPROBE,
      TLBINSTR,
      TLBDATA
   );
   signal TLBState : tTLBState := TLBIDLE;
   
   signal TLB_init                        : std_logic := '0';
   signal TLB_resetMode                   : std_logic := '0';
   signal TLB_resetAddr                   : unsigned(4 downto 0) := (others => '0');
   
   signal TLB_readAddr                    : unsigned(4 downto 0) := (others => '0');
   signal TLB_compareEnd                  : unsigned(4 downto 0) := (others => '0');
   
   signal TLBInvalidate                   : std_logic := '0'; 
   
   signal TLB_Instr_fetchReq_saved        : std_logic := '0'; 
   signal TLB_Data_fetchReq_saved         : std_logic := '0'; 
   
   signal TLB_checkMask                   : unsigned(26 downto 0);
   signal TLB_addMask                     : unsigned(23 downto 0);
   signal TLB_virtAddrMasked              : unsigned(26 downto 0);
   signal TLB_addrSelect                  : unsigned(12 downto 0);
   signal TLB_bank                        : std_logic;
   signal TLB_valid                       : std_logic;
   signal TLB_dirty                       : std_logic;
   signal TLB_cache                       : unsigned(2 downto 0);
   signal TLB_phyAddr                     : unsigned(19 downto 0);
   
   signal TLBINIT_global                  : std_logic;
   signal TLBINIT_valid0                  : std_logic;
   signal TLBINIT_valid1                  : std_logic;
   signal TLBINIT_dirty0                  : std_logic;
   signal TLBINIT_dirty1                  : std_logic;
   signal TLBINIT_cache0                  : std_logic_vector(2 downto 0);
   signal TLBINIT_cache1                  : std_logic_vector(2 downto 0);
   signal TLBINIT_phyAddr0                : std_logic_vector(19 downto 0);
   signal TLBINIT_phyAddr1                : std_logic_vector(19 downto 0);
   signal TLBINIT_pageMask                : std_logic_vector(11 downto 0);
   signal TLBINIT_virtAddr                : std_logic_vector(26 downto 0);
   signal TLBINIT_ASID                    : std_logic_vector(7 downto 0);
   signal TLBINIT_region                  : std_logic_vector(1 downto 0);
   signal TLBINIT_random                  : std_logic;
   
   signal TLBWRITE_global                 : std_logic;
   signal TLBWRITE_valid0                 : std_logic;
   signal TLBWRITE_valid1                 : std_logic;
   signal TLBWRITE_dirty0                 : std_logic;
   signal TLBWRITE_dirty1                 : std_logic;
   signal TLBWRITE_cache0                 : unsigned(2 downto 0);
   signal TLBWRITE_cache1                 : unsigned(2 downto 0);
   signal TLBWRITE_phyAddr0               : unsigned(19 downto 0);
   signal TLBWRITE_phyAddr1               : unsigned(19 downto 0);
   signal TLBWRITE_pageMask               : unsigned(11 downto 0);
   signal TLBWRITE_virtAddr               : unsigned(26 downto 0);
   signal TLBWRITE_ASID                   : unsigned(7 downto 0);
   signal TLBWRITE_region                 : unsigned(1 downto 0);
   signal TLBWRITE_random                 : std_logic;
   
   signal TLBREAD_global                  : std_logic;
   signal TLBREAD_valid0                  : std_logic;
   signal TLBREAD_valid1                  : std_logic;
   signal TLBREAD_dirty0                  : std_logic;
   signal TLBREAD_dirty1                  : std_logic;
   signal TLBREAD_cache0                  : unsigned(2 downto 0);
   signal TLBREAD_cache1                  : unsigned(2 downto 0);
   signal TLBREAD_phyAddr0                : unsigned(19 downto 0);
   signal TLBREAD_phyAddr1                : unsigned(19 downto 0);
   signal TLBREAD_pageMask                : unsigned(11 downto 0);
   signal TLBREAD_virtAddr                : unsigned(26 downto 0);
   signal TLBREAD_ASID                    : unsigned(7 downto 0);
   signal TLBREAD_region                  : unsigned(1 downto 0);
   signal TLBREAD_random                  : std_logic;
   
   signal TLBMEM_writeEnable              : std_logic;
   signal TLBMEM_writeData                : std_logic_vector(100 downto 0);
   signal TLBMEM_writeAddr                : std_logic_vector(4 downto 0);
   signal TLBMEM_readAddr                 : std_logic_vector(4 downto 0);
   signal TLBMEM_readData                 : std_logic_vector(100 downto 0);
   
   signal TLB_ExcInstrRead                : std_logic;
   signal TLB_ExcInstrMiss                : std_logic;
   signal TLB_ExcDataRead                 : std_logic;
   signal TLB_ExcDataWrite                : std_logic;
   signal TLB_ExcDataDirty                : std_logic;
   signal TLB_ExcDataMiss                 : std_logic;
   
   signal TLB_InstrClearEna               : std_logic;
   signal TLB_InstrClearIndex             : unsigned(4 downto 0);
   
   signal TLB_Instr_fetchReq              : std_logic;
   signal TLB_Data_fetchReq               : std_logic;
   signal TLB_Instr_fetchAddrIn           : unsigned(63 downto 0);
   signal TLB_Data_fetchAddrIn            : unsigned(63 downto 0);
   signal TLB_fetchAddrIn                 : unsigned(63 downto 0);
   signal TLB_Instr_fetchDone             : std_logic := '0';
   signal TLB_Data_fetchDone              : std_logic := '0';
   signal TLB_fetchExcInvalid             : std_logic := '0';
   signal TLB_fetchExcDirty               : std_logic := '0';
   signal TLB_fetchExcNotFound            : std_logic := '0';
   signal TLB_fetchCached                 : std_logic := '0';
   signal TLB_fetchDirty                  : std_logic := '0';
   signal TLB_fetchRandom                 : std_logic := '0';
   signal TLB_fetchSource                 : unsigned(4 downto 0) := (others => '0');
   signal TLB_fetchAddrOut                : unsigned(31 downto 0) := (others => '0');
   
-- synthesis translate_off
   type tTLBENTRY is record
      global                 : std_logic;
      valid0                 : std_logic;
      valid1                 : std_logic;
      dirty0                 : std_logic;
      dirty1                 : std_logic;
      cache0                 : unsigned(2 downto 0);
      cache1                 : unsigned(2 downto 0);
      phyAddr0               : unsigned(19 downto 0);
      phyAddr1               : unsigned(19 downto 0);
      pageMask               : unsigned(11 downto 0);
      virtAddr               : unsigned(26 downto 0);
      ASID                   : unsigned(7 downto 0);
      region                 : unsigned(1 downto 0);
      random                 : std_logic;
   end record; 
   type tTLBENTRYS  is array(0 to 31) of tTLBENTRY;
   signal TLBENTRYS : tTLBENTRYS;
-- synthesis translate_on
   
   -- savestates
   type t_ssarray is array(0 to 31) of unsigned(63 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  

begin 

   COP1_enable   <= COP0_12_SR_enable_cop1;
   COP2_enable   <= COP0_12_SR_enable_cop2;
   fpuRegMode    <= COP0_12_SR_floatingPointMode;
   privilegeMode <= COP0_12_SR_privilegeMode;
   bit64region   <= bit64mode;
   
   TagLo_Valid   <= COP0_28_TAGLO_primaryCacheState(1);
   TagLo_Dirty   <= COP0_28_TAGLO_primaryCacheState(0);
   TagLo_Addr    <= COP0_28_TAGLO_physicalAddress;
   
   process (all)
   begin
   
      irqTrigger <= '0';
      if (COP0_12_SR_interruptEnable = '1' and COP0_12_SR_exceptionLevel = '0' and COP0_12_SR_errorLevel = '0' and writeEnable = '0') then
         if ((COP0_12_SR_interruptMask and COP0_13_CAUSE_interruptPending) > 0) then
            irqTrigger <= '1';
         end if;
      end if;
            
   end process;
   
   
   process (all)
   begin
      
      readValue <= (others => '0');
   
      case (to_integer(regIndex)) is
            
         when 0 =>
            readValue(5 downto 0) <= COP0_0_INDEX_tlbEntry;
            readValue(31)         <= COP0_0_INDEX_probefailure;
            
         when 1 => readValue(5 downto 0)   <= COP0_1_RANDOM;
         
         when 2 =>
            readValue(29 downto 6)  <= COP0_2_ENTRYLO0_phyAdr;
            readValue(5 downto 3)   <= COP0_2_ENTRYLO0_cache; 
            readValue(2)            <= COP0_2_ENTRYLO0_dirty; 
            readValue(1)            <= COP0_2_ENTRYLO0_valid; 
            readValue(0)            <= COP0_2_ENTRYLO0_global;
         
         when 3 =>
            readValue(29 downto 6)  <= COP0_3_ENTRYLO1_phyAdr;
            readValue(5 downto 3)   <= COP0_3_ENTRYLO1_cache; 
            readValue(2)            <= COP0_3_ENTRYLO1_dirty; 
            readValue(1)            <= COP0_3_ENTRYLO1_valid; 
            readValue(0)            <= COP0_3_ENTRYLO1_global;
         
         when 4 => 
            readValue(63 downto 23) <= COP0_4_CONTEXT_PTE;
            readValue(22 downto  4) <= COP0_4_CONTEXT_BADVPN;
            readValue( 3 downto  0) <= (others => '0');
            
            
         when 5 => readValue(24 downto 13) <= COP0_5_PAGEMASK;
         when 6 => readValue(5 downto 0)   <= COP0_6_WIRED;
         when 8 => readValue               <= COP0_8_BADVIRTUALADDRESS;
         when 9 => readValue(31 downto 0)  <= COP0_9_COUNT(32 downto 1);
         
         when 10 =>
            readValue(7 downto 0)          <= COP0_10_ENTRYHI_addressSpaceID;
            readValue(39 downto 13)        <= COP0_10_ENTRYHI_virtualAddress;
            readValue(63 downto 62)        <= COP0_10_ENTRYHI_region;

         when 11 => readValue(31 downto 0)  <= COP0_11_COMPARE;
         
         when 12 =>
            readValue(0)            <= COP0_12_SR_interruptEnable;    
            readValue(1)            <= COP0_12_SR_exceptionLevel;     
            readValue(2)            <= COP0_12_SR_errorLevel;        
            readValue(4 downto 3)   <= COP0_12_SR_privilegeMode;      
            readValue(5)            <= COP0_12_SR_userExtendedAddr;   
            readValue(6)            <= COP0_12_SR_supervisorAddr;     
            readValue(7)            <= COP0_12_SR_kernelExtendedAddr; 
            readValue(15 downto 8)  <= COP0_12_SR_interruptMask;     
            readValue(16)           <= COP0_12_SR_de;                 
            readValue(17)           <= COP0_12_SR_ce;                 
            readValue(18)           <= COP0_12_SR_condition;          
            readValue(20)           <= COP0_12_SR_softReset;          
            readValue(21)           <= COP0_12_SR_tlbShutdown;      
            readValue(22)           <= COP0_12_SR_vectorLocation;     
            readValue(24)           <= COP0_12_SR_instructionTracing; 
            readValue(25)           <= COP0_12_SR_reverseEndian;      
            readValue(26)           <= COP0_12_SR_floatingPointMode;  
            readValue(27)           <= COP0_12_SR_lowPowerMode;       
            readValue(28)           <= COP0_12_SR_enable_cop0;
            readValue(29)           <= COP0_12_SR_enable_cop1;
            readValue(30)           <= COP0_12_SR_enable_cop2;
            readValue(31)           <= COP0_12_SR_enable_cop3;
            
         when 13 =>
            readValue(6 downto 2)   <= COP0_13_CAUSE_exceptionCode;   
            readValue(15 downto 8)  <= COP0_13_CAUSE_interruptPending;   
            readValue(29 downto 28) <= COP0_13_CAUSE_coprocessorError;   
            readValue(31)           <= COP0_13_CAUSE_branchDelay;   
            
         when 14 => readValue <= COP0_14_EPC;
            
         when 15 => readValue(11 downto 0) <= x"B22"; -- COP0_15_COPREVISION
         
         when 16 =>
            readValue(1 downto 0)   <= COP0_16_CONFIG_cacheAlgoKSEG0;
            readValue(3 downto 2)   <= COP0_16_CONFIG_cu;   
            readValue(14 downto 4)  <= "11001000110";
            readValue(15)           <= COP0_16_CONFIG_bigEndian;
            readValue(23 downto 16) <= "00000110"; 
            readValue(27 downto 24) <= COP0_16_CONFIG_sysadWBPattern; 
            readValue(30 downto 28) <= COP0_16_CONFIG_systemClockRatio;
            
         when 17 => readValue <= COP0_17_LOADLINKEDADDRESS;    
         when 18 => readValue(31 downto 0) <= COP0_18_WATCHLO;    
         when 19 => readValue(3 downto 0) <= COP0_19_WATCHHI;    
         
         when 20 => 
            readValue(63 downto 33) <= COP0_20_XCONTEXT_PTE;    
            readValue(32 downto 31) <= COP0_20_XCONTEXT_Region;    
            readValue(30 downto  4) <= COP0_20_XCONTEXT_BadVPN;    
            
         when 26 => readValue(7 downto 0) <= COP0_26_PARITYERROR;       

         when 27 => readValue <= (others => '0');

         when 28 =>
            readValue(7 downto 6)  <= COP0_28_TAGLO_primaryCacheState;
            readValue(27 downto 8) <= COP0_28_TAGLO_physicalAddress;
            
         when 29 => readValue <= (others => '0');
         
         when 30 => readValue <= COP0_30_EPCERROR;
          
         when others => readValue <= COP0_LATCH;
                     
      end case;
   end process;

   process (clk93)
      variable mode        : unsigned(1 downto 0); 
      variable nextEPC     : unsigned(63 downto 0);
      variable excAddr     : unsigned(63 downto 0);   
      variable excAddrWE   : std_logic;   
   begin
      if (rising_edge(clk93)) then
      
         error_exception     <= '0';
         error_TLB           <= '0';
         TLB_Instr_fetchDone <= '0';
         TLB_Data_fetchDone  <= '0';
         TLBInvalidate       <= '0';
      
         DISABLE_BOOTCOUNT_INTERN <= DISABLE_BOOTCOUNT;
      
         if (COP0_12_SR_errorLevel = '1') then
            eretPC <= COP0_30_EPCERROR;
         else
            eretPC <= COP0_14_EPC;
         end if;
         
         if (COP0_12_SR_vectorLocation = '1') then
         
            if (COP0_12_SR_errorLevel = '0' and ((exception = '1' and tlbMiss3 = '1') or (exception = '0' and exceptionStage1 = '1' and tlbMiss1 = '1'))) then
               if (bit64mode = '1') then
                  exceptionPC(31 downto 0) <= x"BFC00280";
               else
                  exceptionPC(31 downto 0) <= x"BFC00200";
               end if;
            else
               exceptionPC(31 downto 0) <= x"BFC00380";
            end if;
            
         else
            
            if (COP0_12_SR_errorLevel = '0' and ((exception = '1' and tlbMiss3 = '1') or (exception = '0' and exceptionStage1 = '1' and tlbMiss1 = '1'))) then
               if (bit64mode = '1') then
                  exceptionPC(31 downto 0) <= x"80000080";
               else
                  exceptionPC(31 downto 0) <= x"80000000";
               end if;
            else
               exceptionPC(31 downto 0) <= x"80000180";
            end if;
            
         end if;
         if (bit64mode = '1') then
            exceptionPC(63 downto 32) <= (others => '1');
         else
            exceptionPC(63 downto 32) <= (others => '0');
         end if;
         
         --if (COP0_12_SR_interruptEnable = '1' or COP0_12_SR_exceptionLevel = '1') then    
         --   irq_offCount <= (others => '0');
         --else
         --   irq_offCount <= irq_offCount + 1;
         --end if;
         --error_exception <= irq_offCount(13);
      
         if (reset = '1') then
         
            COP0_0_INDEX_tlbEntry           <= (others => '0');
            COP0_0_INDEX_probefailure       <= '0';
            COP0_1_RANDOM                   <= (others => '0');
            COP0_2_ENTRYLO0_phyAdr          <= (others => '0');
            COP0_2_ENTRYLO0_cache           <= (others => '0');
            COP0_2_ENTRYLO0_dirty           <= '0';       
            COP0_2_ENTRYLO0_valid           <= '0';       
            COP0_2_ENTRYLO0_global          <= '0';
            COP0_3_ENTRYLO1_phyAdr          <= (others => '0');
            COP0_3_ENTRYLO1_cache           <= (others => '0');
            COP0_3_ENTRYLO1_dirty           <= '0';       
            COP0_3_ENTRYLO1_valid           <= '0';       
            COP0_3_ENTRYLO1_global          <= '0';
            COP0_4_CONTEXT_PTE              <= (others => '0');
            COP0_4_CONTEXT_BADVPN           <= (others => '0');
            COP0_5_PAGEMASK                 <= (others => '0');
            COP0_6_WIRED                    <= ss_in(6)(5 downto 0); -- (others => '0');
            COP0_8_BADVIRTUALADDRESS        <= (others => '0');
            COP0_9_COUNT                    <= ss_in(9)(31 downto 0) & '0'; -- (others => '0');
            COP0_10_ENTRYHI_addressSpaceID  <= (others => '0'); 
            COP0_10_ENTRYHI_virtualAddress  <= (others => '0'); 
            COP0_10_ENTRYHI_region          <= (others => '0'); 
            COP0_11_COMPARE                 <= ss_in(11)(31 downto 0); -- (others => '0');
            COP0_12_SR_interruptEnable      <= ss_in(12)(0);           -- '0';
            COP0_12_SR_exceptionLevel       <= ss_in(12)(1);           -- '0';
            COP0_12_SR_errorLevel           <= ss_in(12)(2);           -- '1';
            COP0_12_SR_privilegeMode        <= ss_in(12)(4 downto 3);  -- (others => '0');
            COP0_12_SR_userExtendedAddr     <= ss_in(12)(5);           -- '0';
            COP0_12_SR_supervisorAddr       <= ss_in(12)(6);           -- '0';
            COP0_12_SR_kernelExtendedAddr   <= ss_in(12)(7);           -- '0';
            COP0_12_SR_interruptMask        <= ss_in(12)(15 downto 8); -- (others => '1');
            COP0_12_SR_de                   <= ss_in(12)(16);          -- '0';
            COP0_12_SR_ce                   <= ss_in(12)(17);          -- '0';
            COP0_12_SR_condition            <= ss_in(12)(18);          -- '0';
            COP0_12_SR_softReset            <= ss_in(12)(20);          -- '1';
            COP0_12_SR_tlbShutdown          <= ss_in(12)(21);          -- '0';
            COP0_12_SR_vectorLocation       <= ss_in(12)(22);          -- '1';
            COP0_12_SR_instructionTracing   <= ss_in(12)(24);          -- '0';
            COP0_12_SR_reverseEndian        <= ss_in(12)(25);          -- '0';
            COP0_12_SR_floatingPointMode    <= ss_in(12)(26);          -- '1';
            COP0_12_SR_lowPowerMode         <= ss_in(12)(27);          -- '0';
            COP0_12_SR_enable_cop0          <= ss_in(12)(28);          -- '1';
            COP0_12_SR_enable_cop1          <= ss_in(12)(29);          -- '1';
            COP0_12_SR_enable_cop2          <= ss_in(12)(30);          -- '0';
            COP0_12_SR_enable_cop3          <= ss_in(12)(31);          -- '0';
            COP0_13_CAUSE_exceptionCode     <= (others => '0'); 
            COP0_13_CAUSE_interruptPending  <= (others => '0'); 
            COP0_13_CAUSE_coprocessorError  <= (others => '0'); 
            COP0_13_CAUSE_branchDelay       <= ss_in(13)(31);          -- '0'
            COP0_14_EPC                     <= 32x"0" & ss_in(14)(31 downto 0); -- (others => '0'); will not work for savestates with TLB
            COP0_16_CONFIG_cacheAlgoKSEG0   <= ss_in(16)(1 downto 0); -- (others => '0'); required for systemtest
            COP0_16_CONFIG_cu               <= (others => '0'); 
            COP0_16_CONFIG_bigEndian        <= '1';
            COP0_16_CONFIG_sysadWBPattern   <= (others => '0'); 
            COP0_16_CONFIG_systemClockRatio <= (others => '1'); 
            COP0_17_LOADLINKEDADDRESS       <= (others => '0'); 
            COP0_18_WATCHLO                 <= (others => '0');   
            COP0_19_WATCHHI                 <= (others => '0');   
            COP0_20_XCONTEXT_PTE            <= (others => '0');
            COP0_20_XCONTEXT_Region         <= (others => '0');
            COP0_20_XCONTEXT_BadVPN         <= (others => '0');
            COP0_26_PARITYERROR             <= (others => '0');  
            COP0_28_TAGLO_primaryCacheState <= (others => '0');     
            COP0_28_TAGLO_physicalAddress   <= (others => '0');     
            COP0_30_EPCERROR                <= (others => '0'); 
            
            COP0_LATCH                      <= (others => '0'); 
            
            bit64mode                       <= '0';
            
            cop0Written6                    <= 0;
            cop0Written9                    <= 0;
            cop0FirstWrite9                 <= (not loading_savestate) and (not DISABLE_BOOTCOUNT_INTERN);
            
            TLBState                        <= TLBIDLE;
            TLBDone                         <= '0';
            TLB_Instr_fetchReq_saved        <= '0';
            TLB_Data_fetchReq_saved         <= '0';
            tlbMiss1                        <= '0';
            tlbMiss3                        <= '0';
            
         elsif (ce = '1') then
         
            -- interrupt
            COP0_13_CAUSE_interruptPending(2) <= irqRequest;

            -- count
            if (cop0Written9 = 0) then
               COP0_9_COUNT <= COP0_9_COUNT + 1;
               if (COP0_9_COUNT(32 downto 1) = COP0_11_COMPARE) then
                  COP0_13_CAUSE_interruptPending(7) <= '1';
               end if;
            else
               cop0Written9 <= cop0Written9 - 1;
            end if;
            
            -- random
            if (stall = 0) then
               if (COP0_6_WIRED(5) = '0' and COP0_1_RANDOM(4 downto 0) = COP0_6_WIRED(4 downto 0)) then
                  COP0_1_RANDOM <= 6x"1F";
                  --COP0_1_RANDOM <= 6x"03"; -- DO NOT COMMIT AS ACTIVE!
               else
                  COP0_1_RANDOM <= COP0_1_RANDOM - 1;
               end if;
            end if;
            
            if (cop0Written6 > 0) then
               cop0Written6 <= cop0Written6 - 1;
               if (cop0Written6 = 1) then
                  COP0_1_RANDOM   <= to_unsigned(31, 6);
               end if;
            end if;
            
            -- linked address
            if (stall = 0 and executeSetLL = '1') then 
               if (executeLLfromTLB = '1') then
                  COP0_17_LOADLINKEDADDRESS <= 36x"0" & executeLLAddr(31 downto 4);
               else
                  COP0_17_LOADLINKEDADDRESS <= 39x"0" & executeLLAddr(28 downto 4);
               end if;
            end if;
            
            -- when debugging systemtest...
-- synthesis translate_off
            --COP0_9_COUNT  <= (others => '0');
            --COP0_1_RANDOM <= (others => '0');
            --COP0_13_CAUSE_interruptPending(7) <= '0';
-- synthesis translate_on
            
            -- CPU access
            if (exception = '1') then
         
               COP0_14_EPC               <= nextEPC_1;
               COP0_13_CAUSE_branchDelay <= isDelaySlot_1;
               
               case (COP0_13_CAUSE_exceptionCode(3 downto 0)) is
                  when x"4" | x"5" | x"9" | x"A" | x"C"  => error_exception <= '1';
                  when others => null;
               end case;
         
            elsif (stall4Masked = 0 and executeNew = '1') then
               if (writeEnable = '1') then
               
                  COP0_LATCH <= writeValue;
                  
                  case (to_integer(regIndex)) is
                     
                     when 0 =>
                        COP0_0_INDEX_tlbEntry     <= writeValue(5 downto 0);
                        COP0_0_INDEX_probefailure <= writeValue(31);
                        
                        when 2 =>
                           COP0_2_ENTRYLO0_phyAdr <= writeValue(29 downto 6);
                           COP0_2_ENTRYLO0_cache  <= writeValue(5 downto 3); 
                           COP0_2_ENTRYLO0_dirty  <= writeValue(2);          
                           COP0_2_ENTRYLO0_valid  <= writeValue(1);          
                           COP0_2_ENTRYLO0_global <= writeValue(0);          
                        
                        when 3 =>
                           COP0_3_ENTRYLO1_phyAdr <= writeValue(29 downto 6);
                           COP0_3_ENTRYLO1_cache  <= writeValue(5 downto 3); 
                           COP0_3_ENTRYLO1_dirty  <= writeValue(2);          
                           COP0_3_ENTRYLO1_valid  <= writeValue(1);          
                           COP0_3_ENTRYLO1_global <= writeValue(0);     
                        
                        when 4 => COP0_4_CONTEXT_PTE <= writeValue(63 downto 23);
                        when 5 => COP0_5_PAGEMASK <= writeValue(24 downto 13);
                        
                        when 6 => 
                           COP0_6_WIRED    <= writeValue(5 downto 0);
                           cop0Written6    <= 2;
                        
                        when 9 => 
                           COP0_9_COUNT    <= writeValue(31 downto 0) & '0';
                           cop0Written9    <= 3;
                           cop0FirstWrite9 <= '0';
                           if (cop0FirstWrite9 = '1') then -- compensate for RDRAM calibration wait time, e.g. battletanx or waverace shindue
                              COP0_9_COUNT(24 downto 21) <= x"F";
                           end if;
                        
                        when 10 =>
                           COP0_10_ENTRYHI_addressSpaceID <= writeValue(7 downto 0);
                           COP0_10_ENTRYHI_virtualAddress <= writeValue(39 downto 13);
                           COP0_10_ENTRYHI_region         <= writeValue(63 downto 62);
                           if (COP0_10_ENTRYHI_addressSpaceID /= writeValue(7 downto 0)) then
                              TLBInvalidate <= '1';
                           end if;
                           
                        when 11 =>
                           COP0_11_COMPARE   <= writeValue(31 downto 0);
                           COP0_13_CAUSE_interruptPending(7) <= '0';
                        
                        when 12 =>
                           COP0_12_SR_interruptEnable     <= writeValue(0 );
                           COP0_12_SR_exceptionLevel      <= writeValue(1 );
                           COP0_12_SR_errorLevel          <= writeValue(2 );
                           COP0_12_SR_privilegeMode       <= writeValue(4 downto 3);
                           COP0_12_SR_userExtendedAddr    <= writeValue(5);
                           COP0_12_SR_supervisorAddr      <= writeValue(6);
                           COP0_12_SR_kernelExtendedAddr  <= writeValue(7);
                           COP0_12_SR_interruptMask       <= writeValue(15 downto 8);
                           COP0_12_SR_de                  <= writeValue(16);
                           COP0_12_SR_ce                  <= writeValue(17);
                           COP0_12_SR_condition           <= writeValue(18);
                           COP0_12_SR_softReset           <= writeValue(20);
                           --COP0_12_SR_tlbShutdown         <= writeValue(21); -- read only
                           COP0_12_SR_vectorLocation      <= writeValue(22);
                           COP0_12_SR_instructionTracing  <= writeValue(24);
                           COP0_12_SR_reverseEndian       <= writeValue(25);
                           COP0_12_SR_floatingPointMode   <= writeValue(26);
                           COP0_12_SR_lowPowerMode        <= writeValue(27);
                           COP0_12_SR_enable_cop0         <= writeValue(28);
                           COP0_12_SR_enable_cop1         <= writeValue(29);
                           COP0_12_SR_enable_cop2         <= writeValue(30);
                           COP0_12_SR_enable_cop3         <= writeValue(31);
                           
                        when 13 => COP0_13_CAUSE_interruptPending(1 downto 0) <= writeValue(9 downto 8);
                        when 14 => COP0_14_EPC <= writeValue;
                        
                        when 16 =>
                           COP0_16_CONFIG_cacheAlgoKSEG0 <= writeValue(1 downto 0);
                           COP0_16_CONFIG_cu             <= writeValue(3 downto 2);   
                           COP0_16_CONFIG_bigEndian      <= writeValue(15);
                           COP0_16_CONFIG_sysadWBPattern <= writeValue(27 downto 24); 
                           --COP0_16_CONFIG_systemClockRatio <= writeValue(30 downto 28); -- read only
                     
                        when 17 => COP0_17_LOADLINKEDADDRESS(31 downto 0) <= writeValue(31 downto 0);
                        
                        when 18 => COP0_18_WATCHLO <= writeValue(31 downto 3) & '0' & writeValue(1 downto 0);
                        when 19 => COP0_19_WATCHHI <= writeValue(3 downto 0);
                        when 20 => COP0_20_XCONTEXT_PTE <= writeValue(63 downto 33);
                        when 26 => COP0_26_PARITYERROR <= writeValue(7 downto 0);
                        
                        when 28 =>
                           COP0_28_TAGLO_primaryCacheState <= writeValue(7 downto 6);
                           COP0_28_TAGLO_physicalAddress   <= writeValue(27 downto 8);
                           
                        when 30 => COP0_30_EPCERROR <= writeValue;
                     
                     when others => null;   
                        
                  end case;
                     
               end if; -- write enable

               -- eret
               if (eret = '1' and exception = '0' and exceptionStage1 = '0') then
                  if (COP0_12_SR_errorLevel = '1') then
                     COP0_12_SR_errorLevel <= '0';
                  else
                     COP0_12_SR_exceptionLevel <= '0';
                  end if;
               end if;
               
               -- set mode
               mode := COP0_12_SR_privilegeMode;
               if (mode > 2) then mode := "10"; end if;
               if (COP0_12_SR_exceptionLevel = '1') then mode := "00"; end if;
               if (COP0_12_SR_errorLevel     = '1') then mode := "00"; end if;
               -- should also switch endian mode, but we don't allow little endian in this CPU implementation!
               case (mode) is
                  when "00" => bit64mode <= COP0_12_SR_kernelExtendedAddr;
                  when "01" => bit64mode <= COP0_12_SR_supervisorAddr;
                  when "10" => bit64mode <= COP0_12_SR_userExtendedAddr;
                  when others => null;
               end case;
               
            end if; -- stall
            
            if (writeDatacacheTagEna = '1') then
               COP0_28_TAGLO_primaryCacheState <= writeDatacacheTagValue(21 downto 20);
               COP0_28_TAGLO_physicalAddress   <= writeDatacacheTagValue(19 downto 0);
            end if;

            -- new exception
            nextEPC := pcOld1;
            if (isDelaySlot = '1') then
               nextEPC := pcOld1 - 4; -- should this be pcOld2 instead? need to test with exception in branch delay slot after branch in branch delay slot 
            end if;
            if (exceptionNewPC = '1') then
               nextEPC := exceptionPCStore;
            end if;
            if (stall = 0) then
               exception       <= '0';
               exceptionStage1 <= '0';
               nextEPC_1       <= nextEPC;
               isDelaySlot_1   <= isDelaySlot;
               if (exception = '0' and exceptionStage1 = '1') then
                  COP0_13_CAUSE_coprocessorError <= "00";
                  COP0_13_CAUSE_exceptionCode    <= '0' & x"2";
                  COP0_14_EPC                  <= TLB_Instr_fetchAddrIn;
                  COP0_13_CAUSE_branchDelay    <= '0';
                  if (nextDelaySlot = '1') then
                     COP0_14_EPC               <= TLB_Instr_fetchAddrIn - 4;
                     COP0_13_CAUSE_branchDelay <= '1';
                  end if;
               end if;
            end if;
            
            if (TLB_ExcInstrRead = '1') then
               exceptionStage1            <= '1';
               tlbMiss1                   <= TLB_ExcInstrMiss;
               COP0_12_SR_exceptionLevel  <= '1';
            end if;
            
            if (exception = '0') then
               if (stall = 0 or exceptionFPU = '1' or TLB_ExcDataRead = '1' or TLB_ExcDataWrite = '1' or TLB_ExcDataDirty = '1') then
               
                  tlbMiss3 <= '0';
               
                  if (decode_irq = '1' or exceptionFPU = '1' or exception3 = '1' or TLB_ExcDataRead = '1' or TLB_ExcDataWrite = '1' or TLB_ExcDataDirty = '1') then
                  
                     exception <= '1';
                     COP0_12_SR_exceptionLevel   <= '1';
                     COP0_13_CAUSE_coprocessorError <= "00";
                     if (decode_irq = '1') then
                        COP0_13_CAUSE_exceptionCode    <= (others => '0');
                     elsif (exceptionFPU = '1') then
                        COP0_13_CAUSE_exceptionCode    <= '0' & x"F";
                     elsif (TLB_ExcDataRead = '1') then
                        COP0_13_CAUSE_exceptionCode    <= '0' & x"2";
                        tlbMiss3 <= TLB_ExcDataMiss;
                     elsif (TLB_ExcDataWrite = '1') then
                        COP0_13_CAUSE_exceptionCode    <= '0' & x"3";
                        tlbMiss3 <= TLB_ExcDataMiss;
                     elsif (TLB_ExcDataDirty = '1') then
                        COP0_13_CAUSE_exceptionCode    <= '0' & x"1";
                     elsif (exception3 = '1') then
                        COP0_13_CAUSE_exceptionCode    <= '0' & exceptionCode_3;
                        COP0_13_CAUSE_coprocessorError <= exception_COP;
                     else
                        COP0_13_CAUSE_exceptionCode <= '0' & exceptionCode_1;
                     end if;
                  
                  end if;
               end if;
            end if;
            
            -- addr exception
            excAddrWE := '0';
            excAddr   := TLB_dataAddrIn; -- unmodified mem address
            
            if (exception3 = '1' and (exceptionCode_3 = x"4" or exceptionCode_3 = x"5")) then
               excAddrWE := '1';
               if (exceptionNewPC = '1') then
                  excAddr := exceptionPCStore;
               end if;
            end if;

            if (TLB_ExcDataRead = '1' or TLB_ExcDataWrite = '1' or TLB_ExcDataDirty = '1') then
               excAddrWE := '1';
               excAddr   := TLB_Data_fetchAddrIn;
            end if;
            
            if (TLB_ExcInstrRead = '1') then
               excAddrWE := '1';
               excAddr   := TLB_Instr_fetchAddrIn; 
            end if;

            if (excAddrWE = '1') then
               COP0_8_BADVIRTUALADDRESS       <= excAddr;
               
               COP0_10_ENTRYHI_virtualAddress <= excAddr(39 downto 13);
               COP0_10_ENTRYHI_region         <= excAddr(63 downto 62);
               
               COP0_4_CONTEXT_BADVPN          <= excAddr(31 downto 13);
               
               COP0_20_XCONTEXT_Region        <= excAddr(63 downto 62);
               COP0_20_XCONTEXT_BadVPN        <= excAddr(39 downto 13);
            end if;
            
            -- tlb
            TLBDone                  <= '0';
            TLB_Instr_fetchReq_saved <= TLB_Instr_fetchReq_saved or TLB_Instr_fetchReq;
            TLB_Data_fetchReq_saved  <= TLB_Data_fetchReq_saved  or TLB_Data_fetchReq;
            
            if (TLBWI = '1' or TLBWR = '1') then
               TLBInvalidate <= '1';
            end if;
            
            if (TLBState /= TLBIDLE and (TLBR = '1' or TLBWI = '1' or TLBWR = '1' or TLBP = '1')) then
               error_TLB <= '1';
            end if;
            
            case (TLBState) is
            
               when TLBIDLE =>
                  TLB_readAddr     <= (others => '0');
                  
                  if (exception = '0' and stall4Masked = 0 and executeNew = '1' and TLBR = '1') then
                     COP0_2_ENTRYLO0_global         <= TLBREAD_global;
                     COP0_3_ENTRYLO1_global         <= TLBREAD_global;
                     COP0_2_ENTRYLO0_valid          <= TLBREAD_valid0;
                     COP0_3_ENTRYLO1_valid          <= TLBREAD_valid1;
                     COP0_2_ENTRYLO0_dirty          <= TLBREAD_dirty0;
                     COP0_3_ENTRYLO1_dirty          <= TLBREAD_dirty1;
                     COP0_2_ENTRYLO0_cache          <= TLBREAD_cache0;
                     COP0_3_ENTRYLO1_cache          <= TLBREAD_cache1;
                     COP0_2_ENTRYLO0_phyAdr         <= x"0" & TLBREAD_phyAddr0;
                     COP0_3_ENTRYLO1_phyAdr         <= x"0" & TLBREAD_phyAddr1;
                     COP0_5_PAGEMASK                <= TLBREAD_pageMask;
                     COP0_10_ENTRYHI_virtualAddress <= TLBREAD_virtAddr;
                     COP0_10_ENTRYHI_addressSpaceID <= TLBREAD_ASID;
                     COP0_10_ENTRYHI_region         <= TLBREAD_region;
                  
                  elsif (exception = '0' and stall4Masked = 0 and executeNew = '1' and (TLBWI = '1' or TLBWR = '1')) then
                     null;

                  elsif (exception = '0' and stall4Masked = 0 and executeNew = '1' and TLBP = '1') then
                     TLBState   <= TLBPROBE;
                     
                  elsif (TLB_Instr_fetchReq_saved = '1' or TLB_Instr_fetchReq = '1') then
                     TLB_Instr_fetchReq_saved <= '0';
                     TLB_readAddr             <= TLB_fetchSource;
                     TLB_compareEnd           <= TLB_fetchSource - 1;
                     TLBState                 <= TLBINSTR;
                     TLB_fetchAddrIn          <= TLB_Instr_fetchAddrIn;
                     TLB_fetchExcNotFound     <= '1';
                     TLB_fetchExcInvalid      <= '0';                
                     
                  elsif (TLB_Data_fetchReq_saved = '1' or TLB_Data_fetchReq = '1') then
                     TLB_Data_fetchReq_saved  <= '0';
                     TLB_readAddr             <= TLB_fetchSource;
                     TLB_compareEnd           <= TLB_fetchSource - 1;
                     TLBState                 <= TLBDATA;
                     TLB_fetchAddrIn          <= TLB_Data_fetchAddrIn;
                     TLB_fetchExcNotFound     <= '1';
                     TLB_fetchExcInvalid      <= '0';
                     TLB_fetchExcDirty        <= '0';
                     
                  end if;
                  
               when TLBPROBE =>
                  TLB_readAddr <= TLB_readAddr + 1;
                  if (TLB_readAddr = 31) then
                     TLBState                  <= TLBIDLE;
                     COP0_0_INDEX_probefailure <= '1';
                     COP0_0_INDEX_tlbEntry     <= (others => '0');
                     TLBDone                   <= '1';
                  end if;
                  if ((COP0_10_ENTRYHI_virtualAddress and TLB_checkMask) = (TLBREAD_virtAddr and TLB_checkMask)) then
                     if (COP0_10_ENTRYHI_region = TLBREAD_region) then
                        if (TLBREAD_global = '1' or (COP0_10_ENTRYHI_addressSpaceID = TLBREAD_ASID)) then
                           TLBState                  <= TLBIDLE;
                           COP0_0_INDEX_probefailure <= '0';
                           COP0_0_INDEX_tlbEntry     <= '0' & TLB_readAddr;
                           TLBDone                   <= '1';
                        end if;
                     end if;
                  end if;
                  
               when TLBDATA | TLBINSTR =>
                  TLB_readAddr <= TLB_readAddr + 1;
                  if (TLB_readAddr = TLB_compareEnd) then
                     TLBState           <= TLBIDLE;
                     if (TLBState = TLBINSTR) then
                        TLB_Instr_fetchDone <= '1';
                     else
                        TLB_Data_fetchDone <= '1';
                     end if;
                  end if;
                  if (TLBREAD_global = '1' or (COP0_10_ENTRYHI_addressSpaceID = TLBREAD_ASID)) then
                     if (TLB_virtAddrMasked = TLBREAD_virtAddr) then
                        if (TLB_fetchAddrIn(63 downto 62) = TLBREAD_region) then
                     
                           if (TLB_valid = '0') then
                              TLB_fetchExcInvalid <= '1';
                           end if;
                           
                           if (TLB_dirty = '0') then
                              TLB_fetchExcDirty <= '1';
                           end if;

                           TLBState              <= TLBIDLE;
                           TLB_fetchExcNotFound  <= '0';
                           TLB_fetchAddrOut      <= (TLB_phyAddr & x"000") + (x"00" & (TLB_fetchAddrIn(23 downto 0) and TLB_addMask));
                     
                           TLB_fetchCached <= '1';
                           if (TLB_cache = 2) then
                              TLB_fetchCached <= '0';
                           end if;
                           
                           TLB_fetchDirty <= TLB_dirty;
                           
                           TLB_fetchRandom <= TLBREAD_random;
                           
                           if (TLBState = TLBINSTR) then
                              TLB_Instr_fetchDone <= '1';
                           else
                              TLB_Data_fetchDone <= '1';
                           end if;
                           
                           TLB_fetchSource <= TLB_readAddr;
                     
                        end if;
                     end if;
                  end if;
            
            end case;

         end if; -- ce
         
         TLB_init <= '0';
         
         if (SS_reset = '1' or TLB_InstrClearEna = '1') then
            if (TLB_InstrClearEna = '1') then
               TLB_init         <= '1';
               TLB_resetAddr    <= TLB_InstrClearIndex;
            else
               TLB_resetAddr    <= (others => '1');
               TLB_resetMode    <= '1';
            end if;
            TLBINIT_global   <= '0';
            TLBINIT_valid0   <= '0';
            TLBINIT_valid1   <= '0';
            TLBINIT_dirty0   <= '0';
            TLBINIT_dirty1   <= '0';
            TLBINIT_cache0   <= (others => '0');
            TLBINIT_cache1   <= (others => '0');
            TLBINIT_phyAddr0 <= (others => '0');
            TLBINIT_phyAddr1 <= (others => '0');
            TLBINIT_pageMask <= (others => '0');
            TLBINIT_virtAddr <= (others => '0');
            TLBINIT_ASID     <= (others => '0');
            TLBINIT_region   <= (others => '0');
            TLBINIT_random   <= '0';
         end if;
         
         if (TLB_resetMode = '1') then
            TLB_resetAddr <= TLB_resetAddr + 1;
            TLB_init      <= '1';
            if (TLB_resetAddr = 30) then
               TLB_resetMode <= '0';
            end if;
         end if;
         
         if (SS_wren_CPU = '1') then
            if (SS_Adr(0) = '0') then
               TLBINIT_phyAddr0 <= SS_DataWrite(19 downto  0);
               TLBINIT_phyAddr1 <= SS_DataWrite(51 downto 32);
               TLBINIT_cache0   <= SS_DataWrite(60 downto 58);
               TLBINIT_cache1   <= SS_DataWrite(63 downto 61);
            else
               TLBINIT_virtAddr <= SS_DataWrite(26 downto  0);
               TLBINIT_ASID     <= SS_DataWrite(39 downto 32);
               TLBINIT_pageMask <= SS_DataWrite(51 downto 40);
               TLBINIT_region   <= SS_DataWrite(55 downto 54);
               TLBINIT_global   <= SS_DataWrite(56);
               TLBINIT_valid0   <= SS_DataWrite(57);
               TLBINIT_valid1   <= SS_DataWrite(58);
               TLBINIT_dirty0   <= SS_DataWrite(59);
               TLBINIT_dirty1   <= SS_DataWrite(60);
               TLBINIT_random   <= SS_DataWrite(61);
            end if;
         end if;
         
         if (SS_wren_CPU = '1' and SS_Adr >= 256 and SS_Adr < 320) then
            TLB_resetAddr <= SS_Adr(5 downto 1);
            TLB_init      <= SS_Adr(0);
         end if;
         
         
      end if;
   end process;
   
   TLB_checkMask      <= 15x"7FFF" & (not TLBREAD_pageMask);
   TLB_addMask        <= TLBREAD_pageMask & x"FFF";
   
   TLB_virtAddrMasked <= TLB_fetchAddrIn(39 downto 13) and TLB_checkMask;
   
   TLB_addrSelect     <= ('0' & TLBREAD_pageMask) + 1;
   TLB_bank           <= '1' when ((TLB_fetchAddrIn(24 downto 12) and TLB_addrSelect) > 0) else '0';
   
   TLB_valid   <= TLBREAD_valid1   when (TLB_bank = '1') else TLBREAD_valid0;
   TLB_dirty   <= TLBREAD_dirty1   when (TLB_bank = '1') else TLBREAD_dirty0;
   TLB_cache   <= TLBREAD_cache1   when (TLB_bank = '1') else TLBREAD_cache0;
   TLB_phyAddr <= TLBREAD_phyAddr1 when (TLB_bank = '1') else TLBREAD_phyAddr0;
   

   
   TLBWRITE_global   <= COP0_2_ENTRYLO0_global and COP0_3_ENTRYLO1_global;
   TLBWRITE_valid0   <= COP0_2_ENTRYLO0_valid;
   TLBWRITE_valid1   <= COP0_3_ENTRYLO1_valid;
   TLBWRITE_dirty0   <= COP0_2_ENTRYLO0_dirty;
   TLBWRITE_dirty1   <= COP0_3_ENTRYLO1_dirty;
   TLBWRITE_cache0   <= COP0_2_ENTRYLO0_cache;
   TLBWRITE_cache1   <= COP0_3_ENTRYLO1_cache;
   TLBWRITE_phyAddr0 <= COP0_2_ENTRYLO0_phyAdr(19 downto 0);
   TLBWRITE_phyAddr1 <= COP0_3_ENTRYLO1_phyAdr(19 downto 0);
   TLBWRITE_pageMask <= COP0_5_PAGEMASK(11) & COP0_5_PAGEMASK(11) & COP0_5_PAGEMASK(9) & COP0_5_PAGEMASK(9) & COP0_5_PAGEMASK(7) & COP0_5_PAGEMASK(7) &
                        COP0_5_PAGEMASK(5)  & COP0_5_PAGEMASK(5)  & COP0_5_PAGEMASK(3) & COP0_5_PAGEMASK(3) & COP0_5_PAGEMASK(1) & COP0_5_PAGEMASK(1);
   TLBWRITE_virtAddr(26 downto 12) <= COP0_10_ENTRYHI_virtualAddress(26 downto 12);
   TLBWRITE_virtAddr(11 downto  0) <= COP0_10_ENTRYHI_virtualAddress(11 downto 0) and (not TLBWRITE_pageMask);
   TLBWRITE_ASID     <= COP0_10_ENTRYHI_addressSpaceID;
   TLBWRITE_region   <= COP0_10_ENTRYHI_region;
   TLBWRITE_random   <= TLBWR;
   
   TLBMEM_writeData(0)            <= TLBINIT_global    when (TLB_init = '1') else TLBWRITE_global;  
   TLBMEM_writeData(1)            <= TLBINIT_valid0    when (TLB_init = '1') else TLBWRITE_valid0;  
   TLBMEM_writeData(2)            <= TLBINIT_valid1    when (TLB_init = '1') else TLBWRITE_valid1;  
   TLBMEM_writeData(3)            <= TLBINIT_dirty0    when (TLB_init = '1') else TLBWRITE_dirty0;  
   TLBMEM_writeData(4)            <= TLBINIT_dirty1    when (TLB_init = '1') else TLBWRITE_dirty1;  
   TLBMEM_writeData( 7 downto  5) <= TLBINIT_cache0    when (TLB_init = '1') else std_logic_vector(TLBWRITE_cache0);  
   TLBMEM_writeData(10 downto  8) <= TLBINIT_cache1    when (TLB_init = '1') else std_logic_vector(TLBWRITE_cache1);  
   TLBMEM_writeData(30 downto 11) <= TLBINIT_phyAddr0  when (TLB_init = '1') else std_logic_vector(TLBWRITE_phyAddr0);
   TLBMEM_writeData(50 downto 31) <= TLBINIT_phyAddr1  when (TLB_init = '1') else std_logic_vector(TLBWRITE_phyAddr1);
   TLBMEM_writeData(62 downto 51) <= TLBINIT_pageMask  when (TLB_init = '1') else std_logic_vector(TLBWRITE_pageMask);
   TLBMEM_writeData(89 downto 63) <= TLBINIT_virtAddr  when (TLB_init = '1') else std_logic_vector(TLBWRITE_virtAddr);
   TLBMEM_writeData(97 downto 90) <= TLBINIT_ASID      when (TLB_init = '1') else std_logic_vector(TLBWRITE_ASID);    
   TLBMEM_writeData(99 downto 98) <= TLBINIT_region    when (TLB_init = '1') else std_logic_vector(TLBWRITE_region); 
   TLBMEM_writeData(100)          <= TLBINIT_random    when (TLB_init = '1') else TLBWRITE_random;   

   TLBMEM_writeEnable <= '1' when (TLB_init = '1') else
                         '1' when (exception = '0' and stall4Masked = 0 and executeNew = '1' and (TLBWI = '1' or TLBWR = '1')) else 
                         '0';
   
   TLBMEM_writeAddr <= std_logic_vector(TLB_resetAddr) when (TLB_init = '1') else
                       std_logic_vector(COP0_0_INDEX_tlbEntry(4 downto 0)) when (TLBWI = '1') else
                       std_logic_vector(COP0_1_RANDOM(4 downto 0));
   
   iTLBMEM : entity mem.RamMLAB
	GENERIC MAP 
   (
      width      => 101,
      widthad    => 5
	)
	PORT MAP (
      inclock    => clk93,
      wren       => TLBMEM_writeEnable,
      data       => TLBMEM_writeData,
      wraddress  => TLBMEM_writeAddr,
      rdaddress  => TLBMEM_readAddr,
      q          => TLBMEM_readData
	);
   
   TLBMEM_readAddr <= std_logic_vector(COP0_0_INDEX_tlbEntry(4 downto 0)) when (TLBState = TLBIDLE) else
                      std_logic_vector(TLB_readAddr);
   
   TLBREAD_global   <= TLBMEM_readData(0);           
   TLBREAD_valid0   <= TLBMEM_readData(1);           
   TLBREAD_valid1   <= TLBMEM_readData(2);           
   TLBREAD_dirty0   <= TLBMEM_readData(3);           
   TLBREAD_dirty1   <= TLBMEM_readData(4);           
   TLBREAD_cache0   <= unsigned(TLBMEM_readData( 7 downto  5));
   TLBREAD_cache1   <= unsigned(TLBMEM_readData(10 downto  8));
   TLBREAD_phyAddr0 <= unsigned(TLBMEM_readData(30 downto 11));
   TLBREAD_phyAddr1 <= unsigned(TLBMEM_readData(50 downto 31));
   TLBREAD_pageMask <= unsigned(TLBMEM_readData(62 downto 51));
   TLBREAD_virtAddr <= unsigned(TLBMEM_readData(89 downto 63));
   TLBREAD_ASID     <= unsigned(TLBMEM_readData(97 downto 90));
   TLBREAD_region   <= unsigned(TLBMEM_readData(99 downto 98));
   TLBREAD_random   <= TLBMEM_readData(100);
   
   icpu_TLB_instr : entity work.cpu_TLB_instr
   port map
   (
      clk93                => clk93,    
      ce                   => ce,
      reset                => reset,   

      RANDOMMISS           => RANDOMMISS,
                                       
      TLBInvalidate        => TLBInvalidate,          
                                       
      TLB_Req              => TLB_instrReq,   
      TLB_ss_load          => TLB_ss_load,
      TLB_AddrIn           => TLB_instrAddrIn, 
      TLB_useCache         => TLB_instrUseCache,  
      TLB_Stall            => TLB_instrStall,  
      TLB_UnStall          => TLB_instrUnStall,
      TLB_AddrOutFound     => TLB_instrAddrOutFound,
      TLB_AddrOutLookup    => TLB_instrAddrOutLookup,
      
      TLB_ExcRead          => TLB_ExcInstrRead,
      TLB_ExcMiss          => TLB_ExcInstrMiss, 
      
      TLB_ClearEna         => TLB_InstrClearEna,  
      TLB_ClearIndex       => TLB_InstrClearIndex,
      
      TLB_fetchReq         => TLB_Instr_fetchReq,          
      TLB_fetchAddrIn      => TLB_Instr_fetchAddrIn,     
      TLB_fetchDone        => TLB_Instr_fetchDone,       
      TLB_fetchExcInvalid  => TLB_fetchExcInvalid,  
      TLB_fetchExcNotFound => TLB_fetchExcNotFound,
      TLB_fetchCached      => TLB_fetchCached,     
      TLB_fetchRandom      => TLB_fetchRandom, 
      TLB_fetchSource      => TLB_fetchSource,
      TLB_fetchAddrOut     => TLB_fetchAddrOut 
   );
   
   icpu_TLB_data : entity work.cpu_TLB_data
   port map
   (
      clk93                => clk93,          
      reset                => reset,    

      DISABLE_DTLBMINI     => DISABLE_DTLBMINI,
                                       
      TLBInvalidate        => TLBInvalidate,                 
                                       
      TLB_Req              => TLB_dataReq,  
      TLB_IsWrite          => TLB_dataIsWrite,     
      TLB_AddrIn           => TLB_dataAddrIn, 
      TLB_useCacheFound    => TLB_dataUseCacheFound, 
      TLB_useCacheLookup   => TLB_dataUseCacheLookup, 
      TLB_Stall            => TLB_dataStall,  
      TLB_UnStall          => TLB_dataUnStall,
      TLB_AddrOutFound     => TLB_dataAddrOutFound,
      TLB_AddrOutLookup    => TLB_dataAddrOutLookup,
      
      TLB_ExcRead          => TLB_ExcDataRead, 
      TLB_ExcWrite         => TLB_ExcDataWrite,
      TLB_ExcDirty         => TLB_ExcDataDirty,
      TLB_ExcMiss          => TLB_ExcDataMiss, 
      
      TLB_fetchReq         => TLB_Data_fetchReq,          
      TLB_fetchAddrIn      => TLB_Data_fetchAddrIn,     
      TLB_fetchDone        => TLB_Data_fetchDone,       
      TLB_fetchExcInvalid  => TLB_fetchExcInvalid, 
      TLB_fetchExcDirty    => TLB_fetchExcDirty,   
      TLB_fetchExcNotFound => TLB_fetchExcNotFound,
      TLB_fetchCached      => TLB_fetchCached,     
      TLB_fetchDirty       => TLB_fetchDirty,     
      TLB_fetchSource      => TLB_fetchSource, 
      TLB_fetchAddrOut     => TLB_fetchAddrOut 
   );
   
   -- synthesis translate_off
   process (clk93)
   begin
      if (rising_edge(clk93)) then
         if (TLBMEM_writeEnable = '1') then
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).global   <= TLBMEM_writeData(0);           
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).valid0   <= TLBMEM_writeData(1);           
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).valid1   <= TLBMEM_writeData(2);           
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).dirty0   <= TLBMEM_writeData(3);           
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).dirty1   <= TLBMEM_writeData(4);           
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).cache0   <= unsigned(TLBMEM_writeData( 7 downto  5));
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).cache1   <= unsigned(TLBMEM_writeData(10 downto  8));
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).phyAddr0 <= unsigned(TLBMEM_writeData(30 downto 11));
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).phyAddr1 <= unsigned(TLBMEM_writeData(50 downto 31));
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).pageMask <= unsigned(TLBMEM_writeData(62 downto 51));
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).virtAddr <= unsigned(TLBMEM_writeData(89 downto 63));
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).ASID     <= unsigned(TLBMEM_writeData(97 downto 90));
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).region   <= unsigned(TLBMEM_writeData(99 downto 98));
            TLBENTRYS(to_integer(unsigned(TLBMEM_writeAddr))).random   <= TLBMEM_writeData(100);
         end if;
      end if;
   end process;
-- synthesis translate_on
   
--##############################################################
--############################### savestates
--##############################################################

   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         if (SS_reset = '1') then
         
            for i in 0 to 31 loop
               ss_in(i) <= (others => '0');
            end loop;
            
            ss_in(12)(31 downto 0) <= x"3450FF04"; --cop12
            ss_in(16)(31 downto 0) <= x"7006E460"; --cop16
            
         elsif (SS_wren_CPU = '1' and SS_Adr >= 64 and SS_Adr < 96) then
            ss_in(to_integer(SS_Adr(4 downto 0))) <= unsigned(SS_DataWrite);
         end if;
      
      end if;
   end process;


   -- synthesis translate_off
   cop0_export(0)(5 downto 0)    <= COP0_0_INDEX_tlbEntry;
   cop0_export(0)(31)            <= COP0_0_INDEX_probefailure;
   
   cop0_export(1)(5 downto 0)    <= COP0_1_RANDOM;
   
   cop0_export(2)(29 downto 6)   <= COP0_2_ENTRYLO0_phyAdr;
   cop0_export(2)(5 downto 3)    <= COP0_2_ENTRYLO0_cache; 
   cop0_export(2)(2)             <= COP0_2_ENTRYLO0_dirty; 
   cop0_export(2)(1)             <= COP0_2_ENTRYLO0_valid; 
   cop0_export(2)(0)             <= COP0_2_ENTRYLO0_global;
   
   cop0_export(3)(29 downto 6)   <= COP0_3_ENTRYLO1_phyAdr;
   cop0_export(3)(5 downto 3)    <= COP0_3_ENTRYLO1_cache; 
   cop0_export(3)(2)             <= COP0_3_ENTRYLO1_dirty; 
   cop0_export(3)(1)             <= COP0_3_ENTRYLO1_valid; 
   cop0_export(3)(0)             <= COP0_3_ENTRYLO1_global;
   
   cop0_export(4)(63 downto 23)  <= COP0_4_CONTEXT_PTE;
   cop0_export(4)(22 downto  4)  <= COP0_4_CONTEXT_BADVPN;
   cop0_export(4)( 3 downto  0)  <= (others => '0');
   
   cop0_export(5)(24 downto 13)  <= COP0_5_PAGEMASK;
   cop0_export(6)(5 downto 0)    <= COP0_6_WIRED;
   cop0_export(8)                <= COP0_8_BADVIRTUALADDRESS;
   cop0_export(9)(31 downto 0)   <= COP0_9_COUNT(32 downto 1);
   
   cop0_export(10)(7 downto 0)   <= COP0_10_ENTRYHI_addressSpaceID;
   cop0_export(10)(39 downto 13) <= COP0_10_ENTRYHI_virtualAddress;
   cop0_export(10)(63 downto 62) <= COP0_10_ENTRYHI_region;
   
   cop0_export(11)(31 downto 0)  <= COP0_11_COMPARE;
   
   cop0_export(12)(0)            <= COP0_12_SR_interruptEnable;    
   cop0_export(12)(1)            <= COP0_12_SR_exceptionLevel;     
   cop0_export(12)(2)            <= COP0_12_SR_errorLevel;        
   cop0_export(12)(4 downto 3)   <= COP0_12_SR_privilegeMode;      
   cop0_export(12)(5)            <= COP0_12_SR_userExtendedAddr;   
   cop0_export(12)(6)            <= COP0_12_SR_supervisorAddr;     
   cop0_export(12)(7)            <= COP0_12_SR_kernelExtendedAddr; 
   cop0_export(12)(15 downto 8)  <= COP0_12_SR_interruptMask;     
   cop0_export(12)(16)           <= COP0_12_SR_de;                 
   cop0_export(12)(17)           <= COP0_12_SR_ce;                 
   cop0_export(12)(18)           <= COP0_12_SR_condition;          
   cop0_export(12)(20)           <= COP0_12_SR_softReset;          
   cop0_export(12)(21)           <= COP0_12_SR_tlbShutdown;      
   cop0_export(12)(22)           <= COP0_12_SR_vectorLocation;     
   cop0_export(12)(24)           <= COP0_12_SR_instructionTracing; 
   cop0_export(12)(25)           <= COP0_12_SR_reverseEndian;      
   cop0_export(12)(26)           <= COP0_12_SR_floatingPointMode;  
   cop0_export(12)(27)           <= COP0_12_SR_lowPowerMode;       
   cop0_export(12)(28)           <= COP0_12_SR_enable_cop0;
   cop0_export(12)(29)           <= COP0_12_SR_enable_cop1;
   cop0_export(12)(30)           <= COP0_12_SR_enable_cop2;
   cop0_export(12)(31)           <= COP0_12_SR_enable_cop3;
   
   cop0_export(13)(6 downto 2)   <= COP0_13_CAUSE_exceptionCode;   
   cop0_export(13)(15 downto 8)  <= COP0_13_CAUSE_interruptPending;   
   cop0_export(13)(29 downto 28) <= COP0_13_CAUSE_coprocessorError;   
   cop0_export(13)(31)           <= COP0_13_CAUSE_branchDelay;   
   
   cop0_export(14)               <= COP0_14_EPC;
   cop0_export(15)(11 downto 0)  <= x"B22";
   
   cop0_export(16)(1 downto 0)   <= COP0_16_CONFIG_cacheAlgoKSEG0;
   cop0_export(16)(3 downto 2)   <= COP0_16_CONFIG_cu;   
   cop0_export(16)(14 downto 4)  <= "11001000110";
   cop0_export(16)(15)           <= COP0_16_CONFIG_bigEndian;
   cop0_export(16)(23 downto 16) <= "00000110"; 
   cop0_export(16)(27 downto 24) <= COP0_16_CONFIG_sysadWBPattern; 
   cop0_export(16)(30 downto 28) <= COP0_16_CONFIG_systemClockRatio;
   
   cop0_export(17)               <= COP0_17_LOADLINKEDADDRESS;    
   cop0_export(18)(31 downto 0)  <= COP0_18_WATCHLO;    
   cop0_export(19)(3 downto 0)   <= COP0_19_WATCHHI;    
   
   cop0_export(20)(63 downto 33) <= COP0_20_XCONTEXT_PTE;    
   cop0_export(20)(32 downto 31) <= COP0_20_XCONTEXT_Region;    
   cop0_export(20)(30 downto  4) <= COP0_20_XCONTEXT_BadVPN;   
   
   cop0_export(26)(7 downto 0)   <= COP0_26_PARITYERROR;       
   
   cop0_export(28)(7 downto 6)   <= COP0_28_TAGLO_primaryCacheState;
   cop0_export(28)(27 downto 8)  <= COP0_28_TAGLO_physicalAddress;
   
   cop0_export(30)               <= COP0_30_EPCERROR;
   -- synthesis translate_on

end architecture;
