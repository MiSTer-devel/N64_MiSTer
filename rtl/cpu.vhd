library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   

library mem;
use work.pFunctions.all;
use work.pexport.all;

entity cpu is
   port 
   (
      clk1x                 : in  std_logic;
      clk93                 : in  std_logic;
      clk2x                 : in  std_logic;
      ce_1x                 : in  std_logic;
      ce_93                 : in  std_logic;
      reset_1x              : in  std_logic;
      reset_93              : in  std_logic;
      
      INSTRCACHEON          : in  std_logic;
      DATACACHEON           : in  std_logic;
      DATACACHESLOW         : in  std_logic_vector(3 downto 0); 
      DATACACHEFORCEWEB     : in  std_logic;
      DATACACHETLBON        : in  std_logic;
      RANDOMMISS            : in  unsigned(3 downto 0);
      DISABLE_BOOTCOUNT     : in  std_logic;
      DISABLE_DTLBMINI      : in  std_logic;

      irqRequest            : in  std_logic;
      cpuPaused             : in  std_logic;
      
      error_instr           : out std_logic := '0';
      error_stall           : out std_logic := '0';
      error_FPU             : out std_logic := '0';
      error_exception       : out std_logic := '0';
      error_fifo            : out std_logic := '0';
      error_TLB             : out std_logic := '0';
      
      mem_request           : out std_logic := '0';
      mem_rnw               : out std_logic := '0'; 
      mem_address           : buffer unsigned(31 downto 0) := (others => '0'); 
      mem_req64             : out std_logic := '0'; 
      mem_size              : out unsigned(2 downto 0) := (others => '0');
      mem_writeMask         : out std_logic_vector(7 downto 0) := (others => '0'); 
      mem_dataWrite         : out std_logic_vector(63 downto 0) := (others => '0');
      mem_dataRead          : in  std_logic_vector(63 downto 0); 
      mem_done              : in  std_logic;
      rdram_granted2x       : in  std_logic;
      rdram_done            : in  std_logic;
      ddr3_DOUT             : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY       : in  std_logic;
      
      ram_done              : in  std_logic;
      ram_rnw               : in  std_logic;
      ram_dataRead          : in  std_logic_vector(31 downto 0); 
      
-- synthesis translate_off
      cpu_done              : out std_logic := '0'; 
      cpu_export            : out cpu_export_type := export_init;
-- synthesis translate_on
      
      SS_reset              : in  std_logic;
      loading_savestate     : in  std_logic;
      SS_DataWrite          : in  std_logic_vector(63 downto 0);
      SS_Adr                : in  unsigned(11 downto 0);
      SS_wren_CPU           : in  std_logic;
      SS_rden_CPU           : in  std_logic;
      SS_DataRead_CPU       : out std_logic_vector(63 downto 0);
      SS_idle               : out std_logic
   );
end entity;

architecture arch of cpu is
     
   -- register file
   signal regs_address_a               : std_logic_vector(4 downto 0);
   signal regs_data_a                  : std_logic_vector(63 downto 0);
   signal regs_wren_a                  : std_logic;
   signal regs1_address_b              : std_logic_vector(4 downto 0);
   signal regs1_q_b                    : std_logic_vector(63 downto 0);
   signal regs2_address_b              : std_logic_vector(4 downto 0);
   signal regs2_q_b                    : std_logic_vector(63 downto 0);  

   -- FPU register file
   signal FPUregs_address_a            : std_logic_vector(4 downto 0);
   signal FPUregs_data_a               : std_logic_vector(63 downto 0);
   signal FPUregs_wren_a               : std_logic_vector(1 downto 0);
   signal FPUregs1_address_b           : std_logic_vector(4 downto 0);
   signal FPUregs1_q_b                 : std_logic_vector(63 downto 0);
   signal FPUregs2_address_b           : std_logic_vector(4 downto 0);
   signal FPUregs2_q_b                 : std_logic_vector(63 downto 0);  

   signal FPUWriteTarget               : unsigned(4 downto 0) := (others => '0');
   signal FPUWriteData                 : unsigned(63 downto 0) := (others => '0');
   signal FPUWriteEnable               : std_logic := '0';   
   signal FPUWriteMask                 : std_logic_vector(1 downto 0) := (others => '0');
   
   -- other register
   signal PC                           : unsigned(63 downto 0) := (others => '0');
   signal hi                           : unsigned(63 downto 0) := (others => '0');
   signal lo                           : unsigned(63 downto 0) := (others => '0');
          
   -- memory interface
   signal memoryMuxStage4              : std_logic := '0';
   signal mem1_request_latched         : std_logic := '0';
   signal mem1_cache_latched           : std_logic := '0';
   
   signal mem_done_1                   : std_logic := '0';
   signal mem_finished_instr           : std_logic := '0';
   signal mem_finished_read            : std_logic := '0';
   signal mem_finished_dataRead        : std_logic_vector(63 downto 0);
          
   signal writefifo_Din                : std_logic_vector(107 downto 0);
   signal writefifo_wr                 : std_logic := '0';
   signal writefifo_Dout               : std_logic_vector(107 downto 0);
   signal writefifo_Rd                 : std_logic := '0';
   signal writefifo_Empty              : std_logic;
   signal writefifo_block              : std_logic;
   signal writefifo_cnt                : integer range 0 to 7;
          
   signal writefifo_rd_1x              : std_logic := '0';
   signal writefifo_rd_93              : std_logic := '0';
          
   -- common   
   type t_memstate is
   (
      MEMSTATE_IDLE,
      MEMSTATE_BUSY
   );
   signal memstate : t_memstate := MEMSTATE_IDLE;                 
   
   signal stallNew4                    : std_logic := '0';
               
   signal stall1                       : std_logic := '0';
   signal stall2                       : std_logic := '0';
   signal stall3                       : std_logic := '0';
   signal stall4                       : std_logic := '0';
   signal stall                        : unsigned(4 downto 0) := (others => '0');
   signal stall4Masked                 : unsigned(4 downto 0) := (others => '0');
                     
   signal exception                    : std_logic;
   signal exceptionStage1              : std_logic;
   signal exceptionNew3                : std_logic := '0';
   signal exceptionNewPC               : std_logic;
   signal exceptionFPU                 : std_logic;
   signal exception_COP                : unsigned(1 downto 0);
   
   signal exception_SR                 : unsigned(31 downto 0) := (others => '0');
   signal exception_CAUSE              : unsigned(31 downto 0) := (others => '0');
   signal exception_EPC                : unsigned(31 downto 0) := (others => '0');
   signal exception_JMP                : unsigned(31 downto 0) := (others => '0');
   
   signal exceptionCode                : unsigned(3 downto 0);
   signal exceptionCode_3              : unsigned(3 downto 0);   
   signal exceptionInstr               : unsigned(1 downto 0);
   signal exception_PC                 : unsigned(31 downto 0);
   signal exception_branch             : std_logic;
   signal exception_brslot             : std_logic;
   signal exception_JMPnext            : unsigned(31 downto 0);     
               
   signal opcode0                      : unsigned(31 downto 0) := (others => '0');
   signal opcode1                      : unsigned(31 downto 0) := (others => '0');
-- synthesis translate_off
   signal opcode2                      : unsigned(31 downto 0) := (others => '0');
   signal opcode3                      : unsigned(31 downto 0) := (others => '0');
   signal opcode4                      : unsigned(31 downto 0) := (others => '0');
-- synthesis translate_on  
  
   signal PCold0                       : unsigned(63 downto 0) := (others => '0');
   signal PCold1                       : unsigned(63 downto 0) := (others => '0');
   
-- synthesis translate_off
   signal PCold2                       : unsigned(63 downto 0) := (others => '0');
   signal PCold3                       : unsigned(63 downto 0) := (others => '0');
   signal PCold4                       : unsigned(63 downto 0) := (others => '0');
   
   signal hi_1                         : unsigned(63 downto 0) := (others => '0');
   signal lo_1                         : unsigned(63 downto 0) := (others => '0');
   signal hi_2                         : unsigned(63 downto 0) := (others => '0');
   signal lo_2                         : unsigned(63 downto 0) := (others => '0');
-- synthesis translate_on
   
   signal value1                       : unsigned(63 downto 0) := (others => '0');
   signal value2                       : unsigned(63 downto 0) := (others => '0');
   signal executeForwardValue1         : std_logic := '0';
   signal executeForwardValue2         : std_logic := '0';
   signal writebackForwardValue1       : std_logic := '0';
   signal writebackForwardValue2       : std_logic := '0';
               
   -- stage 1          
   -- cache
   signal FetchAddr                    : unsigned(63 downto 0) := (others => '0'); 
   signal FetchAddr1                   : unsigned(63 downto 0) := (others => '0'); 
   signal FetchAddr2                   : unsigned(63 downto 0) := (others => '0'); 
   signal FetchAddrTLBMuxed1           : unsigned(31 downto 0) := (others => '0'); 
   signal FetchAddrTLBMuxed2           : unsigned(31 downto 0) := (others => '0'); 
   signal FetchAddrSelect              : std_logic;
   signal fetchCache                   : std_logic;
   signal useCached_data               : std_logic := '0';
   
   signal fill_addrTag                 : unsigned(31 downto 0) := (others => '0'); 
   signal instrcache_request           : std_logic;
   signal instrcache_active            : std_logic := '0';
   signal instrcache_hit               : std_logic;
   signal instrcache_data              : std_logic_vector(31 downto 0);
   signal instrcache_fill              : std_logic := '0';
   signal instrcache_fill_done         : std_logic;
   signal cache_commandEnableI         : std_logic;
   signal cache_commandEnableD         : std_logic;
   
   signal cacheHitLast                 : std_logic := '0';
   
   -- regs           
   signal fetchReady                   : std_logic := '0';
   
   -- wires   
   signal mem1_request                 : std_logic := '0';
   signal mem1_cacherequest            : std_logic := '0';
   signal mem1_address                 : unsigned(31 downto 0) := (others => '0'); 
            
   -- stage 2           
   --regs      
   signal decodeNew                    : std_logic := '0';
   signal decodeResultWriteEnable      : std_logic := '0';
   signal decode_irq                   : std_logic := '0';
   signal blockIRQ                     : std_logic := '0';
   signal decodeImmData                : unsigned(15 downto 0) := (others => '0');
   signal decodeSource1                : unsigned(4 downto 0) := (others => '0');
   signal decodeSource2                : unsigned(4 downto 0) := (others => '0');
   signal decodeValue1                 : unsigned(63 downto 0) := (others => '0');
   signal decodeValue2                 : unsigned(63 downto 0) := (others => '0');
   signal decodeShamt                  : unsigned(5 downto 0) := (others => '0');
   signal decodeRD                     : unsigned(4 downto 0) := (others => '0');
   signal decodeTarget                 : unsigned(4 downto 0) := (others => '0');
   signal decodeJumpTarget             : unsigned(25 downto 0) := (others => '0');
   signal decodeUseImmidateValue2      : std_logic := '0';
   signal decodeShiftSigned            : std_logic := '0';
   signal decodeShift32                : std_logic := '0';
   signal decodeShiftAmountType        : std_logic_vector(1 downto 0) := "00";
   signal decodeFPUSource1             : unsigned(4 downto 0) := (others => '0');
   signal decodeFPUSource2             : unsigned(4 downto 0) := (others => '0');
   signal decodeFPUValue1              : unsigned(63 downto 0) := (others => '0');
   signal decodeFPUValue2              : unsigned(63 downto 0) := (others => '0');
   signal decodeFPUForwardUse          : std_logic := '0';
   signal decodeFPUTarget              : unsigned(4 downto 0) := (others => '0');
   signal decodeFPUCommandEnable       : std_logic := '0';
   signal decodeFPUTransferEnable      : std_logic := '0';
   signal decodeFPUMULS                : std_logic := '0';
   signal decodeFPUMULD                : std_logic := '0';
   signal decodeExcCode                : unsigned(3 downto 0); 
   signal decodeExcCOP                 : unsigned(1 downto 0); 
   signal decodecalcMULT               : std_logic := '0';
   signal decodecalcMULTU              : std_logic := '0';
   signal decodecalcDMULT              : std_logic := '0';
   signal decodecalcDMULTU             : std_logic := '0';
   signal decodecalcDIV                : std_logic := '0';
   signal decodecalcDIVU               : std_logic := '0';
   signal decodecalcDDIV               : std_logic := '0';
   signal decodecalcDDIVU              : std_logic := '0';
   signal decodehiUpdate               : std_logic := '0';
   signal decodeloUpdate               : std_logic := '0';
   signal decodeMemWriteEnable         : std_logic := '0';
   signal decodeMemWriteLL             : std_logic := '0';
   signal decodeMemReadEnable          : std_logic := '0';
   signal decodeMem64Bit               : std_logic := '0';
   signal decodeCacheEnable            : std_logic := '0';
   signal decodeSetLL                  : std_logic := '0';
   signal decodeResetLL                : std_logic := '0';
   signal decodeERET                   : std_logic := '0';
   signal decodeCOP0ReadEnable         : std_logic := '0';
   signal decodeCOP0WriteEnable        : std_logic := '0';
   signal decodeCOP0Register           : unsigned(4 downto 0);
   signal decodeCOP1ReadEnable         : std_logic := '0';
   signal decodeCOP2ReadEnable         : std_logic := '0';
   signal decodeCOP2WriteEnable        : std_logic := '0';
   signal decodeCOP64                  : std_logic := '0';
   signal decodeTLBR                   : std_logic := '0';
   signal decodeTLBWI                  : std_logic := '0';
   signal decodeTLBWR                  : std_logic := '0';
   signal decodeTLBP                   : std_logic := '0';
   
   type t_decodeBitFuncType is
   (
      BITFUNC_SIGNED,
      BITFUNC_UNSIGNED,
      BITFUNC_IMM_SIGNED,
      BITFUNC_IMM_UNSIGNED,
      BITFUNC_SC
   );
   signal decodeBitFuncType : t_decodeBitFuncType;    

   type t_decodeBranchType is
   (
      BRANCH_OFF,
      BRANCH_ALWAYS_REG,
      BRANCH_JUMPIMM,
      BRANCH_BRANCH_BLTZ,
      BRANCH_BRANCH_BGEZ, 
      BRANCH_BRANCH_BEQ,
      BRANCH_BRANCH_BNE,
      BRANCH_BRANCH_BLEZ,
      BRANCH_BRANCH_BGTZ,
      BRANCH_BC1,
      BRANCH_ERET
   );
   signal decodeBranchType    : t_decodeBranchType;   
   signal decodeBranchLikely  : std_logic;

   type t_decodeResultMux is
   (
      RESULTMUX_SHIFTLEFT, 
      RESULTMUX_SHIFTRIGHT,
      RESULTMUX_ADD,       
      RESULTMUX_PC,        
      RESULTMUX_HI,        
      RESULTMUX_LO,        
      RESULTMUX_SUB,       
      RESULTMUX_AND,       
      RESULTMUX_OR,        
      RESULTMUX_XOR,       
      RESULTMUX_NOR,       
      RESULTMUX_BIT,
      RESULTMUX_FPU,      
      RESULTMUX_LUI
   );
   signal decodeResultMux : t_decodeResultMux;   
   signal decodeResult32               : std_logic := '0';
   
   type t_decodeExcType is
   (
      EXCTYPE_NONE,
      EXCTYPE_DECODE, 
      EXCTYPE_PC,
      EXCTYPE_ADDRH,
      EXCTYPE_ADDRW,
      EXCTYPE_ADDRD,
      EXCTYPE_ADD,
      EXCTYPE_DADD,
      EXCTYPE_ADDI,
      EXCTYPE_DADDI,
      EXCTYPE_SUB,
      EXCTYPE_DSUB,
      EXCTYPE_TRAPU0, 
      EXCTYPE_TRAPU1, 
      EXCTYPE_TRAPS0, 
      EXCTYPE_TRAPS1, 
      EXCTYPE_TRAPE0, 
      EXCTYPE_TRAPE1, 
      EXCTYPE_TRAPIU0,
      EXCTYPE_TRAPIU1,
      EXCTYPE_TRAPIS0,
      EXCTYPE_TRAPIS1,
      EXCTYPE_TRAPIE0,
      EXCTYPE_TRAPIE1
   );
   signal decodeExcType : t_decodeExcType := EXCTYPE_NONE;    
   
   type t_decodeMemWriteType is
   (
      MEMWRITETYPE_BYTE,
      MEMWRITETYPE_HALF,
      MEMWRITETYPE_WORD,
      MEMWRITETYPE_SWL,
      MEMWRITETYPE_SWR,
      MEMWRITETYPE_DWORD,
      MEMWRITETYPE_SDL,
      MEMWRITETYPE_SDR,
      MEMWRITETYPE_COP1L,
      MEMWRITETYPE_COP1H,
      MEMWRITETYPE_COP1D
   );
   signal decodeMemWriteType : t_decodeMemWriteType := MEMWRITETYPE_BYTE;    
   
   type CPU_LOADTYPE is
   (
      LOADTYPE_SBYTE,
      LOADTYPE_SWORD,
      LOADTYPE_LEFT,
      LOADTYPE_DWORD,
      LOADTYPE_DWORDU,
      LOADTYPE_BYTE,
      LOADTYPE_WORD,
      LOADTYPE_RIGHT,
      LOADTYPE_QWORD,
      LOADTYPE_LEFT64,
      LOADTYPE_RIGHT64
   );
   signal decodeLoadType               : CPU_LOADTYPE;
   
   -- wires
   signal opcodeCacheMuxed             : unsigned(31 downto 0) := (others => '0');
   
   signal decImmData                   : unsigned(15 downto 0);
   signal decSource1                   : unsigned(4 downto 0);
   signal decSource2                   : unsigned(4 downto 0);
   signal decOP                        : unsigned(5 downto 0);
   signal decFunct                     : unsigned(5 downto 0);
   signal decShamt                     : unsigned(4 downto 0);
   signal decRD                        : unsigned(4 downto 0);
   signal decTarget                    : unsigned(4 downto 0);
   signal decJumpTarget                : unsigned(25 downto 0);
   signal decFPUSource1                : unsigned(4 downto 0);
   signal decFPUSource2                : unsigned(4 downto 0);
   signal decRequiresFPUreg1           : std_logic; 
   signal decRequiresFPUreg2           : std_logic;
   signal decFPUForwardUse             : std_logic;
            
   -- stage 3   
   signal value2_muxedSigned           : unsigned(63 downto 0);
   signal value2_muxedLogical          : unsigned(63 downto 0);
   signal calcResult_add               : unsigned(63 downto 0);
   signal calcResult_sub               : unsigned(63 downto 0);
   signal calcResult_and               : unsigned(63 downto 0);
   signal calcResult_or                : unsigned(63 downto 0);
   signal calcResult_xor               : unsigned(63 downto 0);
   signal calcResult_nor               : unsigned(63 downto 0);
   signal calcMemAddr                  : unsigned(63 downto 0);
   
   signal calcResult_lesserSigned      : std_logic;
   signal calcResult_lesserUnSigned    : std_logic;
   signal calcResult_lesserIMMSigned   : std_logic;
   signal calcResult_lesserIMMUnsigned : std_logic;
   signal calcResult_equal             : std_logic;
   signal calcResult_bit               : unsigned(63 downto 0);
   
   signal executeShamt                 : unsigned(5 downto 0);
   signal shiftValue                   : signed(64 downto 0);
   signal calcResult_shiftL            : unsigned(63 downto 0);
   signal calcResult_shiftR            : unsigned(63 downto 0);
   
   signal cmpEqual                     : std_logic;
   signal cmpNegative                  : std_logic;
   signal cmpZero                      : std_logic;
   signal PCnext                       : unsigned(63 downto 0) := (others => '0');
   signal PCnextBranch                 : unsigned(63 downto 0) := (others => '0');
   
   signal resultDataMuxed              : unsigned(63 downto 0);
   signal resultDataMuxed64            : unsigned(63 downto 0);
   
   --regs         
   signal executeNew                   : std_logic := '0';
   signal executeIgnoreNext            : std_logic := '0';
   signal executeStallFromMEM          : std_logic := '0';
   signal resultWriteEnable            : std_logic := '0';
   signal executeBranchdelaySlot       : std_logic := '0';
   signal resultTarget                 : unsigned(4 downto 0) := (others => '0');
   signal resultData                   : unsigned(63 downto 0) := (others => '0');
   signal executeMem64Bit              : std_logic := '0';
   signal executeMemWriteEnable        : std_logic := '0';
   signal executeMemUseCache           : std_logic := '0';
   signal executeMemWriteData          : unsigned(63 downto 0) := (others => '0');
   signal executeMemWriteMask          : std_logic_vector(7 downto 0) := (others => '0');
   signal executeMemAddress            : unsigned(31 downto 0) := (others => '0');
   signal executeMemReadEnable         : std_logic := '0';
   signal executeMemReadLastData       : unsigned(63 downto 0) := (others => '0');
   signal executeCOP0WriteEnable       : std_logic := '0';
   signal executeCOP0ReadEnable        : std_logic := '0';
   signal executeCOP0Register          : unsigned(4 downto 0) := (others => '0');
   signal executeCOP0WriteValue        : unsigned(63 downto 0) := (others => '0');
   signal executeCOP2WriteEnable       : std_logic := '0';
   signal executeCOP2ReadEnable        : std_logic := '0';
   signal executeCOP64                 : std_logic := '0';
   signal executeSetLL                 : std_logic := '0';
   signal executeLLfromTLB             : std_logic := '0';
   signal executeLoadType              : CPU_LOADTYPE;
   signal executeICacheEnable          : std_logic := '0';
   signal executeDCacheEnable          : std_logic := '0';
   signal executeCacheCommand          : unsigned(4 downto 0) := (others => '0');
   signal executeCOP1Target            : unsigned(4 downto 0) := (others => '0');
   signal executeCOP1ReadEnable        : std_logic := '0';
   signal execute_unstallFPUForward    : std_logic := '0';
   signal execute_ERET                 : std_logic := '0';
   signal execute_TLBR                 : std_logic := '0';
   signal execute_TLBWI                : std_logic := '0';
   signal execute_TLBWR                : std_logic := '0';
   signal execute_TLBP                 : std_logic := '0';

   signal hiloWait                     : integer range 0 to 69;
   
   signal llBit                        : std_logic := '0';

   --wires
   signal EXEIgnoreNext                : std_logic := '0';
   signal EXEBranchdelaySlot           : std_logic := '0';
   signal EXECOPBranchDelaySlot        : std_logic := '0';
   signal EXEBranchTaken               : std_logic := '0';
   signal EXEMemWriteData              : unsigned(63 downto 0) := (others => '0');
   signal EXEMemWriteMask              : std_logic_vector(7 downto 0) := (others => '0');
   signal EXECOP0WriteValue            : unsigned(63 downto 0) := (others => '0');
   signal EXECacheAddr                 : unsigned(31 downto 0);
   signal EXEExceptionMem              : std_logic;
   signal EXETLBMapped                 : std_logic;
   signal EXETLBDataAccess             : std_logic;
   
   --MULT/DIV
   type CPU_HILOCALC is
   (
      HILOCALC_MULT, 
      HILOCALC_MULTU,
      HILOCALC_DMULT,
      HILOCALC_DMULTU,
      HILOCALC_DIV,  
      HILOCALC_DIVU,
      HILOCALC_DDIV,  
      HILOCALC_DDIVU
   );
   signal hilocalc                     : CPU_HILOCALC;
   
   signal mulsign                      : std_logic;
   signal mul1                         : std_logic_vector(63 downto 0);
   signal mul2                         : std_logic_vector(63 downto 0);
   signal mulResult                    : std_logic_vector(127 downto 0);
   
   signal DIVstart                     : std_logic;
   signal DIVis32                      : std_logic;
   signal DIVdividend                  : signed(64 downto 0);
   signal DIVdivisor                   : signed(64 downto 0);
   signal DIVquotient                  : signed(64 downto 0);
   signal DIVremainder                 : signed(64 downto 0);     
         
   -- COP0
   signal eretPC                       : unsigned(63 downto 0) := (others => '0');
   signal exceptionPC                  : unsigned(63 downto 0) := (others => '0');
   signal COP0ReadValue                : unsigned(63 downto 0) := (others => '0');
   
   signal COP1_enable                  : std_logic;
   signal COP2_enable                  : std_logic;
   signal fpuRegMode                   : std_logic;
   signal privilegeMode                : unsigned(1 downto 0);
   signal bit64region                  : std_logic;
   signal irqTrigger                   : std_logic;
   signal TLBDone                      : std_logic;
   
   signal TLB_ss_load                  : std_logic;
   signal TLB_instrMapped              : std_logic;
   signal TLB_instrReq                 : std_logic;
   signal TLB_instrUseCache            : std_logic;
   signal TLB_instrStall               : std_logic;
   signal TLB_instrUnStall             : std_logic;
   signal TLB_instrAddrOutFound        : unsigned(31 downto 0);   
   signal TLB_instrAddrOutLookup       : unsigned(31 downto 0);   
   signal TLB_dataUseCacheFound        : std_logic;
   signal TLB_dataUseCacheLookup       : std_logic;
   signal TLB_dataStall                : std_logic;
   signal TLB_dataUnStall              : std_logic;
   signal TLB_dataAddrOutFound         : unsigned(31 downto 0);
   signal TLB_dataAddrOutLookup        : unsigned(31 downto 0);
   
   signal TagLo_Valid                  : std_logic;
   signal TagLo_Dirty                  : std_logic;
   signal TagLo_Addr                   : unsigned(19 downto 0);
   
   signal writeDatacacheTagEna         : std_logic;
   signal writeDatacacheTagValue       : unsigned(21 downto 0);

   -- COP1
   signal cop1_stage4_writeEnable      : std_logic := '0';
   signal cop1_stage4_writeMask        : std_logic_vector(1 downto 0) := (others => '0');
   signal cop1_stage4_data             : unsigned(63 downto 0) := (others => '0');
   signal cop1_stage4_target           : unsigned(4 downto 0) := (others => '0');

   signal FPU_CF                       : std_logic;
   signal FPU_command_ena              : std_logic := '0';
   signal FPU_command_done             : std_logic := '0';
   signal FPU_TransferEna              : std_logic := '0';
   signal FPU_TransferData             : unsigned(63 downto 0);

   -- COP2
   signal COP2Latch                    : unsigned(63 downto 0) := (others => '0');

   -- stage 4 
   -- reg      
   signal writebackNew                 : std_logic := '0';
   signal writebackStallFromMEM        : std_logic := '0';
   signal writebackTarget              : unsigned(4 downto 0) := (others => '0');
   signal writebackData                : unsigned(63 downto 0) := (others => '0');
   signal writebackWriteEnable         : std_logic := '0';
   signal writeback_UseCache           : std_logic := '0';
   signal writebackLoadType            : CPU_LOADTYPE;
   signal writebackReadAddress         : unsigned(31 downto 0) := (others => '0');
   signal writebackReadLastData        : unsigned(63 downto 0) := (others => '0');
   signal writeback_COP1_ReadEnable    : std_logic := '0'; 
   signal writeback_fifoStall          : std_logic := '0'; 
         
   -- wire     
   signal mem4_request                 : std_logic := '0';
   signal mem4_address                 : unsigned(31 downto 0) := (others => '0');
   signal mem4_req64                   : std_logic := '0';
   signal mem4_rnw                     : std_logic := '0';
   signal mem4_dataWrite               : std_logic_vector(63 downto 0) := (others => '0');    
   signal mem4_writeMask               : std_logic_vector(7 downto 0) := (others => '0');    
   
   signal read4_dataReadData           : unsigned(63 downto 0);
   signal read4_dataReadRot64          : unsigned(63 downto 0);
   signal read4_dataReadRot32          : unsigned(31 downto 0);
   signal read4_Addr                   : unsigned(31 downto 0);
   signal read4_oldData                : unsigned(63 downto 0);
   signal read4_cop1_readEna           : std_logic;
   signal read4_cop1_target            : unsigned(4 downto 0);
   signal read4_useLoadType            : CPU_LOADTYPE;
   signal read4_useTarget              : unsigned(4 downto 0);
   
   -- Cache
   signal DATACACHEON_intern           : std_logic := '0';
   signal DATACACHETLBON_intern        : std_logic := '0';
   signal datacache_request            : std_logic;
   signal datacache_active             : std_logic := '0';
   signal datacache_reqAddr            : unsigned(31 downto 0);
   signal datacache_readena            : std_logic;
   signal datacache_readbusy           : std_logic;
   signal datacache_readdone           : std_logic;
   signal datacache_addr               : unsigned(31 downto 0);   
   signal datacache_data_out           : std_logic_vector(63 downto 0);   
   signal datacache_writeena           : std_logic;
   signal datacache_writedone          : std_logic;
   signal datacache_CmdStall           : std_logic;
   signal datacache_CmdDone            : std_logic;
   
   signal datacache_wb_ena             : std_logic;
   signal datacache_wb_addr            : unsigned(31 downto 0);
   signal datacache_wb_data            : std_logic_vector(63 downto 0);
   
   -- savestates
   type t_ssarray is array(0 to 31) of std_logic_vector(63 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
   signal ss_out : t_ssarray := (others => (others => '0'));  

   signal regsSS_address_b             : std_logic_vector(4 downto 0) := (others => '0');
   signal regsSS_q_b                   : std_logic_vector(63 downto 0);
   signal regsSS_rden                  : std_logic := '0';
   
   signal ss_regs_loading              : std_logic := '0';
   signal ss_regs_load                 : std_logic := '0';
   signal ss_regs_addr                 : unsigned(4 downto 0);
   signal ss_regs_data                 : std_logic_vector(63 downto 0);   
   
   signal ss_FPUregs_load              : std_logic := '0';
   signal ss_FPUregs_addr              : unsigned(4 downto 0);
   signal ss_FPUregs_data              : std_logic_vector(63 downto 0);   
   
   -- debug
   --signal debugCnt                     : unsigned(31 downto 0);
   --signal debugSum                     : unsigned(31 downto 0);
   --signal debugTmr                     : unsigned(31 downto 0);
   --signal debugwrite                   : std_logic := '0';
   
-- synthesis translate_off
   signal stallcountNo                 : integer;
   signal stallcount1                  : integer;
   signal stallcount3                  : integer;
   signal stallcount4                  : integer;
   signal stallcountDMA                : integer;
-- synthesis translate_on
   
   signal debugStallcounter            : unsigned(12 downto 0);
   
   -- export
-- synthesis translate_off
   type tRegs is array(0 to 31) of unsigned(63 downto 0);
   signal regs                         : tRegs := (others => (others => '0'));
   signal FPUregs                      : tRegs := (others => (others => '0'));
   
   signal cop0_export                  : tExportRegs := (others => (others => '0'));
   signal cop0_export_1                : tExportRegs := (others => (others => '0'));
   signal csr_export                   : unsigned(24 downto 0) := (others => '0');
   signal csr_export_1                 : unsigned(24 downto 0) := (others => '0');
   signal csr_export_2                 : unsigned(24 downto 0) := (others => '0');
-- synthesis translate_on
   
begin 

   -- common
   stall        <= '0' & stall4 & stall3 & stall2 & stall1;
   
   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         writefifo_wr    <= '0';
         writefifo_Rd    <= '0';
         writefifo_rd_93 <= writefifo_rd_1x;
         
         if (reset_93 = '1') then
         
            mem1_request_latched  <= '0';
            writefifo_cnt         <= 0;
         
         else
         
            if (writefifo_rd_93 = '0' and writefifo_rd_1x = '1') then
               writefifo_Rd <= '1';
            end if;
         
            if (writefifo_wr = '1' and writefifo_Rd = '0') then
               writefifo_cnt <= writefifo_cnt + 1;
            end if;
            if (writefifo_Rd = '1' and writefifo_wr = '0') then
               writefifo_cnt <= writefifo_cnt - 1;
            end if;
            
            -- when stage 4 and stage 1 request at the same time, latch the stage 1 request and insert it into the fifo as soon as possible
            if (datacache_wb_ena = '1' or mem4_request = '1' or datacache_request = '1') then
               if (mem1_request = '1' or instrcache_request = '1') then
                  mem1_request_latched <= '1';
                  mem1_cache_latched   <= instrcache_request;
               end if;            
            end if;

            -- only 1 action from stage 4 can be active at any time
            if (datacache_wb_ena = '1') then
               writefifo_wr                 <= '1';
               writefifo_Din( 63 downto  0) <= datacache_wb_data;
               writefifo_Din( 95 downto 64) <= std_logic_vector(datacache_wb_addr);
               writefifo_Din(103 downto 96) <= x"FF";
               writefifo_Din(104)           <= '1';
               writefifo_Din(105)           <= '0';
               writefifo_Din(106)           <= '1';
               writefifo_Din(107)           <= '0';
            elsif (mem4_request = '1' and mem4_rnw = '0') then
               writefifo_wr                 <= '1';
               writefifo_Din( 63 downto  0) <= mem4_dataWrite;
               writefifo_Din( 95 downto 64) <= std_logic_vector(mem4_address);
               writefifo_Din(103 downto 96) <= mem4_writeMask;
               writefifo_Din(104)           <= '1';
               writefifo_Din(105)           <= '0';
               writefifo_Din(106)           <= mem4_req64;
               writefifo_Din(107)           <= '0';
            elsif (mem4_request = '1' or datacache_request = '1') then
               writefifo_wr                 <= '1';
               writefifo_Din( 95 downto 64) <= std_logic_vector(mem4_address);
               writefifo_Din(104)           <= '1';
               writefifo_Din(105)           <= '1';
               writefifo_Din(106)           <= mem4_req64;
               writefifo_Din(107)           <= datacache_request;
               if (datacache_request = '1') then
                  writefifo_Din( 95 downto 64) <= std_logic_vector(datacache_reqAddr(31 downto 4)) & "0000";
               end if;
            elsif (mem1_request = '1' or instrcache_request = '1') then
               writefifo_wr                 <= '1';
               writefifo_Din( 95 downto 64) <= std_logic_vector(mem1_address);
               writefifo_Din(104)           <= '0';
               writefifo_Din(105)           <= '1';
               writefifo_Din(106)           <= '0';
               writefifo_Din(107)           <= instrcache_request;
               if (instrcache_request = '1') then
                  writefifo_Din( 95 downto 64) <= std_logic_vector(mem1_address(31 downto 5)) & "00000";
               end if;  
            elsif (mem1_request_latched = '1') then
               mem1_request_latched         <= '0';
               writefifo_wr                 <= '1';
               writefifo_Din( 95 downto 64) <= std_logic_vector(mem1_address);
               writefifo_Din(104)           <= '0';
               writefifo_Din(105)           <= '1';
               writefifo_Din(106)           <= '0';
               writefifo_Din(107)           <= mem1_cache_latched;
               if (mem1_cache_latched = '1') then
                  writefifo_Din( 95 downto 64) <= std_logic_vector(mem1_address(31 downto 5)) & "00000";
               end if;  
            end if;
            
            mem_finished_dataRead <= mem_dataRead;
            mem_finished_instr    <= '0';
            mem_finished_read     <= '0';
            mem_done_1            <= mem_done;
            if (mem_done = '1' and mem_done_1 = '0') then
               if (memoryMuxStage4 = '1') then
                  if (mem_rnw = '1') then
                     mem_finished_read <= '1';
                  end if;
               else
                  mem_finished_instr <= '1';
               end if;
            end if;
            
         end if;
      end if;
   end process;
   
   iSyncFifo: entity mem.SyncFifoFallThroughMLAB
   generic map
   (
      SIZE              => 8,
      DATAWIDTH         => 108, -- 64bit data, 32bit address, 8 bit byte enable, 1 bit stage1/4, 1 bit r/w, 1 bit 64bit access, 1 bit cache
      NEARFULLDISTANCE  => 4
   )
   port map
   ( 
      clk       => clk93,
      reset     => reset_93,  
      Din       => writefifo_Din,     
      Wr        => writefifo_wr,      
      Full      => error_fifo,    
      Dout      => writefifo_Dout,    
      Rd        => writefifo_Rd,      
      Empty     => writefifo_Empty
   );
   
   writefifo_block <= '1' when (writefifo_cnt >= 4 or (writefifo_cnt = 3 and writefifo_wr = '1')) else '0';
   
   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         writefifo_rd_1x <= '0';
         mem_request     <= '0';
      
         if (reset_1x = '1') then
         
            memoryMuxStage4       <= '0'; 
            memstate              <= MEMSTATE_IDLE;
         
         else
            
            case (memstate) is
               when MEMSTATE_IDLE => 
               
                  if (ce_1x = '1') then
                  
                     if (writefifo_Empty = '0') then
                     
                        writefifo_rd_1x   <= '1';
                        memstate          <= MEMSTATE_BUSY;
                        mem_request       <= '1';
                        memoryMuxStage4   <= '1';
                        mem_dataWrite     <= writefifo_Dout(63 downto 0);
                        mem_address       <= unsigned(writefifo_Dout(95 downto 64));
                        mem_writeMask     <= writefifo_Dout(103 downto 96);
                        memoryMuxStage4   <= writefifo_Dout(104);
                        mem_rnw           <= writefifo_Dout(105);
                        mem_req64         <= writefifo_Dout(106);
                        
                        mem_size          <= "001";
                        
                        if (writefifo_Dout(104) = '1' and writefifo_Dout(107) = '1') then
                           mem_size          <= "010";
                           datacache_active  <= '1';
                        end if;
                        
                        if (writefifo_Dout(104) = '0' and writefifo_Dout(107) = '1') then
                           mem_size          <= "100";
                           instrcache_active  <= '1';
                        end if;

                     end if;

                  end if;
                  
               when MEMSTATE_BUSY =>
                  if (mem_done = '1') then
                     memstate          <= MEMSTATE_IDLE;
                     if (memoryMuxStage4 = '1') then
                        datacache_active <= '0';
                     else
                        instrcache_active <= '0';
                     end if;
                  end if;               
                  
            end case;
            
         end if;
      end if;
   end process;
   
--##############################################################
--############################### FPU register file
--##############################################################
   iregisterfileFPU1LO : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 32,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk93,
      wren       => FPUregs_wren_a(0),
      data       => FPUregs_data_a(31 downto 0),
      wraddress  => FPUregs_address_a,
      rdaddress  => FPUregs1_address_b,
      q          => FPUregs1_q_b(31 downto 0)
	);
   iregisterfileFPU1HI : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 32,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk93,
      wren       => FPUregs_wren_a(1),
      data       => FPUregs_data_a(63 downto 32),
      wraddress  => FPUregs_address_a,
      rdaddress  => FPUregs1_address_b,
      q          => FPUregs1_q_b(63 downto 32)
	);
   
   FPUregs_wren_a    <= "11" when (ss_fpuregs_load = '1') else
                        cop1_stage4_writeMask when (ce_93 = '1' and cop1_stage4_writeEnable = '1') else 
                        FPUWriteMask          when (ce_93 = '1' and FPUWriteEnable = '1') else 
                        "00";
   
   FPUregs_data_a    <= ss_FPUregs_data                    when (ss_FPUregs_load = '1') else 
                        std_logic_vector(cop1_stage4_data) when (cop1_stage4_writeEnable = '1') else
                        std_logic_vector(FPUWriteData);
                     
   FPUregs_address_a <= std_logic_vector(ss_FPUregs_addr)    when (ss_FPUregs_load = '1') else 
                        std_logic_vector(cop1_stage4_target) when (cop1_stage4_writeEnable = '1') else
                        std_logic_vector(FPUWriteTarget);
   
   FPUregs1_address_b <= std_logic_vector(decFPUSource1);
   FPUregs2_address_b <= std_logic_vector(decFPUSource2);
   
   iregisterfileFPU2LO : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 32,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk93,
      wren       => FPUregs_wren_a(0),
      data       => FPUregs_data_a(31 downto 0),
      wraddress  => FPUregs_address_a,
      rdaddress  => FPUregs2_address_b,
      q          => FPUregs2_q_b(31 downto 0)
	);
   iregisterfileFPU2HI : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 32,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk93,
      wren       => FPUregs_wren_a(1),
      data       => FPUregs_data_a(63 downto 32),
      wraddress  => FPUregs_address_a,
      rdaddress  => FPUregs2_address_b,
      q          => FPUregs2_q_b(63 downto 32)
	);
   
--##############################################################
--############################### register file
--##############################################################
   iregisterfile1 : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 64,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk93,
      wren       => regs_wren_a,
      data       => regs_data_a,
      wraddress  => regs_address_a,
      rdaddress  => regs1_address_b,
      q          => regs1_q_b
	);
   
   regs_wren_a    <= '1' when (ss_regs_load = '1') else
                     '1' when (ce_93 = '1' and writebackWriteEnable = '1') else 
                     '0';
   
   regs_data_a    <= ss_regs_data when (ss_regs_load = '1') else 
                     std_logic_vector(writebackData);
                     
   regs_address_a <= std_logic_vector(ss_regs_addr) when (ss_regs_load = '1') else 
                     std_logic_vector(writebackTarget);
   
   regs1_address_b <= std_logic_vector(decSource1);
   regs2_address_b <= std_logic_vector(decSource2);
   
   iregisterfile2 : entity mem.RamMLAB
	GENERIC MAP 
   (
      width                               => 64,
      widthad                             => 5
	)
	PORT MAP (
      inclock    => clk93,
      wren       => regs_wren_a,
      data       => regs_data_a,
      wraddress  => regs_address_a,
      rdaddress  => regs2_address_b,
      q          => regs2_q_b
	);
   
   --iregisterfileSS : entity mem.RamMLAB
	--GENERIC MAP 
   --(
   --   width                               => 64,
   --   widthad                             => 5
	--)
	--PORT MAP (
   --   inclock    => clk93,
   --   wren       => regs_wren_a,
   --   data       => regs_data_a,
   --   wraddress  => regs_address_a,
   --   rdaddress  => regsSS_address_b,
   --   q          => regsSS_q_b
	--);

--##############################################################
--############################### stage 1
--##############################################################
   
   cache_commandEnableI <= executeICacheEnable when (stall = 0) else '0';
   
   icpu_instrcache : entity work.cpu_instrcache
   port map
   (
      clk1x             => clk1x,
      clk93             => clk93,
      clk2x             => clk2x,
      reset_93          => reset_93,
      ce_93             => ce_93,
      
      ram_request       => instrcache_request,
      ram_active        => instrcache_active,
      ram_grant         => rdram_granted2X,
      ram_done          => mem_finished_instr,
      ddr3_DOUT         => ddr3_DOUT,      
      ddr3_DOUT_READY   => ddr3_DOUT_READY,
      
      read_select       => FetchAddrSelect,
      read_addr1        => FetchAddr1(31 downto 0),
      read_addr2        => FetchAddr2(31 downto 0),
      read_addrCompare1 => FetchAddrTLBMuxed1,
      read_addrCompare2 => FetchAddrTLBMuxed2,
      read_hit          => instrcache_hit,
      read_data         => instrcache_data,
      
      fill_request      => instrcache_fill,
      fill_addrData     => mem1_address(31 downto 0),
      fill_addrTag      => fill_addrTag,
      fill_done         => instrcache_fill_done,
      
      CacheCommandEna   => cache_commandEnableI,
      CacheCommand      => executeCacheCommand,
      CacheCommandAddr  => executeMemAddress,
      
      TagLo_Valid       => TagLo_Valid,
      TagLo_Addr        => TagLo_Addr,
                            
      SS_reset          => SS_reset
   );
   
   fetchCache     <= '0' when (INSTRCACHEON = '0') else
                     TLB_instrUseCache when (TLB_instrMapped = '1') else
                     '1' when (FetchAddr1(31 downto 29) = "100") else  -- todo: only in kernelmode and only in 32bit mode
                     '0';
   
   FetchAddr <= FetchAddr2 when (FetchAddrSelect = '1') else FetchAddr1;
   
   FetchAddrTLBMuxed1 <= TLB_instrAddrOutFound when (TLB_instrMapped = '1') else FetchAddr1(31 downto 0);
   FetchAddrTLBMuxed2 <= TLB_instrAddrOutFound when (TLB_instrMapped = '1') else FetchAddr2(31 downto 0);

   TLB_instrMapped <= '1' when (privilegeMode = "00" and (FetchAddr(31 downto 29) < 4 or FetchAddr(31 downto 29) = 6 or FetchAddr(31 downto 29) = 7)) else
                      '1' when (privilegeMode = "01" and (FetchAddr(31 downto 29) < 4 or FetchAddr(31 downto 29) = 6)) else
                      '1' when (privilegeMode = "10" and (FetchAddr(31 downto 29) < 4)) else
                      '0';
                      
   TLB_instrReq <= '1' when (TLB_instrMapped = '1' and (stall = 0 or TLB_ss_load = '1')) else '0';
   
   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         instrcache_fill <= '0';
         mem1_request    <= '0';
         TLB_ss_load     <= '0';
         
         if (reset_93 = '1') then
                     
            mem1_request   <= not TLB_instrMapped;
            TLB_ss_load    <= TLB_instrMapped;
            if (ss_in(16)(3) = '1') then
               mem1_address   <= unsigned(ss_in(5)(31 downto 0)); -- last was branch -> should be patched in the savestate already
               fill_addrTag   <= unsigned(ss_in(5)(31 downto 0));
               PC             <= unsigned(ss_in(5)); 
            else
               mem1_address   <= unsigned(ss_in(0)(31 downto 0)); -- x"FFFFFFFFBFC00000";    
               fill_addrTag   <= unsigned(ss_in(0)(31 downto 0));
               PC             <= unsigned(ss_in(0)); -- x"FFFFFFFFBFC00000";                    
            end if;
            stall1         <= '1';
            fetchReady     <= '1';
            useCached_data <= '0';
            opcode0        <= (others => '0'); --unsigned(ss_in(14));
         
         elsif (ce_93 = '1') then

            if (stall = 0) then
               fetchReady <= '0';
            end if;
            
            cacheHitLast <= instrcache_hit;
            if (useCached_data = '1' and cacheHitLast = '1' and stall(4 downto 1) > 0 and stall1 = '0') then
               useCached_data <= '0';
               opcode0        <= unsigned(instrcache_data);
            end if;
         
            if (stall1 = '1') then
            
               if (instrcache_fill_done = '1' and useCached_data = '1') then
                  useCached_data <= '0';
                  stall1         <= '0';
                  opcode0        <= unsigned(instrcache_data);
               elsif (mem_finished_instr = '1' and useCached_data = '0') then
                  stall1         <= '0';
                  opcode0        <= unsigned(byteswap32(mem_finished_dataRead(31 downto 0)));
               end if;
               
               if (TLB_instrUnStall = '1') then
                  if (exceptionStage1 = '1') then
                     stall1         <= '0';
                     opcode0        <= (others => '0');
                     useCached_data <= '0';
                  else
                     mem1_address    <= TLB_instrAddrOutLookup;
                     useCached_data  <= TLB_instrUseCache;
                     if (TLB_instrUseCache = '1') then
                        instrcache_fill <= '1';
                     else
                        mem1_request    <= '1';
                     end if;
                  end if;
               end if;
            
            elsif (stall = 0 or fetchReady = '0') then
            
               PCold0             <= FetchAddr;
               PC                 <= FetchAddr;
               useCached_data     <= fetchCache;
               fetchReady         <= '1';
               
               if (TLB_instrMapped = '1') then
                  mem1_address <= TLB_instrAddrOutFound;
                  fill_addrTag <= FetchAddr(31 downto 0);
               else
                  mem1_address <= FetchAddr(31 downto 0);
                  fill_addrTag <= FetchAddr(31 downto 0);
               end if;
      
               if (TLB_instrStall = '1') then
                  stall1          <= '1'; 
               elsif (fetchCache = '1') then
                  if (instrcache_hit = '0') then
                     instrcache_fill    <= '1';
                     stall1             <= '1';
                  end if;
               else
                  mem1_request    <= '1';
                  stall1          <= '1';     
               end  if;  
               
            end if;
              
         end if;
      end if;
     
   end process;
   
   
--##############################################################
--############################### stage 2
--##############################################################
   
   opcodeCacheMuxed <= unsigned(instrcache_data) when (useCached_data = '1') else 
                       opcode0;     
                       
   decImmData    <= opcodeCacheMuxed(15 downto 0);
   decJumpTarget <= opcodeCacheMuxed(25 downto 0);
   decSource1    <= opcodeCacheMuxed(25 downto 21);
   decSource2    <= opcodeCacheMuxed(20 downto 16);
   decOP         <= opcodeCacheMuxed(31 downto 26);
   decFunct      <= opcodeCacheMuxed(5 downto 0);
   decShamt      <= opcodeCacheMuxed(10 downto 6);
   decRD         <= opcodeCacheMuxed(15 downto 11);
   decTarget     <= opcodeCacheMuxed(20 downto 16) when (opcodeCacheMuxed(31 downto 26) > 0) else opcodeCacheMuxed(15 downto 11);                  

   process (opcodeCacheMuxed, fpuRegMode, decOP)
   begin
      decFPUSource1 <= opcodeCacheMuxed(15 downto 11);
      decFPUSource2 <= opcodeCacheMuxed(20 downto 16);
   
      if (fpuRegMode = '0') then
         decFPUSource1(0) <= '0';
         if (decOP = 16#39# or decOP = 16#3D#) then -- SWC1 and SDC1
            decFPUSource2(0) <= '0';
         end if;
      end if;
  
   end process;
   
   decRequiresFPUreg1 <= '1' when (decOP = 16#11# and (decSource1(4) = '1' or decSource1(3 downto 1) = 0)) else 
                         '0';
                         
   -- can be optimized to only request opcodes that really need 2 ops
   decRequiresFPUreg2 <= '1' when (decOP = 16#11# and (decSource1(4) = '1' or decSource1(3 downto 1) = 0)) else 
                         '1' when (decOP = 16#39# or decOP = 16#3D#) else
                         '0';
   
   decFPUForwardUse <= (decodeFPUCommandEnable or decodeFPUTransferEnable) when (decRequiresFPUreg1 = '1' and decodeFPUTarget(4 downto 1) = decFPUSource1(4 downto 1)) else
                       (decodeFPUCommandEnable or decodeFPUTransferEnable) when (decRequiresFPUreg2 = '1' and decodeFPUTarget(4 downto 1) = decFPUSource2(4 downto 1)) else
                       '0';

   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         error_instr  <= '0';
      
         if (reset_93 = '1') then
         
            stall2           <= '0';
            decodeNew        <= '0';
            decode_irq       <= '0';
            decodeBranchType <= BRANCH_OFF;
            
         elsif (ce_93 = '1') then
         
            if (stall = 0) then
            
               decodeNew <= '0';
            
               if (exception = '1') then
               
                  decode_irq <= '0';
               
               elsif (fetchReady = '1') then
               
                  decodeNew        <= '1'; 
               
                  pcOld1           <= pcOld0;
                  opcode1          <= opcodeCacheMuxed;
                                    
                  decodeImmData    <= decImmData;   
                  decodeJumpTarget <= decJumpTarget;
                  decodeSource1    <= decSource1;
                  decodeSource2    <= decSource2;
                  decodeShamt      <= '0' & decShamt;     
                  decodeRD         <= decRD;        
                  decodeTarget     <= decTarget;    
                  decodeFPUSource1 <= decFPUSource1;
                  decodeFPUSource2 <= decFPUSource2;
                  
                  -- operand fetching
                  decodeValue1     <= unsigned(regs1_q_b);
                  if (decSource1 > 0 and writebackTarget = decSource1 and writebackWriteEnable = '1') then 
                     decodeValue1 <= writebackData;
                  end if;
                  
                  decodeValue2     <= unsigned(regs2_q_b);
                  if (decSource2 > 0 and writebackTarget = decSource2 and writebackWriteEnable = '1') then 
                     decodeValue2 <= writebackData;
                  end if;
                  
                  executeForwardValue1 <= '0';
                  executeForwardValue2 <= '0';
                  if (decSource1 > 0 and decodeTarget = decSource1) then executeForwardValue1 <= '1'; end if;
                  if (decSource2 > 0 and decodeTarget = decSource2) then executeForwardValue2 <= '1'; end if;

                  -- FPU operand fetching
                  decodeFPUValue1 <= unsigned(FPUregs1_q_b);
                  decodeFPUValue2 <= unsigned(FPUregs2_q_b);
                  decodeFPUTarget <= opcodeCacheMuxed(10 downto 6);
                  
                  if (unsigned(FPUregs_address_a) = decFPUSource1 and FPUregs_wren_a(1) = '1') then decodeFPUValue1(63 downto 32) <= unsigned(FPUregs_data_a(63 downto 32)); end if;
                  if (unsigned(FPUregs_address_a) = decFPUSource1 and FPUregs_wren_a(0) = '1') then decodeFPUValue1(31 downto  0) <= unsigned(FPUregs_data_a(31 downto  0)); end if;
                  if (unsigned(FPUregs_address_a) = decFPUSource2 and FPUregs_wren_a(1) = '1') then decodeFPUValue2(63 downto 32) <= unsigned(FPUregs_data_a(63 downto 32)); end if;
                  if (unsigned(FPUregs_address_a) = decFPUSource2 and FPUregs_wren_a(0) = '1') then decodeFPUValue2(31 downto  0) <= unsigned(FPUregs_data_a(31 downto  0)); end if;

                  decodeFPUForwardUse <= decFPUForwardUse;

                  -- decoding default
                  decodeResultWriteEnable <= '0';
                  decodeUseImmidateValue2 <= '0';
                  decodeShiftSigned       <= '0';
                  decodeShift32           <= '0';
                  decodeResult32          <= '0';
                  decodeBranchType        <= BRANCH_OFF;
                  decodeBranchLikely      <= '0';
                  decodeFPUCommandEnable  <= '0';
                  decodeFPUTransferEnable <= '0';
                  decodeFPUMULS           <= '0';
                  decodeFPUMULD           <= '0';
                  blockIRQ                <= '0';
                  decodeExcType           <= EXCTYPE_NONE;
                  decodeExcCode           <= x"0";
                  decodeExcCOP            <= "00";
                  decodecalcMULT          <= '0';
                  decodecalcMULTU         <= '0';
                  decodecalcDMULT         <= '0';
                  decodecalcDMULTU        <= '0';
                  decodecalcDIV           <= '0';
                  decodecalcDIVU          <= '0';
                  decodecalcDDIV          <= '0';
                  decodecalcDDIVU         <= '0';
                  decodehiUpdate          <= '0';
                  decodeloUpdate          <= '0';
                  decodeMemWriteEnable    <= '0';
                  decodeMemWriteLL        <= '0';
                  decodeMemReadEnable     <= '0';
                  decodeMem64Bit          <= '0';
                  decodeCacheEnable       <= '0';
                  decodeSetLL             <= '0';
                  decodeResetLL           <= '0';
                  decodeERET              <= '0';
                  decodeCOP0ReadEnable    <= '0';
                  decodeCOP0WriteEnable   <= '0';
                  decodeCOP0Register      <= decRD;
                  decodeCOP1ReadEnable    <= '0';
                  decodeCOP2ReadEnable    <= '0';
                  decodeCOP2WriteEnable   <= '0';
                  decodeCOP64             <= '0';
                  decodeTLBR              <= '0';
                  decodeTLBWI             <= '0';
                  decodeTLBWR             <= '0';
                  decodeTLBP              <= '0';
                  
                  -- decoding opcode specific
                  case (to_integer(decOP)) is
         
                     when 16#00# =>
                        case (to_integer(decFunct)) is
                        
                           when 16#00# => -- SLL
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTLEFT;
                              decodeShiftAmountType   <= "00";
                              decodeResult32          <= '1';
                              
                           when 16#02# => -- SRL
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTRIGHT;
                              decodeShift32           <= '1';
                              decodeShiftAmountType   <= "00";
                              decodeResult32          <= '1';
                           
                           when 16#03# => -- SRA
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTRIGHT; 
                              decodeShiftSigned       <= '1';
                              decodeShiftAmountType   <= "00";
                              decodeResult32          <= '1';
                              
                           when 16#04# => -- SLLV
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTLEFT;
                              decodeShiftAmountType   <= "01";
                              decodeResult32          <= '1';
                              
                           when 16#06# => -- SRLV
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTRIGHT;
                              decodeShift32           <= '1';
                              decodeShiftAmountType   <= "01";
                              decodeResult32          <= '1';
                           
                           when 16#07# => -- SRAV
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTRIGHT;
                              decodeShiftSigned       <= '1';
                              decodeShiftAmountType   <= "01";
                              decodeResult32          <= '1';

                           when 16#08# => -- JR
                              decodeBranchType        <= BRANCH_ALWAYS_REG;
                              decodeExcType           <= EXCTYPE_PC;
                              decodeExcCode           <= x"4";
                              
                           when 16#09# => -- JALR
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_PC;
                              decodeTarget            <= decRD;
                              decodeBranchType        <= BRANCH_ALWAYS_REG;
                              decodeExcType           <= EXCTYPE_PC;
                              decodeExcCode           <= x"4";
                              
                           when 16#0C# => -- SYSCALL
                              decodeExcType           <= EXCTYPE_DECODE;
                              decodeExcCode           <= x"8";
                     
                           when 16#0D# => -- BREAK
                              decodeExcType           <= EXCTYPE_DECODE;
                              decodeExcCode           <= x"9";
                              
                           when 16#0F# => -- SYNC
                              null;
                              
                           when 16#10# => -- MFHI
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_HI;
                            
                           when 16#11# => -- MTHI
                              decodehiUpdate <= '1';
                  
                           when 16#12# => -- MFLO
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_LO;
                              
                           when 16#13# => -- MTLO
                              decodeloUpdate <= '1';
                              
                           when 16#14# => -- DSLLV
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTLEFT;
                              decodeShiftAmountType   <= "10";   
                  
                           when 16#16# => -- DSRLV
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTRIGHT;
                              decodeShiftAmountType   <= "10";   
                              
                           when 16#17# => -- DSRAV
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTRIGHT;
                              decodeShiftAmountType   <= "10";   
                              decodeShiftSigned       <= '1';
                              
                           when 16#18# => -- MULT
                              decodecalcMULT <= '1';
                              
                           when 16#19# => -- MULTU
                              decodecalcMULTU <= '1';
                              
                           when 16#1A# => -- DIV
                              decodecalcDIV <= '1';
                              
                           when 16#1B# => -- DIVU
                              decodecalcDIVU <= '1';
                              
                           when 16#1C# => -- DMULT
                              decodecalcDMULT <= '1';                
                              
                           when 16#1D# => -- DMULTU
                              decodecalcDMULTU <= '1';                  
                              
                           when 16#1E# => -- DDIV
                              decodecalcDDIV <= '1';             
                              
                           when 16#1F# => -- DDIVU
                              decodecalcDDIVU <= '1';
                              
                           when 16#20# => -- ADD
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_ADD;
                              decodeResult32          <= '1';
                              decodeExcType           <= EXCTYPE_ADD;
                              decodeExcCode           <= x"C";
                  
                           when 16#21# => -- ADDU
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_ADD;
                              decodeResult32          <= '1';
                              
                           when 16#22# => -- SUB
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SUB;
                              decodeResult32          <= '1';
                              decodeExcType           <= EXCTYPE_SUB;
                              decodeExcCode           <= x"C";
                           
                           when 16#23# => -- SUBU
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SUB;
                              decodeResult32          <= '1';
                           
                           when 16#24# => -- AND
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_AND;
                           
                           when 16#25# => -- OR
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_OR;
                              
                           when 16#26# => -- XOR
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_XOR;
                              
                           when 16#27# => -- NOR
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_NOR;
                              
                           when 16#2A# => -- SLT
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_BIT;
                              decodeBitFuncType       <= BITFUNC_SIGNED;
                           
                           when 16#2B# => -- SLTU
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_BIT;
                              decodeBitFuncType       <= BITFUNC_UNSIGNED;
                              
                           when 16#2C# => -- DADD 
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_ADD;
                              decodeExcType           <= EXCTYPE_DADD;
                              decodeExcCode           <= x"C";
                  
                           when 16#2D# => -- DADDU
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_ADD;  
                              
                           when 16#2E# => -- DSUB
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SUB;
                              decodeExcType           <= EXCTYPE_DSUB;
                              decodeExcCode           <= x"C";
                              
                           when 16#2F# => -- DSUBU
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SUB;
                  
                           when 16#30# => -- TGE
                              decodeExcType  <= EXCTYPE_TRAPS0;
                              decodeExcCode  <= x"D";
                              
                           when 16#31# => -- TGEU
                              decodeExcType  <= EXCTYPE_TRAPU0;
                              decodeExcCode  <= x"D";
                              
                           when 16#32# => -- TLT
                              decodeExcType  <= EXCTYPE_TRAPS1;
                              decodeExcCode  <= x"D";
                              
                           when 16#33# => -- TLTU
                              decodeExcType  <= EXCTYPE_TRAPU1;
                              decodeExcCode  <= x"D";
                              
                           when 16#34# => -- TEQ
                              decodeExcType  <= EXCTYPE_TRAPE1;
                              decodeExcCode  <= x"D";
                              
                           when 16#36# => -- TNE
                              decodeExcType  <= EXCTYPE_TRAPE0;
                              decodeExcCode  <= x"D";
                  
                           when 16#38# => -- DSLL
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTLEFT;
                              decodeShiftAmountType   <= "00"; 
                  
                           when 16#3A# => -- DSRL
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTRIGHT;
                              decodeShiftAmountType   <= "00"; 
                              
                           when 16#3B# => -- DSRA
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTRIGHT;
                              decodeShiftAmountType   <= "00"; 
                              decodeShiftSigned       <= '1';
                              
                           when 16#3C# => -- DSLL + 32
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTLEFT;
                              decodeShiftAmountType   <= "00"; 
                              decodeShamt(5)          <= '1';
                              
                           when 16#3E# => -- DSRL + 32
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTRIGHT;
                              decodeShiftAmountType   <= "00"; 
                              decodeShamt(5)          <= '1';
                              
                           when 16#3F# => -- DSRA + 32
                              decodeResultWriteEnable <= '1';
                              decodeResultMux         <= RESULTMUX_SHIFTRIGHT;
                              decodeShiftAmountType   <= "00"; 
                              decodeShamt(5)          <= '1';
                              decodeShiftSigned       <= '1';

                           when others =>
                              decodeExcType  <= EXCTYPE_DECODE;
                              decodeExcCode  <= x"A";
                           
                        end case;
  
                     when 16#01# => 
                        decodeResultMux      <= RESULTMUX_PC;
                        decodeTarget         <= to_unsigned(31, 5);
                        if (decSource2(3) = '1') then -- Traps
                           case (decSource2(2 downto 0)) is
                              when 3x"0" => -- TGEI
                                 decodeExcType  <= EXCTYPE_TRAPIS0;
                                 decodeExcCode  <= x"D";
                                 
                              when 3x"1" => -- TGEIU
                                 decodeExcType  <= EXCTYPE_TRAPIU0;
                                 decodeExcCode  <= x"D";
                                 
                              when 3x"2" => -- TLTI
                                 decodeExcType  <= EXCTYPE_TRAPIS1;
                                 decodeExcCode  <= x"D";
                                 
                              when 3x"3" => -- TLTIU
                                 decodeExcType  <= EXCTYPE_TRAPIU1;
                                 decodeExcCode  <= x"D";
                                 
                              when 3x"4" => -- TEQI
                                 decodeExcType  <= EXCTYPE_TRAPIE1;
                                 decodeExcCode  <= x"D";
                                 
                              when 3x"6" => -- TNEI
                                 decodeExcType  <= EXCTYPE_TRAPIE0;
                                 decodeExcCode  <= x"D";
                              
                              when others =>
                                 decodeExcType  <= EXCTYPE_DECODE;
                                 decodeExcCode  <= x"A";
                                 
                           end case;
                           
                        else -- B: BLTZ, BGEZ, BLTZAL, BGEZAL
                           if (decSource2(4) = '1') then
                              decodeResultWriteEnable <= '1';
                           end if;
                           if (decSource2(0) = '1') then
                              decodeBranchType     <= BRANCH_BRANCH_BGEZ;
                           else
                              decodeBranchType     <= BRANCH_BRANCH_BLTZ;
                           end if;
                           decodeBranchLikely      <= decSource2(1);
                           if (decSource2(1) = '1') then blockIRQ <= '1'; end if;
                        end if;
                        
                     when 16#02# => -- J
                        decodeBranchType        <= BRANCH_JUMPIMM;
               
                     when 16#03# => -- JAL
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_PC;
                        decodeTarget            <= to_unsigned(31, 5);
                        decodeBranchType        <= BRANCH_JUMPIMM;
                        
                     when 16#04# => -- BEQ
                        decodeBranchType        <= BRANCH_BRANCH_BEQ;
                     
                     when 16#05# => -- BNE
                        decodeBranchType        <= BRANCH_BRANCH_BNE;
                     
                     when 16#06# => -- BLEZ
                        decodeBranchType        <= BRANCH_BRANCH_BLEZ;
                        
                     when 16#07# => -- BGTZ
                        decodeBranchType        <= BRANCH_BRANCH_BGTZ;
                        
                     when 16#08# => -- ADDI
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_ADD;
                        decodeResult32          <= '1';
                        decodeUseImmidateValue2 <= '1';
                        decodeExcType           <= EXCTYPE_ADDI;
                        decodeExcCode           <= x"C";
            
                     when 16#09# => -- ADDIU
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_ADD;
                        decodeResult32          <= '1';
                        decodeUseImmidateValue2 <= '1';
                        
                     when 16#0A# => -- SLTI
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_BIT;
                        decodeBitFuncType       <= BITFUNC_IMM_SIGNED;   
                        
                     when 16#0B# => -- SLTIU
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_BIT;
                        decodeBitFuncType       <= BITFUNC_IMM_UNSIGNED; 
                        
                     when 16#0C# => -- ANDI
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_AND;
                        decodeUseImmidateValue2 <= '1';
                        
                     when 16#0D# => -- ORI
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_OR;
                        decodeUseImmidateValue2 <= '1';
                        
                     when 16#0E# => -- XORI
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_XOR;
                        decodeUseImmidateValue2 <= '1';
                        
                     when 16#0F# => -- LUI
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_LUI;
                        
                     when 16#10# => -- COP0
                        blockIRQ <= '1';
                        if (decSource1(4) = '1') then
                           case (to_integer(decImmData(5 downto 0))) is
                              when 1 => decodeTLBR  <= '1';                         
                              when 2 => decodeTLBWI <= '1'; 
                              when 6 => decodeTLBWR <= '1';
                              when 8 => decodeTLBP  <= '1';
                              when 16#18# => -- ERET
                                 decodeBranchType <= BRANCH_ERET;
                                 decodeERET       <= '1';
                                 
                              when others => null;
                                 
                           end case;
                        else
                           case (to_integer(decSource1(3 downto 0))) is
                           
                              when 0 => -- mfc0
                                 decodeCOP0ReadEnable  <= '1';
                                                   
                              when 1 => -- dmfc0
                                 decodeCOP0ReadEnable  <= '1';
                                 decodeCOP64           <= '1';
                           
                              when 4 => -- mtc0
                                 decodeCOP0WriteEnable <= '1';
                                 
                              when 5 => -- dmtc0
                                 decodeCOP0WriteEnable <= '1';
                                 decodeCOP64           <= '1';
                              
                              when others => null;
                                 
                           end case;
                        end if;

                     when 16#11# => -- COP1
                        decodeResultMux         <= RESULTMUX_FPU;
                        if (decSource1(4) = '1') then -- FPU execute
                           decodeFPUCommandEnable  <= COP1_enable;
                           if (decFunct = 2) then
                              if (decSource1 = 16) then decodeFPUMULS <= '1'; end if;
                              if (decSource1 = 17) then decodeFPUMULD <= '1'; end if;
                           end if;
                        else
                           decodeFPUTarget         <= decRD;
                           decodeFPUTransferEnable <= COP1_enable;
                           if (decSource1(3 downto 0) < 3) then
                              decodeResultWriteEnable <= '1';
                           end if;
                           if (decSource1(3 downto 0) = x"8") then
                              decodeBranchType   <= BRANCH_BC1;
                              decodeBranchLikely <= decSource2(1);
                              if (decSource2(1) = '1') then blockIRQ <= '1'; end if;
                           end if;
                        end if;
                        if (COP1_enable = '0' or (decSource1(4) = '0' and decSource1(3 downto 0) > 8)) then
                           decodeExcType           <= EXCTYPE_DECODE;
                           decodeExcCode           <= x"B";
                           decodeExcCOP            <= "01";
                        end if;
                       
                     when 16#12# => -- COP2
                        if (COP2_enable = '0') then
                           decodeExcType           <= EXCTYPE_DECODE;
                           decodeExcCode           <= x"B";
                           decodeExcCOP            <= "10";
                        else
                           case (to_integer(decSource1)) is
                  
                              when 0 | 2 =>
                                 decodeCOP2ReadEnable <= '1';
                              
                              when 1 =>
                                 decodeCOP2ReadEnable <= '1';
                                 decodeCOP64 <= '1';
                                 
                              when 4 | 5 | 6 =>
                                 decodeCOP2WriteEnable <= '1';
                           
                              when others => 
                                 decodeExcType           <= EXCTYPE_DECODE;
                                 decodeExcCode           <= x"A";
                                 decodeExcCOP            <= "10";
                                 
                           end case;
                        end if;

                     when 16#13# => -- COP3 -> does not exist
                        decodeExcType           <= EXCTYPE_DECODE;
                        decodeExcCode           <= x"A";
                        
                     when 16#14# => -- BEQL
                        decodeBranchType        <= BRANCH_BRANCH_BEQ;
                        decodeBranchLikely      <= '1';
                        blockIRQ                <= '1';
                           
                     when 16#15# => -- BNEL
                        decodeBranchType        <= BRANCH_BRANCH_BNE;
                        decodeBranchLikely      <= '1';
                        blockIRQ                <= '1';
                        
                     when 16#16# => -- BLEZL
                        decodeBranchType        <= BRANCH_BRANCH_BLEZ;
                        decodeBranchLikely      <= '1';
                        blockIRQ                <= '1';
                        
                     when 16#17# => -- BGTZL
                        decodeBranchType        <= BRANCH_BRANCH_BGTZ;
                        decodeBranchLikely      <= '1';
                        blockIRQ                <= '1';
                        
                     when 16#18# => -- DADDI   
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_ADD;
                        decodeUseImmidateValue2 <= '1';
                        decodeExcType           <= EXCTYPE_DADDI;
                        decodeExcCode           <= x"C";
            
                     when 16#19# => -- DADDIU 
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_ADD;
                        decodeUseImmidateValue2 <= '1';
                        
                     when 16#1A# => -- LDL
                        decodeMemReadEnable     <= '1';
                        decodeMem64Bit          <= '1';
                        decodeLoadType          <= LOADTYPE_LEFT64;
               
                     when 16#1B# => -- LDR
                        decodeMemReadEnable     <= '1';
                        decodeMem64Bit          <= '1';
                        decodeLoadType          <= LOADTYPE_RIGHT64;
         
                     when 16#20# => -- LB
                        decodeMemReadEnable     <= '1';
                        decodeLoadType          <= LOADTYPE_SBYTE;
                        
                     when 16#21# => -- LH
                        decodeMemReadEnable     <= '1';
                        decodeLoadType          <= LOADTYPE_SWORD;
                        decodeExcType           <= EXCTYPE_ADDRH;
                        decodeExcCode           <= x"4";

                     when 16#22# => -- LWL
                        decodeMemReadEnable     <= '1';
                        decodeLoadType          <= LOADTYPE_LEFT;

                     when 16#23# => -- LW
                        decodeMemReadEnable     <= '1';
                        decodeLoadType          <= LOADTYPE_DWORD;
                        decodeExcType           <= EXCTYPE_ADDRW;
                        decodeExcCode           <= x"4";
                        
                     when 16#24# => -- LBU
                        decodeMemReadEnable     <= '1';
                        decodeLoadType          <= LOADTYPE_BYTE;
               
                     when 16#25# => -- LHU
                        decodeMemReadEnable     <= '1';
                        decodeLoadType          <= LOADTYPE_WORD;
                        decodeExcType           <= EXCTYPE_ADDRH;
                        decodeExcCode           <= x"4";
                        
                     when 16#26# => -- LWR
                        decodeMemReadEnable     <= '1';
                        decodeLoadType          <= LOADTYPE_RIGHT;
               
                     when 16#27# => -- LWU
                        decodeMemReadEnable     <= '1';
                        decodeLoadType          <= LOADTYPE_DWORDU;
                        decodeExcType           <= EXCTYPE_ADDRW;
                        decodeExcCode           <= x"4";
                        
                     when 16#28# => -- SB
                        decodeMemWriteEnable    <= '1';
                        decodeMemWriteType      <= MEMWRITETYPE_BYTE;
               
                     when 16#29# => -- SH
                        decodeMemWriteEnable    <= '1';
                        decodeMemWriteType      <= MEMWRITETYPE_HALF;
                        decodeExcType           <= EXCTYPE_ADDRH;
                        decodeExcCode           <= x"5";
                        
                     when 16#2A# => -- SWL
                        decodeMemWriteEnable    <= '1';
                        decodeMemWriteType      <= MEMWRITETYPE_SWL;
               
                     when 16#2B# => -- SW
                        decodeMemWriteEnable    <= '1';
                        decodeMemWriteType      <= MEMWRITETYPE_WORD;
                        decodeExcType           <= EXCTYPE_ADDRW;
                        decodeExcCode           <= x"5";

                     when 16#2C# => -- SDL
                        decodeMemWriteEnable    <= '1';
                        decodeMem64Bit          <= '1';
                        decodeMemWriteType      <= MEMWRITETYPE_SDL;

                     when 16#2D# => -- SDR
                        decodeMemWriteEnable    <= '1';
                        decodeMem64Bit          <= '1';
                        decodeMemWriteType      <= MEMWRITETYPE_SDR;
                        
                     when 16#2E# => -- SWR
                        decodeMemWriteEnable    <= '1';
                        decodeMemWriteType      <= MEMWRITETYPE_SWR;
                        
                     when 16#2F# => -- Cache
                        decodeCacheEnable       <= '1';
                        case (to_integer(decSource2)) is
                           when 16#00# | 16#01# | 16#05# | 16#08# | 16#09# | 16#0D# | 16#10# | 16#11# | 16#15# | 16#19# => null;
                           when others => error_instr <= '1';
                        end case;

                     when 16#30# => -- LL
                        decodeMemReadEnable     <= '1';
                        decodeLoadType          <= LOADTYPE_DWORD;
                        decodeSetLL             <= '1';
                        decodeExcType           <= EXCTYPE_ADDRW;
                        decodeExcCode           <= x"4";

                     when 16#31# => -- LWC1
                        decodeLoadType          <= LOADTYPE_DWORD;
                        if (COP1_enable = '0') then
                           decodeExcType           <= EXCTYPE_DECODE;
                           decodeExcCode           <= x"B";
                           decodeExcCOP            <= "01";
                        else
                           decodeMemReadEnable     <= '1';
                           decodeCOP1ReadEnable    <= '1';
                        end if;

                     when 16#32# => -- LWC2 -> NOP
                        null;
                        
                     when 16#33# => -- LWC3 -> NOP
                        null;

                     when 16#34# => -- LLD 
                        decodeMemReadEnable     <= '1';
                        decodeMem64Bit          <= '1';
                        decodeLoadType          <= LOADTYPE_QWORD;
                        decodeSetLL             <= '1';
                        decodeExcType           <= EXCTYPE_ADDRD;
                        decodeExcCode           <= x"4";

                     when 16#35# => -- LDC1 
                        decodeMem64Bit          <= '1';
                        decodeLoadType          <= LOADTYPE_QWORD;
                        if (COP1_enable = '0') then
                           decodeExcType           <= EXCTYPE_DECODE;
                           decodeExcCode           <= x"B";
                           decodeExcCOP            <= "01";
                        else
                           decodeMemReadEnable     <= '1';
                           decodeCOP1ReadEnable    <= '1';
                        end if;

                     when 16#37# => -- LD
                        decodeMemReadEnable     <= '1';
                        decodeMem64Bit          <= '1';
                        decodeLoadType          <= LOADTYPE_QWORD;
                        decodeExcType           <= EXCTYPE_ADDRD;
                        decodeExcCode           <= x"4";              
               
                     when 16#38# => -- SC
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_BIT;
                        decodeBitFuncType       <= BITFUNC_SC;
                        decodeMemWriteLL        <= '1';
                        decodeResetLL           <= '1';
                        decodeMemWriteType      <= MEMWRITETYPE_WORD;
                        decodeExcType           <= EXCTYPE_ADDRW;
                        decodeExcCode           <= x"5";
               
                     when 16#39# => -- SWC1 
                        if (fpuRegMode = '0' and decSource2(0) = '1') then
                           decodeMemWriteType <= MEMWRITETYPE_COP1H;
                        else
                           decodeMemWriteType <= MEMWRITETYPE_COP1L;
                        end if;
                        if (COP1_enable = '0') then
                           decodeExcType           <= EXCTYPE_DECODE;
                           decodeExcCode           <= x"B";
                           decodeExcCOP            <= "01";
                        else
                           decodeMemWriteEnable    <= '1';
                        end if;  
                        
                     when 16#3A# => -- SWC2 -> NOP
                        null;
                        
                     when 16#3B# => -- SWC3 -> NOP
                        null;
   
                     when 16#3C# => -- SCD 
                        decodeResultWriteEnable <= '1';
                        decodeResultMux         <= RESULTMUX_BIT;
                        decodeBitFuncType       <= BITFUNC_SC;
                        decodeMemWriteLL        <= '1';
                        decodeResetLL           <= '1';
                        decodeMem64Bit          <= '1';
                        decodeMemWriteType      <= MEMWRITETYPE_DWORD;
                        decodeExcType           <= EXCTYPE_ADDRD;
                        decodeExcCode           <= x"5";
               
                     when 16#3D# => -- SDC1 
                        decodeMem64Bit          <= '1';
                        decodeMemWriteType      <= MEMWRITETYPE_COP1D;
                        if (COP1_enable = '0') then
                           decodeExcType           <= EXCTYPE_DECODE;
                           decodeExcCode           <= x"B";
                           decodeExcCOP            <= "01";
                        else
                           decodeMemWriteEnable    <= '1';
                        end if;
               
                     when 16#3F# => -- SD
                        decodeMemWriteEnable    <= '1';
                        decodeMem64Bit          <= '1';
                        decodeMemWriteType      <= MEMWRITETYPE_DWORD;
                        decodeExcType           <= EXCTYPE_ADDRD;
                        decodeExcCode           <= x"5";
                     
                     when others =>
                        decodeExcType  <= EXCTYPE_DECODE;
                        decodeExcCode  <= x"A";                     
                     
                  end case;
                  
                  if (irqTrigger = '1' and blockIRQ = '0') then
                     decode_irq <= '1';
                     decodeNew  <= '0';
                  end if;
                  
                  if (decode_irq = '1') then
                     decodeNew <= '0';
                  end if;
                  
               end if; -- fetchReady
      
            else
               
               -- operand forwarding in stall
               if (decodeSource1 > 0 and writebackTarget = decodeSource1 and writebackWriteEnable = '1') then decodeValue1 <= writebackData; end if;
               if (decodeSource2 > 0 and writebackTarget = decodeSource2 and writebackWriteEnable = '1') then decodeValue2 <= writebackData; end if;
      
               if (unsigned(FPUregs_address_a) = decodeFPUSource1 and FPUregs_wren_a(1) = '1') then decodeFPUValue1(63 downto 32) <= unsigned(FPUregs_data_a(63 downto 32)); end if;
               if (unsigned(FPUregs_address_a) = decodeFPUSource1 and FPUregs_wren_a(0) = '1') then decodeFPUValue1(31 downto  0) <= unsigned(FPUregs_data_a(31 downto  0)); end if;
               if (unsigned(FPUregs_address_a) = decodeFPUSource2 and FPUregs_wren_a(1) = '1') then decodeFPUValue2(63 downto 32) <= unsigned(FPUregs_data_a(63 downto 32)); end if;
               if (unsigned(FPUregs_address_a) = decodeFPUSource2 and FPUregs_wren_a(0) = '1') then decodeFPUValue2(31 downto  0) <= unsigned(FPUregs_data_a(31 downto  0)); end if;
      
            end if; -- stall

         end if; -- ce
      end if; -- clk
   end process;
   
   
--##############################################################
--############################### stage 3
--##############################################################
   
   ---------------------- Operand forward ------------------
   
   value1 <= resultData    when (executeForwardValue1   = '1' and resultWriteEnable = '1') else 
             writebackData when (writebackForwardValue1 = '1') else 
             decodeValue1;
   
   value2 <= resultData    when (executeForwardValue2   = '1' and resultWriteEnable = '1') else 
             writebackData when (writebackForwardValue2 = '1') else 
             decodeValue2;
   
   ---------------------- Adder ------------------
   value2_muxedSigned <= unsigned(resize(signed(decodeImmData), 64)) when (decodeUseImmidateValue2) else value2;
   calcResult_add     <= value1 + value2_muxedSigned;
   
   calcMemAddr        <= value1 + unsigned(resize(signed(decodeImmData), 64));
   
   ---------------------- Shifter ------------------
   -- multiplex immidiate and register based shift amount, so both types can use the same shifters
   executeShamt <= decodeShamt              when (decodeShiftAmountType = "00") else
                   '0' & value1(4 downto 0) when (decodeShiftAmountType = "01") else
                   value1(5 downto 0);
   
   -- multiplex high bit of rightshift so arithmetic shift can be reused for logical shift
   shiftValue(31 downto 0)  <= signed(value2(31 downto 0));
   shiftValue(63 downto 32) <= (others => '0') when (decodeShift32 = '1') else signed(value2(63 downto 32));
   shiftValue(64) <= value2(63) when (decodeShiftSigned = '1') else '0';

   calcResult_shiftL <= value2 sll to_integer(executeShamt);
   calcResult_shiftR <= resize(unsigned(shift_right(shiftValue,to_integer(executeShamt))), 64);  

   ---------------------- Sub ------------------
   calcResult_sub    <= value1 - value2;
   
   ---------------------- logical calcs ------------------
   value2_muxedLogical <= x"000000000000" & decodeImmData when (decodeUseImmidateValue2) else value2;
   
   calcResult_and    <= value1 and value2_muxedLogical;
   calcResult_or     <= value1 or value2_muxedLogical;
   calcResult_xor    <= value1 xor value2_muxedLogical;
   calcResult_nor    <= value1 nor value2;

   ---------------------- bit functions ------------------
   
   calcResult_lesserSigned      <= '1' when (signed(value1) < signed(value2)) else '0'; 
   calcResult_lesserUnsigned    <= '1' when (value1 < value2) else '0';    
   calcResult_lesserIMMSigned   <= '1' when (signed(value1) < resize(signed(decodeImmData), 64)) else '0'; 
   calcResult_lesserIMMUnsigned <= '1' when (value1 < unsigned(resize(signed(decodeImmData), 64))) else '0'; 
   calcResult_equal             <= '1' when (signed(value1) = resize(signed(decodeImmData), 64)) else '0'; 
   
   calcResult_bit(63 downto 1) <= (others => '0');
   calcResult_bit(0) <= calcResult_lesserSigned       when (decodeBitFuncType = BITFUNC_SIGNED) else
                        calcResult_lesserUnSigned     when (decodeBitFuncType = BITFUNC_UNSIGNED) else
                        calcResult_lesserIMMSigned    when (decodeBitFuncType = BITFUNC_IMM_SIGNED) else
                        calcResult_lesserIMMUnsigned  when (decodeBitFuncType = BITFUNC_IMM_UNSIGNED) else
                        llBit;
   
   ---------------------- branching ------------------
   --PCnext       <= PC + 4;
   --PCnextBranch <= pcOld0 + unsigned((resize(signed(decodeImmData), 62) & "00"));
   -- assume region change cannot/will not happen with counting up or short jumps
   PCnext       <= PC(63 downto 29) & (PC(28 downto 0) + 4);
   PCnextBranch <= pcOld0(63 downto 29) & (pcOld0(28 downto 0) + unsigned((resize(signed(decodeImmData), 27) & "00")));
   
   cmpEqual    <= '1' when (value1 = value2) else '0';
   cmpNegative <= value1(63);
   cmpZero     <= '1' when (value1 = 0) else '0';
   
   -- use two nextaddress/branch paths with 2 tag rams, so different paths can be calculated in parallel to improve timing
   
   FetchAddrSelect <= '0'  when (exception = '1' or exceptionStage1 = '1' or executeIgnoreNext = '1' or decodeNew = '0') else
                      '1'  when (decodeBranchType = BRANCH_BRANCH_BGEZ and (cmpZero = '1' or cmpNegative = '0'))  else
                      '1'  when (decodeBranchType = BRANCH_BRANCH_BLTZ and cmpNegative = '1')                     else
                      '1'  when (decodeBranchType = BRANCH_BRANCH_BEQ  and cmpEqual = '1')                        else
                      '1'  when (decodeBranchType = BRANCH_BRANCH_BNE  and cmpEqual = '0')                        else
                      '1'  when (decodeBranchType = BRANCH_BRANCH_BLEZ and (cmpZero = '1' or cmpNegative = '1'))  else
                      '1'  when (decodeBranchType = BRANCH_BRANCH_BGTZ and (cmpZero = '0' and cmpNegative = '0')) else
                      '1'  when (decodeBranchType = BRANCH_BC1         and decodeSource2(0) = FPU_CF) else
                      '0';
   
   FetchAddr1 <= exceptionPC                                    when (exception = '1' or exceptionStage1 = '1') else
                 PCnext                                         when (executeIgnoreNext = '1' or decodeNew = '0') else
                 value1                                         when (decodeBranchType = BRANCH_ALWAYS_REG) else
                 pcOld0(63 downto 28) & decodeJumpTarget & "00" when (decodeBranchType = BRANCH_JUMPIMM) else
                 eretPC                                         when (decodeBranchType = BRANCH_ERET) else
                 PCnext;

   FetchAddr2 <= PCnextBranch;
   
   EXECOPBranchDelaySlot <= '0' when (executeIgnoreNext = '1') else
                            '1' when (decodeBranchType /= BRANCH_OFF) else 
                            '0';

   EXEBranchdelaySlot <= '0' when (executeIgnoreNext = '1') else
                         '1' when (decodeBranchType = BRANCH_ALWAYS_REG) else
                         '1' when (decodeBranchType = BRANCH_JUMPIMM) else
                         '1' when (decodeBranchType = BRANCH_BRANCH_BGEZ and (decodeBranchLikely = '0' or (cmpZero = '1' or cmpNegative = '0')))  else
                         '1' when (decodeBranchType = BRANCH_BRANCH_BLTZ and (decodeBranchLikely = '0' or cmpNegative = '1')                   )  else
                         '1' when (decodeBranchType = BRANCH_BRANCH_BEQ  and (decodeBranchLikely = '0' or cmpEqual = '1')                      )  else
                         '1' when (decodeBranchType = BRANCH_BRANCH_BNE  and (decodeBranchLikely = '0' or cmpEqual = '0')                      )  else
                         '1' when (decodeBranchType = BRANCH_BRANCH_BLEZ and (decodeBranchLikely = '0' or (cmpZero = '1' or cmpNegative = '1')))  else
                         '1' when (decodeBranchType = BRANCH_BRANCH_BGTZ and (decodeBranchLikely = '0' or (cmpZero = '0' and cmpNegative = '0'))) else
                         '1' when (decodeBranchType = BRANCH_BC1         and (decodeBranchLikely = '0' or decodeSource2(0) = FPU_CF))             else
                         '0';
                         
   EXEIgnoreNext      <= '0' when (executeIgnoreNext = '1') else
                         '1' when (decodeBranchType = BRANCH_ERET) else                      
                         '1' when (decodeBranchType = BRANCH_BRANCH_BGEZ and decodeBranchLikely = '1' and cmpZero = '0' and cmpNegative = '1')  else
                         '1' when (decodeBranchType = BRANCH_BRANCH_BLTZ and decodeBranchLikely = '1' and cmpNegative = '0')                    else
                         '1' when (decodeBranchType = BRANCH_BRANCH_BEQ  and decodeBranchLikely = '1' and cmpEqual = '0')                       else
                         '1' when (decodeBranchType = BRANCH_BRANCH_BNE  and decodeBranchLikely = '1' and cmpEqual = '1')                       else
                         '1' when (decodeBranchType = BRANCH_BRANCH_BLEZ and decodeBranchLikely = '1' and cmpZero = '0' and cmpNegative = '0')  else
                         '1' when (decodeBranchType = BRANCH_BRANCH_BGTZ and decodeBranchLikely = '1' and (cmpZero = '1' or cmpNegative = '1')) else
                         '1' when (decodeBranchType = BRANCH_BC1         and decodeBranchLikely = '1' and decodeSource2(0) /= FPU_CF)           else
                         '0';

   ---------------------- result muxing ------------------
   resultDataMuxed <= calcResult_shiftL when (decodeResultMux = RESULTMUX_SHIFTLEFT)  else
                      calcResult_shiftR when (decodeResultMux = RESULTMUX_SHIFTRIGHT) else
                      calcResult_add    when (decodeResultMux = RESULTMUX_ADD)        else
                      PCnext            when (decodeResultMux = RESULTMUX_PC)         else
                      HI                when (decodeResultMux = RESULTMUX_HI)         else
                      LO                when (decodeResultMux = RESULTMUX_LO)         else
                      calcResult_sub    when (decodeResultMux = RESULTMUX_SUB)        else
                      calcResult_and    when (decodeResultMux = RESULTMUX_AND)        else
                      calcResult_or     when (decodeResultMux = RESULTMUX_OR )        else
                      calcResult_xor    when (decodeResultMux = RESULTMUX_XOR)        else
                      calcResult_nor    when (decodeResultMux = RESULTMUX_NOR)        else
                      calcResult_bit    when (decodeResultMux = RESULTMUX_BIT)        else
                      FPU_TransferData  when (decodeResultMux = RESULTMUX_FPU)        else
                      unsigned(resize(signed(decodeImmData) & x"0000", 64)); -- (decodeResultMux = RESULTMUX_LUI);
                      
   resultDataMuxed64(31 downto 0) <= resultDataMuxed(31 downto 0);
   resultDataMuxed64(63 downto 32) <= (others => resultDataMuxed(31)) when decodeResult32 else resultDataMuxed(63 downto 32);

   ---------------------- exceptions ------------------
   exceptionCode_3  <= decodeExcCode;
   exception_COP    <= decodeExcCOP;
   
   EXEExceptionMem <= '1' when (decodeExcType = EXCTYPE_ADDRH   and calcMemAddr(0) = '1') else
                      '1' when (decodeExcType = EXCTYPE_ADDRW   and calcMemAddr(1 downto 0) > 0) else
                      '1' when (decodeExcType = EXCTYPE_ADDRD   and calcMemAddr(2 downto 0) > 0) else
                      '0';
   
   exceptionNew3  <= '0' when (exception = '1' or stall > 0 or executeIgnoreNext = '1' or decodeNew = '0') else
                     '1' when (EXEExceptionMem = '1') else
                     '1' when (decodeExcType = EXCTYPE_DECODE) else
                     '1' when (decodeExcType = EXCTYPE_PC      and value1(1 downto 0) > 0) else
                     '1' when (decodeExcType = EXCTYPE_ADD     and (((calcResult_add(31) xor value1(31)) and (calcResult_add(31) xor value2(31))) = '1')) else
                     '1' when (decodeExcType = EXCTYPE_DADD    and (((calcResult_add(63) xor value1(63)) and (calcResult_add(63) xor value2(63))) = '1')) else
                     '1' when (decodeExcType = EXCTYPE_ADDI    and (((calcResult_add(31) xor value1(31)) and (calcResult_add(31) xor decodeImmData(15))) = '1')) else
                     '1' when (decodeExcType = EXCTYPE_DADDI   and (((calcResult_add(63) xor value1(63)) and (calcResult_add(63) xor decodeImmData(15))) = '1')) else
                     '1' when (decodeExcType = EXCTYPE_SUB     and (((calcResult_sub(31) xor value1(31)) and (value1(31) xor value2(31))) = '1')) else
                     '1' when (decodeExcType = EXCTYPE_DSUB    and (((calcResult_sub(63) xor value1(63)) and (value1(63) xor value2(63))) = '1')) else
                     '1' when (decodeExcType = EXCTYPE_TRAPU0  and calcResult_lesserUnsigned = '0') else
                     '1' when (decodeExcType = EXCTYPE_TRAPU1  and calcResult_lesserUnsigned = '1') else
                     '1' when (decodeExcType = EXCTYPE_TRAPS0  and calcResult_lesserSigned = '0') else
                     '1' when (decodeExcType = EXCTYPE_TRAPS1  and calcResult_lesserSigned = '1') else
                     '1' when (decodeExcType = EXCTYPE_TRAPE0  and cmpEqual = '0') else
                     '1' when (decodeExcType = EXCTYPE_TRAPE1  and cmpEqual = '1') else
                     '1' when (decodeExcType = EXCTYPE_TRAPIU0 and calcResult_lesserIMMUnsigned   = '0') else
                     '1' when (decodeExcType = EXCTYPE_TRAPIU1 and calcResult_lesserIMMUnsigned   = '1') else
                     '1' when (decodeExcType = EXCTYPE_TRAPIS0 and calcResult_lesserIMMSigned     = '0') else
                     '1' when (decodeExcType = EXCTYPE_TRAPIS1 and calcResult_lesserIMMSigned     = '1') else
                     '1' when (decodeExcType = EXCTYPE_TRAPIE0 and calcResult_equal               = '0') else
                     '1' when (decodeExcType = EXCTYPE_TRAPIE1 and calcResult_equal               = '1') else
                     '0';
    
   exceptionNewPC <= '1' when (decodeExcType = EXCTYPE_PC and value1(1 downto 0) > 0) else '0';
    
   ---------------------- COP ------------------                  
   FPU_command_ena      <= decodeFPUCommandEnable  when (exception = '0' and stall = 0 and executeIgnoreNext = '0' and decodeNew = '1') else '0';
   FPU_TransferEna      <= decodeFPUTransferEnable when (exception = '0' and stall = 0 and executeIgnoreNext = '0' and decodeNew = '1') else '0';
                     
   EXECOP0WriteValue    <= unsigned(resize(signed(value2(31 downto 0)), 64)) when (decodeCOP64 = '0') else
                           value2;

   -- 64bit mode?
   EXETLBMapped <= '1' when (privilegeMode = "00" and (calcMemAddr(31 downto 29) < 4 or calcMemAddr(31 downto 29) = 6 or calcMemAddr(31 downto 29) = 7)) else
                   '1' when (privilegeMode = "01" and (calcMemAddr(31 downto 29) < 4 or calcMemAddr(31 downto 29) = 6)) else
                   '1' when (privilegeMode = "10" and (calcMemAddr(31 downto 29) < 4)) else
                   '0';
   
   EXETLBDataAccess <= decodeMemReadEnable or decodeMemWriteEnable or decodeCacheEnable or decodeMemWriteLL when (EXETLBMapped = '1' and exception = '0' and stall = 0 and executeIgnoreNext = '0' and decodeNew = '1') else '0';

   ---------------------- load/store ------------------
   
   EXECacheAddr(31 downto 3) <= calcMemAddr(31 downto 3);
                                
   EXECacheAddr(2 downto 0)  <= "000"                  when (decodeLoadType = LOADTYPE_LEFT64 or decodeLoadType = LOADTYPE_RIGHT64) else 
                                calcMemAddr(2) & "00"  when (decodeLoadType = LOADTYPE_LEFT or decodeLoadType = LOADTYPE_RIGHT) else 
                                calcMemAddr(2 downto 0);  
   
   
   process (all)
      variable rotatedData          : unsigned(63 downto 0) := (others => '0');
   begin
   
      rotatedData             := byteswap32(value2(63 downto 32)) & byteswap32(value2(31 downto 0));
      EXEMemWriteData         <= rotatedData;
      EXEMemWriteMask         <= "00000000";
      
      case (decodeMemWriteType) is
      
         when MEMWRITETYPE_BYTE =>
            case (to_integer(calcMemAddr(1 downto 0))) is 
               when 0 => EXEMemWriteMask(3 downto 0) <= "0001"; EXEMemWriteData <= x"00000000" & x"000000" & rotatedData(31 downto 24); 
               when 1 => EXEMemWriteMask(3 downto 0) <= "0010"; EXEMemWriteData <= x"00000000" & x"0000" &   rotatedData(31 downto 16);   
               when 2 => EXEMemWriteMask(3 downto 0) <= "0100"; EXEMemWriteData <= x"00000000" & x"00" &     rotatedData(31 downto 8);   
               when 3 => EXEMemWriteMask(3 downto 0) <= "1000"; EXEMemWriteData <= x"00000000" &             rotatedData(31 downto 0);   
               when others => null;
            end case;

         when MEMWRITETYPE_HALF =>
            if (calcMemAddr(1) = '1') then
               EXEMemWriteMask(3 downto 0) <= "1100";
            else
               EXEMemWriteData <= x"00000000" & x"0000" & rotatedData(31 downto 16);
               EXEMemWriteMask(3 downto 0) <= "0011";
            end if;
               
         when MEMWRITETYPE_WORD =>
            EXEMemWriteMask(3 downto 0) <= "1111";
               
         when MEMWRITETYPE_SWL =>
            case (to_integer(calcMemAddr(1 downto 0))) is 
               when 0 => EXEMemWriteMask(3 downto 0) <= "1111"; EXEMemWriteData <= x"00000000" & rotatedData(31 downto 0);
               when 1 => EXEMemWriteMask(3 downto 0) <= "1110"; EXEMemWriteData <= x"00000000" & rotatedData(23 downto 0) & x"00";
               when 2 => EXEMemWriteMask(3 downto 0) <= "1100"; EXEMemWriteData <= x"00000000" & rotatedData(15 downto 0) & x"0000";
               when 3 => EXEMemWriteMask(3 downto 0) <= "1000"; EXEMemWriteData <= x"00000000" & rotatedData( 7 downto 0) & x"000000";
               when others => null;
            end case;  
            
         when MEMWRITETYPE_SWR =>
            case (to_integer(calcMemAddr(1 downto 0))) is 
               when 0 => EXEMemWriteMask(3 downto 0) <= "0001"; EXEMemWriteData <= x"00000000" & x"000000" & rotatedData(31 downto 24);
               when 1 => EXEMemWriteMask(3 downto 0) <= "0011"; EXEMemWriteData <= x"00000000" & x"0000" &   rotatedData(31 downto 16);
               when 2 => EXEMemWriteMask(3 downto 0) <= "0111"; EXEMemWriteData <= x"00000000" & x"00" &     rotatedData(31 downto  8);
               when 3 => EXEMemWriteMask(3 downto 0) <= "1111"; EXEMemWriteData <= x"00000000" &             rotatedData(31 downto  0);
               when others => null;
            end case;  
            
         when MEMWRITETYPE_DWORD =>  
            EXEMemWriteMask <= "11111111";  
               
         when MEMWRITETYPE_SDL =>
            case (to_integer(calcMemAddr(2 downto 0))) is 
               when 0 => EXEMemWriteMask <= "11111111"; EXEMemWriteData <= rotatedData(63 downto 0);
               when 1 => EXEMemWriteMask <= "11101111"; EXEMemWriteData <= rotatedData(55 downto 0) & rotatedData(63 downto 56);
               when 2 => EXEMemWriteMask <= "11001111"; EXEMemWriteData <= rotatedData(47 downto 0) & rotatedData(63 downto 48);
               when 3 => EXEMemWriteMask <= "10001111"; EXEMemWriteData <= rotatedData(39 downto 0) & rotatedData(63 downto 40);
               when 4 => EXEMemWriteMask <= "00001111"; EXEMemWriteData <= rotatedData(31 downto 0) & rotatedData(63 downto 32);
               when 5 => EXEMemWriteMask <= "00001110"; EXEMemWriteData <= rotatedData(23 downto 0) & rotatedData(63 downto 24);
               when 6 => EXEMemWriteMask <= "00001100"; EXEMemWriteData <= rotatedData(15 downto 0) & rotatedData(63 downto 16);
               when 7 => EXEMemWriteMask <= "00001000"; EXEMemWriteData <= rotatedData( 7 downto 0) & rotatedData(63 downto 8);
               when others => null;
            end case;
            
         when MEMWRITETYPE_SDR =>
            case (to_integer(calcMemAddr(2 downto 0))) is 
               when 0 => EXEMemWriteMask <= "00010000"; EXEMemWriteData <= rotatedData(55 downto 0) & rotatedData(63 downto 56);
               when 1 => EXEMemWriteMask <= "00110000"; EXEMemWriteData <= rotatedData(47 downto 0) & rotatedData(63 downto 48);
               when 2 => EXEMemWriteMask <= "01110000"; EXEMemWriteData <= rotatedData(39 downto 0) & rotatedData(63 downto 40);
               when 3 => EXEMemWriteMask <= "11110000"; EXEMemWriteData <= rotatedData(31 downto 0) & rotatedData(63 downto 32);
               when 4 => EXEMemWriteMask <= "11110001"; EXEMemWriteData <= rotatedData(23 downto 0) & rotatedData(63 downto 24);
               when 5 => EXEMemWriteMask <= "11110011"; EXEMemWriteData <= rotatedData(15 downto 0) & rotatedData(63 downto 16);
               when 6 => EXEMemWriteMask <= "11110111"; EXEMemWriteData <= rotatedData( 7 downto 0) & rotatedData(63 downto 8);
               when 7 => EXEMemWriteMask <= "11111111"; EXEMemWriteData <= rotatedData(63 downto 0);
               when others => null;
            end case;
         
         when MEMWRITETYPE_COP1L =>         
            EXEMemWriteMask(3 downto 0) <= "1111";
            EXEMemWriteData(31 downto 0) <= byteswap32(decodeFPUValue2(31 downto 0));
                  
         when MEMWRITETYPE_COP1H =>         
            EXEMemWriteMask(3 downto 0) <= "1111";
            EXEMemWriteData(31 downto 0) <= byteswap32(decodeFPUValue2(63 downto 32));
               
         when MEMWRITETYPE_COP1D =>    
            EXEMemWriteMask <= "11111111";
            EXEMemWriteData   <= byteswap32(decodeFPUValue2(63 downto 32)) & byteswap32(decodeFPUValue2(31 downto 0));

      end case;

   end process;
   
   
   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         DIVstart    <= '0';
      
         if (reset_93 = '1') then
         
            stall3                        <= '0';
            executeNew                    <= '0';
            executeIgnoreNext             <= '0';
            executeStallFromMEM           <= '0';

            resultWriteEnable             <= '0';
            executeBranchdelaySlot        <= '0';
            executeMemWriteEnable         <= '0';
            executeMemReadEnable          <= '0';
            executeCOP0WriteEnable        <= '0';
            executeICacheEnable           <= '0';
            executeDCacheEnable           <= '0';
            executeSetLL                  <= '0';
            llBit                         <= '0';
            hiloWait                      <= 0;
            
            hi                            <= unsigned(ss_in(3)); -- (others => '0');
            lo                            <= unsigned(ss_in(4)); -- (others => '0');
            
         elsif (ce_93 = '1') then
            
            -- load delay block
            if (stall3) then
            
               if (stall = "00100") then
                  executeStallFromMEM <= '0';
                  executeNew          <= '0';
               end if;

               if (writebackStallFromMEM = '1') then
                  if (writebackNew = '1' or (mem_finished_read = '1' and writeback_COP1_ReadEnable = '0')) then
                     stall3 <= '0';
                  end if;
               end if;
               
               if (executeStallFromMEM = '1') then               
                  if (executeMemReadEnable = '1' and executeCOP1ReadEnable = '0') then
                     if (executeMemUseCache = '1') then
                        if (datacache_readdone = '1') then
                           stall3 <= '0';
                        end if;
                     end if;
                  end if;
               end if;
               
            end if;
            
            -- mul/div calc/wait
            if (hiloWait > 0) then
               hiloWait <= hiloWait - 1;
               if (hiloWait = 1) then
                  stall3     <= '0';
                  executeNew <= '1';
                  case (hilocalc) is
                     when HILOCALC_MULT | HILOCALC_MULTU => 
                        hi <= unsigned(resize(  signed(mulResult(63 downto 32)),64)); 
                        lo <= unsigned(resize(  signed(mulResult(31 downto 0)),64));
                     when HILOCALC_DMULT | HILOCALC_DMULTU => 
                        hi <= unsigned(mulResult(127 downto 64)); 
                        lo <= unsigned(mulResult(63 downto 0));
                     when HILOCALC_DIV | HILOCALC_DIVU => 
                        hi <= unsigned(resize(DIVremainder(31 downto  0), 64)); 
                        lo <= unsigned(resize(DIVquotient(31 downto 0), 64));
                     when HILOCALC_DDIV | HILOCALC_DDIVU => 
                        hi <= unsigned(DIVremainder(63 downto  0)); 
                        lo <= unsigned(DIVquotient(63 downto 0));
                  end case;
               end if;
            end if;
            
            -- FPU unstall
            execute_unstallFPUForward <= '0';
            
            if (FPU_command_done = '1') then
               if (decodeFPUForwardUse = '1') then
                  execute_unstallFPUForward <= '1';
               else
                  stall3     <= '0';
                  executeNew <= '1';
               end if;
            end if;
            
            if (execute_unstallFPUForward = '1') then
               stall3     <= '0';
               executeNew <= '1';
            end if;
            
            -- TLB unstall            
            if (TLB_dataUnStall = '1') then
               executeMemAddress     <= TLB_dataAddrOutLookup;
               executeNew            <= '1';
               if (exception = '0') then
                  if (executeMemReadEnable = '1') then
                     executeStallFromMEM <= '1';
                  else
                     stall3              <= '0';
                  end if;
               else
                  stall3                <= '0';
                  executeMemReadEnable  <= '0';
                  executeMemWriteEnable <= '0';
                  executeICacheEnable   <= '0';
                  executeDCacheEnable   <= '0';
               end if;
               if (TLB_dataUseCacheLookup = '1' and DATACACHEON_intern = '1') then
                  executeMemUseCache <= DATACACHETLBON_intern;
               else
                  executeMemUseCache <= '0';
               end if;
            end if;
            

            if (stall = 0) then
            
               executeNew              <= '0';
               executeICacheEnable     <= '0';
               executeDCacheEnable     <= '0';
               executeSetLL            <= '0';
               
               resultData              <= resultDataMuxed64;    
               resultTarget            <= decodeTarget;
                  
               executeMem64Bit         <= decodeMem64Bit;
               executeMemWriteData     <= EXEMemWriteData;             
               executeMemWriteMask     <= EXEMemWriteMask;
               executeMemReadLastData  <= value2;           

               executeLLfromTLB        <= EXETLBDataAccess;
               if (EXETLBDataAccess = '1') then
                  executeMemAddress <= TLB_dataAddrOutFound;
               else
                  executeMemAddress <= calcMemAddr(31 downto 0);
               end if;
               
               executeCOP0WriteValue   <= EXECOP0WriteValue; 

               executeBranchdelaySlot  <= EXEBranchdelaySlot;                
            
               if (exception = '1') then
                                                
                  stall3                        <= '0';
                  executeNew                    <= '0';
                  executeIgnoreNext             <= '0';
                     
                  resultWriteEnable             <= '0';
                  executeMemReadEnable          <= '0';
                  executeMemWriteEnable         <= '0';
                  executeCOP0WriteEnable        <= '0';
                  
               elsif (decodeNew = '1') then     
               
                  executeIgnoreNext             <= EXEIgnoreNext;
                   
                  if (executeIgnoreNext = '1') then
                  
                     resultWriteEnable      <= '0';
                     executeCOP0WriteEnable <= '0';
                     executeCOP0ReadEnable  <= '0';
                     executeICacheEnable    <= '0';
                     executeDCacheEnable    <= '0';
                     executeMemReadEnable   <= '0';
                     executeMemWriteEnable  <= '0';
                  
                  else
               
                     executeNew                    <= '1';
               
-- synthesis translate_off
                     pcOld2                        <= pcOld1;  
                     opcode2                       <= opcode1;
-- synthesis translate_on
                            
                     -- from calculation
                     if (decodeTarget = 0 or exceptionNew3 = '1') then
                        resultWriteEnable <= '0';
                     else
                        resultWriteEnable <= decodeResultWriteEnable;
                     end if;
                       
                     executeMemWriteEnable <= '0';
                     if (EXEExceptionMem = '0') then
                        if (decodeMemWriteEnable = '1') then
                           executeMemWriteEnable <= '1';
                        elsif (decodeMemWriteLL = '1') then
                           executeMemWriteEnable <= llBit;
                        end if;
                     end if;
                        
                     executeLoadType               <= decodeLoadType;   
                     executeMemReadEnable          <= decodeMemReadEnable and (not EXEExceptionMem); 
   
                     execute_ERET                  <= decodeERET;
                     executeCOP0WriteEnable        <= decodeCOP0WriteEnable;     
                     executeCOP0ReadEnable         <= decodeCOP0ReadEnable;      
                     executeCOP0Register           <= decodeCOP0Register;
                     
                     executeCOP1ReadEnable         <= decodeCOP1ReadEnable;
                     executeCOP1Target             <= decodeSource2;
                     
                     executeCOP2WriteEnable        <= decodeCOP2WriteEnable;     
                     executeCOP2ReadEnable         <= decodeCOP2ReadEnable; 
                     
                     executeCOP64                  <= decodeCOP64;

                     executeSetLL                  <= decodeSetLL;

                     if (decodeERET = '1') then
                        llBit <= '0';
                     elsif (EXEExceptionMem = '0') then
                        if (decodeResetLL = '1') then
                           llBit <= '0';
                        elsif (decodeSetLL = '1') then
                           llBit <= '1';
                        end if;
                     end if;

                     executeMemUseCache <= '0';
                     if (EXETLBDataAccess = '1') then
                        if (TLB_dataUseCacheFound = '1' and DATACACHEON_intern = '1') then
                           executeMemUseCache <= DATACACHETLBON_intern;
                        end if;
                     else
                        if (to_integer(unsigned(calcMemAddr(31 downto 29))) = 4 and privilegeMode = "00" and DATACACHEON_intern = '1') then
                           executeMemUseCache <= '1';
                        end if;
                     end if;

                     executeICacheEnable           <= decodeCacheEnable;
                     executeDCacheEnable           <= decodeCacheEnable;
                     executeCacheCommand           <= decodeSource2;
                     
                     if (DATACACHEON_intern = '0' or (DATACACHETLBON_intern = '0' and EXETLBDataAccess = '1')) then
                        executeDCacheEnable <= '0';
                     end if;
                     
                     execute_TLBR                  <= decodeTLBR; 
                     execute_TLBWI                 <= decodeTLBWI;
                     execute_TLBWR                 <= decodeTLBWR;
                     execute_TLBP                  <= decodeTLBP; 
                     
                     -- new mul/div
                     if (decodecalcMULT = '1') then
                        hilocalc <= HILOCALC_MULT;
                        mulsign  <= '1';
                        mul1     <= std_logic_vector(resize(signed(value1(31 downto 0)), 64));
                        mul2     <= std_logic_vector(resize(signed(value2(31 downto 0)), 64));
                        hiloWait <= 4;
                        stall3   <= '1';
                     end if;
                     
                     if (decodecalcMULTU = '1') then
                        hilocalc <= HILOCALC_MULTU;
                        mulsign  <= '0';
                        mul1     <= x"00000000" & std_logic_vector(value1(31 downto 0));
                        mul2     <= x"00000000" & std_logic_vector(value2(31 downto 0));
                        hiloWait <= 4;
                        stall3   <= '1';
                     end if;
                     
                     if (decodecalcDMULT = '1') then
                        hilocalc <= HILOCALC_DMULT;
                        mulsign  <= '1';
                        mul1     <= std_logic_vector(value1);
                        mul2     <= std_logic_vector(value2);
                        hiloWait <= 7;
                        stall3   <= '1';
                     end if;
                     
                     if (decodecalcDMULTU = '1') then
                        hilocalc <= HILOCALC_DMULTU;
                        mulsign  <= '0';
                        mul1     <= std_logic_vector(value1);
                        mul2     <= std_logic_vector(value2);
                        hiloWait <= 7;
                        stall3   <= '1';
                     end if;
                     
                     if (decodeFPUMULS = '1') then
                        mulsign  <= '0';
                        mul1 <= 40x"0" & '0' & std_logic_vector(decodeFPUValue1(22 downto 0));
                        mul2 <= 40x"0" & '0' & std_logic_vector(decodeFPUValue2(22 downto 0));
                        if (decodeFPUValue1(30 downto 23) > 0) then mul1(23) <= '1'; end if;
                        if (decodeFPUValue2(30 downto 23) > 0) then mul2(23) <= '1'; end if;
                     end if;
                     
                     if (decodeFPUMULD = '1') then
                        mulsign  <= '0';
                        mul1 <= 11x"0" & '0' & std_logic_vector(decodeFPUValue1(51 downto 0));
                        mul2 <= 11x"0" & '0' & std_logic_vector(decodeFPUValue2(51 downto 0));
                        if (decodeFPUValue1(62 downto 52) > 0) then mul1(52) <= '1'; end if;
                        if (decodeFPUValue2(62 downto 52) > 0) then mul2(52) <= '1'; end if;
                     end if;
                     
                     if (decodecalcDIV = '1') then
                        DIVis32     <= '1';
                        hiloWait    <= 36;
                        stall3      <= '1';
                        DIVdividend <= resize(signed(value1(31 downto 0)), 65);
                        DIVdivisor  <= resize(signed(value2(31 downto 0)), 65);
                        hilocalc    <= HILOCALC_DIV;
                        DIVstart    <= '1';
                     end if;
                     
                      if (decodecalcDDIV = '1') then
                        DIVis32     <= '0';
                        hiloWait    <= 68;
                        stall3      <= '1';
                        DIVdividend <= resize(signed(value1), 65);
                        DIVdivisor  <= resize(signed(value2), 65);
                        hilocalc    <= HILOCALC_DDIV;
                        DIVstart    <= '1';
                     end if;
                     
                     if (decodecalcDIVU = '1') then
                        DIVis32     <= '1';
                        hiloWait    <= 36;
                        stall3      <= '1';
                        DIVdividend <= '0' & x"00000000" & signed(value1(31 downto 0));
                        DIVdivisor  <= '0' & x"00000000" & signed(value2(31 downto 0));
                        hilocalc    <= HILOCALC_DIVU;
                        DIVstart    <= '1';
                     end if;
                     
                     if (decodecalcDDIVU = '1') then
                        DIVis32     <= '0';
                        hiloWait    <= 68;
                        stall3      <= '1';
                        DIVdividend <= '0' & signed(value1);
                        DIVdivisor  <= '0' & signed(value2);
                        hilocalc    <= HILOCALC_DDIVU;
                        DIVstart    <= '1';
                     end if;
                     
                     if (decodehiUpdate = '1') then hi <= value1; end if;
                     if (decodeloUpdate = '1') then lo <= value1; end if;
                     
                     if ((EXEExceptionMem = '0' and decodeMemReadEnable = '1') or decodeCOP0ReadEnable = '1' or decodeCOP2ReadEnable = '1') then
                        stall3              <= '1';
                        executeStallFromMEM <= '1';
                     end if;
                     
                     if (FPU_command_ena = '1' and FPU_command_done = '0') then
                        stall3 <= '1';
                     end if;
                     
                     if (decFPUForwardUse = '1') then
                        stall3 <= '1';
                        if (FPU_command_done = '1' or FPU_command_ena = '0') then
                           execute_unstallFPUForward <= '1';
                        end if;
                     end if;
                        
                     if (TLB_dataStall = '1') then
                        stall3              <= '1';
                        executeStallFromMEM <= '0';
                     end if; 
                     
                  end if;
                  
               end if;
               
               
            end if;

         end if;
         
      end if;
   end process;
   
   
--##############################################################
--############################### stage 4
--##############################################################

   cache_commandEnableD <= executeDCacheEnable when (stall = 0) else '0';

   icpu_datacache : entity work.cpu_datacache
   port map
   (
      clk1x             => clk1x,
      clk93             => clk93,
      clk2x             => clk2x,
      reset_93          => reset_93,
      ce_93             => ce_93,
      stall             => stall,
      stall4            => stall4,
      fifo_block        => writefifo_block,
      
      slow_in           => DATACACHESLOW,
      force_wb_in       => DATACACHEFORCEWEB,
      
      ram_request       => datacache_request,
      ram_reqAddr       => datacache_reqAddr,
      ram_active        => datacache_active,
      ram_grant         => rdram_granted2X,
      ram_done          => mem_finished_read,
      ddr3_DOUT         => ddr3_DOUT,      
      ddr3_DOUT_READY   => ddr3_DOUT_READY,
      
      writeback_ena     => datacache_wb_ena,  
      writeback_addr    => datacache_wb_addr, 
      writeback_data    => datacache_wb_data,
      
      tag_addr          => EXECacheAddr,
      
      read_ena          => datacache_readena,
      RW_addr           => datacache_addr,
      RW_64             => executeMem64Bit,
      read_busy         => datacache_readbusy,
      read_done         => datacache_readdone,
      read_data         => datacache_data_out,
      
      write_ena         => datacache_writeena,
      write_be          => executeMemWriteMask,
      write_data        => std_logic_vector(executeMemWriteData),
      write_done        => datacache_writedone,
      
      CacheCommandEna   => cache_commandEnableD,
      CacheCommand      => executeCacheCommand,
      CachecommandStall => datacache_CmdStall,
      CachecommandDone  => datacache_CmdDone,    
      
      TagLo_Valid       => TagLo_Valid,
      TagLo_Dirty       => TagLo_Dirty,
      TagLo_Addr        => TagLo_Addr, 
      
      writeTagEna       => writeDatacacheTagEna,      
      writeTagValue     => writeDatacacheTagValue,
      
      SS_reset          => SS_reset
   );

   stall4Masked <= stall(4 downto 3) & (stall(2) and (not executeStallFromMEM)) & stall(1 downto 0);
   
   process (all)
      variable skipmem : std_logic;
   begin
   
      stallNew4            <= stall4;
            
      mem4_request         <= '0';
      mem4_req64           <= executeMem64Bit;
      mem4_address         <= executeMemAddress;
      mem4_rnw             <= '1';
      mem4_dataWrite       <= std_logic_vector(executeMemWriteData);
      mem4_writeMask       <= executeMemWriteMask;
      
      datacache_writeena   <= '0';
      datacache_readena    <= '0';
      
      datacache_addr   <= executeMemAddress;
      if (executeMemReadEnable = '1') then
         if (executeLoadType = LOADTYPE_LEFT or executeLoadType = LOADTYPE_RIGHT) then 
            datacache_addr(1 downto 0) <= "00";
         end if;
         if (executeLoadType = LOADTYPE_LEFT64 or executeLoadType = LOADTYPE_RIGHT64) then 
            datacache_addr(2 downto 0) <= "000";
         end if;
      end if;
      
      -- ############
      -- Load/Store
      -- ############
      
      if (stall4Masked = 0 and executeNew = '1') then
      
         if (executeMemWriteEnable = '1') then
            skipmem := '0';
         
            if (executeMemUseCache = '1') then
               datacache_writeena <= '1';
               skipmem            := '1';
               if (datacache_writedone = '0') then
                  stallNew4      <= '1';
               end if;
            end if;
            
            if (skipmem = '0') then
               mem4_request   <= '1';
               if (writefifo_block = '1') then
                  stallNew4      <= '1';
               end if;
            end if;
            
            mem4_rnw       <= '0';
            if (executeMem64Bit = '1') then
               mem4_address(2 downto 0) <= "000";
            else
               mem4_address(1 downto 0) <= "00";
            end if;
         
         end if;
         
         if (executeMemReadEnable = '1') then
            skipmem := '0';
            
            if (executeMemUseCache = '1') then
               datacache_readena  <= '1';
               skipmem            := '1';
               if (datacache_readdone = '0') then
                  stallNew4      <= '1';
               end if;
            end if;

            if (skipmem = '0') then
               mem4_request   <= '1';
               stallNew4      <= '1';
            end if;
            
            if (executeLoadType = LOADTYPE_LEFT or executeLoadType = LOADTYPE_RIGHT) then 
               mem4_address(1 downto 0) <= "00";
            end if;
            if (executeLoadType = LOADTYPE_LEFT64 or executeLoadType = LOADTYPE_RIGHT64) then 
               mem4_address(2 downto 0) <= "000";
            end if;
         
         end if;
         
      end if;
      
   end process;
   
   read4_dataReadData   <= unsigned(datacache_data_out) when (writeback_UseCache = '1' or datacache_readena = '1') else unsigned(mem_finished_dataRead);
   read4_dataReadRot64  <= byteswap32(read4_dataReadData(31 downto 0)) & byteswap32(read4_dataReadData(63 downto 32));
   read4_dataReadRot32  <= byteswap32(read4_dataReadData(31 downto 0));
   
   read4_Addr         <= writebackReadAddress         when (stall4 = '1') else executeMemAddress;
   read4_oldData      <= writebackReadLastData        when (stall4 = '1') else executeMemReadLastData;
   read4_cop1_readEna <= writeback_COP1_ReadEnable    when (stall4 = '1') else executeCOP1ReadEnable;
   read4_cop1_target  <= cop1_stage4_target           when (stall4 = '1') else executeCOP1Target;
   read4_useLoadType  <= writebackLoadType            when (stall4 = '1') else executeLoadType;       
   read4_useTarget    <= writebackTarget              when (stall4 = '1') else resultTarget;
   
   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         DATACACHEON_intern    <= DATACACHEON;
         DATACACHETLBON_intern <= DATACACHETLBON;
      
         if (reset_93 = '1') then
         
            stall4                           <= '0';
            writebackNew                     <= '0';
            writebackStallFromMEM            <= '0';                  
            writebackWriteEnable             <= '0';
            cop1_stage4_writeEnable          <= '0';
            COP2Latch                        <= (others => '0');
            
         elsif (ce_93 = '1') then
         
            stall4                  <= stallNew4;    
            
            cop1_stage4_writeEnable <= '0';

            if (stall4Masked = 0) then
            
               writebackNew   <= '0';
               
               writebackForwardValue1 <= '0';
               writebackForwardValue2 <= '0';
            
               if (executeNew = '1') then
               
                  writebackStallFromMEM        <= executeStallFromMEM;
               
-- synthesis translate_off
                  pcOld3                       <= pcOld2;
                  opcode3                      <= opcode2;
                  hi_1                         <= hi;
                  lo_1                         <= lo;
-- synthesis translate_on
               
                  writebackTarget              <= resultTarget;
                  writebackData                <= resultData;
                  writebackReadLastData        <= executeMemReadLastData;

                  writebackWriteEnable         <= resultWriteEnable;
                  writeback_UseCache           <= datacache_readena or datacache_writeena or executeDCacheEnable;
                  
                  writeback_COP1_ReadEnable    <= executeCOP1ReadEnable;
                  cop1_stage4_target           <= executeCOP1Target;
                  
                  writeback_fifoStall          <= '0';
                  
                  -- check if last command must be forwarded
                  if (resultWriteEnable = '1') then
                     if (decSource1 > 0 and resultTarget = decSource1) then writebackForwardValue1 <= '1'; end if;
                     if (decSource2 > 0 and resultTarget = decSource2) then writebackForwardValue2 <= '1'; end if;
                  end if;
                  
                  if (executeMemReadEnable = '1' and executeCOP1ReadEnable = '0') then
                     if (decodeSource1 > 0 and resultTarget = decodeSource1) then writebackForwardValue1 <= '1'; end if;
                     if (decodeSource2 > 0 and resultTarget = decodeSource2) then writebackForwardValue2 <= '1'; end if;
                  end if;
                  
                  if (executeMemWriteEnable = '1') then
                  
                     if (mem4_request = '1' and writefifo_block = '1') then
                        writeback_fifoStall <= '1';
                     else
                        writebackNew        <= '1';
                     end if;
                  
                  elsif (executeMemReadEnable = '1') then
                  
                     writebackLoadType       <= executeLoadType;
                     writebackReadAddress    <= executeMemAddress;

                  else

                     writebackNew         <= '1';
                     
                  end if;
                  
                  if (executeCOP0ReadEnable = '1') then
                     if (resultTarget > 0) then
                        writebackWriteEnable <= '1';
                     end if;
                     
                     if (executeCOP64 = '1') then
                        writebackData <= COP0ReadValue;
                     else
                        writebackData <= unsigned(resize(signed(COP0ReadValue(31 downto 0)), 64));
                     end if;
                  end if;
                  
                  if (executeCOP2ReadEnable = '1') then
                     if (resultTarget > 0) then
                        writebackWriteEnable <= '1';
                     end if;
                     
                     if (executeCOP64 = '1') then
                        writebackData <= COP2Latch;
                     else
                        writebackData <= unsigned(resize(signed(COP2Latch(31 downto 0)), 64));
                     end if;
                  end if;
                  
                  if (executeCOP2WriteEnable = '1') then
                     COP2Latch <= executeMemReadLastData;
                  end if;

                  if (datacache_CmdStall = '1') then
                     stall4 <= '1';
                  end if;
                  
                  if (execute_TLBP = '1') then
                     stall4 <= '1';
                  end if;

               end if;
               
            end if; -- stall4Masked
            
            if (datacache_CmdDone = '1') then
               stall4        <= '0';
               writebackNew  <= '1';
            end if;
            
            if (TLBDone = '1') then
               stall4        <= '0';
               writebackNew  <= '1';
            end if;
            
            if (writeback_fifoStall = '1' and writefifo_cnt = 4 and writefifo_wr = '0') then
               stall4              <= '0';
               writebackNew        <= '1';
               writeback_fifoStall <= '0';
            end if;
            
            if (datacache_writedone = '1') then
               stall4        <= '0';
               writebackNew  <= '1';
            end if;
            
            if ((writeback_UseCache = '0' and mem_finished_read = '1') or datacache_readdone = '1') then
            
               stall4             <= '0';
               writebackNew       <= '1';
               
               if (read4_cop1_readEna = '1') then
                  cop1_stage4_writeEnable <= '1';
                  if (fpuRegMode = '0') then
                     cop1_stage4_target(0) <= '0';
                  end if;
               end if;
               
               if (read4_useTarget > 0 and read4_cop1_readEna = '0') then
                  writebackWriteEnable <= '1';
               end if;
               
            end if; -- mem_finished_read
            
            if ((writeback_UseCache = '0' and mem_finished_read = '1') or datacache_readena = '1' or datacache_readbusy = '1') then
               
               cop1_stage4_data <= byteswap32(read4_dataReadData(31 downto 0)) & byteswap32(read4_dataReadData(63 downto 32));
               
               cop1_stage4_writeMask   <= "11";
               if (fpuRegMode = '1') then
                  if (read4_useLoadType = LOADTYPE_DWORD) then
                     cop1_stage4_data(31 downto 0) <= byteswap32(read4_dataReadData(31 downto 0));
                     cop1_stage4_writeMask         <= "01";
                  end if;
               else
                  if (read4_useLoadType = LOADTYPE_DWORD) then
                     if (read4_cop1_target(0) = '1') then
                        cop1_stage4_data(63 downto 32) <= byteswap32(read4_dataReadData(31 downto 0));
                        cop1_stage4_writeMask          <= "10";
                     else
                        cop1_stage4_data(31 downto 0) <= byteswap32(read4_dataReadData(31 downto 0));
                        cop1_stage4_writeMask         <= "01";
                     end if;
                  end if;
               end if;
               
               case (read4_useLoadType) is
                  
                  when LOADTYPE_SBYTE => writebackData <= unsigned(resize(signed(read4_dataReadData(7 downto 0)), 64));
                  when LOADTYPE_SWORD => writebackData <= unsigned(resize(signed(byteswap16(read4_dataReadData(15 downto 0))), 64));
                  when LOADTYPE_LEFT =>
                     case (to_integer(read4_Addr(1 downto 0))) is
                        when 3 => writebackData <= unsigned(resize(signed(read4_dataReadRot32( 7 downto 0)) & signed(read4_oldData(23 downto 0)), 64));
                        when 2 => writebackData <= unsigned(resize(signed(read4_dataReadRot32(15 downto 0)) & signed(read4_oldData(15 downto 0)), 64));
                        when 1 => writebackData <= unsigned(resize(signed(read4_dataReadRot32(23 downto 0)) & signed(read4_oldData( 7 downto 0)), 64)); 
                        when 0 => writebackData <= unsigned(resize(signed(read4_dataReadRot32(31 downto 0)), 64));
                        when others => null;
                     end case;
                        
                  when LOADTYPE_DWORD  => writebackData <= unsigned(resize(signed(byteswap32(read4_dataReadData(31 downto 0))), 64));
                  when LOADTYPE_DWORDU => writebackData <= x"00000000" & byteswap32(read4_dataReadData(31 downto 0));
                  when LOADTYPE_BYTE  => writebackData <= x"00000000" & x"000000" & read4_dataReadData(7 downto 0);
                  when LOADTYPE_WORD  => writebackData <= x"00000000" & x"0000" & byteswap16(read4_dataReadData(15 downto 0));
                  when LOADTYPE_RIGHT =>
                     case (to_integer(read4_Addr(1 downto 0))) is
                        when 3 => writebackData <= unsigned(resize(signed(read4_dataReadRot32(31 downto 0)), 64));
                        when 2 => writebackData <= unsigned(resize(signed(read4_oldData(31 downto 24)) & signed(read4_dataReadRot32(31 downto  8)), 64));
                        when 1 => writebackData <= unsigned(resize(signed(read4_oldData(31 downto 16)) & signed(read4_dataReadRot32(31 downto 16)), 64));
                        when 0 => writebackData <= unsigned(resize(signed(read4_oldData(31 downto  8)) & signed(read4_dataReadRot32(31 downto 24)), 64));
                        when others => null;
                     end case;
                     
                  when LOADTYPE_QWORD =>  writebackData <= byteswap32(read4_dataReadData(31 downto 0)) & byteswap32(read4_dataReadData(63 downto 32));
                  
                  when LOADTYPE_LEFT64 => 
                     case (to_integer(read4_Addr(2 downto 0))) is
                        when 7 => writebackData <= read4_dataReadRot64( 7 downto 0) & read4_oldData(55 downto 0);
                        when 6 => writebackData <= read4_dataReadRot64(15 downto 0) & read4_oldData(47 downto 0);
                        when 5 => writebackData <= read4_dataReadRot64(23 downto 0) & read4_oldData(39 downto 0);
                        when 4 => writebackData <= read4_dataReadRot64(31 downto 0) & read4_oldData(31 downto 0);
                        when 3 => writebackData <= read4_dataReadRot64(39 downto 0) & read4_oldData(23 downto 0);
                        when 2 => writebackData <= read4_dataReadRot64(47 downto 0) & read4_oldData(15 downto 0);
                        when 1 => writebackData <= read4_dataReadRot64(55 downto 0) & read4_oldData( 7 downto 0);
                        when 0 => writebackData <= read4_dataReadRot64;
                        when others => null;
                     end case;
                  
                  when LOADTYPE_RIGHT64 =>
                     case (to_integer(read4_Addr(2 downto 0))) is
                        when 7 => writebackData <= read4_dataReadRot64;
                        when 6 => writebackData <= read4_oldData(63 downto 56) & read4_dataReadRot64(63 downto  8);
                        when 5 => writebackData <= read4_oldData(63 downto 48) & read4_dataReadRot64(63 downto 16);
                        when 4 => writebackData <= read4_oldData(63 downto 40) & read4_dataReadRot64(63 downto 24);
                        when 3 => writebackData <= read4_oldData(63 downto 32) & read4_dataReadRot64(63 downto 32);
                        when 2 => writebackData <= read4_oldData(63 downto 24) & read4_dataReadRot64(63 downto 40);
                        when 1 => writebackData <= read4_oldData(63 downto 16) & read4_dataReadRot64(63 downto 48);
                        when 0 => writebackData <= read4_oldData(63 downto  8) & read4_dataReadRot64(63 downto 56);
                        when others => null;
                     end case;
                     
               end case; 
               
            end if; -- mem_read

         end if; -- ce
         

      end if;
   end process;
   
   
--##############################################################
--############################### stage 5
--##############################################################
   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
-- synthesis translate_off
         cpu_done <= '0';
-- synthesis translate_on
         
         --debugTmr <= debugTmr + 1;

         if (reset_93 = '1') then
            
            --debugCnt             <= (others => '0');
            --debugSum             <= (others => '0');
            --debugTmr             <= (others => '0');
         
         elsif (ce_93 = '1') then
            
            if (stall4Masked = 0 and writebackNew = '1') then
            
-- synthesis translate_off
               pcOld4               <= pcOld3;
               opcode4              <= opcode3;
               hi_2                 <= hi_1;
               lo_2                 <= lo_1;
-- synthesis translate_on
               
               -- export
               if (writebackWriteEnable = '1') then 
                  if (writebackTarget > 0) then
-- synthesis translate_off
                     regs(to_integer(writebackTarget)) <= writebackData;
-- synthesis translate_on
                     --debugSum <= debugSum + writebackData(31 downto 0);
                  end if;
               end if;
               --debugCnt          <= debugCnt + 1;
-- synthesis translate_off

               cpu_done          <= '1';
               cpu_export.pc     <= pcOld4;
               cpu_export.opcode <= opcode4;
               cpu_export.hi     <= hi_2;
               cpu_export.lo     <= lo_2;
               for i in 0 to 31 loop
                  cpu_export.regs(i)    <= regs(i);
                  cpu_export.FPUregs(i) <= FPUregs(i);
               end loop;
               cop0_export_1       <= cop0_export;
               cpu_export.cop0regs <= cop0_export_1;
               
               csr_export_1        <= csr_export;
               csr_export_2        <= csr_export_1;
               cpu_export.csr      <= 7x"0" & csr_export_2;
               
-- synthesis translate_on
               --debugwrite <= '0';
               --if (debugCnt(31) = '1' and debugSum(31) = '1' and debugTmr(31) = '1' and writebackTarget = 0) then
               --   debugwrite <= '1';
               --end if;
               
            end if;
             
         end if;
         
         -- export
-- synthesis translate_off
         if (ss_regs_load = '1') then
            regs(to_integer(ss_regs_addr)) <= unsigned(ss_regs_data);
         end if;          
         if (ss_FPUregs_load = '1') then
            FPUregs(to_integer(ss_FPUregs_addr)) <= unsigned(ss_FPUregs_data);
         end if; 
         
         if (FPUregs_wren_a(0) = '1') then
            FPUregs(to_integer(unsigned(FPUregs_address_a)))(31 downto 0) <= unsigned(FPUregs_data_a(31 downto 0));
         end if;        
         
         if (FPUregs_wren_a(1) = '1') then
            FPUregs(to_integer(unsigned(FPUregs_address_a)))(63 downto 32) <= unsigned(FPUregs_data_a(63 downto 32));
         end if;
-- synthesis translate_on
         
      end if;
   end process;

--##############################################################
--############################### submodules
--##############################################################
   
   
   icop0 : entity work.cpu_cop0
   port map
   (
      clk93                   => clk93,
      ce                      => ce_93,   
      stall                   => stall,
      stall4Masked            => stall4Masked,
      executeNew              => executeNew,
      reset                   => reset_93,
      
      RANDOMMISS              => RANDOMMISS,
      DISABLE_BOOTCOUNT       => DISABLE_BOOTCOUNT,
      DISABLE_DTLBMINI        => DISABLE_DTLBMINI, 
            
      error_exception         => error_exception,
      error_TLB               => error_TLB,
      
      irqRequest              => irqRequest,
      irqTrigger              => irqTrigger,
      decode_irq              => decode_irq,

-- synthesis translate_off
      cop0_export             => cop0_export,
-- synthesis translate_on

      eret                    => execute_ERET,
      exception3              => exceptionNew3,
      exceptionNewPC          => exceptionNewPC,
      exceptionPCStore        => value1,
      exceptionFPU            => exceptionFPU,
      exceptionCode_1         => "0000", -- todo
      exceptionCode_3         => exceptionCode_3,
      exception_COP           => exception_COP,
      isDelaySlot             => executeBranchdelaySlot,
      nextDelaySlot           => EXECOPBranchDelaySlot,
      pcOld1                  => PCold1,
            
      eretPC                  => eretPC,
      exceptionPC             => exceptionPC,
      exception               => exception,   
      exceptionStage1         => exceptionStage1,   
            
      COP1_enable             => COP1_enable,
      COP2_enable             => COP2_enable,
      fpuRegMode              => fpuRegMode,
      privilegeMode           => privilegeMode,
      bit64region             => bit64region,
      
      writeEnable             => executeCOP0WriteEnable,
      regIndex                => executeCOP0Register,
      writeValue              => executeCOP0WriteValue,
      readValue               => COP0ReadValue,
      
      executeSetLL            => executeSetLL,
      executeLLfromTLB        => executeLLfromTLB,
      executeLLAddr           => executeMemAddress,
      
      TagLo_Valid             => TagLo_Valid,
      TagLo_Dirty             => TagLo_Dirty,
      TagLo_Addr              => TagLo_Addr, 
      
      writeDatacacheTagEna    => writeDatacacheTagEna,      
      writeDatacacheTagValue  => writeDatacacheTagValue,
            
      TLBR                    => execute_TLBR,  
      TLBWI                   => execute_TLBWI, 
      TLBWR                   => execute_TLBWR, 
      TLBP                    => execute_TLBP,  
      TLBDone                 => TLBDone,
            
      TLB_instrReq            => TLB_instrReq,
      TLB_ss_load             => TLB_ss_load,
      TLB_instrAddrIn         => FetchAddr,
      TLB_instrUseCache       => TLB_instrUseCache,
      TLB_instrStall          => TLB_instrStall,
      TLB_instrUnStall        => TLB_instrUnStall,
      TLB_instrAddrOutFound   => TLB_instrAddrOutFound,
      TLB_instrAddrOutLookup  => TLB_instrAddrOutLookup,
      
      TLB_dataReq             => EXETLBDataAccess,   
      TLB_dataIsWrite         => decodeMemWriteEnable or decodeMemWriteLL,   
      TLB_dataAddrIn          => calcMemAddr,
      TLB_dataUseCacheFound   => TLB_dataUseCacheFound,
      TLB_dataUseCacheLookup  => TLB_dataUseCacheLookup,
      TLB_dataStall           => TLB_dataStall,
      TLB_dataUnStall         => TLB_dataUnStall,
      TLB_dataAddrOutFound    => TLB_dataAddrOutFound,
      TLB_dataAddrOutLookup   => TLB_dataAddrOutLookup,
            
      SS_reset                => SS_reset,    
      loading_savestate       => loading_savestate,    
      SS_DataWrite            => SS_DataWrite,
      SS_Adr                  => SS_Adr,      
      SS_wren_CPU             => SS_wren_CPU, 
      SS_rden_CPU             => SS_rden_CPU 
   );
   
   icpu_mul : entity work.cpu_mul
   port map
   (
      clk       => clk93,
      sign      => mulsign,
      value1_in => mul1,
      value2_in => mul2,
      result    => mulResult
   );
   
   idivider : entity work.divider
   port map
   (
      clk       => clk93,      
      start     => DIVstart,
      is32      => DIVis32,
      done      => open,      
      busy      => open,
      dividend  => DIVdividend, 
      divisor   => DIVdivisor,  
      quotient  => DIVquotient, 
      remainder => DIVremainder
   );
   
   icpu_FPU : entity work.cpu_FPU
   port map
   (
      clk93             => clk93,         
      reset             => reset_93, 
      error_FPU         => error_FPU,
      
      -- synthesis translate_off
      csr_export        => csr_export,
      -- synthesis translate_on
      
      fpuRegMode        => fpuRegMode,      
                                         
      command_ena       => FPU_command_ena,
      command_code      => opcode1,  
      command_op1       => decodeFPUValue1,  
      command_op2       => decodeFPUValue2,   
      command_done      => FPU_command_done,
      
      transfer_ena      => FPU_TransferEna,
      transfer_code     => decodeSource1(3 downto 0),
      transfer_RD       => decodeRD,
      transfer_value    => value2,
      transfer_data     => FPU_TransferData,
      
      mul_result        => unsigned(mulResult),
      
      exceptionFPU      => exceptionFPU,
      FPU_CF            => FPU_CF,
                                      
      FPUWriteTarget    => FPUWriteTarget,
      FPUWriteData      => FPUWriteData,  
      FPUWriteEnable    => FPUWriteEnable,
      FPUWriteMask      => FPUWriteMask,
      
      SS_FPU_CF         => ss_in(24)(32),
      SS_CSR            => unsigned(ss_in(24)(24 downto 0))
   );
   
--##############################################################
--############################### savestates
--##############################################################

   SS_idle <= '1';

   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         ss_regs_load    <= '0';
         ss_FPUregs_load <= '0';
      
         if (SS_reset = '1') then
         
            for i in 0 to 31 loop
               ss_in(i) <= (others => '0');
            end loop;
            
            ss_in(0)  <= x"FFFFFFFFBFC00000"; -- PC
            
            ss_regs_loading <= '1';
            ss_regs_addr    <= (others => '0');
            ss_regs_data    <= (others => '0');
            ss_FPUregs_addr <= (others => '0');
            ss_FPUregs_data <= (others => '0');
            
         elsif (SS_wren_CPU = '1' and SS_Adr < 32) then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         elsif (SS_wren_CPU = '1' and SS_Adr >= 32 and SS_Adr < 64) then
            ss_regs_load <= '1';
            ss_regs_addr <= SS_Adr(4 downto 0);
            ss_regs_data <= SS_DataWrite;
         elsif (SS_wren_CPU = '1' and SS_Adr >= 96 and SS_Adr < 128) then
            ss_FPUregs_load <= '1';
            ss_FPUregs_addr <= SS_Adr(4 downto 0);
            ss_FPUregs_data <= SS_DataWrite;
         end if;
         
         if (ss_regs_loading = '1') then
            ss_regs_load    <= '1';
            ss_regs_addr    <= ss_regs_addr + 1;            
            ss_FPUregs_load <= '1';
            ss_FPUregs_addr <= ss_regs_addr + 1;
            if (ss_regs_addr = 31) then
               ss_regs_loading <= '0';
            end if;
         end if;
      
         --SS_idle <= '0';
         --if (hiloWait = 0 and blockIRQ = '0' and (irqRequest = '0' or cop0_SR(0) = '0') and mem_done = '0') then
         --   SS_idle <= '1';
         --end if;
      
         --regsSS_rden <= '0';
         --if (SS_rden_CPU = '1' and SS_Adr >= 32 and SS_Adr < 64) then
         --   regsSS_address_b <= std_logic_vector(SS_Adr(4 downto 0));
         --   regsSS_rden      <= '1';
         --end if;
         --
         --if (regsSS_rden = '1') then
         --   SS_DataRead_CPU <= regsSS_q_b;
         --elsif (SS_rden_CPU = '1' and SS_Adr < 31) then
         --   SS_DataRead_CPU <= ss_out(to_integer(SS_Adr));
         --end if;
      
      end if;
   end process;
   
   SS_DataRead_CPU <= (others => '0');
   
--##############################################################
--############################### debug
--##############################################################

   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         error_stall <= '0';
      
         if (reset_93 = '1') then
         
            debugStallcounter <= (others => '0');
            
-- synthesis translate_off
            stallcountNo      <= 0;
            stallcount1       <= 0;
            stallcount3       <= 0;
            stallcount4       <= 0;
            stallcountDMA     <= 0;
-- synthesis translate_on
      
         elsif (ce_93 = '1') then
         
            if (stall = 0) then
               debugStallcounter <= (others => '0');
            elsif (cpuPaused = '0') then  
               debugStallcounter <= debugStallcounter + 1;
            end if;         
            
            --if (debugStallcounter(12) = '1' and debugwrite = '0') then
            if (debugStallcounter(12) = '1') then
               error_stall       <= '1';
            end if;
            
-- synthesis translate_off
            
            if (stallcountNo = 0 and stallcount4 = 0 and stallcount3 = 0 and stallcount1 = 0 and stallcountDMA = 0) then
               stallcountNo <= 0;
            end if;
            
            -- performance counters
            if (stall = 0) then
               stallcountNo <= stallcountNo + 1;
            elsif (stall4 = '1') then
               stallcount4 <= stallcount4 + 1;
            elsif (stall3 = '1') then
               stallcount3 <= stallcount3 + 1;
            elsif (stall1 = '1') then
               stallcount1 <= stallcount1 + 1;
            end if;
            
         else
            
            stallcountDMA <= stallcountDMA + 1;
            
-- synthesis translate_on
            
         end if;
         
      end if;
   end process;
   
   

end architecture;





