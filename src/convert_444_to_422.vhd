----------------------------------------------------------------------------------
-- Engineer: Charles Steinkuehler <charles@steinkuehler.net>
-- Engineer: Mike Field <hamster@snap.net.nz>
--
-- Module Name: convert_444_to_422
--
-- Description: Convert from 444 YCbCr video to 422 YCbCr
--
----------------------------------------------------------------------------------
-- The MIT License (MIT)
--
-- Copyright (c) 2018 Charles Steinkuehler
-- Copyright (c) 2015 Michael Alan Field
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
------------------------------------------------------------------------------------
----- Want to say thanks? ----------------------------------------------------------
------------------------------------------------------------------------------------
--
-- This design has taken many hours - with the industry metric of 30 lines
-- per day, it is equivalent to about 6 months of work. I'm more than happy
-- to share it if you can make use of it. It is released under the MIT license,
-- so you are not under any onus to say thanks, but....
--
-- If you what to say thanks for this design how about trying PayPal?
--  Educational use - Enough for a beer
--  Hobbyist use    - Enough for a pizza
--  Research use    - Enough to take the family out to dinner
--  Commercial use  - A weeks pay for an engineer (I wish!)
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity convert_444_to_422 is
    port (
        clk             : in std_Logic;
        input_is_422    : in std_logic;

        in_blank        : in  std_logic;
        in_hsync        : in  std_logic;
        in_vsync        : in  std_logic;
        in_ch0          : in  unsigned(11 downto 0);   -- Cb or void
        in_ch1          : in  unsigned(11 downto 0);   -- Y
        in_ch2          : in  unsigned(11 downto 0);   -- Cr or CbCr

        out_blank       : out std_logic;
        out_hsync       : out std_logic;
        out_vsync       : out std_logic;
        out_Y           : out unsigned(11 downto 0);
        out_C           : out unsigned(11 downto 0) );
end entity;

architecture Behavioral of convert_444_to_422 is
    subtype sample_t    is unsigned(11 downto 0);
    type    sample_a    is array (natural range<>) of sample_t;

    signal dl_ch0       : sample_a(1 downto 0);
    signal dl_ch1       : sample_a(2 downto 0);
    signal dl_ch2       : sample_a(2 downto 0);

    signal flt_C        : unsigned(12 downto 0);

    -- Delay line for framing signals
    signal blank_q      : std_logic_vector(2 downto 0);
    signal hsync_q      : std_logic_vector(2 downto 0);
    signal vsync_q      : std_logic_vector(2 downto 0);

    signal phase        : std_logic;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            -- Framing signal delay lines
            blank_q <= blank_q(blank_q'left-1 downto 0) & in_blank;
            hsync_q <= hsync_q(hsync_q'left-1 downto 0) & in_hsync;
            vsync_q <= vsync_q(vsync_q'left-1 downto 0) & in_vsync;

            -- Input value delay lines
            dl_ch0(0)   <= in_ch0;
            dl_ch0(1)   <= dl_ch0(0);

            dl_ch1(0)   <= in_ch1;
            dl_ch1(1)   <= dl_ch1(0);
            dl_ch1(2)   <= dl_ch1(1);

            dl_ch2(0)   <= in_ch2;
            dl_ch2(1)   <= dl_ch2(0);
            dl_ch2(2)   <= dl_ch2(1);

            -- Create a signal to toggle between Cb and Cr
            if blank_q(1)='1' then
                phase   <= '0';
            else
                phase   <= not phase;
            end if;

            if input_is_422='1' then
                flt_C   <= dl_ch2(1) & '0';
            elsif phase='0' then
                flt_C   <= resize(dl_ch0(0),13) + resize(dl_ch0(1),13) + 1;
            else
                flt_C   <= resize(dl_ch2(1),13) + resize(dl_ch2(2),13) + 1;
            end if;

        end if;
    end process;

    -- Assign outputs
    out_blank   <= blank_q(2);
    out_hsync   <= hsync_q(2);
    out_vsync   <= vsync_q(2);
    out_Y       <= dl_ch1(2);
    out_C       <= flt_C(flt_C'left downto 1);

end architecture;
