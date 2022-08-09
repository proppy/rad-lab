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

# CFU Playground


### Design Space Exploration

```python tags=["parameters"]
# Vexriscv soft core parameters available for tuning
bypass            = True
cfu               = True
dCacheSize        = 2048
hardwareDiv       = True
iCacheSize        = 1024
mulDiv            = True
prediction        = "none"
safe              = True
singleCycleShift  = True
singleCycleMulDiv = True
```

```python
# Constants 
CSR_PLUGIN_CONFIG = "mcycle"
TARGET            = "digilent_arty"
```

```python
# Change directory to design space exploration project in CFU-Playground
%cd /CFU-Playground/proj/dse_template
```

```python tags=[]
import dse_framework

dse_framework.dse(CSR_PLUGIN_CONFIG, bypass, cfu, dCacheSize, hardwareDiv, iCacheSize, mulDiv, prediction, safe, singleCycleShift, singleCycleMulDiv)
```

```python tags=[]
# Obtain metrics and glue to notebook for later use
import scrapbook as sb

cycles = dse_framework.get_cycle_count()
cells  = dse_framework.get_resource_util(TARGET)

sb.glue('cells', cells)
sb.glue('cycles', cycles)

print("Cycle Count: " + str(cycles))
print("Cells Used:  " + str (cells))
```

```python
import hypertune

print('Reporting Metric:', 'Cells^2 + Cycles',   (cells*cells) + cycles)
hpt = hypertune.HyperTune()
hpt.report_hyperparameter_tuning_metric(
    hyperparameter_metric_tag='cells+cycles',
    metric_value=((cells*cells) + cycles),
)
```
