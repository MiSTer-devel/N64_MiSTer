library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;

entity SI is
   port 
   (
      clk1x            : in  std_logic;
      ce               : in  std_logic;
      reset            : in  std_logic;
      
      irq_out          : out std_logic := '0';
      
      SIPIF_ramreq     : out std_logic := '0';
      SIPIF_addr       : out unsigned(5 downto 0) := (others => '0');
      SIPIF_writeEna   : out std_logic := '0'; 
      SIPIF_writeData  : out std_logic_vector(7 downto 0) := (others => '0');
      SIPIF_ramgrant   : in  std_logic;
      SIPIF_readData   : in  std_logic_vector(7 downto 0);
      
      SIPIF_writeProc  : out std_logic := '0';
      SIPIF_readProc   : out std_logic := '0';
      SIPIF_ProcDone   : in  std_logic;
      
      bus_addr         : in  unsigned(19 downto 0); 
      bus_dataWrite    : in  std_logic_vector(31 downto 0);
      bus_read         : in  std_logic;
      bus_write        : in  std_logic;
      bus_dataRead     : out std_logic_vector(31 downto 0) := (others => '0');
      bus_done         : out std_logic := '0';
      
      rdram_request    : out std_logic := '0';
      rdram_rnw        : out std_logic := '0'; 
      rdram_address    : out unsigned(27 downto 0):= (others => '0');
      rdram_burstcount : out unsigned(9 downto 0):= (others => '0');
      rdram_writeMask  : out std_logic_vector(7 downto 0) := (others => '0'); 
      rdram_dataWrite  : out std_logic_vector(63 downto 0) := (others => '0');
      rdram_done       : in  std_logic;
      rdram_dataRead   : in  std_logic_vector(63 downto 0)
   );
end entity;

architecture arch of SI is

   signal SI_DRAM_ADDR           : unsigned(23 downto 0); -- 0x04800000 (W): [23:0] starting RDRAM address
   signal SI_PIF_ADDR_RD64B      : unsigned(31 downto 0); -- 0x04800004 SI address read 64B (W): [] any write causes a 64B DMA write
   signal SI_PIF_ADDR_WR64B      : unsigned(31 downto 0); -- 0x04800010 SI address write 64B (W) : [] any write causes a 64B DMA read
   signal SI_STATUS_DMA_busy     : std_logic;             -- 0x04800018 (W): [] any write clears interrupt (R) : [0] DMA busy
   signal SI_STATUS_IO_busy      : std_logic;             -- 0x04800018 (W): [] any write clears interrupt (R) : [1] IO read busy 
   signal SI_STATUS_readPending  : std_logic;             -- 0x04800018 (W): [] any write clears interrupt (R) : [2] readPending
   signal SI_STATUS_DMA_error    : std_logic;             -- 0x04800018 (W): [] any write clears interrupt (R) : [3] dmaError
   signal SI_STATUS_pchState     : unsigned(3 downto 0);  -- 0x04800018 (W): [] any write clears interrupt (R) : [7:4] pchState
   signal SI_STATUS_dmaState     : unsigned(3 downto 0);  -- 0x04800018 (W): [] any write clears interrupt (R) : [11:8] dmaState
   signal SI_STATUS_IRQ          : std_logic;             -- 0x04800018 (W): [] any write clears interrupt (R) : [12] interrupt
   
   type tState is
   (
      IDLE,
      
      READ_WAITPIFPROC,
      READ_FROMPIF,
      READ_WAIT1,
      READ_WAIT2,
      READ_DATACCU,
      READ_WRITERDRAM,
      READ_WAITRDRAM,
      
      WRITE_FETCH,
      WRITE_WAITRDRAM,
      WRITE_TOPIF,
      WRITE_WAITPIFPROC,
      
      WAITDONE
   );
   signal state                  : tState := IDLE;
   
   signal nextDMAisRead          : std_logic := '0';
   signal nextDMATime            : integer range 0 to 2047 := 0;
   signal pifIndex               : unsigned(5 downto 0) := (others => '0');
   signal dataLatch              : std_logic_vector(63 downto 0) := (others => '0');
   signal piframCheck            : unsigned(10 downto 0) := (others => '0');

begin 

   irq_out <= SI_STATUS_IRQ;
   
   rdram_burstcount <= 10x"01";
   rdram_writeMask  <= x"FF";

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         rdram_request <= '0';
         
         if (reset = '1') then
            
            bus_done                <= '0';
            
            SI_DRAM_ADDR            <= (others => '0');
            SI_PIF_ADDR_RD64B       <= (others => '0');
            SI_PIF_ADDR_WR64B       <= (others => '0');
            SI_STATUS_DMA_busy      <= '0';
            SI_STATUS_IO_busy       <= '0';
            SI_STATUS_readPending   <= '0';
            SI_STATUS_DMA_error     <= '0';
            SI_STATUS_pchState      <= (others => '0');
            SI_STATUS_dmaState      <= (others => '0');
            SI_STATUS_IRQ           <= '0';
            
            state                   <= IDLE;
            SIPIF_ramreq            <= '0';
            SIPIF_writeEna          <= '0';
            SIPIF_writeProc         <= '0';
            SIPIF_readProc          <= '0';
            
         elsif (ce = '1') then
         
            bus_done         <= '0';
            bus_dataRead     <= (others => '0');
            
            SIPIF_writeEna   <= '0';
            SIPIF_writeProc  <= '0';
            SIPIF_readProc   <= '0';

            -- bus read
            if (bus_read = '1') then
               bus_done <= '1';
               case (bus_addr(19 downto 2) & "00") is   
                  when x"00000" => bus_dataRead(23 downto 0) <= std_logic_vector(SI_DRAM_ADDR);
                  when x"00004" => bus_dataRead              <= std_logic_vector(SI_PIF_ADDR_RD64B);
                  when x"00010" => bus_dataRead              <= std_logic_vector(SI_PIF_ADDR_WR64B);
                  when x"00018" =>
                     bus_dataRead(0)            <= SI_STATUS_DMA_busy;  
                     bus_dataRead(1)            <= SI_STATUS_IO_busy;    
                     bus_dataRead(2)            <= SI_STATUS_readPending;
                     bus_dataRead(3)            <= SI_STATUS_DMA_error;  
                     bus_dataRead(7 downto 4)   <= std_logic_vector(SI_STATUS_pchState);   
                     bus_dataRead(11 downto 8)  <= std_logic_vector(SI_STATUS_dmaState);   
                     bus_dataRead(12)           <= SI_STATUS_IRQ;        
                  when others   => null;                  
               end case;
            end if;
            
            -- bus write
            if (bus_write = '1') then
               bus_done <= '1';
               
               case (bus_addr(19 downto 2) & "00") is
                  when x"00000" => SI_DRAM_ADDR <= unsigned(bus_dataWrite(23 downto 3)) & "000";
                  when x"00004" => 
                     SI_PIF_ADDR_RD64B  <= unsigned(bus_dataWrite(31 downto 1)) & '0';
                     SI_STATUS_DMA_busy <= '1';
                     nextDMAisRead      <= '1';
                     
                  when x"00010" => 
                     SI_PIF_ADDR_WR64B  <= unsigned(bus_dataWrite(31 downto 1)) & '0';
                     SI_STATUS_DMA_busy <= '1';
                     nextDMAisRead      <= '0';
                     nextDMATime        <= 2047;
                     
                  when x"00018" => SI_STATUS_IRQ     <= '0';
                  when others   => null;                  
               end case;
               
            end if;
            
            
            if (nextDMAtime > 0) then
               nextDMAtime <= nextDMAtime - 1; 
            end if;
            
            case (state) is
            
               when IDLE =>
                  pifIndex   <= (others => '0');
                  if (SI_STATUS_DMA_busy = '1') then
                     if (nextDMAisRead = '1') then
                        state           <= READ_WAITPIFPROC;
                        SIPIF_readProc  <= '1';
                        piframCheck     <= SI_PIF_ADDR_RD64B(10 downto 0);
                     else
                        state           <= WRITE_FETCH;
                        SIPIF_ramreq    <= '1';
                        piframCheck     <= SI_PIF_ADDR_WR64B(10 downto 0);
                     end if;
                  end if;
                  
               -- reading from PIF 
               when READ_WAITPIFPROC =>
                  if (SIPIF_ProcDone = '1') then
                     state        <= READ_FROMPIF;
                     SIPIF_ramreq <= '1';
                  end if;
                  
               when READ_FROMPIF =>
                  state         <= READ_WAIT1;
                  SIPIF_addr    <= pifIndex;
                  rdram_address <= (x"0" & SI_DRAM_ADDR(23 downto 0)) + (pifIndex(5 downto 3) & "000");
                  nextDMATime   <= 2047;
                  
               when READ_WAIT1 =>
                  state <= READ_WAIT2;
                  
               when READ_WAIT2 =>
                  state <= READ_DATACCU;

               when READ_DATACCU =>
                  if (piframCheck < 16#7C0#) then
                     rdram_dataWrite <= x"00" & rdram_dataWrite(63 downto 8);
                  else
                     rdram_dataWrite <= SIPIF_readData & rdram_dataWrite(63 downto 8);
                  end if;
                  pifIndex        <= pifIndex + 1;
                  piframCheck     <= piframCheck + 1;
                  if (pifIndex(2 downto 0) = "111") then
                     state <= READ_WRITERDRAM;
                  else
                     state        <= READ_FROMPIF;
                  end if;
                  
               when READ_WRITERDRAM =>
                  state            <= READ_WAITRDRAM;
                  rdram_request    <= '1';
                  rdram_rnw        <= '0';
                  
               when READ_WAITRDRAM =>  
                  if (rdram_done = '1') then
                     if (pifIndex(5 downto 3) = "000") then
                        state         <= WAITDONE;
                        SIPIF_ramreq  <= '0';
                     else
                        state         <= READ_FROMPIF;
                     end if;
                  end if;
                  
               -- writing to PIF  
               when WRITE_FETCH =>
                  state            <= WRITE_WAITRDRAM;
                  rdram_request    <= '1';
                  rdram_rnw        <= '1';
                  rdram_address    <= (x"0" & SI_DRAM_ADDR(23 downto 0)) + (pifIndex(5 downto 3) & "000");
                  
               when WRITE_WAITRDRAM =>
                  if (rdram_done = '1') then
                     state     <= WRITE_TOPIF;
                     dataLatch <= rdram_dataRead;
                  end if;
                  
               when WRITE_TOPIF =>
                  if (SIPIF_ramgrant = '1') then
                     if (piframCheck >= 16#7C0#) then
                        SIPIF_writeEna  <= '1';
                     end if;
                     SIPIF_addr      <= pifIndex;
                     SIPIF_writeData <= dataLatch(7 downto 0);
                     dataLatch       <= x"00" & dataLatch(63 downto 8);
                     pifIndex        <= pifIndex + 1;
                     piframCheck     <= piframCheck + 1;
                     if (pifIndex(2 downto 0) = "111") then
                        if (pifIndex(5 downto 3) = "111") then
                           state           <= WRITE_WAITPIFPROC;
                           SIPIF_ramreq    <= '0';
                           SIPIF_writeProc <= '1';
                        else
                           state <= WRITE_FETCH;
                        end if;
                     end if;
                  end if;
                  
               when WRITE_WAITPIFPROC =>
                  if (SIPIF_ProcDone = '1') then
                     state <= WAITDONE;
                  end if;
                  
               when WAITDONE =>
                  if (nextDMAtime = 0) then
                     state              <= IDLE;
                     SI_STATUS_DMA_busy <= '0';
                     SI_STATUS_IRQ      <= '1';
                  end if;
            
            end case;

         end if;
      end if;
   end process;

end architecture;





