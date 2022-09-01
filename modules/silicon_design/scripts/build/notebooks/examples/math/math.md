---
jupyter:
  jupytext:
    formats: ipynb,md
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

## Parameter cell with the tag parameters

```python tags=["parameters"]
param_1 = 5
param_2 = 20
```

```python
# Parse string inputs
param_1 = float(param_1)
param_2 = float(param_2)
```

```python
#
product = ((param_1-25)**2+10) * ((param_2-25)**2+10)
```

```python
import hypertune

print('reporting metric:', 'product', product)
hpt = hypertune.HyperTune()
hpt.report_hyperparameter_tuning_metric(
    hyperparameter_metric_tag = 'product',
    metric_value = product,
)
```

```python
import pandas as pd
import scrapbook as sb

df = pd.DataFrame([[param_1, param_2, product]], columns=('param_1', 'param_2', 'product'))
sb.glue('metrics', df, 'pandas')
df
```
