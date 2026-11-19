# Standalone RISC-V HPM SoC C-test RTL file list.
# =============================================================================
# run_ctest.f — VCS Filelist for RISC-V HPM SoC Integration
# Project  : 1602-23-735-108 RISC-V HPM SoC
# Tool     : Synopsys VCS U-2023.03
# =============================================================================

+incdir+../rtl/cycle_counter
+incdir+../rtl/instr_counter
+incdir+../rtl/event_counter
+incdir+../rtl/interconnect
+incdir+../rtl/peripherals
+incdir+../rtl/Cores-VeeR-EL2/design/include
+incdir+../rtl/Cores-VeeR-EL2/configs

# Common
../rtl/common/reg_slave_if.v

# HPM IPs
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

# Top Level SoC
../rtl/top/soc_top.v

# Testbench Collateral
../tb/top/uart_monitor.v
tb_soc_ctest.sv
