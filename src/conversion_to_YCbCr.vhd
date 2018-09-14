----------------------------------------------------------------------------------
-- Engineer: Charles Steinkuehler <charles@steinkuehler.net>
-- Engineer: Mike Field <hamster@snap.net.nz>
--
-- Module Name: conversion_to_YCbCr - Behavioral
--
-- Description: Convert from RGB, studio level RGB or YCbCr to YCbCr
--
-- Designed to efficiently use Xilinx DSP blocks and have the same latency
-- regardless of the conversion being performed.
----------------------------------------------------------------------------------
-- HD Colorspace from SMPTE 274M / ITU-R BT.709:
--
-- Y  = 0.2126*R + 0.7152*G + 0.0722*B + 16
-- Cb = (0.5 / (1 - 0.0722))*(B - Y)
-- Cr = (0.5 / (1 - 0.2126))*(R - Y)
--
-- Conversion from full range RGB to YCbCr:
--
-- Y  = (219 / 256) * ( 0.2126*R + 0.7152*G + 0.0722*B) + 16
-- Cb = (224 / 256) * (-0.1146*R - 0.3854*G + 0.5000*B) + 128
-- Cr = (224 / 256) * ( 0.5000*R - 0.4542*G - 0.0458*B) + 128
--
-- Y  = ( 0.1819*R + 0.6118*G + 0.0618*B) + 16
-- Cb = (-0.1003*R - 0.3372*G + 0.4375*B) + 128
-- Cr = ( 0.4375*R - 0.3974*G - 0.0401*B) + 128
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity conversion_to_YCbCr is
    port (
        clk             : in std_Logic;
        input_is_YCbCr  : in std_Logic;
        input_is_sRGB   : in std_Logic;

        ------------------------
        in_blank        : in  std_logic;
        in_hsync        : in  std_logic;
        in_vsync        : in  std_logic;
        in_ch0          : in  unsigned(11 downto 0);   -- B or Cb
        in_ch1          : in  unsigned(11 downto 0);   -- G or Y
        in_ch2          : in  unsigned(11 downto 0);   -- R or Cr

        ------------------------
        out_blank       : out std_logic;
        out_hsync       : out std_logic;
        out_vsync       : out std_logic;
        out_ch0         : out unsigned(11 downto 0);
        out_ch1         : out unsigned(11 downto 0);
        out_ch2         : out unsigned(11 downto 0) );
end entity;

architecture Behavioral of conversion_to_YCbCr is
    subtype coef_t      is signed(15 downto 0);
    type    coef_set    is array (2 downto 0) of coef_t;
    type    coef_matrix is array (2 downto 0) of coef_set;

    subtype prod_t      is signed(47 downto 0);
    type    prod_set    is array (2 downto -1) of prod_t;
    type    prod_matrix is array (2 downto 0) of prod_set;

    subtype dcfx_t      is signed(47 downto 0);
    type    dcfx_set    is array (2 downto 0) of dcfx_t;
    type    dcfx_matrix is array (2 downto 0) of dcfx_set;

    signal coefficients : coef_matrix;
    signal p            : prod_matrix;
    signal dc_fix       : dcfx_matrix;

    constant coef_identity : coef_matrix := (
        --     0 => Blue     1 => Green    2 => Red
        0 => ( 0 => x"4000", 1 => x"0000", 2 => x"0000"),   -- Cb
        1 => ( 0 => x"0000", 1 => x"4000", 2 => x"0000"),   -- Y
        2 => ( 0 => x"0000", 1 => x"0000", 2 => x"4000") ); -- Cr

    constant dc_identity : dcfx_matrix := (
        0 => ( 0 => x"000000000000", 1 => x"000000000000", 2 => x"000000000000"),
        1 => ( 0 => x"000000000000", 1 => x"000000000000", 2 => x"000000000000"),
        2 => ( 0 => x"000000000000", 1 => x"000000000000", 2 => x"000000000000") );


    constant coef_RGB2YCbCr : coef_matrix := (
        --     0 => Blue     1 => Green    2 => Red
        0 => ( 0 => x"1C00", 1 => x"EA6B", 2 => x"F995"),   -- Cb
        1 => ( 0 => x"03F5", 1 => x"2728", 2 => x"0BA4"),   -- Y
        2 => ( 0 => x"FD6F", 1 => x"E7B8", 2 => x"1C00") ); -- Cr

    constant dc_RGB2YCbCr : dcfx_matrix := (
        0 => ( 0 => x"000000000000", 1 => x"000000000000", 2 => x"000002002000"),
        1 => ( 0 => x"000000000000", 1 => x"000000000000", 2 => x"000000402000"),
        2 => ( 0 => x"000000000000", 1 => x"000000000000", 2 => x"000002002000") );


    -- FIXME!!
    constant coef_sRGB2YCbCr : coef_matrix := (
        --     0 => Blue     1 => Green    2 => Red
        0 => ( 0 => x"1C00", 1 => x"EA6B", 2 => x"F995"),   -- Cb
        1 => ( 0 => x"03F5", 1 => x"2728", 2 => x"0BA4"),   -- Y
        2 => ( 0 => x"FD6F", 1 => x"E7B8", 2 => x"1C00") ); -- Cr

    constant dc_sRGB2YCbCr : dcfx_matrix := (
        0 => ( 0 => x"000000000000", 1 => x"000000000000", 2 => x"000002002000"),
        1 => ( 0 => x"000000000000", 1 => x"000000000000", 2 => x"000000402000"),
        2 => ( 0 => x"000000000000", 1 => x"000000000000", 2 => x"000002002000") );


    subtype sample_t    is signed(13 downto 0);
    type    sample_a    is array (natural range<>) of sample_t;

    signal dl_ch1       : sample_a(0 downto 0);
    signal dl_ch2       : sample_a(1 downto 0);
    signal VidIn        : sample_a(2 downto 0);

    -- Min/Max values for clamping the output
    constant csc_min    : sample_t := b"00000000010000";
    constant csc_max    : sample_t := b"00111111100000";

    signal csc_out      : sample_a(2 downto 0);
    signal csc_clamp    : sample_a(2 downto 0);

    -- Delay line for framing signals
    signal blank_q      : std_logic_vector(7 downto 0);
    signal hsync_q      : std_logic_vector(7 downto 0);
    signal vsync_q      : std_logic_vector(7 downto 0);

begin

    process(clk)
    begin
        if rising_edge(clk) then
            -- Delay input values to match multiplier waterfall
            dl_ch1(0)  <= signed(resize(in_ch1, sample_t'length));
            dl_ch2(0)  <= signed(resize(in_ch2, sample_t'length));
            dl_ch2(1)  <= dl_ch2(0);

            VidIn(0)   <= signed(resize(in_ch0, sample_t'length));
            VidIn(1)   <= dl_ch1(0);
            VidIn(2)   <= dl_ch2(1);

            -- Select coefficients
            if input_is_YCbCr='1' then
                coefficients    <= coef_identity;
                dc_fix          <= dc_identity;
            elsif input_is_sRGB='1' then
                coefficients    <= coef_sRGB2YCbCr;
                dc_fix          <= dc_sRGB2YCbCr;
            else
                coefficients    <= coef_RGB2YCbCr;
                dc_fix          <= dc_RGB2YCbCr;
            end if;
        end if;
    end process;


    row : for y in 0 to 2 generate
    begin
        -- Zero the adder chain input for the first multiplier
        p(y)(-1)  <= (others=>'0');

        col : for x in 0 to 2 generate
        begin
            -- Instantiate one multiplier of the 3x3 matrix
            mul : entity work.dsp_mult_add
            generic map (
                A_WIDTH => 14,
                B_WIDTH => 16,
                C_WIDTH => 48,
                P_WIDTH => 48 )
            port map (
                clk     => clk,
                A       => VidIn(x),
                B       => coefficients(y)(x),
                C       => dc_fix(y)(x),
                PCIn    => p(y)(x - 1),
                P       => p(y)(x) );
        end generate;

        process(clk)
        begin
            if rising_edge(clk) then
                -- Register final csc multiplier output
                csc_out(y)  <= p(y)(2)(27 downto 14);

                -- Don't clamp if we're not doing a color space conversion
                if input_is_YCbCr='1' then
                    csc_clamp(y)    <= csc_out(y);
                -- Negative overflow
                elsif csc_out(y)(csc_out(y)'left)='1' then
                    csc_clamp(y)    <= csc_min;
                -- Positive overflow
                elsif csc_out(y)(csc_out(y)'left-1)='1' then
                    csc_clamp(y)    <= csc_max;
                else
                    csc_clamp(y)    <= csc_out(y);
                end if;

            end if;
        end process;
    end generate;

    process(clk)
    begin
        if rising_edge(clk) then
            blank_q <= in_blank & blank_q(blank_q'left downto 1);
            hsync_q <= in_hsync & hsync_q(hsync_q'left downto 1);
            vsync_q <= in_vsync & vsync_q(vsync_q'left downto 1);

        end if;
    end process;

    out_blank   <= blank_q(0);
    out_hsync   <= hsync_q(0);
    out_vsync   <= vsync_q(0);
    out_ch0     <= unsigned(csc_clamp(0)(out_ch0'range));
    out_ch1     <= unsigned(csc_clamp(1)(out_ch1'range));
    out_ch2     <= unsigned(csc_clamp(2)(out_ch2'range));


end architecture;
