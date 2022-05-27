---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.13.8
  kernelspec:
    display_name: Python 3 (ipykernel)
    language: python
    name: python3
---

<!-- #region tags=[] -->
# LUTs exploration

```
Copyright 2022 Google LLC.
SPDX-License-Identifier: Apache-2.0
```
<!-- #endregion -->

## Define flow parameters

```python tags=["parameters"]
fp_core_util = 45
pl_target_density = 90
synth_defines='FRACTURABLE'
synth_param_inputs=5
run_path = 'runs/lut'
```

## Get LUT test designs

```python
!git clone https://github.com/growly/lut-tests.git
```

## Write flow configuration

See [OpenLane Variables information](https://github.com/The-OpenROAD-Project/OpenLane/blob/master/configuration/README.md) for the list of available variables.

```python
%%writefile config.tcl
# Design
# This is the config used to openlane for synthesis only
set ::env(DESIGN_NAME) "LUT"

#set ::env(SYNTH_DEFINES) "FRACTURABLE PREDECODE_2"
#set ::env(SYNTH_DEFINES) ""
#set ::env(SYNTH_DEFINES) "FRACTURABLE"
#set ::env(SYNTH_PARAMETERS) "INPUTS=6"

set script_dir [file dirname [file normalize [info script]]]
set ::env(VERILOG_FILES) [glob $script_dir/lut-tests/src/*.v]
set ::env(CLOCK_TREE_SYNTH) 0
#set ::env(CLOCK_PORT) "config_clk"
set ::env(CLOCK_PORT) ""
# Design config
set ::env(CLOCK_PERIOD) 30
#set ::env(CLOCK_PERIOD) "5.21"
set ::env(SYNTH_STRATEGY) "DELAY 1"

#set ::env(FP_CORE_UTIL) 50
#set ::env(PL_TARGET_DENSITY) 0.99
#set ::env(FP_CORE_UTIL) 40
#set ::env(PL_TARGET_DENSITY) 0.49

# "Enable logic verification using yosys, for comparing each netlist at each
# stage of the flow with the previous netlist and verifying that they are
# logically equivalent." Logical equivalence checking?
#set ::env(LEC_ENABLE) "1"
#set ::env(FP_WELLTAP_CELL) "sky130_fd_sc_hd__tap*"

set ::env(CELL_PAD) "0"
set ::env(TOP_MARGIN_MULT) 1
set ::env(BOTTOM_MARGIN_MULT) 1
set ::env(LEFT_MARGIN_MULT) 2
set ::env(RIGHT_MARGIN_MULT) 2
#set ::env(FILL_INSERTION) "0"
#set ::env(PL_RESIZER_DESIGN_OPTIMIZATIONS) "0"
#set ::env(PL_RESIZER_TIMING_OPTIMIZATIONS) "0"
#set ::env(GLB_RESIZER_DESIGN_OPTIMIZATIONS) "0"
#set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) "0"

set ::env(RT_MAX_LAYER) "met4"
set ::env(GLB_RT_ALLOW_CONGESTION) "1"

#set ::env(CELLS_LEF) "$::env(DESIGN_DIR)/cells.lef"
#
#set ::env(DIE_AREA) "0 0 393.76 27.200000000000003"
#
#set ::env(DIODE_INSERTION_STRATEGY) "0"

set ::env(ROUTING_CORES) 28

set ::env(DESIGN_IS_CORE) "0"
set ::env(SYNTH_PARAMETERS) "INPUTS=$::env(SYNTH_PARAM_INPUTS)"

#set ::env(FP_PDN_CORE_RING) "0"
##
#set ::env(PRODUCTS_PATH) "./build/8x32_DEFAULT/products"
#
#set ::env(INITIAL_NETLIST) "$::env(DESIGN_DIR)/RAM8.nl.v"
#set ::env(INITIAL_DEF) "$::env(DESIGN_DIR)/RAM8.placed.def"
#set ::env(INITIAL_SDC) "$::env(BASE_SDC_FILE)"
#
#set ::env(LVS_CONNECT_BY_LABEL) "1"
#
#set ::env(QUIT_ON_TIMING_VIOLATIONS) "0"
set ::env(TEST_MISMATCHES) none
set ::env(PDN_CFG) "$script_dir/pdn_cfg.tcl"
```

```python
%%writefile pdn_cfg.tcl

set ::env(VDD_NET) $::env(VDD_PIN)
set ::env(GND_NET) $::env(GND_PIN)

        foreach power_pin $::env(STD_CELL_POWER_PINS) {
            add_global_connection \
                -net $::env(VDD_NET) \
                -inst_pattern .* \
                -pin_pattern $power_pin \
                -power
        }
        foreach ground_pin $::env(STD_CELL_GROUND_PINS) {
            add_global_connection \
                -net $::env(GND_NET) \
                -inst_pattern .* \
                -pin_pattern $ground_pin \
                -ground
        }
        
set secondary []

foreach net $::env(VDD_NETS) {
    if { $net != $::env(VDD_NET)} {
        lappend secondary $net

        set db_net [[ord::get_db_block] findNet $net]
        if {$db_net == "NULL"} {
            set net [odb::dbNet_create [ord::get_db_block] $net]
            $net setSpecial
            $net setSigType "POWER"
        }
    }
}

foreach net $::env(GND_NETS) {
    if { $net != $::env(GND_NET)} {
        lappend secondary $net

        set db_net [[ord::get_db_block] findNet $net]
        if {$db_net == "NULL"} {
            set net [odb::dbNet_create [ord::get_db_block] $net]
            $net setSpecial
            $net setSigType "GROUND"
        }
    }
}

set_voltage_domain -name CORE -power $::env(VDD_NET) -ground $::env(GND_NET) \
    -secondary_power $secondary

define_pdn_grid \
        -name stdcell_grid \
        -starts_with POWER \
        -voltage_domain CORE \
        -pins $::env(FP_PDN_LOWER_LAYER)

add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(FP_PDN_LOWER_LAYER) \
        -width $::env(FP_PDN_VWIDTH) \
        -pitch $::env(FP_PDN_VPITCH) \
        -offset $::env(FP_PDN_VOFFSET) \
        -starts_with POWER

add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(FP_PDN_RAILS_LAYER) \
        -width $::env(FP_PDN_RAIL_WIDTH) \
        -followpins \
        -starts_with POWER

add_pdn_connect \
        -grid stdcell_grid \
        -layers "$::env(FP_PDN_RAILS_LAYER) $::env(FP_PDN_LOWER_LAYER)"

define_pdn_grid \
    -macro \
    -name macro \
    -starts_with POWER \
    -halo "$::env(FP_PDN_HORIZONTAL_HALO) $::env(FP_PDN_VERTICAL_HALO)"

add_pdn_connect \
    -grid macro \
    -layers "$::env(FP_PDN_LOWER_LAYER) $::env(FP_PDN_UPPER_LAYER)"

```

## Run OpenLane flow

[OpenLane](https://github.com/The-OpenROAD-Project/OpenLane) is an automated RTL to GDSII flow based on several components including [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD), [Yosys](https://github.com/YosysHQ/yosys), Magic, Netgen, Fault, CVC, SPEF-Extractor, CU-GR, Klayout and a number of custom scripts for design exploration and optimization.

```python
#papermill_description=RunningOpenLaneFlow
%env FP_CORE_UTIL={fp_core_util}
%env PL_TARGET_DENSITY={pl_target_density}
%env SYNTH_DEFINES={synth_defines}
%env SYNTH_PARAM_INPUTS={synth_param_inputs}

!flow.tcl -design . -run_path {run_path}
```

## Display layout

Use [GDSII Tool Kit](https://github.com/heitzmann/gdstk) to convert the resulting GDSII file to SVG.

```python
!python -m pip install scrapbook
```

```python
#papermill_description=RenderingGDS
import pathlib
import gdstk
import IPython.display
import scrapbook as sb

gds_path = sorted(pathlib.Path(run_path).glob('*/results/final/gds/*.gds'))[-1]
library = gdstk.read_gds(gds_path)
top_cells = library.top_level()
svg_path = pathlib.Path(run_path) / 'adders.svg'
top_cells[0].write_svg(svg_path)
sb.glue('layout', IPython.display.SVG(svg_path), 'display', display=True)
```

## Dump flow report

See [OpenLane Datapoint Definitions](https://github.com/The-OpenROAD-Project/OpenLane/blob/master/regression_results/datapoint_definitions.md) for the description of the report columns.

```python
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

```python
#papermill_description=ExtractingMetrics
import scrapbook as sb

def area_density_ppa():
    for report in sorted(pathlib.Path(run_path).glob('*/reports/metrics.csv')):
        yield (df['FP_CORE_UTIL'][0], df['PL_TARGET_DENSITY'][0], df['power_typical_switching_uW'][0])

df = pd.DataFrame(area_density_ppa(), columns=('DIEAREA_mm^2', 'PL_TARGET_DENSITY', 'power_typical_switching_uW'))
sb.glue('metrics', df, 'pandas')
(df.style.hide_index()
   .format({'area': '{:.8f}', 'density': '{:.2%}', 'power': '{:.8f}'})
   .bar(subset=['power_typical_switching_uW'], color='pink')
   .background_gradient(subset=['PL_TARGET_DENSITY'], cmap='Greens')
   .bar(color='lightblue', vmin=0.001, subset=['DIEAREA_mm^2']))
```

Report metrics for hyper-parameters tuning.

```python
!python -m pip install cloudml-hypertune
```

```python
#papermill_description=ReportingMetrics
import hypertune

total_power = df['power_typical_switching_uW'][0] * 1e6
print('reporting metric:', 'power_typical_switching_uW', total_power)
hpt = hypertune.HyperTune()
hpt.report_hyperparameter_tuning_metric(
    hyperparameter_metric_tag='power_typical_switching_uW',
    metric_value=total_power,
)
```
