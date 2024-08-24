library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package uart_tx_pkg is

    subtype uint12 is integer range 0 to 2**12-1;

    type uart_tx_clock_group is record
        clock : std_logic;
    end record;
    
    type uart_tx_FPGA_output_group is record
        uart_tx : std_logic;
    end record;
    
    type uart_tx_data_input_group is record
        uart_transmit_is_requested : boolean;
        data_to_be_transmitted     : std_logic_vector(7 downto 0);
        number_of_clocks_per_bit   : uint12;
    end record;

    function init_uart_tx ( number_of_clocks_per_bit : integer)
        return uart_tx_data_input_group;
    
    type uart_tx_data_output_group is record
        uart_tx_is_ready : boolean;
    end record;
    
------------------------------------------------------------------------
    procedure set_number_of_clocks_per_bit (
        signal uart_tx_data_in : out uart_tx_data_input_group;
        set_number_of_clocks_per_bit_to : integer range 0 to 2**12-1);
------------------------------------------------------------------------
    procedure init_uart (
        signal uart_tx_input : out uart_tx_data_input_group);

    procedure init_uart (
        signal uart_tx_input : out uart_tx_data_input_group;
        number_of_clocks_per_bit : uint12);
------------------------------------------------------------------------
    procedure transmit_8bit_data_package (
        signal uart_tx_input : out uart_tx_data_input_group;
        transmitted_data : std_logic_vector(7 downto 0));
------------------------------------------------------------------------
    function uart_tx_is_ready ( uart_tx_output : uart_tx_data_output_group)
        return boolean;
------------------------------------------------------------------------
    

end package uart_tx_pkg; 

package body uart_tx_pkg is

    function init_uart_tx
    (
        number_of_clocks_per_bit : integer
    )
    return uart_tx_data_input_group
    is
        variable return_value : uart_tx_data_input_group;
    begin
        return_value := (
            uart_transmit_is_requested => false,
            data_to_be_transmitted     => (others => '0'),
            number_of_clocks_per_bit   => number_of_clocks_per_bit);

        return return_value;
        
    end init_uart_tx;

------------------------------------------------------------------------
    procedure set_number_of_clocks_per_bit
    (
        signal uart_tx_data_in : out uart_tx_data_input_group;
        set_number_of_clocks_per_bit_to : integer range 0 to 2**12-1
    ) is
    begin
        uart_tx_data_in.number_of_clocks_per_bit <= set_number_of_clocks_per_bit_to;
    end set_number_of_clocks_per_bit;
------------------------------------------------------------------------
    procedure init_uart
    (
        signal uart_tx_input : out uart_tx_data_input_group
    ) is
    begin
        uart_tx_input.uart_transmit_is_requested <= false;
    end init_uart;
--------
    procedure init_uart
    (
        signal uart_tx_input : out uart_tx_data_input_group;
        number_of_clocks_per_bit : uint12
    ) is
    begin
        uart_tx_input.uart_transmit_is_requested <= false;
        uart_tx_input.number_of_clocks_per_bit <= number_of_clocks_per_bit;
    end init_uart;


------------------------------------------------------------------------
    procedure transmit_8bit_data_package
    (
        signal uart_tx_input : out uart_tx_data_input_group;
        transmitted_data : std_logic_vector(7 downto 0)
    ) is
    begin

        uart_tx_input.uart_transmit_is_requested <= true;
        uart_tx_input.data_to_be_transmitted <= transmitted_data; 
        
    end transmit_8bit_data_package;

------------------------------------------------------------------------
    function uart_tx_is_ready
    (
        uart_tx_output : uart_tx_data_output_group
    )
    return boolean
    is
    begin
        return uart_tx_output.uart_tx_is_ready;
    end uart_tx_is_ready;
------------------------------------------------------------------------
------------------------------------------------------------------------
end package body uart_tx_pkg; 
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.uart_tx_pkg.all; 

entity uart_tx is
    port (
        clock : in std_logic;
        uart_tx_FPGA_out : out uart_tx_FPGA_output_group;
        uart_tx_data_in  : in uart_tx_data_input_group;
        uart_tx_data_out : out uart_tx_data_output_group
    );
end entity;

architecture rtl of uart_tx is

    alias clock_in_uart_bit is uart_tx_data_in.number_of_clocks_per_bit;
    constant total_number_of_transmitted_bits_per_word : natural := 10;
    signal transmit_register : std_logic_vector(9 downto 0) := (others => '1');
    signal transmit_bit_counter : natural range 0 to 2047;
    signal transmit_data_bit_counter : natural range 0 to 15; 

    type list_of_uart_transmitter_states is (wait_for_transmit_request, transmit);
    signal uart_transmitter_state : list_of_uart_transmitter_states := wait_for_transmit_request;

begin

    uart_tx_FPGA_out <= (uart_tx => transmit_register(transmit_register'right));

------------------------------------------------------------------------
    uart_transmitter : process(clock)

        --------------------------------------------------
        procedure shift_and_register
        (
            signal shift_register : inout std_logic_vector
        ) is
        begin
            shift_register <= '1' & shift_register(shift_register'left downto 1);
        end shift_and_register; 

        --------------------------------------------------
        procedure load_data_with_start_and_stop_bits_to
        (
            signal transmitter_register : out std_logic_vector;
            data_to_be_transmitted : in std_logic_vector
        ) is
        begin

            transmitter_register <= '1' & data_to_be_transmitted & '0';

        end load_data_with_start_and_stop_bits_to;

        --------------------------------------------------


    begin
        if rising_edge(clock) then

            uart_tx_data_out.uart_tx_is_ready <= false;
            CASE uart_transmitter_state is

                WHEN wait_for_transmit_request =>
                    uart_transmitter_state <= wait_for_transmit_request;

                    transmit_data_bit_counter <= 0;

                    if uart_tx_data_in.uart_transmit_is_requested then
                        load_data_with_start_and_stop_bits_to(transmit_register, uart_tx_data_in.data_to_be_transmitted);
                        uart_transmitter_state <= transmit; 
                        transmit_bit_counter <= clock_in_uart_bit - 1;
                    end if;

                WHEN transmit =>
                    uart_transmitter_state <= transmit;

                    if transmit_bit_counter /= 0 then
                        transmit_bit_counter <= transmit_bit_counter - 1;
                    else
                        transmit_data_bit_counter <= transmit_data_bit_counter + 1;
                        transmit_bit_counter <= clock_in_uart_bit - 1;
                        shift_and_register(transmit_register); 
                        if transmit_data_bit_counter = transmit_register'high then
                            uart_transmitter_state <= wait_for_transmit_request;
                            uart_tx_data_out.uart_tx_is_ready <= true;
                        end if;
                    end if; 

            end CASE; 

        end if; --rising_edge
    end process uart_transmitter;	

------------------------------------------------------------------------
end rtl; 
