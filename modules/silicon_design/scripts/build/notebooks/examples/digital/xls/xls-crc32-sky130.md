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

<!-- #region tags=[] -->
# XLS Sample

```
Copyright 2022 Google LLC.
SPDX-License-Identifier: Apache-2.0
```

This notebook shows how to run a [XLS](https://google.github.io/xls/)-based CRC checksum calculator design thru an end-to-end RTL to GDSII flow targetting the [SKY130](https://github.com/google/skywater-pdk/) process node.
<!-- #endregion -->

<!-- #region tags=[] -->
## Define flow parameters
<!-- #endregion -->

```python tags=["parameters"]
die_width = 100
target_density = 80
run_path = 'runs/crc32'
```

<!-- #region id="ylo5KQ-gvX02" -->
## Write and test DSLX module

The CRC computation is written using the [DSLX](https://google.github.io/xls/dslx_reference/) HLS, a domain specific, dataflow-oriented functional language used to build hardware w/ a Rust-like syntax.
<!-- #endregion -->

```bash colab={"base_uri": "https://localhost:8080/"} id="JKGxScUtoV4E" outputId="b9359a05-fa7f-4366-ecf8-40138acb11f1" magic_args="-c 'cat > crc32.x; interpreter_main crc32.x'"
// Performs a table-less crc32 of the input data as in Hacker's Delight:
// https://github.com/hcs0/Hackers-Delight/blob/master/crc.c.txt (roughly flavor b)

fn crc32_one_byte(byte: u8, polynomial: u32, crc: u32) -> u32 {
  let crc = crc ^ (byte as u32);
  // 8 rounds of updates.
  for (i, crc): (u32, u32) in range(u32:0, u32:8) {
    let mask = -(crc & u32:1);
    (crc >> u32:1) ^ (polynomial & mask)
  }(crc)
}

fn main(message: u8) -> u32 {
  crc32_one_byte(message, u32:0xEDB88320, u32:0xFFFFFFFF) ^ u32:0xFFFFFFFF
}

#[test]
fn crc32_one_char() {
  assert_eq(u32:0x83DCEFB7, main('1'))
}
```

<!-- #region id="smMIJhopvqwo" -->
## Generate IR and Verilog

XLS can generate combinational or pipelined version of a given design.
<!-- #endregion -->

```python colab={"base_uri": "https://localhost:8080/"} id="YMTh7WB6oxeW" outputId="a4e9d2f2-69e3-47e9-cad6-e1b89124553b"
!ir_converter_main --top main crc32.x > crc32.ir
!opt_main crc32.ir > crc32_opt.ir
!codegen_main --generator=combinational crc32_opt.ir > crc32.v
!cat crc32.v
```

## Write flow configuration

See [OpenLane Variables information](https://github.com/The-OpenROAD-Project/OpenLane/blob/master/configuration/README.md) for the list of available variables.

```python id="rBk7BdF0n_o5"
%%writefile config.tcl
set ::env(DESIGN_NAME) __crc32__main

set ::env(VERILOG_FILES) "crc32.v"
 
set ::env(CLOCK_TREE_SYNTH) 0
set ::env(CLOCK_PORT) ""

set ::env(FP_SIZING) "absolute"
set ::env(DIE_AREA) "0 0 $::env(DIE_WIDTH) $::env(DIE_WIDTH)"
set ::env(PL_TARGET_DENSITY) [expr {$::env(TARGET_DENSITY) / 100.0}]

# TODO(proppy) find out why LVS fails
set ::env(RUN_LVS) 0
```

## Run OpenLane flow

[OpenLane](https://github.com/The-OpenROAD-Project/OpenLane) is an automated RTL to GDSII flow based on several components including [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD), [Yosys](https://github.com/YosysHQ/yosys), Magic, Netgen, Fault, CVC, SPEF-Extractor, CU-GR, Klayout and a number of custom scripts for design exploration and optimization.

```python colab={"base_uri": "https://localhost:8080/"} id="8gim7pEdozHv" outputId="3d4cccd8-bda2-4380-a1c3-5c9002560b7b" tags=[]
#papermill_description=RunningOpenLaneFlow
%env DIE_WIDTH={die_width}
%env TARGET_DENSITY={target_density}
!flow.tcl -design . -run_path {run_path} -ignore_mismatches
```

## Display layout

Use [GDSII Tool Kit](https://github.com/heitzmann/gdstk) and [CairoSVG](https://cairosvg.org/) to convert the resulting GDSII file to PNG.

```python colab={"base_uri": "https://localhost:8080/", "height": 1000} id="1uSEdmRhtXdl" outputId="6830cf44-e85f-48fc-aa84-84f794c25dc8"
#papermill_description=RenderingGDS
import pathlib
import gdstk
import cairosvg

import IPython.display
import scrapbook as sb

gds_path = sorted(pathlib.Path(run_path).glob('*/results/final/gds/*.gds'))[-1]
library = gdstk.read_gds(gds_path)
top_cells = library.top_level()
svg_path = pathlib.Path(run_path) / 'xls.svg'
top_cells[0].write_svg(svg_path)
png_path = pathlib.Path(run_path) / 'xls.png'

cairosvg.svg2png(url=str(svg_path), write_to=str(png_path))
sb.glue('layout', IPython.display.Image(png_path), 'display', display=True)
```

## Dump flow report

See [OpenLane Datapoint Definitions](https://github.com/The-OpenROAD-Project/OpenLane/blob/master/regression_results/datapoint_definitions.md) for the description of the report columns.

```python tags=[]
#papermill_description=DumpingReport
import pandas as pd
import pathlib
import scrapbook as sb

final_summary_report = sorted(pathlib.Path(run_path).glob('*/reports/metrics.csv'))[-1]
df = pd.read_csv(final_summary_report)
pd.set_option('display.max_rows', None)
sb.glue('summary', df, 'pandas')
df.transpose()
```

## Extract power metrics

Build a pandas dataframe with area, density and power consumption.

```python tags=[]
#papermill_description=ExtractingMetrics
import scrapbook as sb

def get_power(sta_power_report):
    with sta_power_report.open() as f:
        for l in f.readlines():
            if l.startswith('Total'):
                return float(l.split(' ')[-2])

def area_density_ppa():
    for report in sorted(pathlib.Path(run_path).glob('*/reports')):
        sta_power_report = report / 'signoff/23-rcx_sta.power.rpt'
        final_summary_report = report / 'metrics.csv'
        if final_summary_report.exists() and sta_power_report.exists():
            df = pd.read_csv(final_summary_report)
            power = get_power(sta_power_report)
            yield (df['DIEAREA_mm^2'][0], df['PL_TARGET_DENSITY'][0], power)

df = pd.DataFrame(area_density_ppa(), columns=('DIEAREA_mm^2', 'PL_TARGET_DENSITY', 'TOTAL_POWER'))
sb.glue('metrics', df, 'pandas')
(df.style.hide_index()
   .format({'area': '{:.8f}', 'density': '{:.2%}', 'power': '{:.8f}'})
   .bar(subset=['TOTAL_POWER'], color='pink')
   .background_gradient(subset=['PL_TARGET_DENSITY'], cmap='Greens')
   .bar(color='lightblue', vmin=0.001, subset=['DIEAREA_mm^2']))
```

```python
#papermill_description=ReportingMetrics
import hypertune

total_power = df['TOTAL_POWER'][0] * 1e6
print('reporting metric:', 'total_power', total_power)
hpt = hypertune.HyperTune()
hpt.report_hyperparameter_tuning_metric(
    hyperparameter_metric_tag='total_power',
    metric_value=total_power,
)
```
