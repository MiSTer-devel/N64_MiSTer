library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   
use STD.textio.all;

library mem;
use work.pFunctions.all;

entity cpu_datacache is
   port 
   (
      clk1x             : in  std_logic;
      clk93             : in  std_logic;
      clk2x             : in  std_logic;
      reset_93          : in  std_logic;
      ce_93             : in  std_logic;
      stall             : in  unsigned(4 downto 0);
      stall4            : in  std_logic;
      fifo_block        : in  std_logic;
      
      slow_in           : in  std_logic_vector(3 downto 0); 
      force_wb_in       : in  std_logic;
      
      ram_request       : out std_logic := '0';
      ram_reqAddr       : out unsigned(31 downto 0) := (others => '0');
      ram_active        : in  std_logic := '0';
      ram_grant         : in  std_logic := '0';
      ram_done          : in  std_logic := '0';
      ddr3_DOUT         : in  std_logic_vector(63 downto 0);
      ddr3_DOUT_READY   : in  std_logic;
      
      writeback_ena     : out std_logic := '0';
      writeback_addr    : out unsigned(31 downto 0) := (others => '0');
      writeback_data    : out std_logic_vector(63 downto 0) := (others => '0');
      
      tag_addr          : in  unsigned(31 downto 0);
      
      read_ena          : in  std_logic;
      RW_addr           : in  unsigned(31 downto 0);
      RW_64             : in  std_logic;
      read_busy         : out std_logic;
      read_done         : out std_logic;
      read_data         : out std_logic_vector(63 downto 0) := (others => '0');
      
      write_ena         : in  std_logic;
      write_be          : in  std_logic_vector(7 downto 0);
      write_data        : in  std_logic_vector(63 downto 0);
      write_done        : out  std_logic;
      
      CacheCommandEna   : in  std_logic;
      CacheCommand      : in  unsigned(4 downto 0);
      CachecommandStall : out std_logic;
      CachecommandDone  : out std_logic := '0';
      
      TagLo_Valid       : in  std_logic;
      TagLo_Dirty       : in  std_logic;
      TagLo_Addr        : in  unsigned(19 downto 0);
      
      writeTagEna       : out std_logic := '0';
      writeTagValue     : out unsigned(21 downto 0) := (others => '0');

      SS_reset          : in  std_logic
   );
end entity;

architecture arch of cpu_datacache is

   signal ce_fetch         : std_logic;

   -- tags
   signal tag_address_a    : std_logic_vector(8 downto 0) := (others => '0');
   signal tag_data_a       : std_logic_vector(21 downto 0) := (others => '0');
   signal tag_wren_a       : std_logic := '0';
   signal tag_address_b    : std_logic_vector(8 downto 0);
   signal tag_q_b          : std_logic_vector(21 downto 0);
   
   signal tag_newEna       : std_logic := '0';
   signal tag_newData      : std_logic_vector(21 downto 0);
   signal tag_compare      : std_logic_vector(21 downto 0);

   signal read_hit         : std_logic;
   
   signal tag_addr_1       : unsigned(31 downto 0) := (others => '0');
   signal tag_addr_low     : unsigned(3 downto 0) := (others => '0');
   signal tag_read_addr    : unsigned(12 downto 0) := (others => '0');
   signal fillAddr         : unsigned(31 downto 0) := (others => '0');

   -- data
   signal tag_read_addr_1x : unsigned(8 downto 0) := (others => '0');
   signal tag_read_addr_2x : unsigned(8 downto 0) := (others => '0');
   
   signal ram_grant_2x     : std_logic := '0';
   signal cache_addr_a     : unsigned(9 downto 0) := (others => '0');
   signal cache_wr_a       : std_logic;
   
   signal cache_address_b  : std_logic_vector(9 downto 0);
   signal cache_data_b     : std_logic_vector(63 downto 0);
   signal cache_we_b       : std_logic;
   signal cache_be_b       : std_logic_vector(7 downto 0);
   signal cache_q_b        : std_logic_vector(63 downto 0);
   
   signal write_be_rot     : std_logic_vector(7 downto 0);
   signal write_be_1       : std_logic_vector(7 downto 0);
   
   signal write_data_rot   : std_logic_vector(63 downto 0);
   signal write_data_1     : std_logic_vector(63 downto 0);
   
   -- state machine
   type tState is
   (
      IDLE,
      CLEARCACHE,
      FILL,
      READWAIT,
      WAITSLOW,
      WRITEBACK1ADDR,
      WRITEBACK1READ,
      WRITEBACK1WRITE,
      WRITEBACK2WRITE,
      WRITEBACKDONE,
      COMMANDPROCESS,
      COMMANDDONE
   );
   signal state : tstate := IDLE;
   
   signal writeMode        : std_logic := '0';
   signal fillNext         : std_logic := '0';
   signal write_ena_1      : std_logic := '0';
         
   signal clearAddr        : std_logic_vector(8 downto 0);
      
   signal isCommand        : std_logic := '0';
   signal isWB             : std_logic := '0';
   
   signal tag_wren_cmd     : std_logic := '0';
   signal tag_addr_cmd     : std_logic_vector(8 downto 0) := (others => '0');
   signal tag_data_cmd     : std_logic_vector(21 downto 0) := (others => '0');
   
   -- slow
   signal slow       : unsigned(3 downto 0) := (others => '0');
   signal slow_on    : std_logic := '0';
   signal slowcnt    : unsigned(3 downto 0) := (others => '0');
   
   signal force_wb   : std_logic := '0';
   signal wb_done    : std_logic := '0';
   
begin 

   ce_fetch <= '1' when (stall = 0 and ce_93 = '1') else '0';

   ------------------ tags   
   
   tag_wren_a     <= '1' when (tag_wren_cmd = '1') else
                     '1' when (state = IDLE and write_ena = '1' and read_hit = '1') else
                     '0';
                     
   tag_address_a  <= tag_addr_cmd when (tag_wren_cmd = '1') else
                     std_logic_vector(tag_addr_1(12 downto 4));
                     
   tag_data_a     <= tag_data_cmd when (tag_wren_cmd = '1') else
                     '1' & tag_compare(20 downto 0);
   
   
   itagram : entity mem.dpram
   generic map 
   ( 
      addr_width  => 9,
      data_width  => 22 -- 30 bits(31..12) of address + 1 bit valid + 1 bit dirty
   )
   port map
   (
      clock_a     => clk93,
      address_a   => tag_address_a,
      data_a      => tag_data_a,
      wren_a      => tag_wren_a,
      
      clock_b     => clk93,
      clken_b     => ce_fetch,
      address_b   => tag_address_b,
      data_b      => 22x"0",
      wren_b      => '0',
      q_b         => tag_q_b
   ); 
   
   tag_address_b <= std_logic_vector(tag_addr(12 downto 4));
   
   tag_compare   <= tag_newData when (tag_newEna = '1') else
                    tag_q_b;
   

   
   --itagram : entity mem.RamMLAB
   --generic map
   --(
   --   width      => 22, -- 30 bits(31..12) of address + 1 bit valid + 1 bit dirty
   --   widthad    => 9
   --)
   --port map
   --(
   --   inclock    => clk93,
   --   wren       => tag_wren_a,
   --   data       => tag_data_a,
   --   wraddress  => tag_address_a,
   --   rdaddress  => tag_address_b,
   --   q          => tag_q_b
   --);
   --
   --tag_address_b <= std_logic_vector(tag_addr_1(12 downto 4));
   
   --tag_compare   <= tag_q_b;
   
   read_hit      <= '1' when (unsigned(tag_compare(19 downto 0)) = RW_addr(31 downto 12) and tag_compare(20) = '1') else '0';
  
   --------- data
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         tag_read_addr_1x <= tag_read_addr(12 downto 4);
      end if;
   end process;
   
   process (clk2x)
   begin
      if rising_edge(clk2x) then
      
         tag_read_addr_2x <= tag_read_addr_1x;
      
         if (ram_grant = '1'and ram_active = '1') then
            ram_grant_2x <= '1';
         end if;
         
         if (ram_grant = '1') then
            cache_addr_a <= tag_read_addr_2x & "0";
         elsif (ddr3_DOUT_READY = '1') then
            cache_addr_a <= cache_addr_a + 1;
            if (ram_grant_2x = '1' and cache_addr_a(0) = '1') then
               ram_grant_2x <= '0';
            end if;
         end if;
         
      end if;
   end process;

   cache_wr_a    <= ram_grant_2x and ddr3_DOUT_READY;

   gcache: for i in 0 to 7 generate
   begin
      icache: entity work.dpram
      generic map 
      ( 
         addr_width  => 10,
         data_width  => 8
      )
      port map
      (
         clock_a     => clk2x,
         address_a   => std_logic_vector(cache_addr_a),
         data_a      => ddr3_DOUT(((i * 8) + 7) downto (i*8)),
         wren_a      => cache_wr_a,
         
         clock_b     => clk93,
         address_b   => cache_address_b,
         data_b      => cache_data_b(((i * 8) + 7) downto (i*8)),
         wren_b      => cache_we_b and cache_be_b(i),
         q_b         => cache_q_b(((i * 8) + 7) downto (i*8))
      );
   end generate;
   
   cache_address_b <= std_logic_vector(tag_read_addr(12 downto 3)) when (state /= IDLE) else 
                      std_logic_vector(tag_addr_1(12 downto 3)) when (ce_fetch = '0' or write_ena = '1') else 
                      std_logic_vector(tag_addr(12 downto 3));
               
  
   write_be_rot    <= write_be when (RW_addr(2) = '0' and RW_64 = '0') else write_be(3 downto 0) & write_be(7 downto 4);
   
   write_data_rot  <= write_data when (RW_addr(2) = '0' and RW_64 = '0') else write_data(31 downto 0) & write_data(63 downto 32);
                      
   cache_data_b    <= write_data_1 when (stall4 = '1') else write_data_rot;
   cache_be_b      <= write_be_1   when (stall4 = '1') else write_be_rot;
   
   cache_we_b      <= '1' when ((state = IDLE and read_hit = '1' and write_ena = '1') or (writeMode = '1' and state = FILL and ram_done = '1')) else '0';
   
   write_done      <=  wb_done when (force_wb = '1') else
                       '1'     when ((state = IDLE and read_hit = '1' and write_ena = '1') or (writeMode = '1' and state = FILL and ram_done = '1')) else 
                       '0';
   
   read_busy       <= '1' when (state = READWAIT or state = WAITSLOW or state = FILL) else '0';
   
   read_done       <= '1' when (state = IDLE and write_ena_1 = '0' and read_hit = '1' and read_ena = '1' and slow_on = '0') else
                      '1' when (state = READWAIT) else
                      '1' when (state = WAITSLOW and slowcnt = 0) else
                      '1' when (writeMode = '0' and state = FILL and ram_done = '1') else 
                      '0';
   
   read_data       <= cache_q_b                        when (RW_addr(2 downto 0) = "000") else
                      8x"0"  & cache_q_b(63 downto  8) when (RW_addr(2 downto 0) = "001") else
                      16x"0" & cache_q_b(63 downto 16) when (RW_addr(2 downto 0) = "010") else
                      24x"0" & cache_q_b(63 downto 24) when (RW_addr(2 downto 0) = "011") else
                      32x"0" & cache_q_b(63 downto 32) when (RW_addr(2 downto 0) = "100") else
                      40x"0" & cache_q_b(63 downto 40) when (RW_addr(2 downto 0) = "101") else
                      48x"0" & cache_q_b(63 downto 48) when (RW_addr(2 downto 0) = "110") else
                      56x"0" & cache_q_b(63 downto 56); -- when (RW_addr(2 downto 0) = "111")
   
   CachecommandStall <= '1' when (CacheCommandEna = '1' and CacheCommand = 5x"01") else
                        '1' when (CacheCommandEna = '1' and CacheCommand = 5x"05") else
                        '1' when (CacheCommandEna = '1' and CacheCommand = 5x"09") else
                        '1' when (CacheCommandEna = '1' and CacheCommand = 5x"0D") else
                        '1' when (CacheCommandEna = '1' and CacheCommand = 5x"11") else
                        '1' when (CacheCommandEna = '1' and CacheCommand = 5x"15") else
                        '1' when (CacheCommandEna = '1' and CacheCommand = 5x"19") else
                        '0';
   
   process (clk93)
   begin
      if rising_edge(clk93) then

         ram_request       <= '0';
         writeback_ena     <= '0';
         CachecommandDone  <= '0';
         tag_wren_cmd      <= '0';
         wb_done           <= '0';
         writeTagEna       <= '0';
         
         if (ce_fetch = '1') then
            tag_addr_1   <= tag_addr;
            tag_newEna   <= '0';
            if (tag_wren_a = '1') then
               tag_newData  <= tag_data_a;
               if (tag_address_a = std_logic_vector(tag_addr(12 downto 4))) then
                  tag_newEna   <= '1';
               end if;
            end if;
         else
            if (tag_wren_a = '1') then
               tag_newData  <= tag_data_a;
               if (tag_address_a = std_logic_vector(tag_addr_1(12 downto 4))) then
                  tag_newEna   <= '1';
               end if;
            end if;
         end if;
         
         force_wb <= force_wb_in;
         
         slow    <= unsigned(slow_in);
         slow_on <= '0';
         if (slow > 0) then
            slow_on <= '1';
         end if;
         
         if (slowcnt > 0) then
            slowcnt <= slowcnt - 1;
         end if;
         
         if (SS_reset = '1') then
            state          <= CLEARCACHE;
            clearAddr      <= (others => '0');
         else

            case(state) is
            
               when IDLE =>
                  writeMode      <= write_ena;
                  write_be_1     <= write_be_rot; 
                  write_data_1   <= write_data_rot;
                  fillNext       <= '0';
                  write_ena_1    <= write_ena;
                  fillAddr       <= unsigned(tag_compare(19 downto 0)) & RW_addr(11 downto 4) & "0000";
                  tag_addr_low   <= tag_addr_1(3 downto 0);
                  tag_read_addr  <= tag_addr_1(12 downto 0);
                  isCommand      <= '0'; 
                  isWB           <= '0'; 
                  ram_reqAddr    <= RW_addr(31 downto 0); 
                  tag_data_cmd   <= write_ena & '1' & std_logic_vector(RW_addr(31 downto 12)); -- default for fill
                  tag_addr_cmd   <= std_logic_vector(tag_addr_1(12 downto 4)); 
                  writeback_addr <= unsigned(tag_compare(19 downto 0)) & RW_addr(11 downto 4) & "0000";
                  
                  if ((read_ena = '1' or write_ena = '1') and read_hit = '0') then
                     if (tag_compare(21) = '1') then
                        state          <= WRITEBACK1ADDR; 
                        tag_read_addr(3 downto 0) <= "0000";
                        fillNext       <= '1';
                     else
                        state          <= FILL;
                        ram_request    <= '1';
                        if (write_ena = '1' and force_wb = '1') then
                           isWB <= '1';
                        end if;
                     end if;
                     
                  elsif (write_ena = '1' and read_hit = '1' and force_wb = '1') then
                     state          <= WRITEBACK1ADDR; 
                     isWB           <= '1';
                     tag_read_addr(3 downto 0) <= "0000";
                     
                  elsif (read_ena = '1' and slow_on = '1') then
                     state       <= WAITSLOW;
                     slowcnt     <= slow - 1;
                     
                  elsif (write_ena_1 = '1' and read_ena = '1' and read_hit = '1') then
                     state <= READWAIT;
                     
                  elsif (CacheCommandEna = '1') then
                     state          <= COMMANDPROCESS;
                     isCommand      <= '1';
                     tag_read_addr(3 downto 0) <= "0000";
                     writeTagValue  <= tag_compare(20) & tag_compare(21) & unsigned(tag_compare(19 downto 0)); -- valid & dirty & 20 bit address
                  
                     case (CacheCommand) is
                     
                        when 5x"01" => -- dcache index write back invalidate
                           if (tag_compare(21 downto 20) = "11") then
                              state          <= WRITEBACK1ADDR; 
                           end if;
                           tag_wren_cmd    <= '1';
                           tag_data_cmd    <= "00" & tag_compare(19 downto 0);
                           
                        when 5x"05" => -- dcache index load tag
                           writeTagEna <= '1';
                           
                        when 5x"09" => -- dcache index store tag 
                           tag_wren_cmd    <= '1';
                           tag_data_cmd    <= TagLo_Dirty & TagLo_Valid & std_logic_vector(TagLo_Addr);
                           
                        when 5x"0D" => -- dcache create dirty exclusive
                           if (tag_compare(21) = '1' and (tag_compare(20) = '0' or unsigned(tag_compare(19 downto 0)) /= RW_addr(31 downto 12))) then
                              state          <= WRITEBACK1ADDR; 
                           end if;
                           tag_wren_cmd    <= '1';
                           tag_data_cmd    <= "11" & std_logic_vector(RW_addr(31 downto 12));
                        
                        when 5x"11" => -- dcache hit invalidate
                           if (read_hit = '1') then
                              tag_wren_cmd    <= '1';
                              tag_data_cmd    <= "00" & tag_compare(19 downto 0);
                           end if;
                        
                        when 5x"15" => -- dcache hit write back invalidate
                           if (read_hit = '1') then
                              if (tag_compare(21) = '1') then
                                 state          <= WRITEBACK1ADDR; 
                              end if;
                              tag_wren_cmd    <= '1';
                              tag_data_cmd    <= "00" & tag_compare(19 downto 0);
                           end if;
                        
                        when 5x"19" => -- dcache hit write back
                           if (read_hit = '1' and tag_compare(21) = '1') then -- should this really check for dirty?
                              state          <= WRITEBACK1ADDR; 
                              tag_wren_cmd   <= '1';
                              tag_data_cmd   <= "01" & tag_compare(19 downto 0);
                           end if;
                           
                        when others => null;
                     end case;
                     
                  end if;

               when CLEARCACHE =>
                  tag_wren_cmd <= '1';
                  tag_addr_cmd <= clearAddr; 
                  tag_data_cmd <= (others => '0');
                  if (clearAddr /= 9x"1FF") then
                     clearAddr <= std_logic_vector(unsigned(clearAddr) + 1);
                  else
                     state          <= IDLE;
                  end if;
                  
               when FILL =>
                  if (ram_request = '1') then
                     tag_wren_cmd   <= '1';
                  end if;
                  if (ram_done = '1') then
                     state          <= IDLE;
                     if (isWB = '1') then
                        state          <= WRITEBACK1ADDR; 
                        writeback_addr <= fillAddr(31 downto 4) & "0000";
                     end if;
                  end if;
                  
               when READWAIT =>
                  state <= IDLE;
                  
               when WAITSLOW =>
                  if (slowcnt = 0) then
                     state <= IDLE;
                  end if;
                  
               when WRITEBACK1ADDR =>
                  if (fifo_block = '0') then
                     state <= WRITEBACK1READ;
                  end if;
               
               when WRITEBACK1READ =>
                  state            <= WRITEBACK1WRITE;
                  tag_read_addr(3) <= '1';
               
               when WRITEBACK1WRITE =>
                  state          <= WRITEBACK2WRITE;
                  writeback_ena  <= '1';
                  writeback_data <= cache_q_b(31 downto 0) & cache_q_b(63 downto 32);
               
               when WRITEBACK2WRITE =>
                  state             <= WRITEBACKDONE;
                  writeback_ena     <= '1';
                  writeback_data    <= cache_q_b(31 downto 0) & cache_q_b(63 downto 32);
                  writeback_addr(3) <= '1';
               
               when WRITEBACKDONE =>
                  tag_read_addr(3 downto 0) <= tag_addr_low;
                  if (fifo_block = '0') then
                     fillNext <= '0';
                     if (fillNext = '1') then
                        state       <= FILL;
                        ram_request <= '1';
                        if (writeMode = '1' and force_wb = '1') then
                           isWB <= '1';
                        end if;
                     else
                        state             <= IDLE;
                        CachecommandDone  <= isCommand;
                        wb_done           <= isWB;
                     end if;
                  end if;
                  
               when COMMANDPROCESS =>
                  state <= COMMANDDONE;
                  
               when COMMANDDONE =>
                  state             <= IDLE;
                  CachecommandDone  <= '1';
                  
            end case;  
            
         end if;

      end if;
   end process;

--##############################################################
--############################### export
--##############################################################
   
   -- synthesis translate_off
   goutput : if 1 = 1 generate
      type ttracecounts_out is array(1 to 4) of integer;
      signal tracecounts_out : ttracecounts_out;
      type t_dachefull is array(0 to 511, 0 to 1) of std_logic_vector(63 downto 0);
      signal dcachefull : t_dachefull;
   begin
   
      process
         file outfile               : text;
         variable f_status          : FILE_OPEN_STATUS;
         variable line_out          : line;
         variable stringbuffer      : string(1 to 31);
         variable export_AddrSave   : unsigned(31 downto 0);
         variable export_TagSave    : unsigned(21 downto 0);
         variable export_DataSave   : std_logic_vector(63 downto 0);
         variable export_TagWrite   : std_logic_vector(21 downto 0);
      begin
   
         file_open(f_status, outfile, "R:\\cache_n64_sim.txt", write_mode);
         file_close(outfile);
         file_open(f_status, outfile, "R:\\cache_n64_sim.txt", append_mode);
         
         for i in 1 to 4 loop
            tracecounts_out(i) <= 0;
         end loop;
         
         while (true) loop
            
            wait until rising_edge(clk93);
            wait for 1 ns;
            if (read_ena  = '1' or write_ena = '1' or CacheCommandEna = '1') then
               export_AddrSave := "000" & tag_addr_1(28 downto 0);
               export_TagSave  := unsigned(tag_compare);
            end if; 
            
            if (state = FILL) then
               if (tag_wren_a = '1') then
                  export_TagWrite := tag_data_a;
               end if;
               if (ram_grant_2x = '1') then
                  wait until ddr3_DOUT_READY = '1';
                  for i in 0 to 1 loop
                     write(line_out, string'("Fill: I ")); 
                     write(line_out, to_string_len(tracecounts_out(1) + 1 + i, 8));
                     write(line_out, string'(" A ")); 
                     if (i = 0) then write(line_out, to_hstring(ram_reqAddr(31 downto 4) & "0000")); else write(line_out, to_hstring(ram_reqAddr(31 downto 4) & "1000")); end if; 
                     write(line_out, string'(" T ")); 
                     write(line_out, to_hstring(export_TagWrite(16 downto 0)));
                     if (export_TagWrite(20) = '1') then write(line_out, string'(" V 1")); else write(line_out, string'(" V 0")); end if;
                     write(line_out, string'(" D 0"));
                     write(line_out, string'(" I ")); 
                     write(line_out, to_hstring(export_AddrSave(12 downto 4)));
                     write(line_out, string'(" S ")); 
                     write(line_out, to_hstring(to_unsigned(i * 2, 4)));
                     write(line_out, string'(" Data ")); 
                     write(line_out, to_hstring(ddr3_DOUT));
                     dcachefull(to_integer(export_AddrSave(12 downto 4)), i) <= ddr3_DOUT;
                     writeline(outfile, line_out);
                     wait until rising_edge(clk2x);
                     wait for 1 ns;
                  end loop;
                  wait until ram_done = '1';
                  wait for 1 ns;
                  tracecounts_out(1) <= tracecounts_out(1) + 2;
                  
                  if (isWB = '1') then
                     export_TagSave  := unsigned(export_TagWrite);
                  end if;
               end if;
               
            end if;
            
            if (read_done = '1') then
               write(line_out, string'("Read: I ")); 
               write(line_out, to_string_len(tracecounts_out(3) + 1, 8));
               write(line_out, string'(" A ")); 
               write(line_out, to_hstring(export_AddrSave));
               write(line_out, string'(" T ")); 
               if (ram_done = '1') then
                  write(line_out, to_hstring(export_TagWrite(16 downto 0)));
                  if (export_TagWrite(20) = '1') then write(line_out, string'(" V 1")); else write(line_out, string'(" V 0")); end if;
                  if (export_TagWrite(21) = '1') then write(line_out, string'(" D 1")); else write(line_out, string'(" D 0")); end if;
               else
                  write(line_out, to_hstring(export_TagSave(16 downto 0)));
                  if (export_TagSave(20) = '1') then write(line_out, string'(" V 1")); else write(line_out, string'(" V 0")); end if;
                  if (export_TagSave(21) = '1') then write(line_out, string'(" D 1")); else write(line_out, string'(" D 0")); end if;
               end if;
               write(line_out, string'(" I ")); 
               write(line_out, to_hstring(export_AddrSave(12 downto 4)));
               write(line_out, string'(" S 0")); 
               write(line_out, string'(" Data ")); 
               write(line_out, to_hstring(cache_q_b));
               writeline(outfile, line_out);
               tracecounts_out(3) <= tracecounts_out(3) + 1;
            end if;
            
            if (cache_we_b = '1') then
               if (state /= FILL) then
                  export_TagWrite := tag_data_a;
               end if;
               write(line_out, string'("Store: I ")); 
               write(line_out, to_string_len(tracecounts_out(2) + 1, 8));
               write(line_out, string'(" A ")); 
               write(line_out, to_hstring(export_AddrSave(28 downto 13) & unsigned(cache_address_b) & "000"));
               write(line_out, string'(" T ")); 
               write(line_out, to_hstring(export_TagWrite(16 downto 0)));
               if (export_TagWrite(20) = '1') then write(line_out, string'(" V 1")); else write(line_out, string'(" V 0")); end if;
               if (export_TagWrite(21) = '1') then write(line_out, string'(" D 1")); else write(line_out, string'(" D 0")); end if;
               write(line_out, string'(" I ")); 
               write(line_out, to_hstring(export_AddrSave(12 downto 4)));
               write(line_out, string'(" S 0")); 
               write(line_out, string'(" Data ")); 
               export_DataSave := dcachefull(to_integer(export_AddrSave(12 downto 4)), to_integer(to_unsigned(0, 1) & export_AddrSave(3)));
               if (cache_be_b(0) = '1') then export_DataSave( 7 downto  0) := cache_data_b( 7 downto  0); end if;
               if (cache_be_b(1) = '1') then export_DataSave(15 downto  8) := cache_data_b(15 downto  8); end if;
               if (cache_be_b(2) = '1') then export_DataSave(23 downto 16) := cache_data_b(23 downto 16); end if;
               if (cache_be_b(3) = '1') then export_DataSave(31 downto 24) := cache_data_b(31 downto 24); end if;
               if (cache_be_b(4) = '1') then export_DataSave(39 downto 32) := cache_data_b(39 downto 32); end if;
               if (cache_be_b(5) = '1') then export_DataSave(47 downto 40) := cache_data_b(47 downto 40); end if;
               if (cache_be_b(6) = '1') then export_DataSave(55 downto 48) := cache_data_b(55 downto 48); end if;
               if (cache_be_b(7) = '1') then export_DataSave(63 downto 56) := cache_data_b(63 downto 56); end if;
               dcachefull(to_integer(export_AddrSave(12 downto 4)), to_integer(to_unsigned(0, 1) & export_AddrSave(3))) <= export_DataSave;
               write(line_out, to_hstring(export_DataSave));
               writeline(outfile, line_out);
               tracecounts_out(2) <= tracecounts_out(2) + 1;
            end if;
            
            if (writeback_ena = '1') then
               write(line_out, string'("Writeback: I ")); 
               write(line_out, to_string_len(tracecounts_out(4) + 1, 8));
               write(line_out, string'(" A ")); 
               write(line_out, to_hstring(writeback_addr));
               write(line_out, string'(" T ")); 
               
               write(line_out, to_hstring(export_TagSave(16 downto 0)));
               if (export_TagSave(20) = '1') then write(line_out, string'(" V 1")); else write(line_out, string'(" V 0")); end if;
               if (export_TagSave(21) = '1') then write(line_out, string'(" D 1")); else write(line_out, string'(" D 0")); end if;
               write(line_out, string'(" I ")); 
               write(line_out, to_hstring(writeback_addr(12 downto 4)));
               if (state = WRITEBACK2WRITE) then write(line_out, string'(" S 0")); else write(line_out, string'(" S 1")); end if; 
               write(line_out, string'(" Data ")); 
               write(line_out, to_hstring(writeback_data));
               writeline(outfile, line_out);
               tracecounts_out(4) <= tracecounts_out(4) + 1;
            end if;
            
         end loop;
         
      end process;
   
   end generate goutput;

   -- synthesis translate_on   

   
end architecture;




























