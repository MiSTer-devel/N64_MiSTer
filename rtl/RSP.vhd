library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 
use STD.textio.all;

library mem;
use work.pFunctions.all;
use work.pRSP.all;

entity RSP is
   generic
   (
      use2Xclock           : in  std_logic
   );
   port 
   (
      clk1x                : in  std_logic;
      clk2x                : in  std_logic;
      clk2xIndex           : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      
      irq_out              : out std_logic := '0';
      
      error_instr          : out std_logic;
      error_stall          : out std_logic;
      error_Fifo           : out std_logic;
      error_Addr           : out std_logic;
      error_PCON           : out std_logic;
      
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
      rdram_granted        : in  std_logic;
      rdram_done           : in  std_logic;
      ddr3_DOUT            : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY      : in  std_logic;
      
      RSP_RDP_reg_addr     : out unsigned(4 downto 0);
      RSP_RDP_reg_dataOut  : out unsigned(31 downto 0);
      RSP_RDP_reg_read     : out std_logic;
      RSP_RDP_reg_write    : out std_logic;
      RSP_RDP_reg_dataIn   : in  unsigned(31 downto 0);
      
      RSP2RDP_rdaddr       : in  unsigned(11 downto 0); 
      RSP2RDP_len          : in  unsigned(4 downto 0); 
      RSP2RDP_req          : in  std_logic;
      RSP2RDP_data         : out std_logic_vector(63 downto 0) := (others => '0');
      RSP2RDP_we           : out std_logic := '0';
      RSP2RDP_done         : out std_logic := '0';
      
      fifoout_req          : out std_logic := '0';
      fifoout_reset        : out std_logic := '0'; 
      fifoout_Din          : out std_logic_vector(84 downto 0) := (others => '0'); -- 64bit data + 21 bit address
      fifoout_Wr           : out std_logic := '0';  
      fifoout_nearfull     : in  std_logic;   
      fifoout_empty        : in  std_logic;

      SS_reset              : in  std_logic;
      SS_DataWrite          : in  std_logic_vector(63 downto 0);
      SS_Adr                : in  unsigned(8 downto 0);
      SS_wren_RSP           : in  std_logic;
      SS_rden_RSP           : in  std_logic;
      SS_wren_IMEM          : in  std_logic;
      SS_rden_IMEM          : in  std_logic;      
      SS_wren_DMEM          : in  std_logic;
      SS_rden_DMEM          : in  std_logic;
      SS_DataRead           : out std_logic_vector(63 downto 0);
      SS_idle               : out std_logic      
   );
end entity;

architecture arch of RSP is

   -- register
   signal SP_DMA_SPADDR             : unsigned(12 downto 3); -- 0x04040000 Address in IMEM / DMEM for a DMA transfer //(RW) : [12] MEM_BANK [11:3] MEM_ADDR[11:3] [2:0] = 0
   signal SP_DMA_RAMADDR            : unsigned(23 downto 3); -- 0x04040004 Address in RDRAM for a DMA transfer
   signal SP_DMA_LEN                : unsigned(11 downto 3);
   signal SP_DMA_COUNT              : unsigned(7 downto 0);
   signal SP_DMA_SKIP               : unsigned(11 downto 3);
   signal SP_STATUS_halt            : std_logic; -- 0x04040010 RSP status register
   signal SP_STATUS_broke           : std_logic;
   signal SP_STATUS_dmabusy         : std_logic;
   signal SP_STATUS_dmafull         : std_logic;
   signal SP_STATUS_iofull          : std_logic;
   signal SP_STATUS_singlestep      : std_logic;
   signal SP_STATUS_irqonbreak      : std_logic;
   signal SP_STATUS_signal0set      : std_logic;
   signal SP_STATUS_signal1set      : std_logic;
   signal SP_STATUS_signal2set      : std_logic;
   signal SP_STATUS_signal3set      : std_logic;
   signal SP_STATUS_signal4set      : std_logic;
   signal SP_STATUS_signal5set      : std_logic;
   signal SP_STATUS_signal6set      : std_logic;
   signal SP_STATUS_signal7set      : std_logic;
   signal SP_SEMAPHORE              : std_logic; -- 0x0404001C Register to assist implementing a simple mutex between VR4300 and RSP. 
   signal SP_PC                     : unsigned(11 downto 0); -- 0x04080000 PC //(RW) : [11:0]

   -- bus/mem multiplexing
   signal bus_reg_req_read          : std_logic := '0';
   signal bus_reg_req_write         : std_logic := '0';
   signal reg_addr                  : unsigned(19 downto 0); 
   signal reg_dataWrite             : std_logic_vector(31 downto 0);

   -- DMA
   signal SP_DMA_CURRENT_SPADDR     : unsigned(12 downto 3) := (others => '0');
   signal SP_DMA_CURRENT_RAMADDR    : unsigned(23 downto 3) := (others => '0');
   signal SP_DMA_CURRENT_LEN        : unsigned(11 downto 3) := (others => '0');
   signal SP_DMA_CURRENT_COUNT      : unsigned(7 downto 0)  := (others => '0');
   signal SP_DMA_CURRENT_SKIP       : unsigned(11 downto 3) := (others => '0');
   signal SP_DMA_CURRENT_WORKLEN    : unsigned(9 downto 0) := (others => '0');
   signal SP_DMA_CURRENT_FETCHLEN   : integer range 0 to 31;
      
   signal dma_next_isWrite          : std_logic := '0';
   signal dma_isWrite               : std_logic := '0';
   
   signal imem_rden_bus             : std_logic := '0';
   signal dmem_rden_bus             : std_logic := '0';
   signal imem_wren_bus             : std_logic := '0';
   signal dmem_wren_bus             : std_logic := '0';
   
   signal RSP2RDP_req_latched       : std_logic := '0';
   
   type tMEMSTATE is
   (
      MEM_IDLE,
      MEM_BUS_WAIT_IMEM,
      MEM_READ_IMEM,
      MEM_BUS_WAIT_DMEM,
      MEM_READ_DMEM,
      MEM_STARTDMA,
      MEM_RUNDMA,      
      WAIT_DMAFINISH,
      MEM_STARTDMA_RDP,
      MEM_RUNDMA_RDP
   );
   signal MEMSTATE : tMEMSTATE := MEM_IDLE;
   
   signal dma_store                 : std_logic := '0';
   
   signal fifoout_Wr_1              : std_logic := '0';
   
   signal fifoin_reset              : std_logic := '0'; 
   signal fifoin_Dout               : std_logic_vector(63 downto 0);
   signal fifoin_Rd                 : std_logic := '0'; 
   signal fifoin_nearfull           : std_logic;    
   signal fifoin_Empty              : std_logic;    
   
   type tDMASTATE is
   (
      DMA_IDLE,
      DMA_READBLOCK
   );
   signal DMASTATE : tDMASTATE := DMA_IDLE;
   
   -- I/DMEM
   signal mem_address_a             : std_logic_vector(8 downto 0) := (others => '0');
   signal mem_address_a_1           : std_logic_vector(8 downto 0) := (others => '0');
   signal mem_data_a                : std_logic_vector(63 downto 0) := (others => '0');
   signal mem_be_a                  : std_logic_vector(7 downto 0) := (others => '0');
   
   signal imem_address_b            : std_logic_vector(9 downto 0) := (others => '0');    
   signal imem_wren_a               : std_logic := '0'; 
   signal imem_q_a                  : std_logic_vector(63 downto 0); 
   signal imem_q_b                  : std_logic_vector(31 downto 0); 
   
   signal dmem_address_b            : std_logic_vector(9 downto 0) := (others => '0');    
   signal dmem_data_b               : std_logic_vector(31 downto 0) := (others => '0');
   signal dmem_wren_a               : std_logic := '0'; 
   signal dmem_wren_b               : std_logic := '0';   
   signal dmem_q_a                  : std_logic_vector(63 downto 0); 
   signal dmem_q_b                  : std_logic_vector(31 downto 0);  
    
   signal dmem_128_address_a        : tDMEMarray; 
   signal dmem_128_address_b        : tDMEMarray; 
   signal dmem_128_data_a           : std_logic_vector(127 downto 0);
   signal dmem_128_data_b           : tDMEMarray;
   signal dmem_128_wren_a           : std_logic_vector(15 downto 0);
   signal dmem_128_wren_b           : std_logic_vector(15 downto 0);
   signal dmem_128_q_a              : std_logic_vector(127 downto 0);
   signal dmem_128_q_b              : tDMEMarray;
   signal dmem_128_rden_b           : std_logic;

   -- RSP core
   signal PC_trigger                : std_logic := '0';
   signal PC_out                    : unsigned(11 downto 0);
   signal break_core                : std_logic;
   
   signal core_reg_addr             : unsigned(4 downto 0);
   signal core_reg_dataWrite        : unsigned(31 downto 0);
   signal core_reg_RSP_read         : std_logic;
   signal core_reg_RSP_write        : std_logic;
   signal core_reg_RSP_dataRead     : unsigned(31 downto 0);
   
   -- savestates
   type t_ssarray is array(0 to 3) of std_logic_vector(63 downto 0);
   signal ss_in  : t_ssarray := (others => (others => '0'));  
   signal ss_out : t_ssarray := (others => (others => '0'));  
   
   signal ss_reg_we     : std_logic := '0';
   signal ss_vreg_we    : std_logic := '0';
   signal ss_regs_addr  : unsigned(4 downto 0) := (others => '0');
   signal ss_vregs_addr : unsigned(2 downto 0) := (others => '0');
   signal ss_regs_data  : std_logic_vector(31 downto 0) := (others => '0');

begin 

   reg_addr      <= 15x"2000" & core_reg_addr when (core_reg_RSP_read = '1' or core_reg_RSP_write = '1') else bus_addr;     
   reg_dataWrite <= std_logic_vector(core_reg_dataWrite) when (core_reg_RSP_write = '1') else bus_dataWrite;
   
   process (clk1x)
      variable var_dataRead : std_logic_vector(31 downto 0) := (others => '0');
   begin
      if rising_edge(clk1x) then
      
         dmem_wren_a    <= '0';
         imem_wren_a    <= '0';
            
         fifoin_reset   <= '0';
         fifoin_Rd      <= '0';
         
         fifoout_reset  <= '0';
         fifoout_Wr     <= '0';
         
         rdram_request  <= '0';
         
         RSP2RDP_we     <= '0';
         RSP2RDP_done   <= '0';
         
         error_Addr     <= '0';
         error_PCON     <= '0';
         
         PC_trigger     <= '0';
         
         mem_address_a_1 <= mem_address_a;
         fifoout_Wr_1    <= fifoout_Wr;
      
         if (reset = '1') then
            
            bus_done                   <= '0';

            SP_DMA_SPADDR              <= (others => '0');
            SP_DMA_RAMADDR             <= (others => '0');
            SP_DMA_LEN                 <= (others => '0');
            SP_DMA_COUNT               <= (others => '0');
            SP_DMA_SKIP                <= (others => '0');
            SP_STATUS_halt             <= '1';
            SP_STATUS_broke            <= ss_in(0)(38);
            SP_STATUS_dmabusy          <= '0';
            SP_STATUS_dmafull          <= '0';
            SP_STATUS_iofull           <= '0';
            SP_STATUS_singlestep       <= ss_in(0)(42);
            SP_STATUS_irqonbreak       <= ss_in(0)(43);
            SP_STATUS_signal0set       <= ss_in(0)(44);
            SP_STATUS_signal1set       <= ss_in(0)(45);
            SP_STATUS_signal2set       <= ss_in(0)(46);
            SP_STATUS_signal3set       <= ss_in(0)(47);
            SP_STATUS_signal4set       <= ss_in(0)(48);
            SP_STATUS_signal5set       <= ss_in(0)(49);
            SP_STATUS_signal6set       <= ss_in(0)(50);
            SP_STATUS_signal7set       <= ss_in(0)(51);
            SP_SEMAPHORE               <= ss_in(1)(37);
            SP_PC                      <= (others => '0');
            
            SP_DMA_CURRENT_SPADDR      <= (others => '0');
            SP_DMA_CURRENT_RAMADDR     <= (others => '0');
            SP_DMA_CURRENT_LEN         <= (others => '0');
            SP_DMA_CURRENT_COUNT       <= (others => '0');
            SP_DMA_CURRENT_SKIP        <= (others => '0');
            
            irq_out                    <= '0';
            
            bus_reg_req_read           <= '0';
            bus_reg_req_write          <= '0';
            
            imem_rden_bus              <= '0';
            dmem_rden_bus              <= '0';
            imem_wren_bus              <= '0';
            dmem_wren_bus              <= '0';
            
            RSP2RDP_req_latched        <= '0';
            
            MEMSTATE                   <= MEM_IDLE;
            
            DMASTATE                   <= DMA_IDLE;
            fifoout_req                <= '0';
            
            SP_PC                      <= unsigned(ss_in(0)(63 downto 52));   
            PC_trigger                 <= '1';
 
         elsif (ce = '1') then
         
            if (SP_STATUS_halt = '0' and imem_wren_a = '1' and mem_address_a = imem_address_b(9 downto 1)) then
               error_Addr <= '1';
            end if;            
            
            if (SP_STATUS_halt = '0' and dmem_wren_a = '1' and dmem_128_rden_b = '1' and dmem_128_address_a(0) = dmem_128_address_b(0)) then
               error_Addr <= '1';
            end if;
         
            bus_done     <= '0';
            bus_dataRead <= (others => '0');
            
            -- bus access latch
            if (bus_read = '1') then
               if (bus_addr < 16#40000#) then -- DMEM/IMEM
                  if (bus_addr(12) = '1') then
                     imem_rden_bus <= '1';
                  else
                     dmem_rden_bus <= '1';
                  end if;
               else
                  bus_reg_req_read <= '1';
               end if;
            end if;
               
            if (bus_write = '1') then
               if (bus_addr < 16#40000#) then -- DMEM/IMEM
                  if (bus_addr(12) = '1') then
                     imem_wren_bus <= '1';
                  else
                     dmem_wren_bus <= '1';
                  end if; 
               else
                  bus_reg_req_write <= '1';
               end if;
            end if;

            -- register read access
            var_dataRead := (others => '0');
            case (reg_addr(19 downto 2) & "00") is
               when x"40000" => var_dataRead(12 downto 3) := std_logic_vector(SP_DMA_CURRENT_SPADDR);    
               when x"40004" => var_dataRead(23 downto 3) := std_logic_vector(SP_DMA_CURRENT_RAMADDR);    
               when x"40008" | x"4000C" => 
                  var_dataRead(11 downto  3) := std_logic_vector(SP_DMA_CURRENT_LEN);    
                  var_dataRead(19 downto 12) := std_logic_vector(SP_DMA_CURRENT_COUNT);    
                  var_dataRead(31 downto 23) := std_logic_vector(SP_DMA_CURRENT_SKIP);    
               when x"40010" => 
                  var_dataRead(0)  := SP_STATUS_halt;    
                  var_dataRead(1)  := SP_STATUS_broke;    
                  var_dataRead(2)  := SP_STATUS_dmabusy or SP_STATUS_dmafull; -- games check for busy right after starting DMA in previous cycle
                  var_dataRead(3)  := SP_STATUS_dmafull;  
                  var_dataRead(4)  := SP_STATUS_iofull;    
                  var_dataRead(5)  := SP_STATUS_singlestep;    
                  var_dataRead(6)  := SP_STATUS_irqonbreak;    
                  var_dataRead(7)  := SP_STATUS_signal0set;    
                  var_dataRead(8)  := SP_STATUS_signal1set;    
                  var_dataRead(9)  := SP_STATUS_signal2set;    
                  var_dataRead(10) := SP_STATUS_signal3set;    
                  var_dataRead(11) := SP_STATUS_signal4set;    
                  var_dataRead(12) := SP_STATUS_signal5set;    
                  var_dataRead(13) := SP_STATUS_signal6set;    
                  var_dataRead(14) := SP_STATUS_signal7set;    
               when x"40014" => var_dataRead(0) := SP_STATUS_dmafull;    
               when x"40018" => var_dataRead(0) := SP_STATUS_dmabusy or SP_STATUS_dmafull; -- games check for busy right after starting DMA in previous cycle  
               when x"4001C" => 
                  var_dataRead(0) := SP_SEMAPHORE;   
                  if ((bus_reg_req_read = '1' and core_reg_RSP_write = '0') or core_reg_RSP_read = '1') then       
                     SP_SEMAPHORE  <= '1';
                  end if;
               when x"80000" => var_dataRead(11 downto 0) := std_logic_vector(SP_PC);    
               when others   => null;
            end case;
              
            if (bus_reg_req_read = '1' and core_reg_RSP_read = '0' and core_reg_RSP_write = '0') then
               bus_done         <= '1';              
               bus_dataRead     <= var_dataRead;
               bus_reg_req_read <= '0';
            end if;
            
            core_reg_RSP_dataRead <= unsigned(var_dataRead);
            
            -- register write access
            if (break_core = '1') then
               SP_STATUS_halt  <= '1';
               SP_STATUS_broke <= '1';
               if (SP_STATUS_irqonbreak = '1') then
                  irq_out <= '1';
               end if;
            end if;
            
            if (SP_STATUS_halt = '0') then
               SP_PC <= PC_out;
            end if;
            
            if (bus_reg_req_write = '1' and core_reg_RSP_read = '0' and core_reg_RSP_write = '0') then
               bus_done          <= '1';
               bus_reg_req_write <= '0';
            end if;
            
            if (RSP2RDP_req = '1') then
               RSP2RDP_req_latched <= '1';
            end if;
            
            if ((bus_reg_req_write = '1' and core_reg_RSP_read = '0') or core_reg_RSP_write = '1') then
               
               case (reg_addr(19 downto 2) & "00") is
                  when x"40000" => SP_DMA_SPADDR  <= unsigned(reg_dataWrite(12 downto 3));   
                  when x"40004" => SP_DMA_RAMADDR <= unsigned(reg_dataWrite(23 downto 3));   
                  when x"40008" | x"4000C" => 
                     SP_DMA_LEN    <= unsigned(reg_dataWrite(11 downto  3));     
                     SP_DMA_COUNT  <= unsigned(reg_dataWrite(19 downto 12));     
                     SP_DMA_SKIP   <= unsigned(reg_dataWrite(31 downto 23));
                     SP_STATUS_dmafull <= '1';
                     if (reg_addr(19 downto 2) & "00" = x"40008") then dma_next_isWrite <= '0'; else dma_next_isWrite <= '1'; end if;
                  when x"40010" => 
                     if (reg_dataWrite(0 ) = '1' and reg_dataWrite(1 ) = '0') then SP_STATUS_halt        <= '0'; end if;
                     if (reg_dataWrite(1 ) = '1' and reg_dataWrite(0 ) = '0') then SP_STATUS_halt        <= '1'; end if;
                     if (reg_dataWrite(2 ) = '1')                             then SP_STATUS_broke       <= '0'; end if;
                     if (reg_dataWrite(3 ) = '1' and reg_dataWrite(4 ) = '0') then irq_out               <= '0'; end if;
                     if (reg_dataWrite(4 ) = '1' and reg_dataWrite(3 ) = '0') then irq_out               <= '1'; end if;
                     if (reg_dataWrite(5 ) = '1' and reg_dataWrite(6 ) = '0') then SP_STATUS_singlestep  <= '0'; end if;
                     if (reg_dataWrite(6 ) = '1' and reg_dataWrite(5 ) = '0') then SP_STATUS_singlestep  <= '1'; end if;
                     if (reg_dataWrite(7 ) = '1' and reg_dataWrite(8 ) = '0') then SP_STATUS_irqonbreak  <= '0'; end if;
                     if (reg_dataWrite(8 ) = '1' and reg_dataWrite(7 ) = '0') then SP_STATUS_irqonbreak  <= '1'; end if;
                     if (reg_dataWrite(9 ) = '1' and reg_dataWrite(10) = '0') then SP_STATUS_signal0set  <= '0'; end if;
                     if (reg_dataWrite(10) = '1' and reg_dataWrite( 9) = '0') then SP_STATUS_signal0set  <= '1'; end if;
                     if (reg_dataWrite(11) = '1' and reg_dataWrite(12) = '0') then SP_STATUS_signal1set  <= '0'; end if;
                     if (reg_dataWrite(12) = '1' and reg_dataWrite(11) = '0') then SP_STATUS_signal1set  <= '1'; end if;
                     if (reg_dataWrite(13) = '1' and reg_dataWrite(14) = '0') then SP_STATUS_signal2set  <= '0'; end if;
                     if (reg_dataWrite(14) = '1' and reg_dataWrite(13) = '0') then SP_STATUS_signal2set  <= '1'; end if;
                     if (reg_dataWrite(15) = '1' and reg_dataWrite(16) = '0') then SP_STATUS_signal3set  <= '0'; end if;
                     if (reg_dataWrite(16) = '1' and reg_dataWrite(15) = '0') then SP_STATUS_signal3set  <= '1'; end if;
                     if (reg_dataWrite(17) = '1' and reg_dataWrite(18) = '0') then SP_STATUS_signal4set  <= '0'; end if;
                     if (reg_dataWrite(18) = '1' and reg_dataWrite(17) = '0') then SP_STATUS_signal4set  <= '1'; end if;
                     if (reg_dataWrite(19) = '1' and reg_dataWrite(20) = '0') then SP_STATUS_signal5set  <= '0'; end if;
                     if (reg_dataWrite(20) = '1' and reg_dataWrite(19) = '0') then SP_STATUS_signal5set  <= '1'; end if;
                     if (reg_dataWrite(21) = '1' and reg_dataWrite(22) = '0') then SP_STATUS_signal6set  <= '0'; end if;
                     if (reg_dataWrite(22) = '1' and reg_dataWrite(21) = '0') then SP_STATUS_signal6set  <= '1'; end if;
                     if (reg_dataWrite(23) = '1' and reg_dataWrite(24) = '0') then SP_STATUS_signal7set  <= '0'; end if;
                     if (reg_dataWrite(24) = '1' and reg_dataWrite(23) = '0') then SP_STATUS_signal7set  <= '1'; end if;
                  when x"4001C" => SP_SEMAPHORE <= '0';    
                  when x"80000" => 
                     SP_PC      <= unsigned(reg_dataWrite(11 downto 2)) & "00";   
                     PC_trigger <= '1';
                     if (SP_STATUS_halt = '0') then
                        error_PCON <= '1';
                     end if;
                  when others => null;
               end case;
            end if;
            
            -- Bus/DMA Memory access
            case (MEMSTATE) is
            
               when MEM_IDLE =>
                  if (imem_wren_bus = '1') then
                     bus_done       <= '1';
                     imem_wren_bus  <= '0';
                     imem_wren_a    <= '1';
                     mem_address_a <= std_logic_vector(bus_addr(11 downto 3));
                     if (bus_addr(2) = '1') then
                        mem_be_a   <= x"F0";
                        mem_data_a <= byteswap32(bus_dataWrite) & 32x"0";
                     else
                        mem_be_a   <= x"0F";
                        mem_data_a <= 32x"0" & byteswap32(bus_dataWrite);
                     end if;
                     
                  elsif (dmem_wren_bus = '1') then
                     bus_done       <= '1';
                     dmem_wren_bus  <= '0';
                     dmem_wren_a    <= '1';
                     mem_address_a <= std_logic_vector(bus_addr(11 downto 3));
                     if (bus_addr(2) = '1') then
                        mem_be_a   <= x"F0";
                        mem_data_a <= byteswap32(bus_dataWrite) & 32x"0";
                     else
                        mem_be_a   <= x"0F";
                        mem_data_a <= 32x"0" & byteswap32(bus_dataWrite);
                     end if;
                  
                  elsif (imem_rden_bus = '1') then
                     imem_rden_bus <= '0';
                     mem_address_a <= std_logic_vector(bus_addr(11 downto 3));
                     MEMSTATE      <= MEM_BUS_WAIT_IMEM;
                  
                  elsif (dmem_rden_bus = '1') then
                     dmem_rden_bus <= '0';
                     mem_address_a <= std_logic_vector(bus_addr(11 downto 3));
                     MEMSTATE      <= MEM_BUS_WAIT_DMEM;
                     
                  elsif (fifoin_Empty = '0' and (fifoin_Rd = '0' or use2Xclock = '1')) then
                     if (SP_DMA_CURRENT_SPADDR(12) = '1') then
                        imem_wren_a <= '1';
                     else
                        dmem_wren_a <= '1';
                     end if;
                     mem_address_a <= std_logic_vector(SP_DMA_CURRENT_SPADDR(11 downto 3));
                     mem_be_a      <= x"FF";
                     mem_data_a    <= fifoin_Dout;
                     fifoin_Rd     <= '1';
                     SP_DMA_CURRENT_SPADDR(11 downto 3) <= SP_DMA_CURRENT_SPADDR(11 downto 3) + 1;
                    
                  elsif (SP_STATUS_dmabusy = '1' and fifoout_nearfull = '0' and dma_isWrite = '1' and SP_DMA_CURRENT_WORKLEN > 0) then
                     MEMSTATE      <= MEM_STARTDMA;
                     mem_address_a <= std_logic_vector(SP_DMA_CURRENT_SPADDR(11 downto 3));
                     SP_DMA_CURRENT_SPADDR(11 downto 3) <= SP_DMA_CURRENT_SPADDR(11 downto 3) + 1;
                     if (SP_DMA_CURRENT_WORKLEN >= 16) then
                        SP_DMA_CURRENT_FETCHLEN <= 16;
                     else
                        SP_DMA_CURRENT_FETCHLEN <= to_integer(SP_DMA_CURRENT_WORKLEN(3 downto 0));
                     end if;
                     
                  elsif (RSP2RDP_req_latched = '1' and SP_STATUS_dmabusy = '0') then
                     RSP2RDP_req_latched     <= '0';
                     MEMSTATE                <= MEM_STARTDMA_RDP;
                     mem_address_a           <= std_logic_vector(RSP2RDP_rdaddr(11 downto 3));
                     SP_DMA_CURRENT_FETCHLEN <= to_integer(RSP2RDP_len);
                     
                  end if;
                  
               when MEM_BUS_WAIT_IMEM =>
                  MEMSTATE <= MEM_READ_IMEM;
                  
               when MEM_READ_IMEM =>
                  MEMSTATE <= MEM_IDLE;
                  bus_done <= '1';
                  if (bus_addr(2) = '1') then
                     bus_dataRead   <= byteswap32(imem_q_a(63 downto 32));
                  else
                     bus_dataRead   <= byteswap32(imem_q_a(31 downto 0));
                  end if;
                  
               when MEM_BUS_WAIT_DMEM =>
                  MEMSTATE <= MEM_READ_DMEM;
                  
               when MEM_READ_DMEM =>
                  MEMSTATE <= MEM_IDLE;
                  bus_done <= '1';
                  if (bus_addr(2) = '1') then
                     bus_dataRead   <= byteswap32(dmem_q_a(63 downto 32));
                  else
                     bus_dataRead   <= byteswap32(dmem_q_a(31 downto 0));
                  end if;
                  
               when MEM_STARTDMA =>
                  MEMSTATE      <= MEM_RUNDMA;
                  mem_address_a <= std_logic_vector(SP_DMA_CURRENT_SPADDR(11 downto 3));
                  SP_DMA_CURRENT_SPADDR(11 downto 3) <= SP_DMA_CURRENT_SPADDR(11 downto 3) + 1;
                  fifoout_req   <= '1';
            
               when MEM_RUNDMA =>
                  mem_address_a <= std_logic_vector(SP_DMA_CURRENT_SPADDR(11 downto 3));
                  if (SP_DMA_CURRENT_FETCHLEN > 1) then
                     SP_DMA_CURRENT_SPADDR(11 downto 3) <= SP_DMA_CURRENT_SPADDR(11 downto 3) + 1;
                  else
                     MEMSTATE <= WAIT_DMAFINISH;
                     SP_DMA_CURRENT_SPADDR(11 downto 3) <= SP_DMA_CURRENT_SPADDR(11 downto 3) - 1;
                  end if;
                  SP_DMA_CURRENT_FETCHLEN <= SP_DMA_CURRENT_FETCHLEN - 1;
                  SP_DMA_CURRENT_WORKLEN  <= SP_DMA_CURRENT_WORKLEN - 1;
                  if (SP_DMA_CURRENT_SPADDR(12) = '1') then
                     fifoout_Din <= std_logic_vector(SP_DMA_CURRENT_RAMADDR) & imem_q_a;
                  else
                     fifoout_Din <= std_logic_vector(SP_DMA_CURRENT_RAMADDR) & dmem_q_a;
                  end if;
                  fifoout_Wr <= '1';
                  SP_DMA_CURRENT_RAMADDR <= SP_DMA_CURRENT_RAMADDR + 1;
                  
               when WAIT_DMAFINISH =>
                  if (fifoout_empty = '1' and fifoout_Wr = '0' and (fifoout_Wr_1 = '0' or use2Xclock = '1')) then
                     MEMSTATE    <= MEM_IDLE;
                     fifoout_req <= '0';                     
                  end if;
                  
               when MEM_STARTDMA_RDP =>
                  MEMSTATE      <= MEM_RUNDMA_RDP;
                  mem_address_a <= std_logic_vector(unsigned(mem_address_a) + 1);
                  
               when MEM_RUNDMA_RDP =>
                  mem_address_a <= std_logic_vector(unsigned(mem_address_a) + 1);
                  if (SP_DMA_CURRENT_FETCHLEN < 2) then
                     MEMSTATE     <= MEM_IDLE;
                     RSP2RDP_done <= '1';
                  end if;
                  SP_DMA_CURRENT_FETCHLEN <= SP_DMA_CURRENT_FETCHLEN - 1;
                  RSP2RDP_we   <= '1';
                  RSP2RDP_data <= byteswap64(dmem_q_a);
            
            end case;

            -- DMA prefetch
            case (DMASTATE) is
            
               when DMA_IDLE =>
                  if (bus_reg_req_write = '0' and core_reg_RSP_write = '0') then
                  
                     if (SP_STATUS_dmabusy = '1') then
                      
                        if (SP_DMA_CURRENT_WORKLEN > 0) then
                           if (dma_isWrite = '0' and fifoin_nearfull = '0') then
                              DMASTATE         <= DMA_READBLOCK;
                              rdram_request    <= '1';
                              rdram_rnw        <= '1';
                              rdram_address    <= "0000" & SP_DMA_CURRENT_RAMADDR & "000";
                              if (SP_DMA_CURRENT_WORKLEN >= 16) then
                                 rdram_burstcount       <= to_unsigned(16,10);
                              else
                                 rdram_burstcount       <= SP_DMA_CURRENT_WORKLEN;
                              end if;
                           end if;
                        else
                           if ((dma_isWrite = '1' and fifoout_empty = '1' and fifoout_Wr = '0' and (fifoout_Wr_1 = '0' or use2Xclock = '1')) or (dma_isWrite = '0' and fifoin_Empty = '1')) then
                              if (SP_DMA_CURRENT_COUNT > 0) then
                                 SP_DMA_CURRENT_COUNT    <= SP_DMA_CURRENT_COUNT - 1;
                                 SP_DMA_CURRENT_RAMADDR  <= SP_DMA_CURRENT_RAMADDR + SP_DMA_CURRENT_SKIP;
                                 SP_DMA_CURRENT_WORKLEN  <= ('0' & SP_DMA_CURRENT_LEN) + 1;
                              else
                                 SP_DMA_CURRENT_LEN      <= (others => '1');
                                 SP_STATUS_dmabusy       <= '0';
                              end if;
                           end if;
                        end if;
                        
                     elsif (SP_STATUS_dmafull = '1') then
                        SP_STATUS_dmabusy       <= '1';
                        SP_STATUS_dmafull       <= '0';
                        dma_isWrite             <= dma_next_isWrite;
                        SP_DMA_CURRENT_SPADDR   <= SP_DMA_SPADDR;
                        SP_DMA_CURRENT_RAMADDR  <= SP_DMA_RAMADDR;
                        SP_DMA_CURRENT_LEN      <= SP_DMA_LEN;
                        SP_DMA_CURRENT_COUNT    <= SP_DMA_COUNT;
                        SP_DMA_CURRENT_SKIP     <= SP_DMA_SKIP;
                        SP_DMA_CURRENT_WORKLEN  <= ('0' & SP_DMA_LEN) + 1;
                     end if;

                  end if;

               when DMA_READBLOCK =>
                  if (rdram_done = '1') then
                     DMASTATE               <= DMA_IDLE;
                     SP_DMA_CURRENT_WORKLEN <= SP_DMA_CURRENT_WORKLEN - rdram_burstcount;
                     SP_DMA_CURRENT_RAMADDR <= SP_DMA_CURRENT_RAMADDR + rdram_burstcount;
                  end if;
            
            end case;
            
         else  -- no ce -> savestates
            
            imem_wren_a   <= SS_wren_IMEM;
            dmem_wren_a   <= SS_wren_DMEM;
            mem_address_a <= std_logic_vector(SS_Adr);
            mem_be_a      <= x"FF";
            mem_data_a    <= SS_DataWrite;
            
         end if;
         
      end if; -- clk
   end process;
   
   rdram_writeMask <= x"FF";
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         
         if (rdram_granted = '1') then
            dma_store <= '1';
         end if;
         
         if (rdram_done = '1') then
            dma_store <= '0';
         end if;
         
      end if;
   end process; 
   
   -- DMA exchange
   iSyncFifo_IN: entity mem.SyncFifoFallThrough
   generic map
   (
      SIZE             => 64,
      DATAWIDTH        => 64,
      NEARFULLDISTANCE => 16
   )
   port map
   ( 
      clk      => clk2x,
      reset    => fifoin_reset,  
      Din      => ddr3_DOUT,     
      Wr       => (ddr3_DOUT_READY and dma_store),      
      Full     => error_Fifo,    
      NearFull => fifoin_nearfull,
      Dout     => fifoin_Dout,    
      Rd       => (fifoin_Rd and clk2xIndex),      
      Empty    => fifoin_Empty   
   );
   
   -- Memory
   iIMEM: entity work.dpram_dif_be
   generic map 
   ( 
      addr_width_a    => 9,
      data_width_a    => 64,
      addr_width_b    => 10,
      data_width_b    => 32,
      width_byteena_a => 8,
      width_byteena_b => 4
   )
   port map
   (
      clock_a     => clk1x,
      address_a   => mem_address_a,
      data_a      => mem_data_a,
      wren_a      => imem_wren_a,
      byteena_a   => mem_be_a,
      q_a         => imem_q_a,
      
      clock_b     => clk1x,
      address_b   => imem_address_b,
      data_b      => 32x"0",
      wren_b      => '0',
      byteena_b   => "0000",
      q_b         => imem_q_b
   );
   
   dmem_128_data_a <= mem_data_a & mem_data_a;
   
   dmem_q_a        <= dmem_128_q_a(127 downto 64) when (mem_address_a_1(0) = '1') else
                      dmem_128_q_a( 63 downto  0);
                      
   dmem_128_wren_a <= mem_be_a & x"00" when (dmem_wren_a = '1' and mem_address_a(0) = '1') else
                      x"00" & mem_be_a when (dmem_wren_a = '1' and mem_address_a(0) = '0') else
                      x"0000";
   
   gDMEM: for i in 0 to 15 generate
   begin
   
      dmem_128_address_a(i) <= mem_address_a(8 downto 1);
      
      iDMEM: entity work.dpram
      generic map 
      ( 
         addr_width => 8,
         data_width => 8
      )
      port map
      (
         clock_a     => clk1x,
         address_a   => dmem_128_address_a(i),
         data_a      => dmem_128_data_a(((i * 8) + 7) downto (i*8)),
         wren_a      => dmem_128_wren_a(i),
         q_a         => dmem_128_q_a(((i * 8) + 7) downto (i*8)),
         
         clock_b     => clk1x,
         address_b   => dmem_128_address_b(i),
         data_b      => dmem_128_data_b(i),
         wren_b      => dmem_128_wren_b(i),
         q_b         => dmem_128_q_b(i)
      );
   
   end generate;
   
   RSP_RDP_reg_addr    <= core_reg_addr;
   RSP_RDP_reg_dataOut <= core_reg_dataWrite;
   
   iRSP_core : entity work.RSP_core
   port map
   (
      clk1x                 => clk1x,   
      ce_1x                 => not SP_STATUS_halt,   
      reset_1x              => reset,
      
      PC_trigger            => PC_trigger,
      PC_in                 => SP_PC,     
      PC_out                => PC_out,    
      break_out             => break_core,
      
      imem_addr             => imem_address_b,
      imem_dataRead         => imem_q_b,
      
      dmem_addr             => dmem_128_address_b,       
      dmem_dataWrite        => dmem_128_data_b,  
      dmem_ReadEnable       => dmem_128_rden_b,
      dmem_WriteEnable      => dmem_128_wren_b,
      dmem_dataRead         => dmem_128_q_b,   
      
      reg_addr              => core_reg_addr,        
      reg_dataWrite         => core_reg_dataWrite,   
      reg_RSP_read          => core_reg_RSP_read,    
      reg_RDP_read          => RSP_RDP_reg_read,   
      reg_RSP_write         => core_reg_RSP_write,   
      reg_RDP_write         => RSP_RDP_reg_write,   
      reg_RSP_dataRead      => core_reg_RSP_dataRead,
      reg_RDP_dataRead      => RSP_RDP_reg_dataIn,

      error_instr           => error_instr,
      error_stall           => error_stall,
      
      ss_reg_we             => ss_reg_we,    
      ss_vreg_we            => ss_vreg_we,   
      ss_regs_addr          => ss_regs_addr, 
      ss_vregs_addr         => ss_vregs_addr,
      ss_regs_data          => ss_regs_data 
   );
        
--##############################################################
--############################### savestates
--##############################################################

   SS_DataRead <= (others => '0');
   SS_idle     <= '1';

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         ss_reg_we  <= '0';
         ss_vreg_we <= '0';
      
         if (SS_reset = '1') then
            for i in 0 to 3 loop
               ss_in(i) <= (others => '0');
            end loop; 
         elsif (SS_wren_RSP = '1' and SS_Adr < 4) then
            ss_in(to_integer(SS_Adr)) <= SS_DataWrite;
         elsif (SS_wren_RSP = '1' and SS_Adr >= 32 and SS_Adr < 64) then
            ss_reg_we    <= '1';
            ss_regs_addr <= SS_Adr(4 downto 0);
         elsif (SS_wren_RSP = '1' and SS_Adr >= 256 and SS_Adr < 512) then
            ss_vreg_we    <= '1';
            ss_regs_addr  <= SS_Adr(7 downto 3);
            ss_vregs_addr <= SS_Adr(2 downto 0);
         end if;
         
         ss_regs_data <= SS_DataWrite(31 downto 0);
      
      end if;
   end process;
   
   --##############################################################
--############################### export
--##############################################################
   
   -- synthesis translate_off
   goutput : if 1 = 1 generate
      signal out_count        : unsigned(31 downto 0) := (others => '0');
   begin
   
      process
         file outfile          : text;
         variable f_status     : FILE_OPEN_STATUS;
         variable line_out     : line;
         variable stringbuffer : string(1 to 31);
      begin
   
         file_open(f_status, outfile, "R:\\rsp_DMA2RAM_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\rsp_DMA2RAM_sim.txt", append_mode);
         
         while (true) loop
            
            wait until rising_edge(clk1x);
             
            if (reset = '1') then
               file_close(outfile);
               file_open(f_status, outfile, "R:\\rsp_DMA2RAM_sim.txt", write_mode);
               file_close(outfile);
               file_open(f_status, outfile, "R:\\rsp_DMA2RAM_sim.txt", append_mode);
               out_count <= (others => '0');
            end if;
            

            if (fifoout_Wr = '1') then
               write(line_out, string'(" "));
               write(line_out, to_hstring(out_count));
               write(line_out, string'("   ")); 
               
               write(line_out, to_hstring(fifoout_Din(84 downto 64) & "000"));
               write(line_out, string'("   ")); 
               
               write(line_out, to_hstring(fifoout_Din(63 downto 0)));
               write(line_out, string'(" "));
               
               writeline(outfile, line_out);
               out_count <= out_count + 1;
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;

   -- synthesis translate_on  
        
end architecture;





