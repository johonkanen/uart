library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package uart_rx_pkg is

    subtype uint12 is integer range 0 to 2**12-1;

    type uart_rx_clock_group is record
        clock : std_logic;
    end record;
    
    type uart_rx_FPGA_input_group is record
        uart_rx : std_logic;
    end record;
    
    type uart_rx_data_input_group is record
        number_of_clocks_per_bit : uint12;
    end record;
    
    type uart_rx_data_output_group is record
        uart_rx_data : std_logic_vector(7 downto 0);
        uart_rx_data_transmission_is_ready : boolean;
    end record;
    
------------------------------------------------------------------------
    procedure set_number_of_clocks_per_bit (
        signal uart_rx_data_input : out uart_rx_data_input_group;
        set_number_of_clocks_per_bit_to : integer range 0 to 2**12-1);
------------------------------------------------------------------------
    function uart_rx_data_is_ready ( uart_rx_out : uart_rx_data_output_group)
        return boolean;
------------------------------------------------------------------------
    function get_uart_rx_data ( uart_rx_out : uart_rx_data_output_group)
        return std_logic_vector;
------------------------------------------------------------------------
    function get_uart_rx_data ( uart_rx_out : uart_rx_data_output_group)
        return natural;
------------------------------------------------------------------------
    
------------------------------------------------------------------------
end package uart_rx_pkg;

package body uart_rx_pkg is

------------------------------------------------------------------------
    procedure set_number_of_clocks_per_bit
    (
        signal uart_rx_data_input : out uart_rx_data_input_group;
        set_number_of_clocks_per_bit_to : integer range 0 to 2**12-1
    ) is
    begin
        uart_rx_data_input.number_of_clocks_per_bit <= set_number_of_clocks_per_bit_to;
    end set_number_of_clocks_per_bit;
------------------------------------------------------------------------
    function uart_rx_data_is_ready
    (
        uart_rx_out : uart_rx_data_output_group
    )
    return boolean
    is
    begin
        return uart_rx_out.uart_rx_data_transmission_is_ready;
    end uart_rx_data_is_ready;

------------------------------------------------------------------------
    function get_uart_rx_data
    (
        uart_rx_out : uart_rx_data_output_group
    )
    return std_logic_vector 
    is
    begin
        return uart_rx_out.uart_rx_data; 
    end get_uart_rx_data;

------------------------------------------------------------------------
    function get_uart_rx_data
    (
        uart_rx_out : uart_rx_data_output_group
    )
    return natural
    is
    begin
        return to_integer(unsigned(uart_rx_out.uart_rx_data));
    end get_uart_rx_data;
------------------------------------------------------------------------
end package body uart_rx_pkg;

------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.uart_rx_pkg.all;

entity uart_rx is
    port (
        uart_rx_clocks   : in uart_rx_clock_group;
        uart_rx_FPGA_in  : in uart_rx_FPGA_input_group;
        uart_rx_data_in  : in uart_rx_data_input_group;
        uart_rx_data_out : out uart_rx_data_output_group
    );
end entity;

architecture rtl of uart_rx is

    alias clock is uart_rx_clocks.clock;

    alias clock_in_uart_bit is uart_rx_data_in.number_of_clocks_per_bit;
    signal bit_counter_high : natural;

    signal receive_register                    : std_logic_vector(9 downto 0)  := (others => '0');
    signal receive_bit_counter                 : natural range 0 to 2047;
    signal counter_for_number_of_received_bits : natural range 0 to 15         := 0;
    signal received_data                       : std_logic_vector(7 downto 0);
    signal input_buffer                        : std_logic_vector(1 downto 0);
    signal uart_rx_data_transmission_is_ready  : boolean                       := false;


    signal counter_for_data_bit : uint12 := 0;

    constant total_number_of_transmitted_bits_per_word : integer := 10;
    type list_of_uart_rx_states is (wait_for_start_bit, receive_data);
    signal uart_rx_state : list_of_uart_rx_states := wait_for_start_bit;

begin

    bit_counter_high <= clock_in_uart_bit - 1;
    uart_rx_data_out <= (uart_rx_data                      => received_data,
                        uart_rx_data_transmission_is_ready => uart_rx_data_transmission_is_ready);

    uart_rx_receiver : process(clock)

    --------------------------------------------------
        function read_bit_as_1_if_counter_higher_than
        (
            limit_for_bit_being_high : natural;
            counter_for_bit : natural 
        )
        return std_logic
        is
        begin
            if counter_for_bit > limit_for_bit_being_high then
                return '1';
            else
                return '0';
            end if;
            
        end read_bit_as_1_if_counter_higher_than;

    --------------------------------------------------
        function "+"
        (
            left : integer;
            right : std_logic 
        )
        return integer
        is
        begin
            if right = '1' then
                return left + 1;
            else
                return left;
            end if;
        end "+";

    --------------------------------------------------
        
    begin
        if rising_edge(clock) then

            input_buffer <= input_buffer(input_buffer'left-1 downto 0) & uart_rx_FPGA_in.uart_rx;
            uart_rx_data_transmission_is_ready <= false;

            CASE uart_rx_state is
                WHEN wait_for_start_bit =>
                    counter_for_data_bit <= 0;
                    counter_for_number_of_received_bits <= 0;
                    uart_rx_state <= wait_for_start_bit;
                    if input_buffer(input_buffer'left) = '0' then
                        receive_bit_counter <= bit_counter_high;
                        uart_rx_state <= receive_data;
                    end if;

                WHEN receive_data =>
                    counter_for_data_bit <= counter_for_data_bit + input_buffer(input_buffer'left);
                    if receive_bit_counter > 0 then
                        receive_bit_counter <= receive_bit_counter - 1;
                    else 
                        receive_bit_counter <= bit_counter_high;
                        counter_for_number_of_received_bits <= counter_for_number_of_received_bits + 1;

                        if counter_for_number_of_received_bits = total_number_of_transmitted_bits_per_word - 1 then
                            uart_rx_state <= wait_for_start_bit;
                            counter_for_number_of_received_bits <= 0;
                            uart_rx_data_transmission_is_ready <= true;
                            received_data <= receive_register(9 downto 2);
                        else 
                            receive_register <= read_bit_as_1_if_counter_higher_than(bit_counter_high/2-1, counter_for_data_bit) & receive_register(receive_register'left downto 1);
                            counter_for_data_bit <= 0;
                        end if;

                    end if; 
            end CASE;

        end if; --rising_edge
    end process uart_rx_receiver;	

end rtl;
