---
jupyter:
  jupytext:
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.14.0
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


## Run OpenROAD flow

[OpenROAD Flow](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts) is a full RTL-to-GDS flow built entirely on open-source tools. The project aims for automated, no-human-in-the-loop digital circuit design with 24-hour turnaround time.

```python jupyter={"outputs_hidden": true} tags=[]
!cd /OpenROAD-flow-scripts/flow && make SHELL=/bin/bash DESIGN_CONFIG=./designs/asap7/gcd/config.mk
```

<!-- #region tags=[] -->
## Dump flow metrics
<!-- #endregion -->

```python tags=[]
!python /OpenROAD-flow-scripts/flow/util/genMetrics.py
import pathlib
import json
import pandas as pd
from IPython.display import display

pd.set_option('display.max_rows', None)
metrics = sorted(pathlib.Path('/OpenROAD-flow-scripts/flow').glob('reports/asap7/*/base/metrics.json'))
with metrics[-1].open() as f:
    data = json.load(f)
    df = pd.DataFrame.from_records([data]).transpose()
df
```

## Display layout with GDSII Tool Kit

[Gdstk](https://github.com/heitzmann/gdstk) (GDSII Tool Kit) is a C++/Python library for creation and manipulation of GDSII and OASIS files.

```python tags=[]
import pathlib
import gdstk
from IPython.display import SVG

gds = sorted(pathlib.Path('/OpenROAD-flow-scripts/flow').glob('results/asap7/*/base/6_final.gds'))
library = gdstk.read_gds(gds[-1])
top_cells = library.top_level()
top_cells[0].write_svg('layout.svg')
SVG('layout.svg')
```
