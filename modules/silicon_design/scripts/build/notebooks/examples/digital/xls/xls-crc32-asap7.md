---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.14.4
  kernelspec:
    display_name: Python 3 (ipykernel)
    language: python
    name: python3
---

# OpenROAD Flow ASAP7 Sample

```
Copyright 2022 Google LLC.
SPDX-License-Identifier: Apache-2.0
```

This notebook shows how to run a test design thru OpenROAD flow targetting the ASAP7 process node


## Define flow parameters

```python tags=["parameters"]
import datetime

die_width = 30
core_padding = 2
target_density = 0.90
crc32_rounds = 8
pipeline_stages = 4
clock_period = 200
runs_dir = 'runs'
```

## Timestamp run

```python
now = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
run_path = f'{runs_dir}/{now}'
run_path
```

<!-- #region id="ylo5KQ-gvX02" tags=[] -->
## Write and test DSLX module

The CRC computation is written using the [DSLX](https://google.github.io/xls/dslx_reference/) HLS, a domain specific, dataflow-oriented functional language used to build hardware w/ a Rust-like syntax.
<!-- #endregion -->

```bash colab={"base_uri": "https://localhost:8080/"} id="JKGxScUtoV4E" outputId="b9359a05-fa7f-4366-ecf8-40138acb11f1" magic_args="-c 'sed s/__CRC32_ROUNDS__/{crc32_rounds}/ > crc32.x; interpreter_main crc32.x'"
// Performs a table-less crc32 of the input data as in Hacker's Delight:
// https://github.com/hcs0/Hackers-Delight/blob/master/crc.c.txt (roughly flavor b)

fn crc32_one_byte(byte: u8, polynomial: u32, crc: u32) -> u32 {
  let crc = crc ^ (byte as u32);
  // __CRC32_ROUNDS__ rounds of updates.
  for (i, crc): (u32, u32) in range(u32:0, u32:__CRC32_ROUNDS__) {
    let mask = -(crc & u32:1);
    (crc >> u32:1) ^ (polynomial & mask)
  }(crc)
}

fn main(message: u8) -> u32 {
  crc32_one_byte(message, u32:0xEDB88320, u32:0xffffffff) ^ u32:0xffffffff
}
```

<!-- #region id="smMIJhopvqwo" -->
## Generate IR and Verilog

XLS can generate combinational or pipelined version of a given design.
<!-- #endregion -->

```python colab={"base_uri": "https://localhost:8080/"} id="YMTh7WB6oxeW" outputId="a4e9d2f2-69e3-47e9-cad6-e1b89124553b" tags=[]
!ir_converter_main --top main crc32.x > crc32.ir
!opt_main crc32.ir > crc32_opt.ir
!codegen_main --generator=pipeline --delay_model="asap7" --module_name="crc32" --pipeline_stages={pipeline_stages} crc32_opt.ir > crc32.v
!cat crc32.v
```

## Configure OpenROAD Flow

```python
%%writefile config.mk

export PLATFORM               = asap7
export DESIGN_NAME            = crc32
export VERILOG_FILES          = ${PWD}/crc32.v
export SDC_FILE               = ${PWD}/constraint.sdc
export DIE_AREA               = 0 0 $(DIE_WIDTH) $(DIE_WIDTH)
export CORE_AREA              = $(CORE_PADDING) $(CORE_PADDING) $(CORE_WIDTH) $(CORE_WIDTH)

export PLACE_DENSITY          = $(TARGET_DENSITY)
```

```bash magic_args="-c \"sed s/__CLOCK_PERIOD__/{clock_period}/ | tee constraint.sdc\""

set clk_name  clk
set clk_port_name clk
set clk_period __CLOCK_PERIOD__ 
set clk_io_pct 0.1

set clk_port [get_ports $clk_port_name]

create_clock -name $clk_name -period $clk_period $clk_port

set non_clock_inputs [lsearch -inline -all -not -exact [all_inputs] $clk_port]

set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs 
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]
```

## Run OpenROAD Flow

[OpenROAD Flow](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts) is a full RTL-to-GDS flow built entirely on open-source tools. The project aims for automated, no-human-in-the-loop digital circuit design with 24-hour turnaround time.

```python tags=[]
import pathlib
import os

work_dir = pathlib.Path(run_path)
work_dir.mkdir(parents=True, exist_ok=True)
work_dir = str(work_dir.resolve())
pwd = os.getcwd()

!make -C /OpenROAD-flow-scripts/flow \
   SHELL=/bin/bash \
   FLOW_HOME=/OpenROAD-flow-scripts/flow \
   PLATFORM_DIR=/OpenROAD-flow-scripts/flow/platforms/asap7 \
   DESIGN_CONFIG={pwd}/config.mk \
   DIE_WIDTH={die_width} \
   CORE_PADDING={core_padding} \
   CORE_WIDTH={float(die_width) - float(core_padding)} \
   TARGET_DENSITY={target_density} \
   WORK_HOME={work_dir}
```

<!-- #region tags=[] -->
## Dump flow metrics
<!-- #endregion -->

```python tags=[]
import pathlib

flow_path = pathlib.Path(run_path).resolve()
!PLATFORM_DIR=/OpenROAD-flow-scripts/flow/platforms python /OpenROAD-flow-scripts/flow/util/genMetrics.py --flowPath {flow_path} --design crc32 --platform asap7 --output {flow_path}/metrics.json

import json
import pandas as pd
from IPython.display import display
import scrapbook as sb

pd.set_option('display.max_rows', None)
metrics = pathlib.Path(run_path) / 'metrics.json'
with metrics.open() as f:
    data = json.load(f)
    df = pd.DataFrame.from_records([data])
sb.glue('metrics', df, 'pandas')
df.transpose().rename(columns={0: 'metrics'})
```

## Display layout with KLayout

```python
%%writefile /OpenROAD-flow-scripts/flow/util/gallery.json
[
  {
    "name" : "final",
    "layout_file": "6_final.def",
    "min_hierarchy": 0,
    "max_hierarchy": 1,
    "x_resolution": 500,
    "y_resolution": 500,
    "hide_layers": false
  },
  {
    "name" : "final_no_power",
    "layout_file": "6_final_no_power.def",
    "min_hierarchy": 0,
    "max_hierarchy": 1,
    "x_resolution": 500,
    "y_resolution": 500,
    "hide_layers": false
  }
]
```

```python
!make -C /OpenROAD-flow-scripts/flow/ \
   SHELL=/bin/bash \
   FLOW_HOME=/OpenROAD-flow-scripts/flow \
   PLATFORM_DIR=/OpenROAD-flow-scripts/flow/platforms/asap7 \
   DESIGN_CONFIG={pwd}/config.mk \
   WORK_HOME={work_dir} \
   gallery

from IPython.display import Image

gallery = pathlib.Path(run_path) / 'results/asap7/crc32/base/gallery_final_no_power.png'
sb.glue('layout', Image(gallery), 'display', display=True)
```

## Extract  metrics

Build a pandas dataframe with ppa.

```python tags=[]
#papermill_description=ExtractingMetrics
import re
import scrapbook as sb
re_critical_path_delay = r'''critical path delay
--------------------------------------------------------------------------
(\S+)
'''
re_critical_path_slack = r'''finish critical path slack
--------------------------------------------------------------------------
(\S+)
'''
re_total_power = r'''^Total.*%$'''
re_design_area = r'''finish report_design_area
--------------------------------------------------------------------------
Design area (\S+) u\^2 (\S+)% utilization.'''
def runs_ppa():
    for r in pathlib.Path(runs_dir).glob('*/logs/asap7/crc32/base/6_report.log'):
        with r.open() as f:
            report = f.read()
        critical_path_delay = float(re.search(re_critical_path_delay, report).group(1))
        critical_path_slack = float(re.search(re_critical_path_slack, report).group(1))
        m = re.search(re_total_power, report, re.MULTILINE)
        total_power = float(re.split('\s+', m.group())[-2])
        m = re.search(re_design_area, report, re.MULTILINE)
        area = int(m.group(1))
        utilization = float(m.group(2)) / 100.0
        yield r.parts[1], total_power, critical_path_delay, critical_path_slack, area, utilization
        
df = pd.DataFrame.from_records(runs_ppa(), columns=['run', 'power', 'delay', 'slack', 'area', 'utilization'], index='run').sort_index()
sb.glue('ppa', df, 'pandas')
(df.style
   .format({'area': '{:.8f}', 'utilization': '{:.2%}', 'power': '{:.6f}', 'slack':  '{:.6f}', 'delay': '{:.6f}'})
   .bar(subset=['power'], color='pink')
   .bar(subset=['slack'], color='lime')
   .background_gradient(subset=['utilization'], cmap='Greens')
   .bar(subset=['area'], color='lightblue'))
```

Report metrics for hyper-parameters tuning.

```python
#papermill_description=ReportingMetrics
import hypertune

slack = df['slack'][0]
print('reporting metric:', 'slack', slack)
hpt = hypertune.HyperTune()
hpt.report_hyperparameter_tuning_metric(
    hyperparameter_metric_tag='slack',
    metric_value=slack,
)
```
