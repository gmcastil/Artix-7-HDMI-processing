----------------------------------------------------------------------------------
-- Engineer: Charles Steinkuehler <charles@steinkuehler.net>
-- Engineer: Mike Field <hamster@snap.net.nz>
--
-- Module Name: extract_video_infopacket_data - Behavioral
--
-- Description: Extract a couple of fields from the video infopacket, allowin use
--              to correctly convert the incoming pixels into RGB 444 for internal
--              processing.
--
--              Bits 14:13 indicate the colour space and 444 vs 422.
--              Bits 27:26 indicate if the pixels are studio level (16-240)
--              or full range (0-255)
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity extract_video_infopacket_data is
    Port (
        clk                 : in  std_logic;

        -- Data Island Packet Data
        pkt_valid           : in  std_logic;
        pkt_header          : in  std_logic_vector(31 downto 0);
        pkt_subpacket0      : in  std_logic_vector(63 downto 0);
        pkt_subpacket1      : in  std_logic_vector(63 downto 0);
        pkt_subpacket2      : in  std_logic_vector(63 downto 0);
        pkt_subpacket3      : in  std_logic_vector(63 downto 0);

        -- Extracted AVI InfoFrame Details
        input_is_YCbCr      : out std_logic;
        input_is_422        : out std_logic;
        input_is_sRGB       : out std_logic);
end extract_video_infopacket_data;

architecture Behavioral of extract_video_infopacket_data is
begin

process(clk)
    begin
        if rising_edge(clk) then
            if pkt_valid='1' then
                -- AVI InfoFrame Packet
                if pkt_header(7 downto 0) = x"82" then
                    -- Header version 2 or later
                    if unsigned(pkt_header(15 downto 8)) >= 2 then
                        -- Extract Y from packet byte 1
                        case pkt_subpacket0(14 downto 13) is
                            when "00"   => input_is_YCbCr <= '0'; input_is_422 <= '0';
                            when "01"   => input_is_YCbCr <= '1'; input_is_422 <= '1';
                            when "10"   => input_is_YCbCr <= '1'; input_is_422 <= '0';
                            when others => NULL;
                        end case;

                        -- Extract Q from packet byte 3
                        case pkt_subpacket0(27 downto 26) is
                            when "01"   => input_is_sRGB <= '1';
                            when others => input_is_sRGB <= '0';
                        end case;

                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
