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
# Inverter Sample

```
Copyright 2022 Google LLC.
SPDX-License-Identifier: Apache-2.0
```

This notebook shows how to run a simple inverter design thru an end-to-end RTL to GDSII flow targetting the [SKY130](https://github.com/google/skywater-pdk/) process node.
<!-- #endregion -->

## Define flow parameters

```python tags=["parameters"]
die_width = 50
target_density = 70
run_path = 'runs'
```

## Write verilog

Invert the `in` input signal and continuously assign it to the `out` output signal.

```bash magic_args="-c 'cat > inverter.v; iverilog inverter.v'"
module inverter(input wire in, output wire out);
    assign out = !in;
endmodule
```
## Write flow configuration

See [OpenLane Variables information](https://github.com/The-OpenROAD-Project/OpenLane/blob/master/configuration/README.md) for the list of available variables.

```python
%%writefile config.tcl
set ::env(DESIGN_NAME) inverter

set ::env(VERILOG_FILES) "inverter.v"

set ::env(FP_SIZING) "absolute"
set ::env(DIE_AREA) "0 0 $::env(DIE_WIDTH) $::env(DIE_WIDTH)"
set ::env(PL_TARGET_DENSITY) [expr {$::env(TARGET_DENSITY) / 100.0}]

set ::env(CLOCK_TREE_SYNTH) 0
set ::env(CLOCK_PORT) ""
set ::env(DIODE_INSERTION_STRATEGY) 0
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

Use [GDSII Tool Kit](https://github.com/heitzmann/gdstk) to convert the resulting GDSII file to SVG.

```python
#papermill_description=RenderingGDS
import pathlib
import gdstk
import IPython.display
import scrapbook as sb

gds_path = sorted(pathlib.Path(run_path).glob('*/results/final/gds/*.gds'))[-1]
library = gdstk.read_gds(gds_path)
top_cells = library.top_level()
svg_path = pathlib.Path(run_path) / 'layout.svg'
top_cells[0].write_svg(svg_path)
sb.glue('layout', IPython.display.SVG(svg_path), 'display', display=True)
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
