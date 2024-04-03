library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity savestates is
   generic 
   (
      FASTSIM        : std_logic;
      SAVETYPESCOUNT : integer := 14
   );
   port 
   (
      clk1x                   : in  std_logic;  
      clk93                   : in  std_logic;  
      reset_in                : in  std_logic;
      reset_out_1x            : out std_logic := '0';
      reset_out_93            : out std_logic := '0';
      ss_reset_1x             : out std_logic := '0';
      ss_reset_93             : out std_logic := '0';
         
      RAMSIZE8                : in  std_logic;
         
      hps_busy                : in  std_logic;
      sdrammux_idle           : in  std_logic;
      
      load_done               : out std_logic := '0';
            
      increaseSSHeaderCount   : in  std_logic;  
      save                    : in  std_logic;  
      load                    : in  std_logic;
      savestate_address       : in  integer;
      savestate_busy          : out std_logic;

      SS_idle                 : in  std_logic;
      system_paused           : in  std_logic;
      savestate_pause         : out std_logic := '0';
      
      SS_DataWrite            : out std_logic_vector(63 downto 0) := (others => '0');
      SS_Adr                  : out unsigned(11 downto 0) := (others => '0');
      SS_wren                 : out std_logic_vector(SAVETYPESCOUNT - 1 downto 0);
      SS_rden                 : out std_logic_vector(SAVETYPESCOUNT - 1 downto 0);
      SS_DataRead_CPU         : in  std_logic_vector(63 downto 0) := (others => '0');
            
      SS_DataWrite_93         : out std_logic_vector(63 downto 0) := (others => '0');
      SS_Adr_93               : out unsigned(11 downto 0) := (others => '0');
      SS_wren_93              : out std_logic_vector(SAVETYPESCOUNT - 1 downto 0);
            
      loading_savestate       : out std_logic := '0';
      saving_savestate        : out std_logic := '0';
      
      romcopy_start           : in  std_logic;
      romcopy_size            : in  unsigned(26 downto 0);
      romcopy_nearFull        : in  std_logic;
      romcopy_active          : out std_logic := '0';
                   
      rdram_request           : out std_logic := '0';
      rdram_rnw               : out std_logic := '0'; 
      rdram_address           : out unsigned(27 downto 0):= (others => '0');
      rdram_burstcount        : out unsigned(9 downto 0):= (others => '0');
      rdram_writeMask         : out std_logic_vector(7 downto 0) := (others => '0'); 
      rdram_dataWrite         : out std_logic_vector(63 downto 0) := (others => '0');
      rdram_done              : in  std_logic;
      rdram_dataRead          : in  std_logic_vector(63 downto 0)
   );
end entity;

architecture arch of savestates is

   constant STATESIZE      : integer := 4194304;
   
   constant SETTLECOUNT    : integer := 4095;
   
   signal savetype_counter : integer range 0 to SAVETYPESCOUNT;
   type tsavetype is record
      offset      : integer;
      size        : integer;
   end record;
   type t_savetypes is array(0 to SAVETYPESCOUNT - 1) of tsavetype;
   constant savetypes : t_savetypes := 
   (
      (  2048,       4),    -- AI           0 
      (  3072,       1),    -- MI           1 
      (  4096,       8),    -- PI           2 
      (  5120,     128),    -- PIF          3 
      (  6144,       2),    -- RDP          4 
      (  7168,       8),    -- RDRAMREGS    5 
      (  8192,       8),    -- RI           6 
      (  9216,     512),    -- RSP          7 
      ( 10240,       8),    -- SI           8 
      ( 11264,       8),    -- VI           9 
      ( 16384,    4096),    -- CPU          10
      ( 32768,     512),    -- DMEM         11
      ( 65536,     512),    -- IMEM         12   
      (1048576,1048576)     -- RAM          13
   );

   type tstate is
   (
      IDLE,
      
      ROMCOPY_REQUEST,
      ROMCOPY_READ,
      
      WAITPAUSE,
      WAITIDLE,
      SAVE_WAITSETTLE,
--      SAVEMEMORY_NEXT,
--      SAVEMEMORY_STARTREAD,
--      SAVEMEMORY_WAITREAD,
--      SAVEMEMORY_LOAD_VRAM,
--      SAVEMEMORY_LOAD_RAM,
--      SAVEMEMORY_LOAD_SPURAM,
--      SAVEMEMORY_WAIT_SPURAM,
--      SAVEMEMORY_READ,
--      SAVEMEMORY_WRITE,
      SAVESIZEAMOUNT,
--      SAVEWAITHPSDONE,
      LOAD_WAITSETTLE,
      LOAD_HEADERAMOUNTCHECK,
      LOADMEMORY_NEXT,
      LOADMEMORY_READ,
      LOADMEMORY_WRITE_RDRAM,
      LOADMEMORY_WRITE_NEXT,
      RESETTING,
      INITRAMSIZE1,
      INITRAMSIZE2
   );
   signal state : tstate := IDLE;
   
   signal count               : integer range 0 to 2097152 := 0;
   signal maxcount            : integer range 0 to 2097152;
               
   signal settle              : integer range 0 to SETTLECOUNT := 0;
   
   signal unstallwait         : integer range 0 to 67108863 := 0;
   
   --signal SS_DataRead         : std_logic_vector(63 downto 0);
   signal RAMAddrNext         : unsigned(24 downto 0) := (others => '0');
   
   signal header_amount       : unsigned(31 downto 0) := to_unsigned(1, 32);
   
   signal resetMode           : std_logic := '0';
   signal savemode            : std_logic := '0';
   signal loading_ss          : std_logic := '0';
   
   signal reset_in_1          : std_logic := '0';
   signal reset_intern        : std_logic := '0';
   
   signal rdram_address_safe  : unsigned(27 downto 0):= (others => '0');
   
   signal romcopy_latched     : std_logic := '0';

begin 

   saving_savestate <= '0';

   savestate_busy <= '0' when state = IDLE else '1';

   rdram_burstcount <= 10x"01";
   rdram_writeMask  <= x"FF";
   
   process (clk93)
   begin
      if rising_edge(clk93) then
         reset_out_93    <= reset_intern;
         ss_reset_93     <= ss_reset_1x;
         SS_DataWrite_93 <= SS_DataWrite;
         SS_Adr_93       <= SS_Adr;      
         SS_wren_93      <= SS_wren;     
      end if;
   end process;

   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         reset_intern  <= '0';
         ss_reset_1x   <= '0';
         rdram_request <= '0';
         
         reset_out_1x <= reset_intern;
         
         if (loading_ss = '1') then
            loading_savestate <= not resetMode;
         elsif (reset_in = '0') then
            loading_savestate <= '0';
         end if;
         
         SS_wren <= (others => '0');
         SS_rden <= (others => '0');

         --case (savetype_counter) is
         --   when  0 => SS_DataRead <= SS_DataRead_CPU;
         --   --when  1 => SS_DataRead <= SS_DataRead_GPU;
         --   --when  2 => SS_DataRead <= SS_DataRead_GPUTiming;
         --   --when  3 => SS_DataRead <= SS_DataRead_DMA;
         --   --when  4 => SS_DataRead <= SS_DataRead_GTE;
         --   --when  5 => SS_DataRead <= SS_DataRead_JOYPAD;
         --   --when  6 => SS_DataRead <= SS_DataRead_MDEC;
         --   --when  7 => SS_DataRead <= SS_DataRead_MEMORY;
         --   --when  8 => SS_DataRead <= SS_DataRead_TIMER;
         --   --when  9 => SS_DataRead <= SS_DataRead_SOUND;
         --   --when 10 => SS_DataRead <= SS_DataRead_IRQ;
         --   --when 11 => SS_DataRead <= SS_DataRead_SIO;
         --   --when 12 => SS_DataRead <= SS_DataRead_SCP;
         --   --when 13 => SS_DataRead <= SS_DataRead_CD;
         --   --when 16 => SS_DataRead <= ram_data;
         --   when others => SS_DataRead <= (others => '0');
         --end case;
         
         if (romcopy_start = '1') then
            romcopy_latched <= '1';
         end if;
         
         case state is
         
            when IDLE =>
               savestate_pause   <= '0';
               unstallwait       <= 1023;
               if (romcopy_latched = '1') then
                  romcopy_latched   <= '0';
                  romcopy_active    <= '1';
                  state             <= ROMCOPY_REQUEST;
                  RAMAddrNext       <= 25x"400000";
                  reset_intern      <= '1';
                  ss_reset_1x       <= '1';
                  resetMode         <= '1';
                  savemode          <= '0';
                  savetype_counter  <= 12;
                  settle            <= 0;
                  savestate_pause   <= '1';
               elsif (reset_in = '1') then
                  state                <= WAITPAUSE;
                  reset_intern         <= '1';
                  ss_reset_1x          <= '1';
                  resetMode            <= '1';
                  savemode             <= '0';
                  savetype_counter     <= 12;
                  settle               <= 0;
               --elsif (save = '1') then
               --   resetMode            <= '0';
               --   savemode             <= '1';
               --   savetype_counter     <= 0;
               --   state                <= WAITPAUSE;
               --   header_amount        <= header_amount + 1;
               elsif (load = '1') then
                  state                <= WAITPAUSE;
                  reset_intern         <= '1';
                  ss_reset_1x          <= '1';
                  resetMode            <= '0';
                  savemode             <= '0';
                  savetype_counter     <= 0;
                  settle               <= 0;
               end if;
               
-- #########################################################
               
            when ROMCOPY_REQUEST =>
               if (settle < SETTLECOUNT) then
                  settle <= settle + 1;
               elsif (RAMAddrNext >= (romcopy_size(26 downto 3) + 16#400000#)) then
                  state             <= WAITPAUSE;
                  settle            <= 0;
               elsif (romcopy_nearFull = '0') then
                  state             <= ROMCOPY_READ;
                  rdram_request     <= '1';
                  rdram_rnw         <= '1';
                  rdram_address     <= RAMAddrNext & "000";
               end if;
            
            when ROMCOPY_READ =>
               if (rdram_done = '1') then
                  state       <= ROMCOPY_REQUEST;
                  RAMAddrNext <= RAMAddrNext + 1;
               end if;
            
-- #########################################################            
            
            when WAITPAUSE =>
               if (settle < 8) then
                  settle        <= settle + 1;
               else
                  romcopy_active   <= '0';
                  savestate_pause  <= '1';
                  if (system_paused = '1') then
                     state                <= WAITIDLE;
                     settle               <= 0;
                  elsif (unstallwait > 0) then
                     unstallwait <= unstallwait - 1;
                  elsif (savemode = '0') then
                     reset_intern <= '1';
                     ss_reset_1x  <= '1';
                     unstallwait  <= 1023;
                  end if;
               end if;
            
            when WAITIDLE =>
               if (settle < 8) then
                  settle <= settle + 1;
               else
                  if (SS_idle = '1') then
                     if (savemode = '1') then
                        --state             <= SAVE_WAITSETTLE;
                        state             <= SAVESIZEAMOUNT;
                        rdram_request     <= '1';
                        rdram_rnw         <= '0';
                        rdram_address     <= to_unsigned(savestate_address, 28);
                        rdram_dataWrite   <= std_logic_vector(to_unsigned(STATESIZE, 32)) & std_logic_vector(header_amount);
                     else
                        state             <= LOAD_WAITSETTLE;
                     end if;
                     settle            <= 0;
                  else
                     state             <= WAITPAUSE;
                     settle            <= 0;
                     savestate_pause   <= '0';
                     if (savemode = '0') then
                        reset_intern   <= '1';
                     end if;
                  end if;
               end if;
               
            -- #################
            -- SAVE
            -- #################
            
--            when SAVE_WAITSETTLE =>
--               if (settle < SETTLECOUNT) then
--                  settle <= settle + 1;
--               else
--                  state            <= SAVEMEMORY_NEXT;
--                  saving_savestate <= '1';
--               end if;  
--
--               if (settle > (SETTLECOUNT / 2)) then
--                  ddr3_savestate    <= '1';
--               end if;               
--            
--            when SAVEMEMORY_NEXT =>
--               if (savetype_counter < SAVETYPESCOUNT) then
--                  state          <= SAVEMEMORY_STARTREAD;
--                  count          <= 2;
--                  maxcount       <= savetypes(savetype_counter).size;
--                  ddr3_ADDR_save <= std_logic_vector(to_unsigned(savestate_address + savetypes(savetype_counter).offset, 28));
--                  RAMAddrNext    <= (others => '0');
--                  dwordcounter   <= 0;
--               else
--                  state          <= SAVESIZEAMOUNT;
--                  ddr3_ADDR      <= std_logic_vector(to_unsigned(savestate_address, 28));
--                  ddr3_DIN       <= std_logic_vector(to_unsigned(STATESIZE, 32)) & std_logic_vector(header_amount);
--                  ddr3_WE        <= '1';
--                  ddr3_BE        <= x"FF";
--                  if (increaseSSHeaderCount = '0') then
--                     ddr3_BE  <= x"F0";
--                  end if;
--               end if;
--               
--            when SAVEMEMORY_STARTREAD =>
--               if (savetype_counter = 14) then -- spuram
--                  if (useSPUSDRAM = '1' or count <= 1024 or count > 16#1C000#) then
--                     state          <= SAVEMEMORY_LOAD_SPURAM;
--                     SPUwordcounter <= 0;
--                     dwordcounter   <= 1;
--                  else
--                     state          <= SAVEMEMORY_LOAD_VRAM;
--                     ddr3_RD        <= '1'; 
--                     ddr3_ADDR      <= "000000110" & std_logic_vector(RAMAddrNext(17 downto 1));
--                     dwordcounter   <= 1;
--                     RAMAddrNext    <= RAMAddrNext + 4;
--                  end if;
--               elsif (savetype_counter = 15) then -- vram
--                  state          <= SAVEMEMORY_LOAD_VRAM;
--                  ddr3_RD        <= '1'; 
--                  ddr3_ADDR      <= "0000000" & std_logic_vector(RAMAddrNext);
--                  dwordcounter   <= 1;
--                  RAMAddrNext    <= RAMAddrNext + 2;
--               else
--                  if (savetype_counter = 16) then -- sdram
--                     state                     <= SAVEMEMORY_LOAD_RAM;
--                  else
--                     state                     <= SAVEMEMORY_WAITREAD;
--                  end if;
--                  slowcounter                  <= 0;
--                  SS_rden_2x(savetype_counter) <= '1';
--                  SS_Adr_2x                    <= RAMAddrNext;
--                  RAMAddrNext                  <= RAMAddrNext + 1;
--               end if;
--               
--            when SAVEMEMORY_WAITREAD =>
--               if (slowcounter < 8) then
--                  slowcounter <= slowcounter + 1;
--               else
--                  state <= SAVEMEMORY_READ;
--               end if;
--               
--            when SAVEMEMORY_LOAD_VRAM =>
--               if (ddr3_DOUT_READY = '1') then
--                  state             <= SAVEMEMORY_READ;
--                  ddr3_DOUT_saved   <= ddr3_DOUT;
--               end if;
--               
--            when SAVEMEMORY_LOAD_RAM =>
--               if (ram_done = '1') then
--                  state             <= SAVEMEMORY_WAITREAD;
--                  slowcounter       <= 4;
--               end if;
--               
--            when SAVEMEMORY_LOAD_SPURAM =>
--               state               <= SAVEMEMORY_WAIT_SPURAM;
--               SS_SPURAM_Adr       <= std_logic_vector(RAMAddrNext(17 downto 0) & '0');
--               SS_SPURAM_request   <= '1';
--               SS_SPURAM_rnw       <= '1';
--               RAMAddrNext         <= RAMAddrNext + 1;
--               
--            when SAVEMEMORY_WAIT_SPURAM =>
--               if (SPURAM_done2X = '1') then
--                  spu_din(SPUwordcounter * 16 + 15 downto SPUwordcounter * 16) <= SPURAM_dataRead2x;
--                  if (SPUwordcounter = 3) then
--                     state       <= SAVEMEMORY_READ;
--                  else
--                     state <= SAVEMEMORY_LOAD_SPURAM;
--                     SPUwordcounter <=  SPUwordcounter + 1;
--                  end if;
--               end if;
--            
--            when SAVEMEMORY_READ =>
--               if (dwordcounter = 0) then
--                  ddr3_DIN(31 downto 0)  <= SS_DataRead_2x;
--                  state                  <= SAVEMEMORY_STARTREAD;
--                  dwordcounter           <= 1;
--               else
--                  ddr3_DIN(63 downto 32) <= SS_DataRead_2x;
--                  ddr3_ADDR              <= ddr3_ADDR_save;
--                  ddr3_WE                <= '1';
--                  ddr3_BE                <= x"FF";
--                  state                  <= SAVEMEMORY_WRITE;
--                  dwordcounter           <= 0;
--                  
--                  if (savetype_counter = 14) then -- SPUram
--                     if (useSPUSDRAM = '1' or count <= 1024 or count > 16#1C000#) then
--                        ddr3_DIN <= spu_din;
--                     else
--                        ddr3_DIN <= ddr3_DOUT_saved;
--                     end if;
--                  elsif (savetype_counter = 15) then -- vram
--                     ddr3_DIN <= ddr3_DOUT_saved;
--                  end if;
--               end if;
--               
--            when SAVEMEMORY_WRITE =>
--               if (DDR3_busy = '0') then
--                  ddr3_ADDR_save <= std_logic_vector(unsigned(ddr3_ADDR_save) + 2);
--                  if (count < maxcount) then
--                     state        <= SAVEMEMORY_STARTREAD;
--                     count        <= count + 2;
--                  else 
--                     savetype_counter <= savetype_counter + 1;
--                     state            <= SAVEMEMORY_NEXT;
--                  end if;
--               end if;
--            
            when SAVESIZEAMOUNT =>
                if (rdram_done = '1') then
                  state       <= IDLE;
                  --if (increaseSSHeaderCount = '1') then
                  --   unstallwait <= 67108863;
                  --end if;
               end if;
--             
--            when SAVEWAITHPSDONE =>
--               if (hps_busy = '1') then
--                  unstallwait <= 67108863;
--               elsif (unstallwait > 0) then
--                  unstallwait <= unstallwait - 1;
--               else
--                  state            <= IDLE;
--                  saving_savestate <= '0';
--               end if;

            -- #################
            -- LOAD
            -- #################
            
            when LOAD_WAITSETTLE =>
               if (settle < SETTLECOUNT) then
                  settle <= settle + 1;
               else
                  state             <= LOAD_HEADERAMOUNTCHECK;
                  rdram_request     <= not resetMode;
                  rdram_rnw         <= '1';
                  rdram_address     <= to_unsigned(savestate_address, 28);
               end if;
               
            when LOAD_HEADERAMOUNTCHECK =>
               if (rdram_done = '1' or resetMode = '1') then
                  if (rdram_dataRead(63 downto 32) = std_logic_vector(to_unsigned(STATESIZE, 32)) or resetMode = '1') then
                     if (resetMode = '1') then
                        header_amount     <= (others => '0');
                     else
                        header_amount     <= unsigned(rdram_dataRead(31 downto 0));
                     end if;
                     state                <= LOADMEMORY_NEXT;
                     loading_ss           <= '1';
                     reset_intern         <= '1';
                     ss_reset_1x          <= '1';
                  else
                     state                <= IDLE;
                  end if;
               end if;
            
            when LOADMEMORY_NEXT =>
               if (savetype_counter < SAVETYPESCOUNT) then
                  rdram_request  <= not resetMode;
                  rdram_address  <= to_unsigned(savestate_address + (savetypes(savetype_counter).offset * 8), 28);
                  rdram_rnw      <= '1';
                  state          <= LOADMEMORY_READ;
                  count          <= 1;
                  maxcount       <= savetypes(savetype_counter).size;
                  -- delete 8192 more, so area behind 8 mbyte is clean to be used as buffer for rdram read out of bounds
                  if (savetype_counter = 13 and resetMode = '1') then
                     maxcount <= 1056768;
                  end if;
                  RAMAddrNext    <= (others => '0');
               elsif (resetMode = '1') then
                  state            <= INITRAMSIZE1;
                  rdram_request    <= '1';
                  rdram_address    <= 28x"318";
                  rdram_rnw        <= '0';
                  if (RAMSIZE8 = '1') then
                     rdram_dataWrite  <= 64x"8000";
                  else
                     rdram_dataWrite  <= 64x"4000";
                  end if;
               else
                  state          <= RESETTING;
                  reset_intern   <= '1';
                  settle         <= 0;
               end if;
            
            when LOADMEMORY_READ =>
               rdram_address_safe <= rdram_address;
               if (rdram_done = '1' or resetMode = '1') then
                 
                  if (resetMode = '1') then
                     SS_DataWrite     <= (others => '0');
                     rdram_dataWrite  <= (others => '0');
                  else
                     SS_DataWrite     <= rdram_dataRead;
                     rdram_dataWrite  <= rdram_dataRead;
                  end if;
                  rdram_address  <= RAMAddrNext & "000";
                  rdram_rnw      <= '0';
                  RAMAddrNext    <= RAMAddrNext + 1;
                  SS_Adr         <= RAMAddrNext(11 downto 0);
                  
                  if (savetype_counter = 13) then -- rdram
                     state          <= LOADMEMORY_WRITE_RDRAM;
                     rdram_request  <= '1';
                  else
                     SS_wren(savetype_counter) <= not resetMode;
                     state          <= LOADMEMORY_WRITE_NEXT;
                  end if;
                  
               end if;
               
            when LOADMEMORY_WRITE_RDRAM =>
               if (rdram_done = '1') then
                  state <= LOADMEMORY_WRITE_NEXT;
                  if (FASTSIM = '1' and count = 512) then
                     count <= maxcount;
                  end if;
               end if;
               
            when LOADMEMORY_WRITE_NEXT =>
               rdram_address  <= rdram_address_safe + 8;
               rdram_rnw      <= '1';
               if (count < maxcount) then
                  state          <= LOADMEMORY_READ;
                  count          <= count + 1;
                  rdram_request  <= not resetMode;
               else 
                  savetype_counter <= savetype_counter + 1;
                  state            <= LOADMEMORY_NEXT;
               end if;
               
            when RESETTING =>
               if (settle < 8) then
                  reset_intern <= '1';
               end if;
               if (settle < 16) then
                  settle <= settle + 1;
               elsif (reset_in = '0' and sdrammux_idle = '1') then
                  state          <= IDLE;
                  loading_ss     <= '0';
                  load_done      <= not resetMode;
               end if;
               
            when INITRAMSIZE1 =>
               if (rdram_done = '1') then
                  state            <= INITRAMSIZE2;
                  rdram_request    <= '1';
                  rdram_address    <= 28x"3F0";
               end if;
               
            when INITRAMSIZE2 =>
               if (rdram_done = '1') then
                  state          <= RESETTING;
                  reset_intern   <= '1';
                  settle         <= 0;
               end if;   
            
            when others => null;
         
         end case;
         
         reset_in_1 <= reset_in;
         if (reset_in = '1' and reset_in_1 = '0') then
            if (state /= ROMCOPY_REQUEST and state /= ROMCOPY_READ) then
               state    <= IDLE;
            end if;
         end if;
         
      end if;
   end process;
   

end architecture;





