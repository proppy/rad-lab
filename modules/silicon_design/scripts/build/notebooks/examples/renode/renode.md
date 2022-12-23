---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.14.1
  kernelspec:
    display_name: Python 3 (ipykernel)
    language: python
    name: python3
---

## Renode run


```python tags=["parameters"]
quantum = 0.001
mbs = 10000
mips = 100
```


```python
! pip install -q git+https://github.com/antmicro/renode-colab-tools.git # only needed in the Colab environment
! pip install -q git+https://github.com/antmicro/renode-run.git # one of the ways to get Renode (Linux only)
! pip install -q https://github.com/antmicro/pyrenode/archive/mh/flushing.zip # a library to talk to Renode from Python
! pip install -q robotframework==4.0.1 # testing framework used by Renode
# as the compilation process takes several minutes, we will conveniently skip it here and use precompiled binaries
! git clone https://github.com/antmicro/renode-colab-tutorial # repository with resources for this tutorial
! wget https://raw.githubusercontent.com/enjoy-digital/litex/master/litex/tools/litex_json2renode.py  # a helper script
```

```python
%%writefile digilent_arty.repl

rom: Memory.MappedMemory @ sysbus 0x0
    size: 0x20000

sram: Memory.MappedMemory @ sysbus 0x10000000
    size: 0x2000

main_ram: Memory.MappedMemory @ sysbus 0x40000000
    size: 0x10000000

cpu: CPU.VexRiscv @ sysbus
    cpuType: "rv32im"

ctrl: Miscellaneous.LiteX_SoC_Controller_CSR32 @ { sysbus 0xf0000000 }

sysbus:
    init add:
        SilenceRange <0xf0000800 0x200> # ddrphy

sysbus:
    init add:
        SilenceRange <0xf0002000 0x200> # sdram

timer0: Timers.LiteX_Timer_CSR32 @ { sysbus 0xf0002800 }
    -> cpu@1
    frequency: 100000000

uart: UART.LiteX_UART @ { sysbus 0xf0003000 }
    -> cpu@0

cpu:
    init:
        RegisterCustomCSR "BPM" 0xB04  User
        RegisterCustomCSR "BPM" 0xB05  User
        RegisterCustomCSR "BPM" 0xB06  User
        RegisterCustomCSR "BPM" 0xB07  User
        RegisterCustomCSR "BPM" 0xB08  User
        RegisterCustomCSR "BPM" 0xB09  User
        RegisterCustomCSR "BPM" 0xB0A  User
        RegisterCustomCSR "BPM" 0xB0B  User
        RegisterCustomCSR "BPM" 0xB0C  User
        RegisterCustomCSR "BPM" 0xB0D  User
        RegisterCustomCSR "BPM" 0xB0E  User
        RegisterCustomCSR "BPM" 0xB0F  User
        RegisterCustomCSR "BPM" 0xB10  User
        RegisterCustomCSR "BPM" 0xB11  User
        RegisterCustomCSR "BPM" 0xB12  User
        RegisterCustomCSR "BPM" 0xB13  User
        RegisterCustomCSR "BPM" 0xB14  User
        RegisterCustomCSR "BPM" 0xB15  User

cfu0: Verilated.CFUVerilatedPeripheral @ cpu 0
```

```python
%%writefile script.resc

using sysbus                                          # a convenience - allows us to write "uart" instead of "sysbus.uart"
mach create "digilent_arty"
machine LoadPlatformDescription @/digilent_arty.repl       # load the repl file we just created
uart RecordToAsciinema @/output.asciinema       # movie-like recording of the UART output, open with https://github.com/asciinema/asciinema-player/
showAnalyzer uart                                     # open a console window for UART, or put the output to the log
logFile @/log true                              # enable logging to file, flush after every write

macro reset
"""
    cpu.cfu0 SimulationFilePathLinux @/renode-colab-tutorial/binaries/libVtop.so       # actual verilated CFU
    sysbus LoadELF @/renode-colab-tutorial/binaries/software.elf                       # software we're going to run
"""
runMacro $reset
```


```python

# Re-run this snippet if your Colab seems to be stuck!
from pyrenode import connect_renode, get_keywords, shutdown_renode

def restart_renode():  # this might be useful if you ever see Renode not responding!
  shutdown_renode()
  connect_renode()
  get_keywords()

restart_renode()
```


```python
def Restart():
  ResetEmulation()                # Does this hang for you? Replace with `restart_renode()`
  ExecuteScript("script.resc")
  ExecuteCommand('logLevel 3')
  ExecuteCommand(f'emulation SetGlobalQuantum "{quantum}"')
  ExecuteCommand('emulation SetGlobalAdvanceImmediately true')
  ExecuteCommand(f'cpu MaximumBlockSize {int(mbs)}')
  ExecuteCommand(f'cpu PerformanceInMips {int(mips)}')
  CreateTerminalTester("sysbus.uart", timeout=15)

```


```python
Restart()
StartEmulation()

WaitForLineOnUart("Hello, World!")
WaitForPromptOnUart("main>")

WriteToUart("1")
WaitForPromptOnUart("models>")

WriteToUart("2")
WaitForPromptOnUart("mnv2>")

WriteToUart("0")
WaitForPromptOnUart("mnv2>")

WriteToUart("1")
WaitForPromptOnUart("mnv2>")

WriteToUart("g")
WaitForPromptOnUart("mnv2>")

WriteToUart("g")
WaitForPromptOnUart("mnv2>")
ExecuteCommand("emulation GetTimeSourceInfo")
```

```python
str=ExecuteCommand("emulation GetTimeSourceInfo")
print(str)
str=str.split('\n')[1].split(' ')[-1]
from datetime import datetime, timedelta
t = datetime.strptime(str,  '%H:%M:%S.%f')
td=timedelta(hours=t.hour, minutes=t.minute, seconds=t.second, microseconds=t.microsecond)
total=td.total_seconds()
```

```python
import hypertune

print('reporting metric:', 'host time', total)
hpt = hypertune.HyperTune()
hpt.report_hyperparameter_tuning_metric(
    hyperparameter_metric_tag = 'execution_time',
    metric_value = total,
)

```

```python
import pandas as pd
import scrapbook as sb

df = pd.DataFrame([[quantum, mbs, mips, total]], columns=('quantum', 'mbs', 'mips', 'execution_time'))
sb.glue('metrics', df, 'pandas')
df

```
