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

<!-- #region tags=[] -->
# Parameter Tuning Analysis

```
Copyright 2022 Google LLC.
SPDX-License-Identifier: Apache-2.0
```

This notebook shows how to analyse data from [Vertex AI hyperparameter tuning](https://cloud.google.com/vertex-ai/docs/training/hyperparameter-tuning-overview) jobs.
<!-- #endregion -->

<!-- #region tags=[] -->
## Define project parameters
<!-- #endregion -->

```python tags=["parameters"]
import pathlib

worker_image = os.environ['RADLAB_SILICON_CONTAINER']
staging_bucket = os.environ['RADLAB_SILICON_BUCKET']
project = os.environ['RADLAB_SILICON_PROJECT']
location = os.environ['RADLAB_SILICON_LOCATION']
notebook = pathlib.Path('asap7.ipynb')
prefix = notebook.stem
staging_dir = 'asap7-tuning-20220804141156'
```

## Fetch notebooks for all study trials

```python
last_trial_id = 16

import pathlib
from google.cloud import storage
import tqdm

local_dir = pathlib.Path(staging_dir)
local_dir.mkdir(exist_ok=True, parents=True)

client = storage.Client()
bucket = client.bucket(staging_bucket)
for i in tqdm.tqdm(range(1, last_trial_id+1)):
    src = bucket.blob(f'{staging_dir}/{i}/model/{prefix}_out.ipynb')
    dst = local_dir / f'{prefix}_out_{i}.ipynb'
    with dst.open('wb') as f:
        src.download_to_file(f)
```

## Extract metrics from notebooks

```python tags=[]
import scrapbook as sb
books = sb.read_notebooks(staging_dir)
```

```python
 import pathlib
import math

import pandas as pd
import tqdm
def metrics():
    for b in tqdm.tqdm(books):
        trial_id = int(pathlib.Path(books[b].filename).stem.split('_')[-1])
        params = books[b].parameters
        die_width_u = 90 #float(params.die_width)
        target_density = 0.6 #float(params.target_density)
        crc32_rounds = 8 #int(params.crc32_rounds)
        pipeline_stages = int(params.pipeline_stages)
        if ('ppa' in books[b].scraps) and not books[b].scraps['ppa'].data.empty:
            metrics = books[b].scraps['metrics'].data
            ppa = books[b].scraps['ppa'].data
            yield trial_id, crc32_rounds, pipeline_stages, die_width_u, target_density, metrics['globalroute__timing__clock__slack'][0], metrics['finish__design__instance__utilization'][0] / 100.0, ppa['slack'][0], metrics['globalroute__timing__clock__slack'][0], metrics['finish__timing__setup__ws'][0], metrics['finish__timing__cp_delay'][0], ppa['power'][0]
        else:
            yield trial_id, crc32_rounds, pipeline_stages, die_width_u, target_density, math.nan, math.nan,  math.nan,  math.nan
        
df = pd.DataFrame.from_records(metrics(), columns=['trial_id', 'crc32_rounds', 'pipeline_stages', 'die_width^2', 'target_density', 'finish__design__instance__area', 'finish__design__instance__utilization', 'critical_path_slack', 'globalroute__timing__clock__slack', 'finish__timing__setup__ws', 'finish__timing__cp_delay', 'power'], index='trial_id').sort_index()
df.to_csv(f'{prefix}.csv')
(df.sort_values(['pipeline_stages', 'finish__timing__setup__ws'], ascending=[True, True])
   .style
   .format({'finish__design__instance__area': '{:.8f}', 'finish__design__instance__utilization': '{:.2%}', 'finish__timing__setup__ws': '{:.6f}'})
   .background_gradient(subset=['crc32_rounds'], cmap='Blues')
   .background_gradient(subset=['pipeline_stages'], cmap='Oranges')
   .bar(subset=['critical_path_slack'], color='pink')
   .bar(subset=['globalroute__timing__clock__slack'], color='pink')
   .bar(subset=['finish__timing__setup__ws'], color='pink')
   .bar(subset=['finish__timing__cp_delay'], color='pink')
   .bar(subset=['power'], color='pink')
   .background_gradient(subset=['finish__design__instance__utilization'], cmap='Greens')
   .bar(color='lightblue', vmin=0.001, subset=['finish__design__instance__area']))
```

## Plot experiments

```python
ax = pd.plotting.scatter_matrix(df, figsize=(30, 30))
plt.savefig(f'{prefix}_matrix.png')
ax
```

```python
import matplotlib.colors
from matplotlib import pyplot as plt

cool =  matplotlib.colormaps['cool']
cool.set_bad(color='none')
ax = df.plot.scatter(x='pipeline_stages', y='finish__timing__setup__ws', c='finish__timing__cp_delay',
                cmap=cool, s=50, sharex=False, alpha=1.0, edgecolor='black')
plt.savefig(f'{prefix}.png')
ax
```

```python tags=[]
from matplotlib import pyplot as plt
from matplotlib import animation
from matplotlib import cm

from tqdm import tqdm
from IPython.display import Image

min_metric = df['slack'].min()
max_metric = df['slack'].max()
fig, ax = plt.subplots()
fig.colorbar(cm.ScalarMappable(matplotlib.colors.Normalize(min_metric, max_metric), cmap=cool), 
             label='slack',
             ax=ax)
ax.set_xlabel('area')
ax.set_ylabel('pipelines')
plt.close(fig) # hide current figure

def generate_frames():
    for n in range(20, last_trial_id, 20):
        batch = df[0:n]
        yield [ax.scatter(
            batch['area'], batch['pipelines'], c=batch['slack'],
            s=50, vmin=min_metric, vmax=max_metric, cmap=cool, edgecolor='black')]

frames = list(generate_frames())
anim = animation.ArtistAnimation(fig, frames)
anim.save(f'{prefix}.gif', writer=animation.PillowWriter(fps=10))
Image(f'{prefix}.gif')
```

## Render chip layouts

```python
from matplotlib import pyplot as plt
from matplotlib import animation
from matplotlib import cm
from tqdm import tqdm
from IPython.display import Image
from time import sleep
import matplotlib.colors
import io
import base64
import PIL
import PIL.ImageOps
import PIL.ImageDraw
import numpy as np

def trial_images():
    for trial_id, trial in df.dropna().sort_values(['trial_id'], ascending=[True]).iterrows():
        book = books[f'asap7_out_{trial_id}']
        layout = book.scraps['layout']
        f = io.BytesIO(base64.b64decode(layout.display.data['image/png']))
        img = PIL.Image.open(f)#.convert('L')
        yield trial_id, img

size = (500, 500)
fig, ax = plt.subplots(figsize=size)

def generate_frames():
    for trial_id, img in tqdm(trial_images()):
        img = img.resize(size)
        d = PIL.ImageDraw.Draw(img)
        d.text((10, 10), f'CRC32_ASAP7_{trial_id}', fill=(255, 255, 255, 255))
        yield img

frames = list(generate_frames())
frames[0].save(f'allthe{prefix}.gif', save_all=True, loop=0, append_images=frames[1:])
Image(f'allthe{prefix}.gif')
```

```python
len(df.dropna())
```
