library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;    

entity cpu_TLB_data is
   port 
   (
      clk93                : in  std_logic;
      reset                : in  std_logic;
                           
      DISABLE_DTLBMINI     : in  std_logic;
                           
      TLBInvalidate        : in  std_logic;
                           
      TLB_Req              : in  std_logic;
      TLB_IsWrite          : in  std_logic;
      TLB_AddrIn           : in  unsigned(63 downto 0);
      TLB_useCacheFound    : out std_logic := '0';  
      TLB_useCacheLookup   : out std_logic := '0';  
      TLB_Stall            : out std_logic := '0';
      TLB_UnStall          : out std_logic := '0';
      TLB_AddrOutFound     : out unsigned(31 downto 0) := (others => '0');
      TLB_AddrOutLookup    : out unsigned(31 downto 0) := (others => '0');
      
      TLB_ExcRead          : out std_logic := '0';
      TLB_ExcWrite         : out std_logic := '0';
      TLB_ExcDirty         : out std_logic := '0';
      TLB_ExcMiss          : out std_logic := '0';
      
      TLB_fetchReq         : out std_logic := '0';
      TLB_fetchAddrIn      : out unsigned(63 downto 0) := (others => '0');
      TLB_fetchDone        : in  std_logic;
      TLB_fetchExcInvalid  : in  std_logic;
      TLB_fetchExcDirty    : in  std_logic;
      TLB_fetchExcNotFound : in  std_logic;
      TLB_fetchCached      : in  std_logic;
      TLB_fetchDirty       : in  std_logic;
      TLB_fetchSource      : in  unsigned(4 downto 0);
      TLB_fetchAddrOut     : in  unsigned(31 downto 0)
   );
end entity;

architecture arch of cpu_TLB_data is
 
   signal DISABLE_DTLBMINI_INTERN : std_logic := '0';
 
   type tstate is
   (
      IDLE,
      REQUEST,
      EXCEPTION
   );
   signal state : tstate := IDLE;
   
   signal TLB_fetchIsWrite  : std_logic := '0';
   
   constant MINICOUNT : integer := 4;
   
   type tminiEntry is record
      valid    : std_logic;
      region   : unsigned(1 downto 0); 
      virtual  : unsigned(39 downto 0); 
      physical : unsigned(31 downto 0); 
      cached   : std_logic;
      dirty    : std_logic;
      source   : unsigned(4 downto 0);
   end record; 
   
   type tminiEntries is array(0 to MINICOUNT - 1) of tminiEntry;
   signal miniEntries : tminiEntries;
   
   signal mini_hit      : std_logic;
   signal mini_lru      : integer range 0 to MINICOUNT-1 := 0;

begin 

   process (all)
   begin
   
      mini_hit          <= '0';
      TLB_useCacheFound <= miniEntries(0).cached;
      TLB_AddrOutFound  <= miniEntries(0).physical(31 downto 12) & TLB_AddrIn(11 downto 0);
      
      for i in 0 to MINICOUNT - 1 loop
         if (miniEntries(i).valid = '1') then
            if (TLB_AddrIn(39 downto 12) = miniEntries(i).virtual(39 downto 12)) then
               if (TLB_AddrIn(63 downto 62) = miniEntries(i).region) then
                  if (TLB_IsWrite = '0' or miniEntries(i).dirty = '1') then
                     mini_hit          <= '1';
                     TLB_useCacheFound <= miniEntries(i).cached;
                     TLB_AddrOutFound  <= miniEntries(i).physical(31 downto 12) & TLB_AddrIn(11 downto 0);
                  end if;
               end if;
            end if;
         end if;
      end loop;
      
   end process;

   TLB_Stall <= TLB_Req when (mini_hit = '0') else '0';

   process (clk93)
   begin
      if (rising_edge(clk93)) then
      
         DISABLE_DTLBMINI_INTERN <= DISABLE_DTLBMINI;
      
         TLB_UnStall   <= '0';
         TLB_fetchReq  <= '0';
         
         TLB_ExcRead  <= '0';
         TLB_ExcWrite <= '0';
         TLB_ExcDirty <= '0';
         TLB_ExcMiss  <= '0';
         
         if (reset = '1') then
         
            state      <= IDLE;
            for i in 0 to MINICOUNT - 1 loop
               miniEntries(i).valid <= '0';
            end loop;
           
         else
         
            if (TLBInvalidate = '1' or DISABLE_DTLBMINI_INTERN = '1') then
               for i in 0 to MINICOUNT - 1 loop
                  miniEntries(i).valid <= '0';
               end loop;
            end if;
         
            case (state) is
            
               when IDLE =>
                  if (TLB_Req = '1') then
                     TLB_fetchAddrIn  <= TLB_AddrIn;
                     TLB_fetchIsWrite <= TLB_IsWrite;
                  end if;
                  if (TLB_Stall = '1') then
                     state        <= REQUEST;
                     TLB_fetchReq <= '1';
                  end if;
                 
               when REQUEST =>
                  if (TLB_fetchDone = '1') then
                     if (TLB_fetchExcInvalid = '0' and TLB_fetchExcNotFound = '0' and (TLB_fetchExcDirty = '0' or TLB_fetchIsWrite = '0')) then
                        state         <= IDLE;
                        TLB_UnStall   <= '1';
                     else
                        state         <= EXCEPTION;
                     end if;
                     TLB_AddrOutLookup  <= TLB_fetchAddrOut;
                     TLB_useCacheLookup <= TLB_fetchCached;
                     TLB_ExcRead        <= (TLB_fetchExcInvalid or TLB_fetchExcNotFound) and (not TLB_fetchIsWrite);
                     TLB_ExcWrite       <= (TLB_fetchExcInvalid or TLB_fetchExcNotFound) and TLB_fetchIsWrite;
                     TLB_ExcMiss        <= TLB_fetchExcNotFound;
                     if (TLB_fetchExcDirty = '1' and TLB_fetchIsWrite = '1') then
                        TLB_ExcDirty <= '1';
                        if (TLB_fetchExcInvalid = '0') then
                           TLB_ExcRead  <= '0';
                           TLB_ExcWrite <= '0';
                        end if;
                     end if;
                     
                     
                     if (TLB_fetchExcInvalid = '0' and TLB_fetchExcNotFound = '0' and (TLB_fetchExcDirty = '0' or TLB_fetchIsWrite = '0')) then
                        miniEntries(mini_lru).valid <= '1';
                     else
                        miniEntries(mini_lru).valid <= '0';
                     end if;
                     
                     miniEntries(mini_lru).region       <= TLB_fetchAddrIn(63 downto 62);
                     miniEntries(mini_lru).virtual      <= TLB_fetchAddrIn(39 downto 12) & x"000";
                     miniEntries(mini_lru).physical     <= TLB_fetchAddrOut(31 downto 12) & x"000";
                     miniEntries(mini_lru).cached       <= TLB_fetchCached;
                     miniEntries(mini_lru).dirty        <= TLB_fetchDirty;
                     miniEntries(mini_lru).source       <= TLB_fetchSource;
                     
                     if (mini_lru = MINICOUNT-1) then 
                        mini_lru <= 0;
                     else
                        mini_lru <= mini_lru + 1;
                     end if;
                  end if;
            
               when EXCEPTION =>
                  state       <= IDLE;
                  TLB_UnStall <= '1';
            
            end case;

         end if;
      end if;
   end process;
   
   -- synthesis translate_off
   ganalyze : if 1 = 1 generate
      signal cycles        : integer := 0;
      signal stall_cycles  : integer := 0;
      signal stall_count   : integer := 0;
      signal request_count : integer := 0;
   begin
   
      process
      begin
         wait until rising_edge(clk93);
         
         cycles <= cycles + 1;
         
         if (state /= IDLE or TLB_UnStall = '1') then
            stall_cycles <= stall_cycles + 1;
         end if;
         
         if (state = IDLE and TLB_Req = '1') then
            request_count <= request_count + 1;
         end if;         
         
         if (state = IDLE and TLB_Stall = '1') then
            stall_count <= stall_count + 1;
         end if;
         
         if (reset = '1') then
            cycles        <= 0;
            stall_cycles  <= 0;
            stall_count   <= 0;
            request_count <= 0;
         end if;
         
      end process;
   
   end generate ganalyze;

   -- synthesis translate_on   
   
end architecture;
