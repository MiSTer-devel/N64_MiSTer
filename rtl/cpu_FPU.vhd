library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;    
use STD.textio.all;

entity cpu_FPU is
   port 
   (
      clk93             : in  std_logic;
      reset             : in  std_logic;
      error_FPU         : out std_logic := '0';
      
      -- synthesis translate_off
      csr_export       : out unsigned(24 downto 0);
      -- synthesis translate_on
      
      fpuRegMode        : in  std_logic;

      command_ena       : in  std_logic;
      command_code      : in  unsigned(31 downto 0);
      command_op1       : in  unsigned(63 downto 0);
      command_op2       : in  unsigned(63 downto 0);
      command_done      : out std_logic := '0';
      
      transfer_ena      : in  std_logic;
      transfer_code     : in  unsigned(3 downto 0);
      transfer_RD       : in  unsigned(4 downto 0);
      transfer_value    : in  unsigned(63 downto 0);
      transfer_data     : out unsigned(63 downto 0);
      
      mul_result        : in  unsigned(127 downto 0);
      
      exceptionFPU      : out std_logic := '0';
      FPU_CF            : out std_logic := '0';
      
      FPUWriteTarget    : out unsigned(4 downto 0) := (others => '0');
      FPUWriteData      : out unsigned(63 downto 0) := (others => '0');
      FPUWriteEnable    : out std_logic := '0';
      FPUWriteMask      : out std_logic_vector(1 downto 0) := (others => '0');
      
      SS_FPU_CF         : in  std_logic;
      SS_CSR            : in  unsigned(24 downto 0)
   );
end entity;

architecture arch of cpu_FPU is
   
   constant OP_ADD      : unsigned(5 downto 0) := 6x"00";
   constant OP_SUB      : unsigned(5 downto 0) := 6x"01";
   constant OP_MUL      : unsigned(5 downto 0) := 6x"02";
   constant OP_DIV      : unsigned(5 downto 0) := 6x"03";
   constant OP_SQRT     : unsigned(5 downto 0) := 6x"04";
   constant OP_ABS      : unsigned(5 downto 0) := 6x"05";
   constant OP_MOV      : unsigned(5 downto 0) := 6x"06";
   constant OP_NEG      : unsigned(5 downto 0) := 6x"07";
   constant OP_ROUND_L  : unsigned(5 downto 0) := 6x"08";
   constant OP_TRUNC_L  : unsigned(5 downto 0) := 6x"09";
   constant OP_CEIL_L   : unsigned(5 downto 0) := 6x"0A";
   constant OP_FLOOR_L  : unsigned(5 downto 0) := 6x"0B";
   constant OP_ROUND_W  : unsigned(5 downto 0) := 6x"0C";
   constant OP_TRUNC_W  : unsigned(5 downto 0) := 6x"0D";
   constant OP_CEIL_W   : unsigned(5 downto 0) := 6x"0E";
   constant OP_FLOOR_W  : unsigned(5 downto 0) := 6x"0F";
   constant OP_CVT_S    : unsigned(5 downto 0) := 6x"20";
   constant OP_CVT_D    : unsigned(5 downto 0) := 6x"21";
   constant OP_CVT_W    : unsigned(5 downto 0) := 6x"24";
   constant OP_CVT_L    : unsigned(5 downto 0) := 6x"25";
   constant OP_C_F      : unsigned(5 downto 0) := 6x"30";
   constant OP_C_UN     : unsigned(5 downto 0) := 6x"31";
   constant OP_C_EQ     : unsigned(5 downto 0) := 6x"32";
   constant OP_C_UEQ    : unsigned(5 downto 0) := 6x"33";
   constant OP_C_OLT    : unsigned(5 downto 0) := 6x"34";
   constant OP_C_ULT    : unsigned(5 downto 0) := 6x"35";
   constant OP_C_OLE    : unsigned(5 downto 0) := 6x"36";
   constant OP_C_ULE    : unsigned(5 downto 0) := 6x"37";
   constant OP_C_SF     : unsigned(5 downto 0) := 6x"38";
   constant OP_C_NGLE   : unsigned(5 downto 0) := 6x"39";
   constant OP_C_SEQ    : unsigned(5 downto 0) := 6x"3A";
   constant OP_C_NGL    : unsigned(5 downto 0) := 6x"3B";
   constant OP_C_LT     : unsigned(5 downto 0) := 6x"3C";
   constant OP_C_NGE    : unsigned(5 downto 0) := 6x"3D";
   constant OP_C_LE     : unsigned(5 downto 0) := 6x"3E";
   constant OP_C_NGT    : unsigned(5 downto 0) := 6x"3F";
   
   constant INT64_MAX   : signed(63 downto 0)  := x"0080000000000000";
   constant INT64_MIN   : signed(63 downto 0)  := x"FF80000000000000";
   
   signal csr     : unsigned(24 downto 0) := (others => '0'); 
   alias csr_roundmode              is csr(1 downto 0);
   alias csr_flag_inexact           is csr(2);
   alias csr_flag_underflow         is csr(3);
   alias csr_flag_overflow          is csr(4);
   alias csr_flag_divisionByZero    is csr(5);
   alias csr_flag_invalidOperation  is csr(6);
   alias csr_ena_inexact            is csr(7);
   alias csr_ena_underflow          is csr(8);
   alias csr_ena_overflow           is csr(9);
   alias csr_ena_divisionByZero     is csr(10);
   alias csr_ena_invalidOperation   is csr(11);
   alias csr_cause_inexact          is csr(12);
   alias csr_cause_underflow        is csr(13);
   alias csr_cause_overflow         is csr(14);
   alias csr_cause_divisionByZero   is csr(15);
   alias csr_cause_invalidOperation is csr(16);
   alias csr_cause_unimplemented    is csr(17);
   alias csr_compare                is csr(23);
   alias csr_flushSubnormals        is csr(24);
   
   signal bit64   : std_logic;
   signal OPgroup : unsigned(4 downto 0);
   signal OP      : unsigned(5 downto 0);
   
   signal causeReset          : std_logic;
   signal checkInputs_dn      : std_logic;
   signal checkInputs_nan     : std_logic;   
   signal checkInputs2_dn     : std_logic;
   signal checkInputs2_nan    : std_logic;
   signal outputInvalid       : std_logic;
   
   signal signA      : std_logic;
   signal signB      : std_logic;   
   signal expA       : unsigned(10 downto 0);
   signal expB       : unsigned(10 downto 0);   
   signal mantA      : unsigned(51 downto 0);
   signal mantB      : unsigned(51 downto 0);
   
   signal infA      : std_logic;
   signal infB      : std_logic;      
   signal nanA      : std_logic;
   signal nanB      : std_logic;   
   signal exp0A     : std_logic;
   signal exp0B     : std_logic;
   signal dnA       : std_logic;
   signal dnB       : std_logic;      
   signal zeroA     : std_logic;
   signal zeroB     : std_logic; 
   
   signal cmp_inputInvalid_a : std_logic;
   signal cmp_inputInvalid_b : std_logic;
   signal cmp_equal          : std_logic;
   signal cmp_lesser         : std_logic;

   -- calculation pipeline   
   signal flag_inexact     : std_logic := '0';
   signal flag_overflow    : std_logic := '0';
   signal flag_underflow   : std_logic := '0';
   signal flag_divbyzero   : std_logic := '0';
   
   signal signOut          : std_logic := '0';
   signal bit64Out         : std_logic := '0';
   signal roundmode_save   : unsigned(1 downto 0) := (others => '0');
   
   -- common stage 0
   signal bit64_1                         : std_logic := '0';
   signal signA_1                         : std_logic := '0';
   signal signB_1                         : std_logic := '0';  
   signal expA_1                          : unsigned(10 downto 0);
   signal mantA_1                         : unsigned(51 downto 0) := (others => '0');
   signal infA_1                          : std_logic := '0';
   signal infB_1                          : std_logic := '0';
   signal exp0A_1                         : std_logic := '0';
   signal zeroA_1                         : std_logic := '0';
   signal zeroB_1                         : std_logic := '0';
   signal outputInvalid_1                 : std_logic := '0';
   
   signal clz_value                       : unsigned(56 downto 0) := (others => '0');
   signal clz_result                      : integer range 0 to 56 := 0;
   signal exception_checkInputConvert2F   : std_logic := '0';
   signal exception_inputInvalid          : std_logic := '0';
   
   -- common left/right shifter
   signal shifter_right       : std_logic := '0';
   signal shifter_amount      : integer range -63 to 63 := 0;
   signal shifter_input       : unsigned(56 downto 0) := (others => '0');
   signal shifter_output      : unsigned(63 downto 0) := (others => '0');
   signal shifter_lostbits    : std_logic := '0';
   signal shifter_lostbits_in : std_logic := '0';
      
   -- common rounding   
   signal round_store         : std_logic := '0';
   signal sticky              : std_logic := '0';
   signal roundUp             : std_logic := '0';
   signal round_Mant          : unsigned(63 downto 0) := (others => '0');
   signal round_in_exp        : unsigned(10 downto 0) := (others => '0');
   signal round_out32_exp     : unsigned(7 downto 0) := (others => '0');
   signal round_out64_exp     : unsigned(10 downto 0) := (others => '0');
   signal round_out32_mant    : unsigned(22 downto 0) := (others => '0');
   signal round_out64_mant    : unsigned(51 downto 0) := (others => '0');
   signal round_inexact       : std_logic := '0';
   signal round_overflow      : std_logic := '0';
   
   signal overflow_overwrite  : std_logic := '0';
   signal underflow_overwrite : std_logic := '0';
   
   -- shortcuts, e.g. add/mul with zeros
   signal shortcut_store      : std_logic := '0';
   signal shortcut_exp        : unsigned(10 downto 0);
   signal shortcut_mant       : unsigned(51 downto 0);
   
   -- ADD
   signal ADD_start           : std_logic := '0';
   signal SUB_start           : std_logic := '0';
   signal ADD_stage1          : std_logic := '0';
   signal ADD_stage2          : std_logic := '0';
   signal ADD_useADD          : std_logic := '0';
   signal ADD_swapped         : std_logic := '0';
   signal ADD_AGrB            : std_logic := '0';
   signal ADD_exp_initial     : unsigned(10 downto 0);
   signal ADD_exp             : unsigned(10 downto 0);
   signal ADD_value1          : unsigned(55 downto 0);
   signal ADD_shift_value     : unsigned(55 downto 0);
   signal ADD_shift_result    : unsigned(55 downto 0);
   signal ADD_shift_result_or : unsigned(55 downto 0);
   signal ADD_shift_amount    : integer range -63 to 63 := 0;
   signal ADD_shift_lostbits  : std_logic;
   signal ADD_result          : unsigned(56 downto 0);
   signal ADD_leadingZeros    : integer range 0 to 56 := 0;
   
   -- MUL
   signal MUL_start           : std_logic := '0';
   signal MUL_stage1          : std_logic := '0';
   signal MUL_stage2          : std_logic := '0';
   signal mul_stage3          : std_logic := '0';
   signal MUL_exp_calc        : integer range -4095 to 4095 := 0;
   signal MUL_exp             : unsigned(10 downto 0);
   
   -- DIV
   signal DIV_start           : std_logic := '0';
   signal DIV_running         : std_logic := '0';
   signal DIV_done            : std_logic := '0';
   signal dividend            : unsigned(55 downto 0);
   signal divisor             : unsigned(55 downto 0);
   signal divremain           : unsigned(55 downto 0);
   signal quotient            : unsigned(55 downto 0);
   signal divstep             : integer range -1 to 63;
   signal DIV_complete        : std_logic := '1';
   signal DIV_exp_calc        : integer range -4095 to 4095 := 0;
   signal DIV_exp             : unsigned(10 downto 0);
   
   -- SQRT 
   signal SQRT_start          : std_logic := '0';
   signal SQRT_running        : std_logic := '0';
   signal SQRT_done           : std_logic := '0';
   signal SQRT_exp            : unsigned(10 downto 0);
   signal SQRT_startcalc      : std_logic;
   signal SQRT_complete       : std_logic;
   signal SQRT_lostbits       : std_logic;
   signal SQRT_result         : unsigned(54 downto 0);
   
   -- CDS
   signal CDS_start           : std_logic := '0';
   signal CDS_stage1          : std_logic := '0';
   signal CDS_exp             : integer range -2047 to 2047 := 0;
         
   -- CIS / CID      
   signal CIS_start           : std_logic := '0';
   signal CIS_stage1          : std_logic := '0';
   signal CID_start           : std_logic := '0';
   signal CID_stage1          : std_logic := '0';
   signal CISD_stage2         : std_logic := '0';
   signal CISD_stage3         : std_logic := '0';
   signal CID_exp             : integer range -2047 to 2047 := 0;
   signal CID_shift           : integer range -63 to 63 := 0;
         
   -- toInt    
   signal toInt_start         : std_logic := '0';
   signal toInt_stage1        : std_logic := '0';
   signal toInt_stage2        : std_logic := '0';
   signal toInt_store         : std_logic := '0';
   signal toInt_unimpl        : std_logic := '0';
   signal toInt_64            : std_logic := '0';
   signal toInt_limitExp      : unsigned(10 downto 0) := (others => '0');
   signal toInt_shift         : integer range -2047 to 2047 := 0;
   signal toInt_Result        : unsigned(63 downto 0);

   -- synthesis translate_off
   signal debug_calc_count : integer := 0;
   -- synthesis translate_on
   
begin 
   
   -- synthesis translate_off
   csr_export <= csr;
   -- synthesis translate_on
   
   FPU_CF <= csr_compare;
   

   bit64   <= command_code(21);
   OPgroup <= command_code(25 downto 21);
   OP      <= command_code( 5 downto  0);
   
   
   signA   <= command_op1(63) when (bit64 = '1') else command_op1(31);
   signB   <= command_op2(63) when (bit64 = '1') else command_op2(31);          
   expA    <= command_op1(62 downto 52) when (bit64 = '1') else "000" & command_op1(30 downto 23);
   expB    <= command_op2(62 downto 52) when (bit64 = '1') else "000" & command_op2(30 downto 23);   
   mantA   <= command_op1(51 downto 0) when (bit64 = '1') else 29x"0" & command_op1(22 downto 0);
   mantB   <= command_op2(51 downto 0) when (bit64 = '1') else 29x"0" & command_op2(22 downto 0);

   infA    <= '1' when ((bit64 = '1' and command_op1(62 downto 52) = 11x"7FF") or (bit64 = '0' and command_op1(30 downto 23) = x"FF")) else '0';
   infB    <= '1' when ((bit64 = '1' and command_op2(62 downto 52) = 11x"7FF") or (bit64 = '0' and command_op2(30 downto 23) = x"FF")) else '0';
   
   nanA    <= '1' when (infA = '1' and mantA > 0) else '0';
   nanB    <= '1' when (infB = '1' and mantB > 0) else '0';   
   
   exp0A   <= '1' when (expA = 0) else '0';
   exp0B   <= '1' when (expB = 0) else '0';   
   
   dnA     <= '1' when (exp0A = '1' and mantA > 0) else '0';
   dnB     <= '1' when (exp0B = '1' and mantB > 0) else '0';   
           
   zeroA   <= '1' when (exp0A = '1' and mantA = 0) else '0';
   zeroB   <= '1' when (exp0B = '1' and mantB = 0) else '0';

---------------------------------------------------------------------
--------------- Combinatorial ---------------------------------------
---------------------------------------------------------------------

   cmp_inputInvalid_a <= '1' when (nanA = '1' and OP(3) = '1') else
                         '1' when (nanA = '1' and OP(3) = '0' and bit64 = '1' and command_op1(51) = '1') else
                         '1' when (nanA = '1' and OP(3) = '0' and bit64 = '0' and command_op1(22) = '1') else 
                         '0';
                         
   cmp_inputInvalid_b <= '1' when (nanB = '1' and OP(3) = '1') else
                         '1' when (nanB = '1' and OP(3) = '0' and bit64 = '1' and command_op2(51) = '1') else
                         '1' when (nanB = '1' and OP(3) = '0' and bit64 = '0' and command_op2(22) = '1') else 
                         '0';
   
   cmp_equal <= '1' when (zeroA = '1' and zeroB = '1') else
                '1' when (signA = signB and expA = expB and mantA = mantB) else
                '0';
                
   cmp_lesser <= '0'   when (zeroA = '1' and zeroB = '1') else
                 signA when (signA /= signB) else
                 '1'   when (signA = '1' and expA /= expB and expB < expA) else
                 '1'   when (signA = '1' and expA  = expB and mantB < mantA) else
                 '1'   when (signA = '0' and expA /= expB and expA < expB) else
                 '1'   when (signA = '0' and expA  = expB and mantA < mantB) else
                 '0';

   process (all)
   begin
        
      command_done      <= '0';
      exceptionFPU      <= '0';
      causeReset        <= '0';
      checkInputs_dn    <= '0';
      checkInputs_nan   <= '0';      
      checkInputs2_dn   <= '0';
      checkInputs2_nan  <= '0';
      outputInvalid     <= '0';

      if (command_ena = '1') then
         if (OPgroup = 16 or OPgroup = 17) then
            case (op) is
               
               when OP_ADD | OP_SUB  =>
                  causeReset        <= '1';
                  checkInputs_dn    <= '1';
                  checkInputs_nan   <= '1';                  
                  checkInputs2_dn   <= '1';
                  checkInputs2_nan  <= '1';
                  outputInvalid     <= nanA or nanB;
                  if (infA = '1' and infB = '1') then 
                     if (op(0) = '0' and signA /= signB) then outputInvalid <= '1'; end if;
                     if (op(0) = '1' and signA = signB)  then outputInvalid <= '1'; end if;
                  end if;
       
               when OP_MUL  =>
                  causeReset        <= '1';
                  checkInputs_dn    <= '1';
                  checkInputs_nan   <= '1';                  
                  checkInputs2_dn   <= '1';
                  checkInputs2_nan  <= '1';
                  outputInvalid     <= nanA or nanB or (infA and zeroB) or (infB and zeroA);
               
               when OP_DIV  =>
                  causeReset        <= '1';
                  checkInputs_dn    <= '1';
                  checkInputs_nan   <= '1';                  
                  checkInputs2_dn   <= '1';
                  checkInputs2_nan  <= '1';
                  outputInvalid     <= nanA or nanB or (infA and infB) or (zeroA and zeroB);
               
               when OP_SQRT =>
                  causeReset        <= '1';
                  checkInputs_dn    <= '1';
                  checkInputs_nan   <= '1';                  
                  outputInvalid     <= nanA or ((not zeroA) and signA);
            
               when OP_ABS | OP_NEG =>
                  command_done      <= not nanA;
                  causeReset        <= '1';
                  checkInputs_dn    <= '1';
                  checkInputs_nan   <= '1';
                  outputInvalid     <= nanA;   

               when OP_MOV =>
                  command_done <= '1';
               
               when OP_ROUND_L | OP_TRUNC_L | OP_CEIL_L | OP_FLOOR_L | OP_ROUND_W | OP_TRUNC_W | OP_CEIL_W | OP_FLOOR_W | OP_CVT_W | OP_CVT_L =>
                  causeReset        <= '1';
                  checkInputs_dn    <= '1';          
               
               when OP_CVT_S    =>            
                  outputInvalid <= nanA;
                  if (bit64 = '1') then
                     causeReset      <= '1';
                     checkInputs_dn  <= '1';
                     checkInputs_nan <= '1';
                  else
                     command_done <= '1';
                     exceptionFPU <= '1';
                  end if;
               
               when OP_CVT_D    =>
                  command_done  <= not (nanA);
                  outputInvalid <= nanA;
                  if (bit64 = '0') then
                     causeReset     <= '1';
                     checkInputs_dn <= '1';
                     checkInputs_nan   <= '1';
                  else
                     exceptionFPU <= '1';
                  end if;
                  
               when OP_C_F | OP_C_UN | OP_C_EQ | OP_C_UEQ | OP_C_OLT | OP_C_ULT | OP_C_OLE | OP_C_ULE | OP_C_SF | OP_C_NGLE | OP_C_SEQ | OP_C_NGL | OP_C_LT | OP_C_NGE | OP_C_LE | OP_C_NGT =>
                  command_done <= '1';
                  causeReset   <= '1';
                  if (cmp_inputInvalid_a = '1' or cmp_inputInvalid_b = '1') then
                     if (csr_ena_invalidOperation = '1') then
                        exceptionFPU <= '1';
                     end if;
                  end if;
               
               when others =>
                  command_done <= '1';
                  exceptionFPU <= '1';
               
            end case;
         end if;
         
         if (OPgroup = 20 or OPgroup = 21) then
            case (op) is
                         
               when OP_CVT_S    => 
                  causeReset   <= '1';
               
               when OP_CVT_D    => 
                  causeReset   <= '1';
               
               when others =>
                  exceptionFPU <= '1';
                  command_done <= '1';
               
            end case;
         end if;
         
      end if;
      
      transfer_data <= command_op1;
      
      case (transfer_code) is
         when x"0" => -- mfc1
            transfer_data <= unsigned(resize(signed(command_op1(31 downto 0)), 64));
            if (fpuRegMode = '0' and transfer_RD(0) = '1') then
               transfer_data <= unsigned(resize(signed(command_op1(63 downto 32)), 64));
            end if;
         
         when x"2" => -- cfc1
            transfer_data <= (others => '0');
            if (transfer_RD = 0) then
               transfer_data(11 downto 8) <= x"A";  -- revision
            end if;
            if (transfer_RD = 31) then
               transfer_data(24 downto 0) <= csr; 
            end if;
            
         when x"3" | x"7" => -- DCFC1 / DCTC1
            if (transfer_ena = '1') then
               exceptionFPU <= '1';  
               causeReset   <= '1';
            end if;
            
         when x"6" => -- ctc1
            if (transfer_ena = '1' and transfer_RD = 31) then
               if (transfer_value(17) = '1')                              then exceptionFPU <= '1'; end if;
               if (transfer_value(16) = '1' and transfer_value(11) = '1') then exceptionFPU <= '1'; end if;
               if (transfer_value(15) = '1' and transfer_value(10) = '1') then exceptionFPU <= '1'; end if;
               if (transfer_value(14) = '1' and transfer_value( 9) = '1') then exceptionFPU <= '1'; end if;
               if (transfer_value(13) = '1' and transfer_value( 8) = '1') then exceptionFPU <= '1'; end if;
               if (transfer_value(12) = '1' and transfer_value( 7) = '1') then exceptionFPU <= '1'; end if;
            end if;
            
         when x"8" =>  -- BC1 
            if (transfer_ena = '1') then  
               causeReset   <= '1';
            end if;
            
         when others => null;
      end case;
      
      if (checkInputs_dn = '1' and dnA = '1') then
         exceptionFPU <= '1';
         command_done <= '1';
      end if;
      
      if (checkInputs2_dn = '1' and dnB = '1') then
         exceptionFPU <= '1';
         command_done <= '1';
      end if;
      
      if (checkInputs_nan = '1' and nanA = '1') then
         if ((bit64 = '1' and command_op1(51) = '1') or (bit64 = '0' and command_op1(22) = '1')) then
            if (csr_ena_invalidOperation = '1') then
               exceptionFPU <= '1';
               command_done <= '1';
            end if;
         else
            exceptionFPU <= '1';
            command_done <= '1';
         end if;
      end if;      
      
      if (checkInputs2_nan = '1' and nanB = '1') then
         if ((bit64 = '1' and command_op2(51) = '1') or (bit64 = '0' and command_op2(22) = '1')) then
            if (csr_ena_invalidOperation = '1') then
               exceptionFPU <= '1';
               command_done <= '1';
            end if;
         else
            exceptionFPU <= '1';
            command_done <= '1';
         end if;
      end if;
      
      if (exception_checkInputConvert2F = '1') then
         exceptionFPU <= '1';
         command_done <= '1';
      end if;
      
      if (toInt_unimpl = '1') then
         exceptionFPU <= '1';
         command_done <= '1';
      end if;
      
      if (shortcut_store = '1') then
         command_done <= '1';
         
         if (flag_divbyzero = '1' and csr_ena_divisionByZero = '1') then
            exceptionFPU <= '1';
         end if;     
      end if;
         
      if (outputInvalid_1 = '1') then
         command_done <= '1';
         if (csr_ena_invalidOperation = '1') then
            exceptionFPU <= '1';
         end if;    
      end if;
         
      if (toInt_store = '1' or round_store = '1') then
      
         command_done <= '1';
      
         if (flag_underflow = '1' and (csr_flushSubnormals = '0' or csr_ena_underflow = '1' or csr_ena_inexact = '1')) then
            exceptionFPU <= '1';
         end if;
         
         if ((round_inexact = '1' or flag_inexact = '1') and csr_ena_inexact = '1') then
            exceptionFPU <= '1';
         end if;
         
         if ((round_overflow = '1' or flag_overflow = '1') and csr_ena_overflow = '1') then
            exceptionFPU <= '1';
         end if;
         
      end if;
  
   end process;
   
---------------------------------------------------------------------
--------------- new command/transfer and result writeback  ----------
---------------------------------------------------------------------
   

   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         bit64_1         <= bit64;
         signA_1         <= signA;
         signB_1         <= signB;
         expA_1          <= expA;
         mantA_1         <= mantA;
         infA_1          <= infA;
         infB_1          <= infB;
         exp0A_1         <= exp0A;
         zeroA_1         <= zeroA;
         zeroB_1         <= zeroB;
         outputInvalid_1 <= outputInvalid and (not exceptionFPU);
      
         FPUWriteEnable                <= '0';
         error_FPU                     <= exceptionFPU;           
         ADD_start                     <= '0';
         SUB_start                     <= '0';
         MUL_start                     <= '0';
         DIV_start                     <= '0';
         SQRT_start                    <= '0';
         CDS_start                     <= '0';
         CIS_start                     <= '0';
         CID_start                     <= '0';
         toInt_start                   <= '0';
         exception_checkInputConvert2F <= '0';
         exception_inputInvalid        <= '0';
      
         if (reset = '1') then
         
            csr         <= SS_CSR; -- (others => '0');
            csr_compare <= SS_FPU_CF;  -- '0';
           
         else 
         
            if (causeReset = '1') then
               csr_cause_inexact          <= '0';
               csr_cause_underflow        <= '0';
               csr_cause_overflow         <= '0';
               csr_cause_divisionByZero   <= '0';
               csr_cause_invalidOperation <= '0';
               csr_cause_unimplemented    <= '0';
            end if;
         
            if (command_ena = '1') then
            
               FPUWriteTarget <= command_code(10 downto 6);
               FPUWriteMask   <= "11";
               bit64Out       <= bit64;
               roundmode_save <= csr_roundmode;
            
               if (OPgroup = 16 or OPgroup = 17) then
                  case (op) is
                        
                     when OP_ADD  => ADD_start  <= '1';
                     when OP_SUB  => SUB_start  <= '1';
                     when OP_MUL  => MUL_start  <= '1';
                     when OP_DIV  => DIV_start  <= '1';
                     when OP_SQRT => SQRT_start <= '1';
                  
                     when OP_ABS => 
                        FPUWriteEnable <= '1';
                        if (bit64) then
                           FPUWriteData <= '0' & command_op1(62 downto 0);
                        else
                           FPUWriteData <= 33x"0" & command_op1(30 downto 0);
                        end if;

                     when OP_MOV =>
                        FPUWriteEnable <= '1';
                        FPUWriteData   <= command_op1;

                     when OP_NEG => 
                        FPUWriteEnable <= '1';
                        if (bit64) then
                           FPUWriteData <= not(command_op1(63)) & command_op1(62 downto 0);
                        else
                           FPUWriteData <= 32x"0" & not(command_op1(31)) & command_op1(30 downto 0);
                        end if;
                     
                     when OP_ROUND_L  =>
                        toInt_start    <= '1';
                        bit64Out       <= '1'; 
                        roundmode_save <= "00";                    
                        
                     when OP_TRUNC_L  =>
                        toInt_start    <= '1';
                        bit64Out       <= '1';   
                        roundmode_save <= "01"; 
                        
                     when OP_CEIL_L   =>
                        toInt_start    <= '1';
                        bit64Out       <= '1';
                        roundmode_save <= "10"; 
                        
                     when OP_FLOOR_L  =>
                        toInt_start    <= '1';
                        bit64Out       <= '1'; 
                        roundmode_save <= "11";                        
                     
                     when OP_ROUND_W  => 
                        toInt_start    <= '1';
                        bit64Out       <= '0';
                        roundmode_save <= "00";  
                        
                     when OP_TRUNC_W  =>
                        toInt_start    <= '1';
                        bit64Out       <= '0';
                        roundmode_save <= "01";  
                        
                     when OP_CEIL_W   =>
                        toInt_start    <= '1';
                        bit64Out       <= '0';
                        roundmode_save <= "10";  
                        
                     when OP_FLOOR_W  =>
                        toInt_start    <= '1';
                        bit64Out       <= '0';   
                        roundmode_save <= "11";                          
                     
                     when OP_CVT_S    => 
                        if (bit64 = '1') then
                           CDS_start <= '1';
                           bit64Out  <= '0';
                        else
                           csr_cause_unimplemented <= '1';
                        end if;
                     
                     when OP_CVT_D    =>
                        FPUWriteEnable <= '1';
                        bit64Out       <= '1'; 
                        if (bit64 = '0') then
                           if (infA = '1') then
                              FPUWriteData <= signA & 11x"7FF" & mantA;
                           else
                              FPUWriteData <= signA & (expA + 1023 - 127) & mantA(22 downto 0) & 29x"0";
                              if (expA = 0) then
                                 FPUWriteData(62 downto 52) <= (others => '0');
                              end if;
                           end if;
                        else
                           csr_cause_unimplemented <= '1';
                        end if;
                     
                     when OP_CVT_W    => 
                        toInt_start <= '1';
                        bit64Out    <= '0';
                     
                     when OP_CVT_L    =>
                        toInt_start <= '1';
                        bit64Out    <= '1';                     
                        
                     when OP_C_F | OP_C_UN | OP_C_EQ | OP_C_UEQ | OP_C_OLT | OP_C_ULT | OP_C_OLE | OP_C_ULE | OP_C_SF | OP_C_NGLE | OP_C_SEQ | OP_C_NGL | OP_C_LT | OP_C_NGE | OP_C_LE | OP_C_NGT =>
                        if (nanA = '1' or nanB = '1') then
                           if (cmp_inputInvalid_a = '1' or cmp_inputInvalid_b = '1') then
                              csr_cause_invalidOperation <= '1';
                              if (csr_ena_invalidOperation = '0') then
                                 csr_flag_invalidOperation <= '1';
                                 csr_compare               <= op(0);
                              end if;
                           else
                              csr_compare <= op(0);
                           end if;
                        else
                           case (op(2 downto 1)) is
                              when "00" => csr_compare <= '0'; -- CF0
                              when "01" => csr_compare <= cmp_equal; -- EQ
                              when "10" => csr_compare <= cmp_lesser; -- LT
                              when "11" => csr_compare <= cmp_equal or cmp_lesser; -- LE
                              when others => null;
                           end case;
                        end if;   
                        
                     when others =>
                        csr_cause_unimplemented <= '1';

                  end case;
               end if;
               
               if (OPgroup = 20 or OPgroup = 21) then
               
                  if (signed(command_op1) >= INT64_MAX or signed(command_op1) < INT64_MIN) then
                     exception_checkInputConvert2F <= bit64;
                  end if;
               
                  case (op) is
                        
                     when OP_CVT_S =>
                        CIS_start <= '1';
                        bit64Out  <= '0';
                     
                     when OP_CVT_D =>
                        CID_start <= '1';
                        bit64Out  <= '1';
                        
                     when others =>
                        csr_cause_unimplemented <= '1';

                  end case;
               end if;
               
               if (
                     (checkInputs_dn   = '1' and dnA = '1') or 
                     (checkInputs2_dn  = '1' and dnB = '1') or
                     (checkInputs_nan  = '1' and nanA = '1' and not((bit64 = '1' and command_op1(51) = '1') or (bit64 = '0' and command_op1(22) = '1'))) or
                     (checkInputs2_nan = '1' and nanB = '1' and not((bit64 = '1' and command_op2(51) = '1') or (bit64 = '0' and command_op2(22) = '1')))
                  ) then
                  csr_cause_unimplemented <= '1';
                  exception_inputInvalid  <= '1';
               else
                  if ((checkInputs_nan = '1' and nanA = '1') or (checkInputs2_nan = '1' and nanB = '1')) then
                     csr_cause_invalidOperation <= '1';
                     if (csr_ena_invalidOperation = '1') then
                        exception_inputInvalid <= '1';
                     else
                        csr_flag_invalidOperation <= '1';
                     end if;
                  end if;
               end if;
 
            end if;
            
            if (exceptionFPU = '1') then
               FPUWriteEnable <= '0';
            end if;
            
            if (transfer_ena = '1') then
            
               FPUWriteTarget <= transfer_RD;
               FPUWriteData   <= transfer_value;
               FPUWriteMask   <= "11";
               
               if (fpuRegMode = '0') then
                  FPUWriteTarget(0) <= '0';
               end if;
            
               case (transfer_code) is
                  when x"0" => null; -- mfc1
                  when x"1" => null; -- dmfc1
                  when x"2" => null; -- cfc1
                     
                  when x"3" | x"7" => -- DCFC1 / DCTC1
                     csr_cause_unimplemented    <= '1';
                  
                  when x"4" => -- mtc1
                     FPUWriteEnable      <= '1';
                     if (fpuRegMode = '1') then
                        FPUWriteMask        <= "01"; 
                     else
                        if (transfer_RD(0) = '1') then
                           FPUWriteData(63 downto 32) <= transfer_value(31 downto 0);
                           FPUWriteMask   <= "10";
                        else
                           FPUWriteMask   <= "01";
                        end if;
                     end if;
                  
                  when x"5" => -- dmtc1
                     FPUWriteEnable      <= '1';
                     
                  when x"6" => -- ctc1
                     if (transfer_RD = 31) then
                        csr(17 downto  0) <= transfer_value(17 downto  0);
                        csr(24 downto 23) <= transfer_value(24 downto 23);
                     end if;
                  
                  when x"8" => null; -- BC1 
                  
                  when others => null;
               end case;
            end if;
                  
         end if;
         
         if (exception_checkInputConvert2F = '1') then
            csr_cause_unimplemented <= '1';
         end if;
         
         -- writeback toInt
         if (toInt_store = '1') then
            FPUWriteEnable <= '1';
            
            if (bit64Out = '1') then
               FPUWriteData <= toInt_Result;
            else
               FPUWriteData <= 32x"0" & toInt_Result(31 downto 0);
            end if;
         end if;
         
         if (toInt_unimpl = '1') then
            csr_cause_unimplemented  <= '1';
         end if;
         
         -- writeback shortcut
         if (shortcut_store = '1') then
            FPUWriteEnable <= '1';
            if (bit64Out = '1') then
               FPUWriteData <= signOut & shortcut_exp & shortcut_mant;
            else
               FPUWriteData <= 32x"0" & signOut & shortcut_exp(7 downto 0) & shortcut_mant(22 downto 0);
            end if;
            
            if (flag_divbyzero = '1') then
               csr_cause_divisionByZero <= '1';
               if (csr_ena_divisionByZero = '1') then
                  FPUWriteEnable    <= '0';
               else
                  csr_flag_divisionByZero <= '1';
               end if;
            end if;  
         end if;
         
         -- writeback invalid
         if (outputInvalid = '1') then
            FPUWriteEnable <= '0';
         end if;
         if (outputInvalid_1 = '1') then
            
            if (bit64Out = '1') then
               FPUWriteData <= x"7FF7FFFFFFFFFFFF";
            else
               FPUWriteData <= 32x"0" & x"7FBFFFFF";
            end if;
            
            csr_cause_invalidOperation <= '1';
            if (csr_ena_invalidOperation = '1') then
               FPUWriteEnable    <= '0';
            else
               csr_flag_invalidOperation <= '1';
               FPUWriteEnable    <= '1';
            end if;
            
         end if;
         
         -- writeback after rounding
         if (round_store = '1') then
            FPUWriteEnable <= '1';
            
            -- result data
            if (bit64Out = '1') then
               FPUWriteData <= signOut & round_out64_exp & round_out64_mant;
            else
               FPUWriteData <= 32x"0" & signOut & round_out32_exp & round_out32_mant;
            end if;
            
            if (round_overflow = '1' or flag_overflow = '1') then
               if (overflow_overwrite = '1' ) then
                  if (bit64Out = '1') then
                     FPUWriteData <= signOut & 11x"7FE" & x"FFFFFFFFFFFFF";
                  else
                     FPUWriteData <= 32x"0" & signOut & x"FE" & 23x"7FFFFF";
                  end if;
               else
                  if (bit64Out = '1') then
                     FPUWriteData <= signOut & 11x"7FF" & 52x"0";
                  else
                     FPUWriteData <= 32x"0" & signOut & x"FF" & 23x"0";
                  end if;
               end if;
            end if;            
            
            if (flag_underflow = '1') then
               if (underflow_overwrite = '1') then
                  if (bit64Out = '1') then
                     FPUWriteData <= signOut & 11x"001" & 52x"0";
                  else
                     FPUWriteData <= 32x"0" & signOut & x"01" & 23x"0";
                  end if;
               else
                  if (bit64Out = '1') then
                     FPUWriteData <= signOut & 11x"000" & 52x"0";
                  else
                     FPUWriteData <= 32x"0" & signOut & x"00" & 23x"0";
                  end if;
               end if;
            end if;

         end if;
            
         if (toInt_store = '1' or round_store = '1') then
            -- update flags
            if (flag_underflow = '1' and (csr_flushSubnormals = '0' or csr_ena_underflow = '1' or csr_ena_inexact = '1')) then
            
               csr_cause_unimplemented    <= '1';
               FPUWriteEnable             <= '0';
            
            else
            
               if (round_inexact = '1' or flag_inexact = '1') then
                  csr_cause_inexact <= '1';
                  if (csr_ena_inexact = '1') then
                     FPUWriteEnable    <= '0';
                  else
                     csr_flag_inexact <= '1';
                  end if;
               end if;
               
               if (flag_underflow = '1') then
                  csr_cause_underflow <= '1';
                  if (csr_ena_underflow = '1') then
                     FPUWriteEnable    <= '0';
                  else
                     csr_flag_underflow <= '1';
                  end if;
               end if;                       
               
               if (round_overflow = '1' or flag_overflow = '1') then
                  csr_cause_overflow <= '1';
                  if (csr_ena_overflow = '1') then
                     FPUWriteEnable    <= '0';
                  else
                     csr_flag_overflow <= '1';
                  end if;
               end if;  
               
            end if;
            
         end if;

      end if;
   end process;
   
---------------------------------------------------------------------
--------------- shared processing  ----------------------------------
---------------------------------------------------------------------
   
   -- leading zero count for int
   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
      clz_result <= 56;
      for i in 0 to 55 loop
         if (clz_value(i) = '1') then
            clz_result <= 55 - i;
         end if;
      end loop;

      end if;
   end process;
   
   -- shifter
   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         shifter_lostbits <= shifter_lostbits_in;
      
         if (shifter_right = '1') then
            shifter_output <= 7x"0" & shift_right(shifter_input, shifter_amount);  
            for i in 0 to 56 loop
               if (i < shifter_amount and shifter_input(i) = '1') then
                  shifter_lostbits <= '1';
               end if;
            end loop;
         else
            shifter_output <= (7x"0" & shifter_input) sll shifter_amount;
         end if;

      end if;
   end process;
   
   -- rounding
   sticky <= shifter_lostbits or shifter_output(0);
   
   roundUp <= '1' when (roundmode_save = "00" and shifter_output(2) = '1' and (shifter_output(1) = '1' or sticky = '1' or shifter_output(3) = '1')) else -- TONEAREST
              '0' when (roundmode_save = "01" and shifter_output(2) = '1' and (shifter_output(1) = '1' or sticky = '1' or shifter_output(3) = '1')) else -- TOWARDZERO
              '1' when (roundmode_save = "10" and signOut = '0' and (shifter_output(2) = '1' or shifter_output(1) = '1' or sticky = '1')) else -- UPWARD
              '1' when (roundmode_save = "11" and signOut = '1' and (shifter_output(2) = '1' or shifter_output(1) = '1' or sticky = '1')) else -- DOWNWARD
              '0';
   
   round_Mant <= (shifter_output + 8) when (roundUp = '1') else shifter_output;
   
   process (all)
   begin
      
      round_inexact  <= shifter_lostbits;
      round_overflow <= '0';

      -- 32bit part
      if (round_Mant(27) = '1') then
         if (round_in_exp(7 downto 0) = x"FF") then
            round_out32_exp <= x"FF";
         else
            round_out32_exp <= round_in_exp(7 downto 0) + 1;
         end if;
         round_out32_mant <=  round_Mant(26 downto 4);
      else
         round_out32_exp  <= round_in_exp(7 downto 0);
         round_out32_mant <=  round_Mant(25 downto 3);
         
      end if;
      
      -- 64bit part
      if (round_Mant(56) = '1') then
         if (round_in_exp = 11x"7FF") then
            round_out64_exp <= 11x"7FF";
         else
            round_out64_exp <= round_in_exp + 1;
         end if;
         round_out64_mant <=  round_Mant(55 downto 4);
         if (bit64Out = '1' and round_Mant(3 downto 0) > 0) then round_inexact <= '1'; end if;
      else
         round_out64_exp  <= round_in_exp;
         round_out64_mant <=  round_Mant(54 downto 3);
         if (round_Mant(2 downto 0) > 0) then round_inexact <= '1'; end if;
      end if;
      
      -- inexact
      if (round_Mant(2 downto 0) > 0) then round_inexact <= '1'; end if;
      if (bit64Out = '0' and round_Mant(27) = '1' and round_Mant(3) = '1') then round_inexact <= '1'; end if;
      if (bit64Out = '1' and round_Mant(56) = '1' and round_Mant(3) = '1') then round_inexact <= '1'; end if;
      
      -- overflow
      if ((bit64Out = '0' and round_out32_exp = x"FF") or (bit64Out = '1' and round_out64_exp = 11x"7FF")) then 
         round_overflow <= '1'; 
         round_inexact  <= '1'; 
      end if;
      
      if (round_store = '0') then
         round_inexact  <= '0';
         round_overflow <= '0';
      end if;
      
   end process;
   
---------------------------------------------------------------------
--------------- special processing  ---------------------------------
---------------------------------------------------------------------
   
   -- ADD/SUB
   ADD_shift_result <= shift_right(ADD_shift_value, ADD_shift_amount);
   
   ADD_shift_result_or <= ADD_shift_result(ADD_shift_result'left downto 1) & (ADD_shift_result(0) or ADD_shift_lostbits);
   
   ADD_useADD <= '1' when (signA_1  = signB_1 and SUB_start = '0') else
                 '1' when (signA_1 /= signB_1 and SUB_start = '1') else
                 '0';
   
   process (all)
   begin
   
      ADD_shift_lostbits <= '0';
      for i in 0 to 55 loop
         if (i < ADD_shift_amount and ADD_shift_value(i) = '1') then
            ADD_shift_lostbits <= '1';
         end if;
      end loop;
      
      if (bit64Out = '1') then
         ADD_leadingZeros <= 56;
         for i in 0 to 55 loop
            if (add_result(i) = '1') then
               ADD_leadingZeros <= 55 - i;
            end if;
         end loop;
         if (add_result(56) = '1') then
            ADD_leadingZeros <= 0;
         end if;
      else
         ADD_leadingZeros <= 27;
         for i in 0 to 26 loop
            if (add_result(i) = '1') then
               ADD_leadingZeros <= 26 - i;
            end if;
         end loop;
         if (add_result(27) = '1') then
            ADD_leadingZeros <= 0;
         end if;
      end if;
      
   end process;
   
   -- DIV
   process (clk93)
      variable dividend_next : unsigned(55 downto 0);
   begin
      if (rising_edge(clk93)) then
      
         if (command_ena = '1' and op = 3) then
            dividend     <= 4x"0" & mantA;
            divisor      <= 4x"0" & mantB;
            quotient     <= (others => '0');
            DIV_complete <= '0';
            if (bit64 = '1') then
               dividend(52) <= not exp0A;
               divisor(52)  <= '1';
                divstep     <= 55; 
            else
               dividend(23) <= not exp0A;
               divisor(23)  <= '1';
                divstep     <= 26;
            end if;
         elsif (DIV_complete = '0') then
            dividend_next := dividend;
            if (dividend >= divisor) then
               quotient(divstep) <= '1';
               dividend_next     := dividend_next - divisor;
            end if;
            divremain <= dividend_next;
            dividend <= dividend_next(dividend_next'left-1 downto 0) & '0';
            divstep  <= divstep - 1;
            if (divstep = 0) then
               DIV_complete <= '1';
            end if;
         end if;
         
         if (reset = '1') then
            DIV_complete <= '1';
         end if;

      end if;
   end process;
  
   -- SQRT

   SQRT_startcalc <= '1' when (command_ena = '1' and op = 4) else '0';

   icpu_FPU_sqrt : entity work.cpu_FPU_sqrt
   port map
   (
      clk               => clk93,
      reset             => reset,
                        
      start             => SQRT_startcalc,
      bit64             => bit64,
      exp0              => expA(0),
      mant              => mantA,
      result            => SQRT_result,
      lostBits          => SQRT_lostbits,
      done              => SQRT_complete
   );

---------------------------------------------------------------------
--------------- clocked calculations --------------------------------
---------------------------------------------------------------------

   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         round_store     <= '0';
         toInt_store     <= '0';
         toInt_unimpl    <= '0';
         shortcut_store  <= '0';
         
         if (command_ena = '1') then
            flag_inexact        <= '0';
            flag_overflow       <= '0';
            flag_underflow      <= '0';
            flag_divbyzero      <= '0';
            shifter_lostbits_in <= '0';
         end if;
         
         overflow_overwrite <= '0';
         if (roundmode_save = 1)                   then overflow_overwrite <= '1'; end if;
         if (roundmode_save = 2 and signOut = '1') then overflow_overwrite <= '1'; end if;
         if (roundmode_save = 3 and signOut = '0') then overflow_overwrite <= '1'; end if;         
         
         underflow_overwrite <= '0';
         if (roundmode_save = 2 and signOut = '0') then underflow_overwrite <= '1'; end if;
         if (roundmode_save = 3 and signOut = '1') then underflow_overwrite <= '1'; end if;
      
         ---------------------------------
         --------------- ADD/SUB ---------
         ---------------------------------
         ADD_stage1 <= (ADD_start or SUB_start) and (not exception_inputInvalid) and (not outputInvalid_1);
         ADD_stage2 <= ADD_stage1;
         
         -- stage 0
         if (expA > expB) then
            ADD_exp_initial <= expA;
            ADD_value1      <= '0' & mantA & "000";
            ADD_shift_value <= '0' & mantB & "000";
            ADD_swapped     <= '0';
            if (bit64 = '1') then
               ADD_value1(55)      <= not exp0A;
               ADD_shift_value(55) <= not exp0B;
            else
               ADD_value1(26)      <= not exp0A;
               ADD_shift_value(26) <= not exp0B;
            end if;
            if ((expA - expB) > 55) then
               ADD_shift_amount <= 55;
            else
               ADD_shift_amount <= to_integer(expA) - to_integer(expB);
            end if;   
         else
            ADD_exp_initial <= expB;
            ADD_value1      <= '0' & mantB & "000";
            ADD_shift_value <= '0' & mantA & "000";
            ADD_swapped     <= '1';
            if (bit64 = '1') then
               ADD_value1(55)      <= not exp0B;
               ADD_shift_value(55) <= not exp0A;
            else
               ADD_value1(26)      <= not exp0B;
               ADD_shift_value(26) <= not exp0A;
            end if;
            if ((expB - expA) > 55) then
               ADD_shift_amount <= 55;
            else
               ADD_shift_amount <= to_integer(expB) - to_integer(expA);
            end if;  
         end if;
         
         ADD_AGrB <= '0';
         if (expA > expB or (expA = expB and mantA > mantB)) then
            ADD_AGrB <= '1';
         end if;

         -- stage 1
         if (ADD_start = '1' or SUB_start = '1') then
            signOut      <= ((not signA_1) and (not ADD_AGrB) and (SUB_start xor signB_1)) or ((signA_1) and (ADD_AGrB or (SUB_start xor signB_1)));
            flag_inexact <= ADD_shift_lostbits;
            ADD_exp      <= ADD_exp_initial;
            
            if (ADD_useADD = '1') then
               ADD_result   <= resize(ADD_value1, 57) + resize(ADD_shift_result_or, 57);
            elsif (ADD_AGrB /= ADD_swapped) then
               ADD_result   <= resize(ADD_value1, 57) - resize(ADD_shift_result_or, 57);
            else
               ADD_result   <= resize(ADD_shift_result_or, 57) - resize(ADD_value1, 57);
            end if;
            
            if (exception_inputInvalid = '0' and outputInvalid_1 = '0' and (infA_1 = '1' or infB_1 = '1')) then
               shortcut_store <= '1';
               shortcut_mant  <= (others => '0');
               shortcut_exp   <= (others => '1');
               ADD_stage1     <= '0';
            end if;
         end if;
         
         -- stage 2
         if (ADD_stage1 = '1') then
            shifter_input <= ADD_result(56 downto 0);
              
            if (ADD_result = 0) then
               ADD_exp <= (others => '0'); 
               signout <= '0';
            elsif (ADD_leadingZeros >= ADD_exp) then
               ADD_exp        <= (others => '0'); 
               flag_underflow <= '1';
               shifter_amount <= 57;
               shifter_right  <= '1';
            elsif ((bit64Out = '1' and ADD_result(56) = '1') or (bit64Out = '0' and ADD_result(27) = '1')) then
               shifter_amount   <= 1;
               shifter_right    <= '1';
               if ((bit64Out = '1' and ADD_exp < 16#7FF#) or (bit64Out = '0' and ADD_exp < 16#ff#)) then
                  ADD_exp       <= ADD_exp + 1;
               end if;
            else
               ADD_exp          <= ADD_exp - ADD_leadingZeros;
               shifter_amount   <= ADD_leadingZeros;
               shifter_right    <= '0';
            end if;
            
         end if;

         -- stage 3
         if (ADD_stage2 = '1') then
            round_store  <= '1';
            round_in_exp <= ADD_exp;
         end if;
      
         ---------------------------------
         --------------- MUL  ------------
         ---------------------------------
         MUL_stage1 <= MUL_start and (not exception_inputInvalid) and (not outputInvalid_1);
         MUL_stage2 <= MUL_stage1;
         MUL_stage3 <= MUL_stage2;
         
         -- stage 0
         if (bit64 = '1') then
            MUL_exp_calc <= to_integer(expA) + to_integer(expB) - 1023;
         else
            MUL_exp_calc <= to_integer(expA) + to_integer(expB) - 127;
         end if;
      
         -- stage 1 - DSP delay
         if (MUL_start = '1') then
            signOut        <= signA_1 xor signB_1;
            
            if (exception_inputInvalid = '0' and outputInvalid_1 = '0' and (zeroA_1 = '1' or zeroB_1 = '1' or infA_1 = '1' or infB_1 = '1')) then
               shortcut_store <= '1';
               shortcut_mant  <= (others => '0');
               MUL_stage1     <= '0';
               if (zeroA_1 = '1' or zeroB_1 = '1') then
                  shortcut_exp   <= (others => '0');
               else
                  shortcut_exp   <= (others => '1');
               end if;
            end if;
            
            if (MUL_exp_calc < 0) then
               MUL_exp <= (others => '0');
               if (MUL_exp_calc < 0) then
                  flag_underflow <= '1';
                  flag_inexact   <= '1';
               end if;
            elsif ((bit64Out = '1' and MUL_exp_calc > 16#7FF#) or (bit64Out = '0' and MUL_exp_calc > 16#FF#)) then
               MUL_exp <= (others => '1');
            else
               MUL_exp <= to_unsigned(MUL_exp_calc, 11); 
            end if;
         end if;
         
         -- stage 2 -> mul/dsp delay
      
         -- stage 3
         if (MUL_stage2 = '1') then
            if (bit64Out = '1') then
               shifter_input  <= mul_result(104 downto 48);
               shifter_right  <= '1';
               shifter_amount <= 0;
               if (mul_result(47 downto 0) > 0) then
                  flag_inexact        <= '1';
                  shifter_lostbits_in <= '1';
               end if;
               if (mul_result(105) = '1') then
                  shifter_amount   <= 2;
                  shifter_right    <= '1';
                  if (MUL_exp < 16#7ff#) then
                     MUL_exp       <= MUL_exp + 1;
                  end if;
               else
                  shifter_amount   <= 1;
               end if;
            else
               shifter_input <= 10x"0" & mul_result(46 downto 0);
               shifter_right <= '1';
               if (mul_result(47) = '1') then
                  shifter_amount   <= 21;
                  if (MUL_exp < 16#ff#) then
                     MUL_exp       <= MUL_exp + 1;
                  end if;
               else 
                  shifter_amount   <= 20;
               end if;
            end if;
         end if;
         
         -- stage 4
         if (mul_stage3 = '1') then
            round_store  <= '1';
            round_in_exp <= MUL_exp;
            if (MUL_exp = 0) then
               flag_underflow <= '1';
               flag_inexact   <= '1';
            end if;
         end if;
         
         ---------------------------------
         --------------- DIV  ------------
         ---------------------------------

         -- stage 0         
         if (bit64 = '1') then
            DIV_exp_calc <= to_integer(expA) - to_integer(expB) + 1023;
         else
            DIV_exp_calc <= to_integer(expA) - to_integer(expB) + 127;
         end if;
         
         -- stage 1
         if (DIV_start = '1') then
            signOut        <= signA_1 xor signB_1;
            
            DIV_running <= (not exception_inputInvalid) and (not outputInvalid_1);
            
            if (exception_inputInvalid = '0' and outputInvalid_1 = '0' and (zeroA_1 = '1' or zeroB_1 = '1' or infA_1 = '1' or infB_1 = '1')) then
               shortcut_store <= '1';
               shortcut_exp   <= (others => '0');
               shortcut_mant  <= (others => '0');
               DIV_running    <= '0';
               if (infA_1 = '1' or zeroB_1 = '1') then
                  shortcut_exp <= (others => '1');
               end if;
               if (zeroB_1 = '1') then
                  flag_divbyzero <= '1';
               end if;
            end if;

            if (DIV_exp_calc <= 0) then
               DIV_exp        <= (others => '0');
               flag_underflow <= '1';
               flag_inexact   <= '1';
            elsif ((bit64Out = '1' and DIV_exp_calc > 16#7FF#) or (bit64Out = '0' and DIV_exp_calc > 16#FF#)) then
               DIV_exp       <= (others => '1');
               flag_overflow <= (not infA_1) and (not infB_1);
            else
               DIV_exp <= to_unsigned(DIV_exp_calc, 11); 
            end if;
            
         end if;
         
         -- stage n- 1
         DIV_done <= '0';
         if (DIV_running = '1' and DIV_complete = '1') then
            DIV_running    <= '0';
            DIV_done       <= '1';
            shifter_input  <= '0' & quotient;
            shifter_right  <= '0';
            shifter_amount <= 0;
            if ((bit64Out = '1' and quotient(55) = '0') or (bit64Out = '0' and quotient(26) = '0')) then
               if (DIV_exp > 1) then
                  shifter_amount <= 1;
                  DIV_exp        <= DIV_exp - 1;
               else
                  DIV_exp        <= (others => '0');
                  flag_underflow <= '1';
                  flag_inexact   <= '1';
               end if;
            end if;
            if (divremain > 0) then
               flag_inexact        <= '1';
               shifter_lostbits_in <= '1';
            end if;
         end if;
         
         -- stage n
         if (DIV_done = '1') then
            round_store  <= '1';
            round_in_exp <= DIV_exp;
         end if;
         
         ---------------------------------
         --------------- SQRT ------------
         ---------------------------------       
         
         -- stage 1
         if (SQRT_start = '1') then
            signOut        <= signA_1;
            SQRT_running <= (not exception_inputInvalid) and (not outputInvalid_1);
            
            if (exception_inputInvalid = '0' and outputInvalid_1 = '0' and (zeroA_1 = '1' or infA_1 = '1')) then
               shortcut_store <= '1';
               shortcut_exp   <= (others => '0');
               shortcut_mant  <= (others => '0');
               SQRT_running    <= '0';
               if (infA_1 = '1') then
                  shortcut_exp <= (others => '1');
               end if;
            end if;
            
            if (exp0A_1 = '1') then
               SQRT_exp <= (others => '0');
            else
               if (bit64Out = '1') then
                  SQRT_exp <= to_unsigned((to_integer(expA_1) + 1023) / 2, 11);
               else
                  SQRT_exp <= to_unsigned((to_integer(expA_1) + 127) / 2, 11);
               end if;
            end if;

         end if;
         
         -- stage n- 1
         SQRT_done <= '0';
         if (SQRT_running = '1' and SQRT_complete = '1') then
            SQRT_running    <= '0';
            SQRT_done       <= '1';
            shifter_input   <= '0' & SQRT_result & SQRT_lostbits;
            shifter_right   <= '0';
            shifter_amount  <= 0;
            flag_inexact    <= SQRT_lostbits;
         end if;
         
         -- stage n
         if (SQRT_done = '1') then
            round_store  <= '1';
            round_in_exp <= SQRT_exp;
         end if;

         ---------------------------------
         --------------- CDS  ------------
         ---------------------------------
         CDS_stage1 <= CDS_start and (not exception_inputInvalid) and (not outputInvalid_1);
         
         -- stage 0
         CDS_exp <= to_integer(expA) + 127 - 1023;
         
         -- stage 1
         if (CDS_start = '1') then
         
            if (exception_inputInvalid = '0' and outputInvalid_1 = '0' and infA_1 = '1') then
               shortcut_store <= '1';
               shortcut_exp   <= (others => '1');
               shortcut_mant  <= (others => '0');
               CDS_stage1     <= '0';
            end if;
         
            signOut        <= signA_1;
            shifter_right  <= '1';
            shifter_amount <= 26;
            shifter_input  <= 5x"1" & mantA_1;
            if (CDS_exp < 0) then
               round_in_exp(7 downto 0) <= (others => '0');
               if (zeroA_1 = '0') then
                  flag_inexact   <= '1';
                  flag_underflow <= '1';
               end if;
            elsif (CDS_exp >= 255) then
               round_in_exp(7 downto 0) <= (others => '1');
               if (infA_1 = '0') then
                  flag_inexact   <= '1';
                  flag_overflow  <= '1';
               end if;
            elsif (CDS_exp = 0) then
               round_in_exp(7 downto 0) <= (others => '0');
               shifter_input            <= 6x"1" & mantA_1(51 downto 1);
               flag_underflow           <= '1';
            else
               round_in_exp(7 downto 0) <= to_unsigned(CDS_exp, 8);
            end if;
         end if;
         
         -- stage 2
         if (CDS_stage1 = '1') then
            round_store <= '1';
         end if;
      
         ---------------------------------
         --------------- CIS / CID -------
         ---------------------------------
         CIS_stage1 <= CIS_start and (not exception_checkInputConvert2F);
         CID_stage1 <= CID_start and (not exception_checkInputConvert2F);
         CISD_stage2 <= CIS_stage1 or CID_stage1;
         CISD_stage3 <= CISD_stage2;
         
         -- stage 0
         if (command_ena = '1' and OPgroup(2) = '1') then
            if (bit64 = '1') then
               clz_value <= unsigned(abs(resize(signed(command_op1(55 downto 0)), 57)));
            else
               clz_value <= 24x"0" & unsigned(abs(resize(signed(command_op1(31 downto 0)), 33)));
            end if;
         end if;
         
         -- stage 1
         if (CIS_start = '1' or CID_start = '1') then
            signOut       <= signA_1;
            shifter_input <= clz_value;
         end if;
         
         -- stage 2
         if (CIS_stage1 = '1') then
            if (clz_result = 56) then 
               CID_exp <= 0;
            else
               CID_exp   <= 127 + (55 - clz_result);
               CID_shift <= 26 - (55 - clz_result);
            end if;
         end if;
         
         if (CID_stage1 = '1') then
            if (clz_result = 56) then 
               CID_exp <= 0;
            else
               CID_exp   <= 1023 + (55 - clz_result);
               CID_shift <= 55 - (55 - clz_result);
            end if;
         end if;
         
         -- stage 3
         if (CISD_stage2 = '1') then
            round_in_exp <= to_unsigned(CID_exp, 11);
            if (CID_shift < 0) then
               shifter_right  <= '1';
               shifter_amount <= -CID_shift;
            else
               shifter_right  <= '0';
               shifter_amount <= CID_shift;
            end if;
         end if;
         
         -- stage 4
         if (CISD_stage3 = '1') then
            round_store <= '1';
         end if;
         
         ---------------------------------
         --------------- toInt     -------
         ---------------------------------
         toInt_stage1 <= toInt_start and (not exception_inputInvalid);
         toInt_stage2 <= toInt_stage1;
         
         -- stage 0
         if (bit64 = '1') then
            toInt_shift <= to_integer(expA) - 1023 - 49;
            if ((op >= 8 and op <= 11) or op = 16#25#) then -- 64bit output
               toInt_limitExp <= 11x"434";
            else
               toInt_limitExp <= 11x"41E";
            end if;
         else
            toInt_shift <= to_integer(expA) - 127 - 20;
            if ((op >= 8 and op <= 11) or op = 16#25#) then -- 64bit output
               toInt_limitExp <= 11x"0B4";
            else
               toInt_limitExp <= 11x"09E";
            end if;
         end if;
                  
         -- stage 1
         if (toInt_start = '1') then
         
            -- prepare shifter
            signOut <= signA_1;
            shifter_input <= 5x"0" & mantA_1;
            if (zeroA_1 = '0' and bit64_1 = '1') then shifter_input(52) <= '1'; end if;
            if (zeroA_1 = '0' and bit64_1 = '0') then shifter_input(23) <= '1'; end if;
            if (toInt_shift < 0) then
               shifter_right  <= '1';
               if (toInt_shift < -63) then
                  shifter_amount <= 63;
               else
                  shifter_amount <= -toInt_shift;
               end if;
            else
               shifter_right  <= '0';
               if (toInt_shift > 63) then
                  shifter_amount <= 63;
               else
                  shifter_amount <= toInt_shift;
               end if;
            end if;
            
            -- check overflow
            if (expA_1 >= toInt_limitExp) then
               if (signA_1 = '0' or expA_1 > toInt_limitExp or mantA_1 > 0 or bit64Out = '1') then
                  toInt_unimpl <= '1';
                  toInt_stage1 <= '0';
               end if;
            end if;
            
         end if;
         
         -- stage 2 -- shifting
         
         -- stage 3
         if (toInt_stage2 = '1') then
         
            -- store result
            toInt_store  <= '1';
            flag_inexact <= shifter_lostbits;
            if (signOut = '1') then
               toInt_Result <= "111" & (not round_Mant(63 downto 3)) + 1;
            else
               toInt_Result <= "000" & round_Mant(63 downto 3);
            end if;
            if (round_Mant(2 downto 0) /= 0) then
               flag_inexact <= '1';
            end if;
            
            -- overflow check
            if ((round_Mant(34) = '1' and bit64Out = '0') and signOut = '0') then
               toInt_store   <= '0';
               toInt_unimpl  <= '1';
            end if;

         end if;
         
      end if;
   end process;

   -- synthesis translate_off
   process (clk93)
   begin
      if (rising_edge(clk93)) then

         if (reset = '1') then
            debug_calc_count <= 0;
         else  
            if (command_ena = '1') then
               debug_calc_count <= debug_calc_count + 1;
            end if;
         end if;
      end if;
   end process;
   
   goutput : if 1 = 1 generate
   begin
   
      process
         file outfile      : text;
         variable f_status : FILE_OPEN_STATUS;
         variable line_out : line;
         
         variable export_op   : unsigned(31 downto 0);
         variable export_rm   : std_logic;
         variable export_r1   : unsigned(63 downto 0);
         variable export_r2   : unsigned(63 downto 0);
         variable export_rs   : unsigned(63 downto 0);
         variable export_csrb : unsigned(31 downto 0);
         variable export_csra : unsigned(31 downto 0);
         variable export_cfb  : std_logic;
         variable export_cfa  : std_logic;
         variable export_e    : std_logic;
         
         variable export_next : std_logic := '0';
      begin
   
         file_open(f_status, outfile, "R:\\fpu_fpga.txt", write_mode);
         file_close(outfile);
         
         file_open(f_status, outfile, "R:\\fpu_fpga.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk93);
            
            if (FPUWriteEnable = '1') then
               export_rs   := FPUWriteData;
            end if;
            
            if (export_next = '1') then
               export_next := '0';
            
               export_csra := 7x"0" & csr;
               export_cfa  := csr_compare;
               
               write(line_out, string'("OP ")); 
               write(line_out, to_hstring(export_op));              
               if (export_rm = '1') then write(line_out, string'(" RM 1")); else write(line_out, string'(" RM 0")); end if;              
               write(line_out, string'(" R1 ")); 
               write(line_out, to_hstring(export_r1));               
               write(line_out, string'(" R2 ")); 
               write(line_out, to_hstring(export_r2));               
               write(line_out, string'(" RS ")); 
               write(line_out, to_hstring(export_rs));               
               write(line_out, string'(" CSRB ")); 
               write(line_out, to_hstring(export_csrb));               
               write(line_out, string'(" CSRA ")); 
               write(line_out, to_hstring(export_csra));     
               if (export_cfb = '1') then write(line_out, string'(" CFB 1")); else write(line_out, string'(" CFB 0")); end if;
               if (export_cfa = '1') then write(line_out, string'(" CFA 1")); else write(line_out, string'(" CFA 0")); end if;
               if (export_e   = '1') then write(line_out, string'(" E 1"));   else write(line_out, string'(" E 0")); end if;
               
               writeline(outfile, line_out);
            end if;

            if (command_ena = '1') then
               export_op   := command_code;
               export_rm   := fpuRegMode;
               export_r1   := command_op1;
               export_r2   := command_op2;
               export_rs   := (others => '0');
               export_csrb := 7x"0" & csr;
               export_cfb  := csr_compare;
               export_e    := '0';
            end if;
            
            if (exceptionFPU = '1') then
               export_e    := '1';
               export_next := '1';
            end if;
            
            if (command_done = '1') then
               export_next := '1';
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;
   
  -- synthesis translate_on

end architecture;
