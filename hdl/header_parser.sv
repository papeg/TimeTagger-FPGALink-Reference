/**
 * AXI4-Stream Time Tag Packet Header Parser.
 *
 * This file is part of the Time Tagger software defined digital data
 * acquisition FPGA-link reference design.
 *
 * Copyright (C) 2022-2023 Swabian Instruments, All Rights Reserved
 *
 * Authors:
 * - 2022-2023 David Sawatzke <david@swabianinstruments.com>
 * - 2024 Ehsan Jokar <ehsan@swabianinstruments.com>
 *
 * This file is provided under the terms and conditions of the BSD 3-Clause
 * license, accessible under https://opensource.org/licenses/BSD-3-Clause.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

// verilog_format: off
 `resetall
 `timescale 1ns / 1ps
 `default_nettype none
// verilog_format: on

// This module drops invalid packets & detects lost packets (which results in lost tags)
module si_header_parser (

    axis_interface.slave  s_axis,
    axis_interface.master m_axis,

    // Status signals
    // Is high when a packet is lost
    output reg lost_packet,

    // If a packet isn't recognized, this flag is active while the packet is received
    // This is expected to happen if anything other than a timetagger is
    // attached, e.g. ARP packets by a PC
    // If invalid, The packet is dropped by this module
    // NOTE: The timing doesn't quite match up to only the packet received, only use this as a debugging signal
    output wire invalid_packet
);
    initial begin
        // Some sanity checks:

        // - ensure that the data-width is 128 bits, this is the only width supported by this module
        if (s_axis.DATA_WIDTH != 128) begin
            $error("Error: data-width needs to be 128 bits");
            $finish;
        end
    end

    assign m_axis.tdata = s_axis.tdata;
    assign m_axis.tkeep = s_axis.tkeep;
    assign m_axis.tlast = s_axis.tlast;

    reg [1:0] packet_word_counter;  // Count the first few words of the header

    reg valid_header;
    // Save state of valid_header here to determine what to do with the rest of the packet
    reg valid_packet;

    // Next sequence counter
    reg [31:0] next_sequence;
    assign invalid_packet = (~valid_packet) | (~valid_header);

    always @(posedge s_axis.clk) begin
        if (s_axis.rst) begin
            packet_word_counter <= 0;
            valid_packet <= 1;
            lost_packet <= 0;
            next_sequence <= 0;
        end else if (packet_word_counter != 0) begin
            lost_packet <= 0;
            if (s_axis.tvalid && s_axis.tready) begin
                if ((packet_word_counter == 1) && valid_header) begin
                    next_sequence <= s_axis.tdata[8*8+:4*8] + 1;

                    if ((next_sequence != s_axis.tdata[8*8+:4*8]) && (next_sequence != 0)) begin
                        lost_packet <= 1;
                    end

                    valid_packet <= valid_header;
                end
                if (packet_word_counter < 2) begin
                    packet_word_counter <= packet_word_counter + 1;
                end
                if (s_axis.tlast) begin
                    packet_word_counter <= 0;
                    valid_packet <= 1;
                end
            end
        end else begin
            if (s_axis.tvalid && s_axis.tready && ~s_axis.tlast) begin
                packet_word_counter <= 1;
                valid_packet <= valid_header;
            end
        end
    end

    always @(*) begin
        if (packet_word_counter == 2) begin
            if (valid_packet == 1) begin
                m_axis.tvalid = s_axis.tvalid;
                s_axis.tready = m_axis.tready;
            end else begin
                s_axis.tready = 1;
                m_axis.tvalid = 0;
            end
            // This only matters for the invalid_packet output in this state
            valid_header = 1;
        end else begin
            if (s_axis.tvalid) begin
                // Check if header is valid
                if ((packet_word_counter == 0) && (s_axis.tkeep == 16'hFFFF) && (s_axis.tdata[12*8+:4*8] == {
                    // Byte 14 - 15: MAGIC SEQUENCE ASCII "SI"
                    16'h4953,
                    // Byte 12 - 13: Ethertype (0x80FB: AppleTalk)
                    16'h9B80})) begin

                    // This is a valid packet, so pass it through
                    m_axis.tvalid = s_axis.tvalid;
                    s_axis.tready = m_axis.tready;

                    valid_header  = 1;
                end else if ((packet_word_counter == 1) && valid_packet && (s_axis.tkeep == 16'hFFFF) &&
                (s_axis.tdata[0 * 8 +: 4 * 8] ==
                 {
                    // Byte 19: Type
                    8'h00,
                    // Byte 18: Version
                    8'h00,
                    // Byte 16 - 17: MAGIC SEQUENCE ASCII "TT"
                    16'h5454})) begin
                    // This is still a valid packet, so continue to pass it through
                    m_axis.tvalid = s_axis.tvalid;
                    s_axis.tready = m_axis.tready;

                    valid_header  = 1;
                end else begin
                    // Otherwise ... don't
                    s_axis.tready = 1;
                    m_axis.tvalid = 0;
                    valid_header  = 0;
                end
            end else begin
                s_axis.tready = m_axis.tready;
                // Do *not* set tvalid here, otherwise the data is not allowed to change anymore
                m_axis.tvalid = 0;
                // This only matters for the invalid_packet output in this state
                valid_header  = 1;
            end
        end
    end
endmodule  // si_header_parser
`resetall
