----------------------------------------------------------------------------------
-- Engineer: Charles Steinkuehler <charles@steinkuehler.net>
-- Engineer: Mike Field <hamster@snap.net.nz>
--
-- Module Name: extract_audio_samples - Behavioral
--
-- Description: Extract audio data from the HDMI ADP data stream
--
-- Modified by Charles Steinkuehler to work with long strings of packets in a
-- single Data Island Period
------------------------------------------------------------------------------------
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

entity extract_audio_samples is
    Port (
        clk                 : in std_logic;

        -- Data Island Packet Data
        pkt_valid           : in  std_logic;
        pkt_header          : in  std_logic_vector(31 downto 0);
        pkt_subpacket0      : in  std_logic_vector(63 downto 0);
        pkt_subpacket1      : in  std_logic_vector(63 downto 0);
        pkt_subpacket2      : in  std_logic_vector(63 downto 0);
        pkt_subpacket3      : in  std_logic_vector(63 downto 0);

        -- Extracted Audio Data
        audio_de            : out std_logic;
        audio_channel       : out std_logic_vector (2 downto 0);
        audio_sample        : out std_logic_vector (23 downto 0)
    );
end extract_audio_samples;

architecture Behavioral of extract_audio_samples is

    signal grab_other_channel   : std_logic := '0';

begin

process(clk)
    begin
        if rising_edge(clk) then
            audio_de    <= '0';

            if pkt_valid='1' then
                -- Audio Sample Packet
                if pkt_header(7 downto 0) = x"02" then
                    audio_de            <= pkt_header(8);
                    audio_channel       <= "000";
                    audio_sample        <= pkt_subpacket0(23 downto 0);
                    grab_other_channel  <= '1';
                end if;
            end if;

            if grab_other_channel = '1' then
                audio_de           <= pkt_header(8);
                audio_channel      <= "001";
                audio_sample       <= pkt_subpacket0(47 downto 24);
                grab_other_channel <= '0';
            end if;
        end if;
    end process;

end Behavioral;
