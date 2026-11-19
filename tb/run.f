# ==============================================================================
# File: run.f
# Filelist for UVM regression simulation with Synopsys VCS
# ==============================================================================

+incdir+../rtl/cycle_counter
+incdir+../rtl/instr_counter
+incdir+../rtl/event_counter
+incdir+../rtl/interconnect
+incdir+../rtl/peripherals
+incdir+../rtl/Cores-VeeR-EL2/design/include
+incdir+../rtl/Cores-VeeR-EL2/configs
+incdir+../scripts/cycle_cnt_uvm_tb
+incdir+../scripts/instr_cnt_uvm_tb
+incdir+../scripts/event_cnt_uvm_tb
+incdir+../scripts/bus_decoder_uvm_tb
+incdir+../tb

# Common RTL
../rtl/common/reg_slave_if.v

# HPM RTL
../rtl/cycle_counter/cycle_cnt_top.v
../rtl/instr_counter/instr_cnt_top.v
../rtl/event_counter/event_cnt_top.v

# Peripherals
../rtl/peripherals/uart_top.v
../rtl/peripherals/timer_top.v
../rtl/peripherals/gpio_top.v

# Memories
../rtl/mem/imem.v
../rtl/mem/dmem.v

# Interconnect
../rtl/interconnect/bus_decoder.v

# Core Adapters & VeeR EL2
../rtl/core/ahb_to_bus_adapter.v
../rtl/core/ahb_imem_adapter.v
../rtl/core/veer_core_adapter.sv

# Top
../rtl/top/soc_top.v

# Testbench
../tb/tb_soc_uvm.sv
