-- Generic VHDL model of Xilinx DSP48E1 block
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dsp_mult_add is
    generic (
        A_WIDTH : natural := 25;
        B_WIDTH : natural := 18;
        C_WIDTH : natural := 48;
        P_WIDTH : natural := 48 );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic := '0';
        A       : in  signed ((A_WIDTH-1) downto 0);
        B       : in  signed ((B_WIDTH-1) downto 0);
        C       : in  signed ((C_WIDTH-1) downto 0) := (others=>'0');
        PCIn    : in  signed ((P_WIDTH-1) downto 0) := (others=>'0');
        P       : out signed ((P_WIDTH-1) downto 0) );
end dsp_mult_add;

architecture xilinx of dsp_mult_add is

    signal AREG     : signed ((A_WIDTH-1) downto 0);
    signal BREG     : signed ((B_WIDTH-1) downto 0);
    signal CREG     : signed ((C_WIDTH-1) downto 0);
    signal MREG     : signed ((P_WIDTH-1) downto 0);
    signal PREG     : signed ((P_WIDTH-1) downto 0);

begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                AREG    <= (others=>'0');
                BREG    <= (others=>'0');
                CREG    <= (others=>'0');
                MREG    <= (others=>'0');
                PREG    <= (others=>'0');
            else
                AREG    <= A;
                BREG    <= B;
                CREG    <= C;

                MREG    <= resize(AREG * BREG, MREG'length);
                PREG    <= MREG + PCIn + resize(CREG, PREG'length);
            end if;
        end if;
    end process;

    P <= PREG;

end xilinx;
