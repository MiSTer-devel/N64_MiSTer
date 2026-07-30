library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library mem;
use work.pFunctions.all;

entity PI_DD is
   port
   (
      clk1x                : in  std_logic;
      ce                   : in  std_logic;
      reset                : in  std_logic;
      second_ena           : in  std_logic;

      diskAvailable        : in  std_logic;
      iplAvailable         : in  std_logic;
      developmentMode      : in  std_logic;
      hpsRTC               : in  std_logic_vector(64 downto 0);

      irq_out              : out std_logic := '0';

      service_enable       : in  std_logic;
      hold_pi              : out std_logic;

      direct_addr          : in  unsigned(31 downto 0);
      direct_dataWrite     : in  std_logic_vector(31 downto 0);
      direct_read          : in  std_logic;
      direct_write         : in  std_logic;
      direct_selected      : out std_logic;
      direct_dataRead      : out std_logic_vector(31 downto 0) := (others => '0');
      direct_done          : out std_logic := '0';

      dma_addr             : in  unsigned(31 downto 0);
      dma_reg_selected     : out std_logic;
      dma_ipl_selected     : out std_logic;
      dma_read_prepare     : in  std_logic;
      dma_read_commit      : in  std_logic;
      dma_dataRead         : out std_logic_vector(15 downto 0);
      dma_write            : in  std_logic;
      dma_dataWrite        : in  std_logic_vector(15 downto 0);

      dma_ipl_start        : in  std_logic;
      dma_ipl_done         : out std_logic;
      dma_ipl_dataRead     : out std_logic_vector(63 downto 0);

      ddram_request        : out std_logic := '0';
      ddram_rnw            : out std_logic := '1';
      ddram_address        : out unsigned(27 downto 0) := (others => '0');
      ddram_burstcount     : out unsigned(9 downto 0) := (others => '0');
      ddram_writeMask      : out std_logic_vector(7 downto 0) := (others => '0');
      ddram_dataWrite      : out std_logic_vector(63 downto 0) := (others => '0');
      ddram_done           : in  std_logic;
      ddram_dataRead       : in  std_logic_vector(63 downto 0)
   );
end entity;

architecture arch of PI_DD is

   constant DD_DISK_DDR_BASE     : unsigned(27 downto 0) := to_unsigned(16#6000000#, 28);
   constant DD_IPL_DDR_BASE      : unsigned(27 downto 0) := to_unsigned(16#0C00000#, 28);
   constant DD_DISK_HEAD_STRIDE  : unsigned(27 downto 0) := to_unsigned(16#3714000#, 28);
   constant DD_DISK_BLOCK_STRIDE : unsigned(27 downto 0) := to_unsigned(16#0006000#, 28);
   constant DD_BAD_BLOCK_SENTINEL: std_logic_vector(63 downto 0) := x"DDDDDDDDDDDDDDDD";
   constant DD_DIRTY_FLAG_OFFSET : unsigned(27 downto 0) := to_unsigned(16#5F00#, 28);
   constant DD_DIRTY_MAGIC       : std_logic_vector(63 downto 0) := x"D1D1D1D1D1D1D1D1";

   -- Ares expresses these delays on the N64's 187.5 MHz system timeline.
   -- Its next-sector event includes work that PI_DD performs serially through
   -- the PI/DDR path, so use the measured residual delay needed to match the
   -- real drive's end-to-end sector cadence. The initial delay only needs the
   -- 187.5-to-62.5 MHz clock-domain conversion.
   constant DD_BM_NEXT_DELAY_CLK1X : unsigned(14 downto 0) := to_unsigned(6849, 15);
   constant DD_BM_START_DELAY_CLK1X: unsigned(14 downto 0) := to_unsigned(16667, 15);
   constant DD_SECTOR_USER_END   : unsigned(7 downto 0) := to_unsigned(16#55#, 8);
   constant DD_SECTOR_C2_LAST    : unsigned(7 downto 0) := to_unsigned(16#58#, 8);
   constant DD_SECTOR_BLOCK_BASE : unsigned(7 downto 0) := to_unsigned(16#5A#, 8);
   constant DD_SEEK_DELAY_CLK1X  : unsigned(26 downto 0) := to_unsigned(1000000, 27);
   constant DD_SEEK_SPINUP_DELAY_CLK1X: unsigned(26 downto 0) := to_unsigned(125000000, 27);

   type tState is
   (
      IDLE,
      DIRECT_REG_READ,
      DIRECT_REG_READ_WAIT,
      IPL_WAIT,
      LOAD_REQ,
      LOAD_WAIT,
      STORE_READ,
      STORE_REQ,
      STORE_ISSUE,
      STORE_WAIT,
      DIRTY_WRITE,
      DIRTY_WAIT
   );
   signal state : tState := IDLE;

   signal direct_reg_offset    : unsigned(10 downto 0) := (others => '0');
   signal direct_ipl_half      : std_logic := '0';

   signal sector_addr_a     : std_logic_vector(4 downto 0) := (others => '0');
   signal sector_data_a0    : std_logic_vector(15 downto 0) := (others => '0');
   signal sector_data_a1    : std_logic_vector(15 downto 0) := (others => '0');
   signal sector_data_a2    : std_logic_vector(15 downto 0) := (others => '0');
   signal sector_data_a3    : std_logic_vector(15 downto 0) := (others => '0');
   signal sector_wren_a     : std_logic := '0';
   signal sector_addr_b     : std_logic_vector(4 downto 0) := (others => '0');
   signal sector_data_in_b0 : std_logic_vector(15 downto 0) := (others => '0');
   signal sector_data_in_b1 : std_logic_vector(15 downto 0) := (others => '0');
   signal sector_data_in_b2 : std_logic_vector(15 downto 0) := (others => '0');
   signal sector_data_in_b3 : std_logic_vector(15 downto 0) := (others => '0');
   signal sector_data_out_b0: std_logic_vector(15 downto 0);
   signal sector_data_out_b1: std_logic_vector(15 downto 0);
   signal sector_data_out_b2: std_logic_vector(15 downto 0);
   signal sector_data_out_b3: std_logic_vector(15 downto 0);
   signal sector_data_out_a0: std_logic_vector(15 downto 0);
   signal sector_data_out_a1: std_logic_vector(15 downto 0);
   signal sector_data_out_a2: std_logic_vector(15 downto 0);
   signal sector_data_out_a3: std_logic_vector(15 downto 0);
   signal sector_wren_b     : std_logic_vector(3 downto 0) := (others => '0');

   signal hard_reset        : std_logic := '1';
   signal disk_inserted     : std_logic := '0';
   signal disk_changed      : std_logic := '0';
   signal disk_available_d  : std_logic := '0';
   signal head_retracted    : std_logic := '1';
   signal spindle_stopped   : std_logic := '1';
   signal motor_started     : std_logic := '0';
   signal index_lock        : std_logic := '0';
   signal data_reg          : std_logic_vector(15 downto 0) := (others => '0');
   signal rtc_year_month    : std_logic_vector(15 downto 0) := x"9601";
   signal rtc_day_hour      : std_logic_vector(15 downto 0) := x"0100";
   signal rtc_minute_second : std_logic_vector(15 downto 0) := x"0000";
   signal rtc_seeded        : std_logic := '0';
   signal cmd_pending       : std_logic := '0';
   signal cmd_interrupt     : std_logic := '0';
   signal bm_interrupt      : std_logic := '0';
   signal bm_transfer_data  : std_logic := '0';
   signal bm_transfer_c2    : std_logic := '0';
   signal bm_micro_error    : std_logic := '0';
   signal bm_c1_single      : std_logic := '0';
   signal bm_c1_double      : std_logic := '0';
   signal bm_running        : std_logic := '0';
   signal bm_read_mode      : std_logic := '0';
   signal bm_blocks         : std_logic := '0';
   signal bm_reset_latched  : std_logic := '0';
   signal current_sector    : unsigned(7 downto 0) := (others => '0');
   signal sector_advance_pending : std_logic := '0';
   signal sector_advance_counter : unsigned(14 downto 0) := (others => '0');
   signal sector_size       : unsigned(7 downto 0) := x"E7";
   signal sector_size_full  : unsigned(7 downto 0) := x"E7";
   signal sectors_in_block  : unsigned(7 downto 0) := x"59";
   signal head_track        : unsigned(12 downto 0) := (others => '0');
   signal seek_pending      : std_logic := '0';
   signal seek_counter      : unsigned(26 downto 0) := (others => '0');
   signal seek_target       : unsigned(12 downto 0) := (others => '0');
   signal load_addr         : unsigned(27 downto 0) := (others => '0');
   signal load_count        : integer range 0 to 31 := 0;
   signal load_total        : integer range 0 to 32 := 0;
   signal store_addr        : unsigned(27 downto 0) := (others => '0');
   signal store_count       : integer range 0 to 31 := 0;
   signal store_next_sector : unsigned(7 downto 0) := (others => '0');
   signal store_set_data    : std_logic := '0';
   signal store_stop        : std_logic := '0';
   signal write_sector_ready: std_logic := '0';
   signal dirty_addr        : unsigned(27 downto 0) := (others => '0');

   subtype dd_byte is std_logic_vector(7 downto 0);

   function reg_selected(address : unsigned) return boolean is
   begin
      return address >= to_unsigned(16#05000000#, address'length) and
             address <  to_unsigned(16#05010000#, address'length);
   end function;

   function ipl_selected(address : unsigned) return boolean is
   begin
      return address >= to_unsigned(16#06000000#, address'length) and
             address <  to_unsigned(16#06400000#, address'length);
   end function;

   function bcd_increment(value : dd_byte) return dd_byte is
      variable result : unsigned(7 downto 0);
   begin
      result := unsigned(value);
      if unsigned(value(3 downto 0)) = 9 then
         result(3 downto 0) := (others => '0');
         result(7 downto 4) := unsigned(value(7 downto 4)) + 1;
      else
         result(3 downto 0) := unsigned(value(3 downto 0)) + 1;
      end if;
      return std_logic_vector(result);
   end function;

   function is_bcd(value : dd_byte) return boolean is
   begin
      return unsigned(value(3 downto 0)) <= 9 and unsigned(value(7 downto 4)) <= 9;
   end function;

   function days_in_month_bcd(year : dd_byte; month : dd_byte) return dd_byte is
      variable leap_remainder : unsigned(1 downto 0);
   begin
      case month is
         when x"04" | x"06" | x"09" | x"11" =>
            return x"30";
         when x"02" =>
            -- Decimal (10 * tens + ones) modulo four. Only the low bit of
            -- the BCD tens digit contributes because 10 modulo four is two.
            leap_remainder := (others => '0');
            leap_remainder(1) := year(4);
            leap_remainder := leap_remainder + unsigned(year(1 downto 0));
            if leap_remainder = 0 then return x"29"; end if;
            return x"28";
         when others =>
            return x"31";
      end case;
   end function;

   function sector_ddr_address(
      selected_head_track : unsigned(12 downto 0);
      block_sel            : std_logic;
      sector_num           : unsigned(7 downto 0)
   ) return unsigned is
      variable address  : unsigned(27 downto 0);
      variable sector_i : unsigned(7 downto 0);
   begin
      sector_i := sector_num;
      if sector_i >= to_unsigned(90, sector_i'length) then
         sector_i := sector_i - to_unsigned(90, sector_i'length);
      end if;
      if sector_i > to_unsigned(84, sector_i'length) then
         sector_i := to_unsigned(84, sector_i'length);
      end if;

      address := DD_DISK_DDR_BASE
         + ('0' & selected_head_track(11 downto 0) & 15x"0")
         + ("00" & selected_head_track(11 downto 0) & 14x"0")
         + (12x"0" & sector_i & 8x"0");
      if selected_head_track(12) = '1' then address := address + DD_DISK_HEAD_STRIDE; end if;
      if block_sel = '1' then address := address + DD_DISK_BLOCK_STRIDE; end if;
      return address;
   end function;

   function asic_reg_offset(offset : unsigned(10 downto 0)) return unsigned is
      variable reg_offset : unsigned(10 downto 0);
      variable low_offset : unsigned(6 downto 0);
   begin
      reg_offset := offset;
      if offset >= 11x"500" then
         low_offset := offset(6 downto 0);
         low_offset(0) := '0';
         reg_offset := 11x"500" + resize(low_offset, 11);
      end if;
      return reg_offset;
   end function;

   function is_cmd_status_offset(offset : unsigned(10 downto 0)) return boolean is
   begin
      return asic_reg_offset(offset) = 11x"508";
   end function;

   impure function read_half(offset : unsigned(10 downto 0)) return std_logic_vector is
      variable value : std_logic_vector(15 downto 0);
   begin
      value := (others => '0');
      case to_integer(asic_reg_offset(offset)) is
         when 16#500# => value := data_reg;
         when 16#504# => value := (others => '0');
         when 16#508# =>
            value := '0' & bm_transfer_data & '0' & bm_transfer_c2 &
                     '0' & bm_interrupt & cmd_interrupt & disk_inserted &
                     (cmd_pending or seek_pending) & hard_reset &
                     '0' & spindle_stopped & head_retracted & '0' & '0' & disk_changed;
         when 16#50C# => value := '0' & index_lock & index_lock & std_logic_vector(head_track);
         when 16#510# =>
            value := (others => '0');
            value(15) := bm_running;
            value(9)  := bm_micro_error;
            value(8)  := bm_blocks;
            value(6)  := bm_c1_double;
            value(5)  := bm_c1_single;
         when 16#514# =>
            value := (others => '0');
            value(14) := bm_micro_error;
            value(10) := not disk_inserted;
         when 16#518# => value := (others => '0');
         when 16#51C# => value := std_logic_vector(current_sector) & x"C3";
         when 16#528# => value := x"00" & std_logic_vector(sector_size);
         when 16#52C# | 16#530# => value := std_logic_vector(sectors_in_block) & std_logic_vector(sector_size_full);
         when 16#540# =>
            if developmentMode = '1' then value := x"0004";
            else value := x"0003";
            end if;
         when others => value := (others => '0');
      end case;
      return value;
   end function;

   function service_due(
      pending      : std_logic;
      counter      : unsigned(14 downto 0);
      running      : std_logic;
      read_mode    : std_logic;
      sector       : unsigned(7 downto 0);
      write_ready  : std_logic
   ) return boolean is
   begin
      return pending = '1' and counter = 0 and
         (running = '0' or read_mode = '1' or sector = 0 or
          sector = DD_SECTOR_BLOCK_BASE or write_ready = '1');
   end function;

begin

   irq_out <= cmd_interrupt or bm_interrupt;
   ddram_burstcount <= 10x"01";

   direct_selected <= '1' when
      (iplAvailable = '1' and reg_selected(direct_addr(28 downto 0))) or
      (iplAvailable = '1' and ipl_selected(direct_addr(28 downto 0))) else '0';

   dma_reg_selected <= '1' when iplAvailable = '1' and reg_selected(dma_addr(28 downto 0)) else '0';
   dma_ipl_selected <= '1' when iplAvailable = '1' and ipl_selected(dma_addr(28 downto 0)) else '0';

   hold_pi <= '1' when state /= IDLE or
      (service_enable = '1' and service_due(sector_advance_pending, sector_advance_counter,
       bm_running, bm_read_mode, current_sector, write_sector_ready)) else '0';

   dma_ipl_done <= '1' when state = IPL_WAIT and service_enable = '0' and ddram_done = '1' else '0';
   dma_ipl_dataRead <= ddram_dataRead;

   process(all)
      variable offset : unsigned(10 downto 0);
   begin
      offset := dma_addr(10 downto 0);
      if offset >= 11x"400" and offset < 11x"500" then
         case offset(2 downto 1) is
            when "00" => dma_dataRead <= sector_data_out_b0;
            when "01" => dma_dataRead <= sector_data_out_b1;
            when "10" => dma_dataRead <= sector_data_out_b2;
            when others => dma_dataRead <= sector_data_out_b3;
         end case;
      else
         dma_dataRead <= read_half(offset);
      end if;
   end process;

   -- Keep the final cartridge response register in PI. These combinational
   -- response signals match the decision points of the former monolithic FSM.
   process(all)
      variable offset      : unsigned(10 downto 0);
      variable direct_data : std_logic_vector(31 downto 0);
   begin
      direct_done     <= '0';
      direct_dataRead <= (others => '0');
      offset := direct_addr(10 downto 0);

      case state is
         when IDLE =>
            if direct_read = '1' and direct_selected = '1' and service_enable = '1' and
               reg_selected(direct_addr(28 downto 0)) and
               not (offset >= 11x"400" and offset < 11x"500") then
               direct_dataRead <= read_half(offset) & read_half(offset + 2);
               direct_done <= '1';
            elsif direct_write = '1' and direct_selected = '1' and service_enable = '1' then
               direct_done <= '1';
            end if;

         when DIRECT_REG_READ_WAIT =>
            direct_data := (others => '0');
            if direct_reg_offset(1) = '0' then
               if direct_reg_offset(2) = '0' then
                  direct_data := byteswap16(sector_data_out_b0) & byteswap16(sector_data_out_b1);
               else
                  direct_data := byteswap16(sector_data_out_b2) & byteswap16(sector_data_out_b3);
               end if;
            else
               if direct_reg_offset(2) = '0' then
                  direct_data := byteswap16(sector_data_out_b1) & byteswap16(sector_data_out_b2);
               else
                  direct_data := byteswap16(sector_data_out_b3) & x"0000";
               end if;
            end if;
            direct_dataRead <= direct_data;
            direct_done <= '1';

         when IPL_WAIT =>
            if service_enable = '1' and ddram_done = '1' then
               if direct_ipl_half = '0' then
                  direct_dataRead <= ddram_dataRead(7 downto 0) & ddram_dataRead(15 downto 8) &
                                     ddram_dataRead(23 downto 16) & ddram_dataRead(31 downto 24);
               else
                  direct_dataRead <= ddram_dataRead(39 downto 32) & ddram_dataRead(47 downto 40) &
                                     ddram_dataRead(55 downto 48) & ddram_dataRead(63 downto 56);
               end if;
               direct_done <= '1';
            end if;

         when others => null;
      end case;
   end process;

   process(clk1x)
      variable offset          : unsigned(10 downto 0);
      variable write_data      : std_logic_vector(15 downto 0);
      variable next_sector     : unsigned(7 downto 0);
      variable block_sel       : std_logic;
      variable start_sector    : unsigned(7 downto 0);
      variable request_user    : std_logic;
      variable request_stop    : std_logic;
      variable rtc_second      : dd_byte;
      variable rtc_minute      : dd_byte;
      variable rtc_hour        : dd_byte;
      variable rtc_day         : dd_byte;
      variable rtc_month       : dd_byte;
      variable rtc_year        : dd_byte;
      variable rtc_month_days  : dd_byte;
      variable rtc_seed_applied: boolean;
   begin
      if rising_edge(clk1x) then
         sector_wren_a <= '0';
         sector_wren_b <= (others => '0');
         rtc_seed_applied := false;

         if reset = '1' then
            state <= IDLE;
            ddram_rnw <= '1';
            ddram_writeMask <= (others => '0');
            ddram_address <= (others => '0');
            ddram_dataWrite <= (others => '0');

            hard_reset <= '1';
            disk_inserted <= diskAvailable;
            disk_changed <= diskAvailable;
            disk_available_d <= diskAvailable;
            head_retracted <= '1';
            spindle_stopped <= '1';
            motor_started <= '0';
            index_lock <= '0';
            data_reg <= (others => '0');
            rtc_year_month <= x"9601";
            rtc_day_hour <= x"0100";
            rtc_minute_second <= x"0000";
            rtc_seeded <= '0';
            cmd_pending <= '0';
            cmd_interrupt <= '0';
            bm_interrupt <= '0';
            bm_transfer_data <= '0';
            bm_transfer_c2 <= '0';
            bm_micro_error <= '0';
            bm_c1_single <= '0';
            bm_c1_double <= '0';
            bm_running <= '0';
            bm_read_mode <= '0';
            bm_blocks <= '0';
            bm_reset_latched <= '0';
            current_sector <= (others => '0');
            sector_advance_pending <= '0';
            sector_advance_counter <= (others => '0');
            sector_size <= x"E7";
            sector_size_full <= x"E7";
            sectors_in_block <= x"59";
            head_track <= (others => '0');
            seek_pending <= '0';
            seek_counter <= (others => '0');
            seek_target <= (others => '0');
            load_addr <= (others => '0');
            load_count <= 0;
            load_total <= 0;
            store_addr <= (others => '0');
            store_count <= 0;
            store_next_sector <= (others => '0');
            store_set_data <= '0';
            store_stop <= '0';
            write_sector_ready <= '0';
            dirty_addr <= (others => '0');

         elsif ce = '1' then
            ddram_request <= '0';
            ddram_rnw <= '1';
            ddram_writeMask <= (others => '0');

            disk_inserted <= diskAvailable;
            if diskAvailable = '1' and disk_available_d = '0' then
               disk_changed <= '0';
               motor_started <= '0';
               bm_interrupt <= '0';
               bm_transfer_data <= '0';
               bm_transfer_c2 <= '0';
               bm_micro_error <= '0';
               bm_c1_single <= '0';
               bm_c1_double <= '0';
               bm_running <= '0';
               bm_read_mode <= '0';
               bm_blocks <= '0';
               bm_reset_latched <= '0';
               sector_advance_pending <= '0';
               sector_advance_counter <= (others => '0');
               write_sector_ready <= '0';
            end if;
            disk_available_d <= diskAvailable;
            if diskAvailable = '0' then
               disk_changed <= '0';
               motor_started <= '0';
               write_sector_ready <= '0';
            end if;

            if rtc_seeded = '0' then
               -- Main sends a complete BCD RTC value before releasing reset.
               rtc_minute_second <= hpsRTC(15 downto 0);
               rtc_day_hour <= hpsRTC(31 downto 16);
               rtc_year_month <= hpsRTC(47 downto 32);
               rtc_seeded <= '1';
               rtc_seed_applied := true;
            end if;

            if second_ena = '1' and not rtc_seed_applied then
               rtc_second := rtc_minute_second(7 downto 0);
               rtc_minute := rtc_minute_second(15 downto 8);
               rtc_hour := rtc_day_hour(7 downto 0);
               rtc_day := rtc_day_hour(15 downto 8);
               rtc_month := rtc_year_month(7 downto 0);
               rtc_year := rtc_year_month(15 downto 8);

               if not is_bcd(rtc_month) or unsigned(rtc_month) < unsigned'(x"01") or
                  unsigned(rtc_month) > unsigned'(x"12") then rtc_month := x"01"; end if;
               rtc_month_days := days_in_month_bcd(rtc_year, rtc_month);
               if not is_bcd(rtc_day) or unsigned(rtc_day) < unsigned'(x"01") or
                  unsigned(rtc_day) > unsigned(rtc_month_days) then rtc_day := x"01"; end if;

               if is_bcd(rtc_second) and unsigned(rtc_second) < unsigned'(x"59") then
                  rtc_second := bcd_increment(rtc_second);
               else
                  rtc_second := x"00";
                  if is_bcd(rtc_minute) and unsigned(rtc_minute) < unsigned'(x"59") then
                     rtc_minute := bcd_increment(rtc_minute);
                  else
                     rtc_minute := x"00";
                     if is_bcd(rtc_hour) and unsigned(rtc_hour) < unsigned'(x"23") then
                        rtc_hour := bcd_increment(rtc_hour);
                     else
                        rtc_hour := x"00";
                        if unsigned(rtc_day) < unsigned(rtc_month_days) then
                           rtc_day := bcd_increment(rtc_day);
                        else
                           rtc_day := x"01";
                           if unsigned(rtc_month) < unsigned'(x"12") then
                              rtc_month := bcd_increment(rtc_month);
                           else
                              rtc_month := x"01";
                              if is_bcd(rtc_year) and unsigned(rtc_year) < unsigned'(x"99") then
                                 rtc_year := bcd_increment(rtc_year);
                              else
                                 rtc_year := x"00";
                              end if;
                           end if;
                        end if;
                     end if;
                  end if;
               end if;
               rtc_minute_second <= rtc_minute & rtc_second;
               rtc_day_hour <= rtc_day & rtc_hour;
               rtc_year_month <= rtc_year & rtc_month;
            end if;

            if seek_pending = '1' then
               if seek_counter = 0 then
                  seek_pending <= '0';
                  head_track <= seek_target;
                  index_lock <= '1';
                  cmd_pending <= '0';
                  cmd_interrupt <= '1';
                  head_retracted <= '0';
                  spindle_stopped <= '0';
               else
                  seek_counter <= seek_counter - 1;
               end if;
            end if;

            if sector_advance_pending = '1' and sector_advance_counter /= 0 then
               sector_advance_counter <= sector_advance_counter - 1;
            end if;

            if dma_read_prepare = '1' then
               offset := dma_addr(10 downto 0);
               if offset >= 11x"400" and offset < 11x"500" then
                  sector_addr_b <= std_logic_vector(offset(7 downto 3));
               end if;
            end if;

            if dma_read_commit = '1' then
               offset := dma_addr(10 downto 0);
               if is_cmd_status_offset(offset) and bm_interrupt = '1' then
                  bm_interrupt <= '0';
                  sector_advance_pending <= '1';
                  sector_advance_counter <= DD_BM_NEXT_DELAY_CLK1X;
               end if;
            end if;

            if dma_write = '1' then
               offset := dma_addr(10 downto 0);
               if offset >= 11x"400" and offset < 11x"500" then
                  sector_addr_b <= std_logic_vector(offset(7 downto 3));
                  sector_data_in_b0 <= dma_dataWrite;
                  sector_data_in_b1 <= dma_dataWrite;
                  sector_data_in_b2 <= dma_dataWrite;
                  sector_data_in_b3 <= dma_dataWrite;
                  case offset(2 downto 1) is
                     when "00" => sector_wren_b(0) <= '1';
                     when "01" => sector_wren_b(1) <= '1';
                     when "10" => sector_wren_b(2) <= '1';
                     when others => sector_wren_b(3) <= '1';
                  end case;
                  if offset(7 downto 1) = sector_size(7 downto 1) then write_sector_ready <= '1'; end if;
               end if;
            end if;

            case state is
               when IDLE =>
                  if dma_ipl_start = '1' then
                     ddram_request <= '1';
                     ddram_rnw <= '1';
                     ddram_address <= DD_IPL_DDR_BASE + (6x"0" & dma_addr(21 downto 3) & "000");
                     state <= IPL_WAIT;

                  elsif service_enable = '1' and service_due(sector_advance_pending,
                     sector_advance_counter, bm_running, bm_read_mode, current_sector,
                     write_sector_ready) then
                     sector_advance_pending <= '0';
                     if bm_running = '0' then
                        bm_interrupt <= '0';
                     else
                        bm_transfer_data <= '0';
                        bm_transfer_c2 <= '0';
                        bm_micro_error <= '0';
                        bm_c1_single <= '0';
                        bm_c1_double <= '0';
                        block_sel := '0';
                        start_sector := current_sector;
                        if current_sector >= DD_SECTOR_BLOCK_BASE then
                           block_sel := '1';
                           start_sector := current_sector - DD_SECTOR_BLOCK_BASE;
                        end if;

                        if bm_read_mode = '1' then
                           if start_sector < DD_SECTOR_USER_END then
                              load_addr <= sector_ddr_address(head_track, block_sel, start_sector);
                              load_count <= 0;
                              load_total <= 32;
                              state <= LOAD_REQ;
                           elsif start_sector < DD_SECTOR_C2_LAST then
                              current_sector <= current_sector + 1;
                              bm_interrupt <= '1';
                           elsif start_sector = DD_SECTOR_C2_LAST then
                              bm_transfer_c2 <= '1';
                              if bm_blocks = '1' then
                                 bm_blocks <= '0';
                                 if block_sel = '1' then current_sector <= (others => '0');
                                 else current_sector <= DD_SECTOR_BLOCK_BASE;
                                 end if;
                              else
                                 bm_running <= '0';
                              end if;
                              bm_interrupt <= '1';
                           else
                              bm_interrupt <= '1';
                           end if;
                        else
                           request_user := '0';
                           request_stop := '0';
                           next_sector := current_sector + 1;
                           if start_sector <= DD_SECTOR_USER_END then request_user := '1'; end if;
                           if start_sector >= DD_SECTOR_USER_END then
                              if bm_blocks = '1' then
                                 bm_blocks <= '0';
                                 if block_sel = '1' then next_sector := to_unsigned(1, 8);
                                 else next_sector := DD_SECTOR_BLOCK_BASE + 1;
                                 end if;
                              else
                                 request_user := '0';
                                 request_stop := '1';
                              end if;
                           end if;
                           if start_sector > 0 and start_sector <= DD_SECTOR_USER_END and diskAvailable = '1' then
                              write_sector_ready <= '0';
                              store_addr <= sector_ddr_address(head_track, block_sel, start_sector - 1);
                              dirty_addr <= sector_ddr_address(head_track, block_sel, to_unsigned(0, 8)) + DD_DIRTY_FLAG_OFFSET;
                              store_count <= 0;
                              store_next_sector <= next_sector;
                              store_set_data <= request_user;
                              store_stop <= request_stop;
                              state <= STORE_READ;
                           else
                              bm_transfer_data <= request_user;
                              if request_stop = '1' then
                                 bm_running <= '0';
                              end if;
                              current_sector <= next_sector;
                              bm_interrupt <= '1';
                           end if;
                        end if;
                     end if;

                  elsif direct_read = '1' and direct_selected = '1' and service_enable = '1' then
                     offset := direct_addr(10 downto 0);
                     if reg_selected(direct_addr(28 downto 0)) then
                        if offset >= 11x"400" and offset < 11x"500" then
                           direct_reg_offset <= offset;
                           sector_addr_b <= std_logic_vector(offset(7 downto 3));
                           state <= DIRECT_REG_READ;
                        else
                           if is_cmd_status_offset(offset) and bm_interrupt = '1' then
                              bm_interrupt <= '0';
                              sector_advance_pending <= '1';
                              sector_advance_counter <= DD_BM_NEXT_DELAY_CLK1X;
                           end if;
                        end if;
                     else
                        ddram_request <= '1';
                        ddram_rnw <= '1';
                        ddram_address <= DD_IPL_DDR_BASE + (6x"0" & direct_addr(21 downto 3) & "000");
                        direct_ipl_half <= direct_addr(2);
                        state <= IPL_WAIT;
                     end if;

                  elsif direct_write = '1' and direct_selected = '1' and service_enable = '1' then
                     offset := direct_addr(10 downto 0);
                     if reg_selected(direct_addr(28 downto 0)) then
                        if offset >= 11x"400" and offset < 11x"500" then
                        sector_addr_b <= std_logic_vector(offset(7 downto 3));
                        sector_data_in_b0 <= byteswap16(direct_dataWrite(31 downto 16));
                        sector_data_in_b1 <= byteswap16(direct_dataWrite(15 downto 0));
                        sector_data_in_b2 <= byteswap16(direct_dataWrite(31 downto 16));
                        sector_data_in_b3 <= byteswap16(direct_dataWrite(15 downto 0));
                        if offset(2) = '0' then sector_wren_b(1 downto 0) <= "11";
                        else sector_wren_b(3 downto 2) <= "11";
                        end if;
                           if offset(7 downto 2) = sector_size(7 downto 2) then write_sector_ready <= '1'; end if;
                        else
                        write_data := direct_dataWrite(31 downto 16);
                        case to_integer(asic_reg_offset(offset)) is
                           when 16#500# => data_reg <= write_data;
                           when 16#508# =>
                              cmd_pending <= '0';
                              cmd_interrupt <= '1';
                              case write_data(7 downto 0) is
                                 when x"01" | x"02" =>
                                    seek_pending <= '1';
                                    seek_target <= unsigned(data_reg(12 downto 0));
                                    cmd_pending <= '1';
                                    cmd_interrupt <= '0';
                                    index_lock <= '0';
                                    head_retracted <= '0';
                                    spindle_stopped <= '0';
                                    if motor_started = '0' then
                                       motor_started <= '1';
                                       seek_counter <= DD_SEEK_SPINUP_DELAY_CLK1X;
                                    else seek_counter <= DD_SEEK_DELAY_CLK1X;
                                    end if;
                                 when x"03" | x"05" =>
                                    seek_pending <= '0';
                                    head_track <= (others => '0');
                                    index_lock <= '1';
                                    head_retracted <= '0';
                                    spindle_stopped <= '0';
                                 when x"04" =>
                                    seek_pending <= '0';
                                    head_retracted <= '1';
                                    spindle_stopped <= '1';
                                    motor_started <= '0';
                                 when x"08" => disk_changed <= '0';
                                 when x"09" =>
                                    seek_pending <= '0';
                                    hard_reset <= '0';
                                    disk_changed <= '0';
                                 when x"0A" => data_reg <= x"0114";
                                 when x"0C" => data_reg <= (others => '0');
                                 when x"0D" =>
                                    head_retracted <= '1';
                                    spindle_stopped <= '0';
                                 when x"0E" => index_lock <= '1';
                                 when x"1B" => data_reg <= x"0000";
                                 when x"0F" => rtc_year_month <= data_reg; rtc_seeded <= '1';
                                 when x"10" => rtc_day_hour <= data_reg; rtc_seeded <= '1';
                                 when x"11" => rtc_minute_second <= data_reg; rtc_seeded <= '1';
                                 when x"12" => data_reg <= rtc_year_month;
                                 when x"13" => data_reg <= rtc_day_hour;
                                 when x"14" => data_reg <= rtc_minute_second;
                                 when others => null;
                              end case;
                           when 16#510# =>
                              current_sector <= unsigned(write_data(7 downto 0));
                              bm_read_mode <= write_data(14);
                              bm_blocks <= write_data(9);
                              if write_data(8) = '1' then cmd_interrupt <= '0'; end if;
                              if write_data(12) = '1' then
                                 bm_reset_latched <= '1';
                              elsif bm_reset_latched = '1' then
                                 bm_reset_latched <= '0';
                                 bm_running <= '0';
                                 bm_interrupt <= '0';
                                 bm_transfer_data <= '0';
                                 bm_transfer_c2 <= '0';
                                 bm_micro_error <= '0';
                                 sector_advance_pending <= '0';
                                 sector_advance_counter <= (others => '0');
                                 write_sector_ready <= '0';
                              end if;
                              if write_data(15) = '1' then
                                 if diskAvailable = '1' then
                                    bm_running <= '1';
                                    write_sector_ready <= '0';
                                    sector_advance_pending <= '1';
                                    sector_advance_counter <= DD_BM_START_DELAY_CLK1X;
                                 else
                                    bm_micro_error <= '1';
                                    bm_interrupt <= '1';
                                 end if;
                              end if;
                           when 16#520# =>
                              if write_data = x"AAAA" then
                                 hard_reset <= '1';
                                 disk_changed <= '0';
                                 head_retracted <= '1';
                                 spindle_stopped <= '1';
                                 motor_started <= '0';
                                 seek_pending <= '0';
                                 cmd_pending <= '0';
                                 cmd_interrupt <= '0';
                                 bm_reset_latched <= '0';
                                 bm_running <= '0';
                                 bm_read_mode <= '0';
                                 bm_blocks <= '0';
                                 bm_interrupt <= '0';
                                 bm_transfer_data <= '0';
                                 bm_transfer_c2 <= '0';
                                 bm_c1_single <= '0';
                                 bm_c1_double <= '0';
                                 sector_advance_pending <= '0';
                                 sector_advance_counter <= (others => '0');
                                 write_sector_ready <= '0';
                              end if;
                           when 16#528# => sector_size <= unsigned(write_data(7 downto 0));
                           when 16#52C# | 16#530# =>
                              sector_size_full <= unsigned(write_data(7 downto 0));
                              sectors_in_block <= unsigned(write_data(15 downto 8));
                           when others => null;
                        end case;
                        end if;
                     end if;
                  end if;

               when DIRECT_REG_READ => state <= DIRECT_REG_READ_WAIT;

               when DIRECT_REG_READ_WAIT =>
                  state <= IDLE;

               when IPL_WAIT =>
                  if ddram_done = '1' then state <= IDLE; end if;

               when LOAD_REQ =>
                  if diskAvailable = '1' then
                     ddram_request <= '1';
                     ddram_address <= load_addr + to_unsigned(load_count * 8, 28);
                     state <= LOAD_WAIT;
                  else
                     bm_micro_error <= '1';
                     bm_interrupt <= '1';
                     bm_transfer_data <= '0';
                     state <= IDLE;
                  end if;

               when LOAD_WAIT =>
                  if ddram_done = '1' then
                     sector_addr_a <= std_logic_vector(to_unsigned(load_count, sector_addr_a'length));
                     sector_data_a0 <= ddram_dataRead(15 downto 0);
                     sector_data_a1 <= ddram_dataRead(31 downto 16);
                     sector_data_a2 <= ddram_dataRead(47 downto 32);
                     sector_data_a3 <= ddram_dataRead(63 downto 48);
                     sector_wren_a <= '1';
                     if load_count + 1 >= load_total then
                        next_sector := current_sector + 1;
                        current_sector <= next_sector;
                        if load_count = 31 and ddram_dataRead = DD_BAD_BLOCK_SENTINEL then
                           bm_c1_single <= '1';
                           bm_c1_double <= '1';
                        end if;
                        bm_transfer_data <= '1';
                        bm_interrupt <= '1';
                        state <= IDLE;
                     else
                        load_count <= load_count + 1;
                        state <= LOAD_REQ;
                     end if;
                  end if;

               when STORE_READ =>
                  sector_addr_a <= std_logic_vector(to_unsigned(store_count, sector_addr_a'length));
                  state <= STORE_REQ;

               when STORE_REQ => state <= STORE_ISSUE;

               when STORE_ISSUE =>
                  ddram_request <= '1';
                  ddram_rnw <= '0';
                  ddram_address <= store_addr + to_unsigned(store_count * 8, 28);
                  ddram_writeMask <= x"FF";
                  ddram_dataWrite <= sector_data_out_a3 & sector_data_out_a2 & sector_data_out_a1 & sector_data_out_a0;
                  state <= STORE_WAIT;

               when STORE_WAIT =>
                  ddram_rnw <= '0';
                  ddram_address <= store_addr + to_unsigned(store_count * 8, 28);
                  ddram_writeMask <= x"FF";
                  ddram_dataWrite <= sector_data_out_a3 & sector_data_out_a2 & sector_data_out_a1 & sector_data_out_a0;
                  if ddram_done = '1' then
                     if store_count = 31 then state <= DIRTY_WRITE;
                     else store_count <= store_count + 1; state <= STORE_READ;
                     end if;
                  end if;

               when DIRTY_WRITE =>
                  ddram_request <= '1';
                  ddram_rnw <= '0';
                  ddram_address <= dirty_addr;
                  ddram_writeMask <= x"FF";
                  ddram_dataWrite <= DD_DIRTY_MAGIC;
                  state <= DIRTY_WAIT;

               when DIRTY_WAIT =>
                  ddram_rnw <= '0';
                  ddram_address <= dirty_addr;
                  ddram_writeMask <= x"FF";
                  ddram_dataWrite <= DD_DIRTY_MAGIC;
                  if ddram_done = '1' then
                     current_sector <= store_next_sector;
                     bm_transfer_data <= store_set_data;
                     if store_stop = '1' then
                        bm_running <= '0';
                     end if;
                     bm_interrupt <= '1';
                     state <= IDLE;
                  end if;
            end case;
         end if;
      end if;
   end process;

   sector0: entity work.dpram
   generic map(addr_width => 5, data_width => 16)
   port map(
      clock_a => clk1x, address_a => sector_addr_a, data_a => sector_data_a0,
      wren_a => sector_wren_a, q_a => sector_data_out_a0,
      clock_b => clk1x, address_b => sector_addr_b, data_b => sector_data_in_b0,
      wren_b => sector_wren_b(0), q_b => sector_data_out_b0
   );

   sector1: entity work.dpram
   generic map(addr_width => 5, data_width => 16)
   port map(
      clock_a => clk1x, address_a => sector_addr_a, data_a => sector_data_a1,
      wren_a => sector_wren_a, q_a => sector_data_out_a1,
      clock_b => clk1x, address_b => sector_addr_b, data_b => sector_data_in_b1,
      wren_b => sector_wren_b(1), q_b => sector_data_out_b1
   );

   sector2: entity work.dpram
   generic map(addr_width => 5, data_width => 16)
   port map(
      clock_a => clk1x, address_a => sector_addr_a, data_a => sector_data_a2,
      wren_a => sector_wren_a, q_a => sector_data_out_a2,
      clock_b => clk1x, address_b => sector_addr_b, data_b => sector_data_in_b2,
      wren_b => sector_wren_b(2), q_b => sector_data_out_b2
   );

   sector3: entity work.dpram
   generic map(addr_width => 5, data_width => 16)
   port map(
      clock_a => clk1x, address_a => sector_addr_a, data_a => sector_data_a3,
      wren_a => sector_wren_a, q_a => sector_data_out_a3,
      clock_b => clk1x, address_b => sector_addr_b, data_b => sector_data_in_b3,
      wren_b => sector_wren_b(3), q_b => sector_data_out_b3
   );

end architecture;
