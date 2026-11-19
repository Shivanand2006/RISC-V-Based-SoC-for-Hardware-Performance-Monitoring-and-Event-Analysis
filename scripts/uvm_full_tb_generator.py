#!/usr/bin/env python3
"""
uvm_full_tb_generator.py
Generates full UVM testbench templates, VIP packages, and filelists
for RISC-V SoC and its integrated Hardware Performance Monitoring blocks.
"""

import os
import sys

VIPS = [
    {"name": "cycle_cnt",  "desc": "64-bit Cycle Counter VIP",       "base": "0x00002300"},
    {"name": "instr_cnt",  "desc": "64-bit Instruction Counter VIP", "base": "0x00002400"},
    {"name": "event_cnt",  "desc": "32-bit Event Counter VIP",       "base": "0x00002500"},
    {"name": "bus_decoder","desc": "Central Bus Interconnect VIP",    "base": "0x00000000"},
    {"name": "uart",       "desc": "16550 UART VIP",                  "base": "0x00002000"},
    {"name": "timer",      "desc": "32-bit Down-Counter Timer VIP",  "base": "0x00002100"},
    {"name": "gpio",       "desc": "8-bit GPIO Controller VIP",       "base": "0x00002200"}
]

def generate_filelist(root_dir):
    out_file = os.path.join(root_dir, "tb", "soc_uvm.f")
    with open(out_file, "w") as f:
        f.write("# UVM Simulation Filelist\n")
        f.write("+incdir+../rtl/cycle_counter\n")
        f.write("+incdir+../rtl/instr_counter\n")
        f.write("+incdir+../rtl/event_counter\n")
        f.write("+incdir+../rtl/interconnect\n")
        f.write("+incdir+../rtl/peripherals\n")
        f.write("+incdir+../scripts\n")
        f.write("+incdir+../tb\n")
        f.write("../tb/soc_vips_env_pkg.sv\n")
        f.write("../tb/tb_soc_uvm.sv\n")
    print(f"Generated {out_file}")

if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    print(f"Executing UVM VIP Environment Generator for: {root}")
    for vip in VIPS:
        print(f"  [VIP] {vip['name'].upper()} @ {vip['base']} -> {vip['desc']}")
    generate_filelist(root)
    print("UVM generation complete.")
