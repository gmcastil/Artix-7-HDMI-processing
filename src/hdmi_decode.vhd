----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
-- Engineer: George Castillo <gcastillo@newtek.com>
--
-- Module Name: hdmi_decode
--
-- Description: Heavily based on the `hdmi_io` module, but with the low level logic
-- removed to allow use with a different PHY
--
------------------------------------------------------------------------------------
-- The MIT License (MIT)
--
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
use ieee.numeric_std;

use work.type_hdmi.all;

entity hdmi_decode is
    port (
        -- Aligned 10-bit TMDS characters from an HDMI source and
        -- corresponding pixel clock recovered by a PHY
        hdmi_rx_clk             : in    std_logic;
        hdmi_rx_ch0             : in    std_logic_vector(9 downto 0);
        hdmi_rx_ch1             : in    std_logic_vector(9 downto 0);
        hdmi_rx_ch2             : in    std_logic_vector(9 downto 0);
        -- Raw data signals
        raw_blank               : out   std_logic;
        raw_hsync               : out   std_logic;
        raw_vsync               : out   std_logic;
        raw_ch0                 : out   std_logic_vector(7 downto 0);
        raw_ch1                 : out   std_logic_vector(7 downto 0);
        raw_ch2                 : out   std_logic_vector(7 downto 0);
        -- Debug and status signals
        hdmi_rx_detected        : out   std_logic;
        -- ADP data
        adp_data_valid          : out   std_logic;
        adp_header_bit          : out   std_logic;
        adp_frame_bit           : out   std_logic;
        adp_subpacket0_bits     : out   std_logic_vector(1 downto 0);
        adp_subpacket1_bits     : out   std_logic_vector(1 downto 0);
        adp_subpacket2_bits     : out   std_logic_vector(1 downto 0);
        adp_subpacket3_bits     : out   std_logic_vector(1 downto 0)
    );
end hdmi_decode;

architecture arch of hdmi_decode is

    -- Signals driven by the TMDS symbol decode logic (x3)
    signal ch0_invalid_symbol           : std_logic;
    signal ch0_ctl_valid                : std_logic;
    signal ch0_ctl                      : std_logic_vector (1 downto 0);
    signal ch0_terc4_valid              : std_logic;
    signal ch0_terc4                    : std_logic_vector (3 downto 0);
    signal ch0_guardband_valid          : std_logic;
    signal ch0_guardband                : std_logic_vector (0 downto 0);
    signal ch0_data_valid               : std_logic;
    signal ch0_data                     : std_logic_vector (7 downto 0);

    signal ch1_invalid_symbol           : std_logic;
    signal ch1_ctl_valid                : std_logic;
    signal ch1_ctl                      : std_logic_vector (1 downto 0);
    signal ch1_terc4_valid              : std_logic;
    signal ch1_terc4                    : std_logic_vector (3 downto 0);
    signal ch1_guardband_valid          : std_logic;
    signal ch1_guardband                : std_logic_vector (0 downto 0);
    signal ch1_data_valid               : std_logic;
    signal ch1_data                     : std_logic_vector (7 downto 0);

    signal ch2_invalid_symbol           : std_logic;
    signal ch2_ctl_valid                : std_logic;
    signal ch2_ctl                      : std_logic_vector (1 downto 0);
    signal ch2_terc4_valid              : std_logic;
    signal ch2_terc4                    : std_logic_vector (3 downto 0);
    signal ch2_guardband_valid          : std_logic;
    signal ch2_guardband                : std_logic_vector (0 downto 0);
    signal ch2_data_valid               : std_logic;
    signal ch2_data                     : std_logic_vector (7 downto 0);

    -- Flags for indicating which HDMI period we are currently in (nomenclature somewhat
    -- misleading so beware)
    signal in_vdp                       : std_logic;
    signal in_adp                       : std_logic;
    signal in_dvid                      : std_logic;
    signal last_was_ctl                 : std_logic;
    signal dvid_mode                    : std_logic;

    signal vdp_prefix_detect            : std_logic_vector(7 downto 0);
    signal vdp_guardband_detect         : std_logic;
    signal vdp_prefix_seen              : std_logic;
    signal adp_prefix_detect            : std_logic_vector(7 downto 0);
    signal adp_guardband_detect         : std_logic;
    signal adp_prefix_seen              : std_logic;

begin

    ch0 : entity work.tmds_decoder
    port map (
        clk                 => hdmi_rx_clk,         -- in  std_logic
        symbol              => hdmi_rx_ch0,         -- in  std_logic_vector (9 downto 0)
        invalid_symbol      => ch0_invalid_symbol,  -- out std_logic
        ctl_valid           => ch0_ctl_valid,       -- out std_logic
        ctl                 => ch0_ctl,             -- out std_logic_vector (1 downto 0)
        terc4_valid         => ch0_terc4_valid,     -- out std_logic
        terc4               => ch0_terc4,           -- out std_logic_vector (3 downto 0)
        guardband_valid     => ch0_guardband_valid, -- out std_logic
        guardband           => ch0_guardband,       -- out std_logic_vector (0 downto 0)
        data_valid          => ch0_data_valid,      -- out std_logic
        data                => ch0_data             -- out std_logic_vector (7 downto 0)
    );

    ch1 : entity work.tmds_decoder
    port map (
        clk                 => hdmi_rx_clk,         -- in  std_logic
        symbol              => hdmi_rx_ch1,         -- in  std_logic_vector (9 downto 0)
        invalid_symbol      => ch1_invalid_symbol,  -- out std_logic
        ctl_valid           => ch1_ctl_valid,       -- out std_logic
        ctl                 => ch1_ctl,             -- out std_logic_vector (1 downto 0)
        terc4_valid         => ch1_terc4_valid,     -- out std_logic
        terc4               => ch1_terc4,           -- out std_logic_vector (3 downto 0)
        guardband_valid     => ch1_guardband_valid, -- out std_logic
        guardband           => ch1_guardband,       -- out std_logic_vector (0 downto 0)
        data_valid          => ch1_data_valid,      -- out std_logic
        data                => ch1_data             -- out std_logic_vector (7 downto 0)
    );

    ch2 : entity work.tmds_decoder
    port map (
        clk                 => hdmi_rx_clk,         -- in  std_logic
        symbol              => hdmi_rx_ch2,         -- in  std_logic_vector (9 downto 0)
        invalid_symbol      => ch2_invalid_symbol,  -- out std_logic
        ctl_valid           => ch2_ctl_valid,       -- out std_logic
        ctl                 => ch2_ctl,             -- out std_logic_vector (1 downto 0)
        terc4_valid         => ch2_terc4_valid,     -- out std_logic
        terc4               => ch2_terc4,           -- out std_logic_vector (3 downto 0)
        guardband_valid     => ch2_guardband_valid, -- out std_logic
        guardband           => ch2_guardband,       -- out std_logic_vector (0 downto 0)
        data_valid          => ch2_data_valid,      -- out std_logic
        data                => ch2_data             -- out std_logic_vector (7 downto 0)
    );

    -- HDMI period decoding logic is leveraged heavily from the Hamsterworks HDMI core
    -- (e.g., data island vs. control vs video data period) and basically processing the
    -- output of the three TMDS decoders
    hdmi_period_decode: process(hdmi_rx_clk)
    begin
        if rising_edge(hdmi_rx_clk) then
            -- Output the values depending on what sort of data block we are in
            if ch0_ctl_valid = '1' and ch1_ctl_valid = '1' and ch2_ctl_valid = '1' then
                -- As soon as we see avalid CTL symbols we are no longer in the
                -- video or aux data period it doesn't have any trailing guard band
                in_vdp                  <= '0';
                in_adp                  <= '0';
                in_dvid                 <= '0';
                raw_vsync               <= ch0_ctl(1);
                raw_hsync               <= ch0_ctl(0);
                raw_blank               <= '1';
                raw_ch0                 <= (others => '0');
                raw_ch1                 <= (others => '0');
                raw_ch2                 <= (others => '0');
                last_was_ctl            <= '1';
                adp_data_valid          <= '0';
            else
                last_was_ctl            <= '0';
                adp_data_valid          <= '0';
                if in_vdp = '1' then
                    raw_vsync           <= '0';
                    raw_hsync           <= '0';
                    raw_blank           <= '0';
                    raw_ch0             <= ch0_data;
                    raw_ch1             <= ch1_data;
                    raw_ch2             <= ch2_data;
                    if ch2_invalid_symbol = '1' or ch2_invalid_symbol = '1' or ch2_invalid_symbol = '1' then
                        -- TODO These are likely intended to be visual cues that a symbol
                        -- was received in error and should be modified to be different constants
                        -- based upon the color mode
                        raw_ch0         <= x"16";
                        raw_ch1         <= x"16";
                        raw_ch2         <= x"EF";
                    end if;
                elsif in_dvid = '1' then
                    -- In the Video data period
                    raw_vsync           <= '0';
                    raw_hsync           <= '0';
                    raw_blank           <= '0';
                    raw_ch0             <= ch0_data;
                    raw_ch1             <= ch1_data;
                    raw_ch2             <= ch2_data;
                elsif in_adp = '1' then
                    -- In the Aux Data Period Period
                    raw_vsync           <= ch0_terc4(1);
                    raw_hsync           <= ch0_terc4(0);
                    raw_blank           <= '1';
                    raw_ch0             <= (others => '0');
                    raw_ch1             <= (others => '0');
                    raw_ch2             <= (others => '0');
                    -- ADP data extraction
                    adp_data_valid      <= '1';
                    adp_header_bit      <= ch0_terc4(2);
                    adp_frame_bit       <= ch0_terc4(3);
                    adp_subpacket0_bits <= ch2_terc4(0) & ch1_terc4(0);
                    adp_subpacket1_bits <= ch2_terc4(1) & ch1_terc4(1);
                    adp_subpacket2_bits <= ch2_terc4(2) & ch1_terc4(2);
                    adp_subpacket3_bits <= ch2_terc4(3) & ch1_terc4(3);
                end if;
            end if;

            -- These next two sections of logic are looking for the video data or data
            -- island preambles as described in the spec, but with some naming that can be
            -- confusing. For posterity, we have the following control signal mappings
            -- in this RTL:
            --
            --   ch0_ctl(1 downto 0) == VSYNC  & HSYNC
            --   ch1_ctl(1 downto 0) ==  CTL0  &  CTL1
            --   ch2_ctl(1 downto 0) ==  CTL2  &  CTL3
            --
            -- The preamble for each section is, per the specification
            --
            -- CTL0     CTL1    CTL2    CTL3    Period type
            -- ----     ----    ----    ----    ------------------
            --  1        0       0       0      Video data period
            --  1        0       1       0      Data island period
            --
            -- This explains what appear to be odd magical patterns that are being
            -- checked for. See section 5.2.1.1 from HDMI spec 1.4b for more details.

            ------------------------------------------------------------
            -- We need to detect 8 ADP or VDP prefix characters in a row
            ------------------------------------------------------------
            vdp_prefix_detect               <= vdp_prefix_detect(6 downto 0) & '0';
            vdp_prefix_seen                 <= '0';
            if ch0_ctl_valid = '1' and ch1_ctl_valid = '1' and ch2_ctl_valid = '1' then
                if ch1_ctl = "01" and ch2_ctl = "00" then
                    vdp_prefix_detect(0)    <=  '1';
                    if vdp_prefix_detect(6 downto 0) = "1111111" then
                        vdp_prefix_seen     <= '1';
                    end if;
                end if;
            end if;

            ---------------------------------------------
            -- Watch for the Data Island Preamble
            ---------------------------------------------
            adp_prefix_detect               <= adp_prefix_detect(6 downto 0) & '0';
            adp_prefix_seen                 <= '0';
            if ch0_ctl_valid = '1' and ch1_ctl_valid = '1' and ch2_ctl_valid = '1' then
                if ch1_ctl = "01" and ch2_ctl = "01" then
                    adp_prefix_detect(0)    <= '1';
                    if adp_prefix_detect(6 downto 0) = "1111111" then
                        adp_prefix_seen     <= '1';
                    end if;
                end if;
            end if;

            ---------------------------------------------
            -- See if we can detect the ADP guardband
            --
            -- The ADP guardband includes HSYNC and VSYNC
            -- encoded in TERC4 coded in Ch0 - annoying!
            ---------------------------------------------
            adp_guardband_detect            <= '0';
            if in_vdp = '0' and ch0_terc4_valid = '1' and ch1_guardband_valid = '1' and ch2_guardband_valid = '1' then
                if ch0_terc4(3 downto 2) = "11" and ch1_guardband = "0" and ch2_guardband = "0" then
                    adp_guardband_detect    <= adp_prefix_seen;
                    in_adp                  <= adp_guardband_detect AND (not in_adp) and (not in_vdp);
                end if;
            end if;

            -----------------------------------------
            -- See if we can detect the VDP guardband
            -- This is pretty nices as the guard
            -----------------------------------------
            vdp_guardband_detect            <= '0';
            if ch0_guardband_valid = '1' and ch1_guardband_valid = '1' and ch2_guardband_valid = '1' then
                -- TERC Coded for the VDP guard band.
                if ch0_guardband = "1" and ch1_guardband = "0" and ch2_guardband = "1" then
                   vdp_guardband_detect     <= vdp_prefix_seen;
                   in_vdp                   <= vdp_guardband_detect AND (not in_adp) and (not in_vdp);
                   dvid_mode                <= '0';
                end if;
            end if;

            --------------------------------
            -- Is this some DVID video data?
            --------------------------------
            if dvid_mode = '1' and last_was_ctl = '1' and ch0_data_valid = '1' and ch1_data_valid = '1' and ch2_data_valid = '1' then
                in_dvid                     <= '1';
            end if;
            -------------------------------------------------------------
            -- Is this an un-announced video data? If so we receiving
            -- DVI-D data, and not HDMI
            -------------------------------------------------------------
            if ch0_data_valid = '1' and ch1_data_valid = '1' and ch2_data_valid = '1' and last_was_ctl = '1' and vdp_prefix_seen = '0' and adp_prefix_seen = '0' then
               dvid_mode                    <= '1';
            end if;
        end if;
    end process;

    -- Crudely determine that we are seeing HDMI traffic by just inverting the
    -- DVID detection logic (in this case, "not DVID" == HDMI)
    hdmi_rx_detected                <= not dvid_mode;

end arch;

