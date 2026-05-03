#!/usr/bin/env python3

# Python script to generate a memory initialization file (MIF) of specified
# audio data for a single note for use in Quartus and the DE1-SoC audio codec
# for UW EE/CSE371.
#
# Written by Justin Hsia, Cole Van Pelt (20au, 21wi)
#
# Update 23sp: Changed the way tone mif calculations are done to get a matching note tone
# from Labsland FPGA output. Instead of a continuous wave, the waves will repeat every
# 3.63 wavelengths until 48000 samples are reached.

import argparse
import math
import re

# note frequencies (Hz) - https://pages.mtu.edu/~suits/notefreqs.html
#       octave: 0      1      2       3       4       5       6        7        8
notes = {'B#': [16.35, 32.7,  65.41,  130.81, 261.63, 523.25, 1046.5,  2093.0,  4186.01],
         'C':  [16.35, 32.7,  65.41,  130.81, 261.63, 523.25, 1046.5,  2093.0,  4186.01],
         'C#': [17.32, 34.65, 69.3,   138.59, 277.18, 554.37, 1108.73, 2217.46, 4434.92],
         'Db': [17.32, 34.65, 69.3,   138.59, 277.18, 554.37, 1108.73, 2217.46, 4434.92],
         'D':  [18.35, 36.71, 73.42,  146.83, 293.66, 587.33, 1174.66, 2349.32, 4698.63],
         'D#': [19.45, 38.89, 77.78,  155.56, 311.13, 622.25, 1244.51, 2489.02, 4978.03],
         'Eb': [19.45, 38.89, 77.78,  155.56, 311.13, 622.25, 1244.51, 2489.02, 4978.03],
         'E':  [20.6,  41.2,  82.41,  164.81, 329.63, 659.25, 1318.51, 2637.02, 5274.04],
         'Fb': [20.6,  41.2,  82.41,  164.81, 329.63, 659.25, 1318.51, 2637.02, 5274.04],
         'E#': [21.83, 43.65, 87.31,  174.61, 349.23, 698.46, 1396.91, 2793.83, 5587.65],
         'F':  [21.83, 43.65, 87.31,  174.61, 349.23, 698.46, 1396.91, 2793.83, 5587.65],
         'F#': [23.12, 46.25, 92.5,   185.0,  369.99, 739.99, 1479.98, 2959.96, 5919.91],
         'Gb': [23.12, 46.25, 92.5,   185.0,  369.99, 739.99, 1479.98, 2959.96, 5919.91],
         'G':  [24.5,  49.0,  98.0,   196.0,  392.0,  783.99, 1567.98, 3135.96, 6271.93],
         'G#': [25.96, 51.91, 103.83, 207.83, 415.3,  830.61, 1661.22, 3322.44, 6644.88],
         'Ab': [25.96, 51.91, 103.83, 207.83, 415.3,  830.61, 1661.22, 3322.44, 6644.88],
         'A':  [27.5,  55.0,  110.0,  220.0,  440.0,  880.0,  1760.0,  3520.0,  7040.0 ],
         'A#': [29.14, 58.27, 116.54, 233.08, 466.16, 932.33, 1864.66, 3729.31, 7458.62],
         'Bb': [29.14, 58.27, 116.54, 233.08, 466.16, 932.33, 1864.66, 3729.31, 7458.62],
         'B':  [30.87, 61.74, 123.47, 246.94, 493.88, 987.77, 1975.53, 3951.07, 7902.13],
         'Cb': [30.87, 61.74, 123.47, 246.94, 493.88, 987.77, 1975.53, 3951.07, 7902.13]}


def note_data_gen(freq: float,  # frequency (Hz)
                  amp: float,   # amplitude. must fit within 24 bits including sign bit
                  dur: float,   # duration (cycles)
                  rate: float = 48000,  # clock rate (Hz) default for CODEC is 48 kHz
                  fname: str = 'note_data.mif'):  # output file name

    # After some experimentation, 3.63 multiplier performed the best results - Updated code
    note_data = []
    samples = int(rate*dur/freq)
    wavelength_dur = int(rate/freq)
    max_wavelength_dur = int(wavelength_dur * 3.63)
    num_total_max_wavelength_dur = math.ceil(samples / max_wavelength_dur)
    for i in range(0,max_wavelength_dur):
        curr_sample = int(round( amp * math.sin(2*math.pi*freq*i/rate) ))
        # store as unsigned 24 bit int
        if curr_sample >= 0:
            note_data.append(curr_sample)
        else:
            note_data.append(curr_sample + 2**24)
    # Incorporate periodicity until total samples is reached
    note_data = note_data * num_total_max_wavelength_dur

    # dump data to file
    with open(fname, 'w') as f:
        f.write(f"WIDTH=24;\n")
        f.write(f"DEPTH={samples};\n\n")
        f.write(f"ADDRESS_RADIX=UNS;\n")
        f.write(f"DATA_RADIX=UNS;\n\n")
        f.write(f"CONTENT BEGIN\n")
        for x in range(samples):
            f.write(f"\t{x}\t:\t{note_data[x]};\n")
        f.write("END;")


if __name__ == '__main__':
    # argument parsing (options -h)
    parser = argparse.ArgumentParser(description="Generate a MIF file with audio data with the specified characteristics")
    parser.add_argument("note",
            help=("Specify note as either a numerical frequency in Hz (e.g., "
                  "440.0)\nor an English 12-tone chromatic note on a piano "
                  "(e.g., C#3, Ab7)"))
    parser.add_argument("amplitude",help="Relative amplitude/volume (from 1.0 to 10.0)")
    parser.add_argument("duration",help="Note duration in seconds")
    parser.add_argument("filename", nargs="?", default="note_data.mif",
            help="output filename (include the extention .mif)")
    args = parser.parse_args()

    # convert note to frequency
    try:
        freq = float(args.note)
    except:
        # regex search for valid English 12-tone chromatic note name
        chrom = re.match(r"([A-G][#b]?)([1-8])", args.note)
        if not chrom:
            exit((f"Error: Unrecognized note {args.note}\n"
                  " - note should be A through G (capitalized)\n"
                  " - add # for sharp and b for flat\n"
                  " - octave should be 1 through 8"))
        note = chrom.group(1)
        octave = int(chrom.group(2))
        freq = notes[note][octave]
    if freq <= 0:
        exit(f"Error: Note frequency ({args.note}) must be a positive.")

    # parse amplitude
    try:
        amp = float(args.amplitude)
        failA = (amp < 1) or (amp > 10)
    except:
        failA = True
    if failA:
        exit(f"Error: Amplitude ({args.amplitude}) must be a decimal number from 1.0 to 10.0.")

    # convert duration from seconds to wavelengths
    try:
        sec = float(args.duration)
        failD = (sec <= 0)
    except:
        failD = True
    if failD:
        exit(f"Error: Sample duration ({args.duration}) must be a positive decimal number.")
    dur = sec * freq

    print((f"Audio characteristics:\n"
           f" - frequency: {freq} Hz\n"
           f" - amplitude: {amp} out of 10\n"
           f" - duration:  {sec} seconds = {dur} wavelengths\n"
           f" - sample rate of 48000.0 Hz (same as Audio CODEC)\n"))
    note_data_gen(freq, amp/10.0 * 16777215, dur, 48000, args.filename)
    print(f"File {args.filename} generated.")
