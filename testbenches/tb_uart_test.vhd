LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.uart_tx_pkg.all;
    use work.uart_rx_pkg.all;

entity uart_test_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of uart_test_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 5000;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    signal uart_rx_FPGA_in  : uart_rx_FPGA_input_group;
    signal uart_rx_data_in  : uart_rx_data_input_group := (number_of_clocks_per_bit => 24);
    signal uart_rx_data_out : uart_rx_data_output_group;

    signal uart_tx_FPGA_out  : uart_tx_FPGA_output_group;
    signal uart_tx_data_in  : uart_tx_data_input_group := init_uart_tx(number_of_clocks_per_bit =>24);
    signal uart_tx_data_out : uart_tx_data_output_group;

    constant time_between_packages : integer := 100;
    signal transmit_timer : integer range 0 to 127 := 1;

    type memory_array is array (integer range 0 to 7) of std_logic_vector(7 downto 0);
    signal memory : memory_array := (others => (others => '0'));
    signal data_buffer : std_logic_vector(7 downto 0) := (others => '0');
    signal memory_address : integer range memory_array'range := 0;


    signal transmit_buffer : memory_array := (x"ff", x"07",x"06",x"05",x"04",x"03",x"02",x"ff");
    signal transmit_counter : natural := 0;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        check(transmit_buffer = memory, "did not get all bits correctly");
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            init_uart(uart_tx_data_in, 24);
            set_number_of_clocks_per_bit(uart_rx_data_in, 24);

            if uart_tx_is_ready(uart_tx_data_out) then
                transmit_timer <= time_between_packages;
            end if;

            if transmit_timer > 0 then
                transmit_timer <= transmit_timer - 1;
            end if;

            if transmit_timer = 1 then
                transmit_counter <= transmit_counter + 1;
                if transmit_counter < transmit_buffer'length then
                    transmit_8bit_data_package(uart_tx_data_in, transmit_buffer(transmit_counter));
                end if;
            end if;

            if uart_rx_data_is_ready(uart_rx_data_out) then
                memory(memory_address) <= get_uart_rx_data(uart_rx_data_out);
                if memory_address < memory_array'high then
                    memory_address <= memory_address + 1;
                else
                    memory_address <= 0;
                end if;
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_uart_rx : entity work.uart_rx
    port map(simulator_clock,
         (uart_rx => uart_tx_FPGA_out.uart_tx),
    	  uart_rx_data_in,
    	  uart_rx_data_out); 

------------------------------------------------------------------------
    u_uart_tx : entity work.uart_tx
    port map(simulator_clock,
    	  uart_tx_FPGA_out,
    	  uart_tx_data_in,
    	  uart_tx_data_out);

------------------------------------------------------------------------
end vunit_simulation;
