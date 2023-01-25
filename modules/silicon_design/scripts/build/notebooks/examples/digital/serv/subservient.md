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
# Serv Sample

```
Copyright 2022 Google LLC.
SPDX-License-Identifier: Apache-2.0
```

This notebook shows how to run the [SERV](https://github.com/olofk/serv) RISC-V core design thru an end-to-end RTL to GDSII flow targetting the [SKY130](https://github.com/google/skywater-pdk/) process node.
<!-- #endregion -->

## Define flow parameters

```python tags=["parameters"]
die_width = 200
target_density = 80
run_path = 'runs/serv'
```

## Get SERV RTL

```python
!git clone -b serial_dbg_if https://github.com/olofk/subservient
!git clone https://github.com/olofk/serv
```
## Write flow configuration

See [OpenLane Variables information](https://github.com/The-OpenROAD-Project/OpenLane/blob/master/configuration/README.md) for the list of available variables.

```python
%%writefile config.tcl
set ::env(DESIGN_NAME) subservient

set ::env(VERILOG_FILES) "
    [glob "serv/rtl/*.v"]
    [glob "serv/serving/*.v"]
    [glob "subservient/rtl/*.v"]
"
set ::env(CLOCK_PERIOD) "10"
set ::env(CLOCK_PORT) "i_clk"
set ::env(DESIGN_IS_CORE) 0

set ::env(FP_SIZING) "absolute"
set ::env(DIE_AREA) "0 0 $::env(DIE_WIDTH) $::env(DIE_WIDTH)"
set ::env(PL_TARGET_DENSITY) [expr {$::env(TARGET_DENSITY) / 100.0}]
```

## Run OpenLane flow

[OpenLane](https://github.com/The-OpenROAD-Project/OpenLane) is an automated RTL to GDSII flow based on several components including [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD), [Yosys](https://github.com/YosysHQ/yosys), Magic, Netgen, Fault, CVC, SPEF-Extractor, CU-GR, Klayout and a number of custom scripts for design exploration and optimization.

```python tags=[]
#papermill_description=RunningOpenLaneFlow
%env DIE_WIDTH={die_width}
%env TARGET_DENSITY={target_density}
!flow.tcl -design . -run_path {run_path} -ignore_mismatches
```

## Display layout

Use [GDSII Tool Kit](https://github.com/heitzmann/gdstk) and [CairoSVG](https://cairosvg.org/) to convert the resulting GDSII file to PNG.

```python
#papermill_description=RenderingGDS
import pathlib
import gdstk
import cairosvg

import IPython.display
import scrapbook as sb

gds_path = sorted(pathlib.Path(run_path).glob('*/results/final/gds/*.gds'))[-1]
library = gdstk.read_gds(gds_path)
top_cells = library.top_level()
svg_path = gds_path.parent / 'subservient.svg'
top_cells[0].write_svg(svg_path)
png_path = gds_path.parent / 'subservient.png'

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
   .format({'DIEAREA_mm^2': '{:.8f}', 'PL_TARGET_DENSITY': '{:.2%}', 'TOTAL_POWER': '{:.6f}'})
   .bar(subset=['TOTAL_POWER'], color='pink')
   .background_gradient(subset=['PL_TARGET_DENSITY'], cmap='Greens')
   .bar(color='lightblue', vmin=0.001, subset=['DIEAREA_mm^2']))
```

Report metrics for hyper-parameters tuning.

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
