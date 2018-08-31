----------------------------------------------------------------------------------
-- Engineer: Charles Steinkuehler <charles@steinkuehler.net
-- Engineer: Mike Field <hamster@snap.net.nz>
--
-- Module Name: extract_packet - Behavioral
--
-- Description: Extract Data Island Packets from an HDMI stream
--
-- Modified from extract_audio_samples by Charles Steinkuehler in 2018, as the
-- existing packet detection logic did not handle multiple packets in a single
-- Data Island Period, causing the Video InfoFrame packet to not be seen.  Now
-- this logic just extracts all data island packets and leaves it to downstream
-- logic to decide if it's a packet we need to process.
--
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity extract_packet is
    port (
        clk                 : in  std_logic;

        -- Raw input from the HDMI stream
        adp_data_valid      : in  std_logic;
        adp_header_bit      : in  std_logic;
        adp_frame_bit       : in  std_logic;
        adp_subpacket0_bits : in  std_logic_vector(1 downto 0);
        adp_subpacket1_bits : in  std_logic_vector(1 downto 0);
        adp_subpacket2_bits : in  std_logic_vector(1 downto 0);
        adp_subpacket3_bits : in  std_logic_vector(1 downto 0);

        -- Extracted Data Island Packet
        pkt_valid           : out std_logic;
        pkt_header          : out std_logic_vector(31 downto 0);
        pkt_subpacket0      : out std_logic_vector(63 downto 0);
        pkt_subpacket1      : out std_logic_vector(63 downto 0);
        pkt_subpacket2      : out std_logic_vector(63 downto 0);
        pkt_subpacket3      : out std_logic_vector(63 downto 0)
    );
end extract_packet;

architecture behavioral of extract_packet is
    signal header_bits      : std_logic_vector (31 downto 0);
    signal subpacket0_bits  : std_logic_vector (63 downto 0);
    signal subpacket1_bits  : std_logic_vector (63 downto 0);
    signal subpacket2_bits  : std_logic_vector (63 downto 0);
    signal subpacket3_bits  : std_logic_vector (63 downto 0);

    signal valid_q          : std_logic;
    signal count            : unsigned(4 downto 0);

begin

process(clk)
    begin
        if rising_edge(clk) then
            -----------------------------------------------
            -- Move the incoming bits into a shift register
            -----------------------------------------------
            header_bits     <= adp_header_bit      & header_bits(header_bits'high downto 1);
            subpacket0_bits <= adp_subpacket0_bits & subpacket0_bits(subpacket0_bits'high downto 2);
            subpacket1_bits <= adp_subpacket1_bits & subpacket1_bits(subpacket1_bits'high downto 2);
            subpacket2_bits <= adp_subpacket2_bits & subpacket2_bits(subpacket2_bits'high downto 2);
            subpacket3_bits <= adp_subpacket3_bits & subpacket3_bits(subpacket3_bits'high downto 2);

            -- Delay the valid signal to match the delay above
            valid_q <= adp_data_valid;

            -- Track where we are in the current header
            if adp_data_valid='1' then
                if adp_frame_bit='0' then
                    -- Reset the count when we see the framing bit = 0
                    -- at the start of a Data Island Period
                    count   <= to_unsigned(31, count'length);
                else
                    -- Keep a running count...
                    -- Every 32 valid cycles we have a packet
                    count   <= count - 1;
                end if;
            else
                count   <= (others=>'1');
                -- adp_data_valid = 1
            end if;

            -- Once we've accumulated a full packet, send it to the output
            if adp_data_valid='1' and count=0 then
                pkt_valid       <= '1';
                pkt_header      <= header_bits;
                pkt_subpacket0  <= subpacket0_bits;
                pkt_subpacket1  <= subpacket1_bits;
                pkt_subpacket2  <= subpacket2_bits;
                pkt_subpacket3  <= subpacket3_bits;
            else
                pkt_valid       <= '0';
            end if;

        end if;
    end process;

end behavioral;
