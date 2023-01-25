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
# Parameter Tuning Analysis

```
Copyright 2022 Google LLC.
SPDX-License-Identifier: Apache-2.0
```

This notebook shows how to analyse data from [Vertex AI hyperparameter tuning](https://cloud.google.com/vertex-ai/docs/training/hyperparameter-tuning-overview) jobs.
<!-- #endregion -->

## Define project parameters

```python tags=["parameters"]
import pathlib

worker_image = os.environ['RADLAB_SILICON_CONTAINER']
staging_bucket = os.environ['RADLAB_SILICON_BUCKET']
project = os.environ['RADLAB_SILICON_PROJECT']
location = os.environ['RADLAB_SILICON_LOCATION']
machine_type = 'n1-standard-8'
notebook = 'subservient.ipynb'
prefix = pathlib.Path(notebook).stem
staging_dir = f'{prefix}-tuning'
last_trial_id = 20
```

## Fetch notebooks for all study trials

```python
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
books = sb.read_notebooks(str(dst_dir))
```

```python
import pathlib
import math

import pandas as pd
import tqdm
def metrics():
    for b in tqdm.tqdm(books):
        trial_id = int(pathlib.Path(books[b].filename).stem.split('_')[-1])
        if 'metrics' in books[b].scraps:
            metrics = books[b].scraps['metrics'].data
            yield trial_id, metrics['DIEAREA_mm^2'][0], metrics['PL_TARGET_DENSITY'][0], metrics['TOTAL_POWER'][0]
        else:
            params = books[b].parameters
            die_width_mm = float(params.die_width) / 1000.0
            target_density = float(params.target_density) / 100.0
            yield trial_id, die_width_mm * die_width_mm, target_density, math.nan
        
df = pd.DataFrame.from_records(metrics(), columns=['TRIAL_ID', 'DIEAREA_mm^2', 'PL_TARGET_DENSITY', 'TOTAL_POWER'], index='TRIAL_ID').sort_index()
(df.dropna()
   .sort_values(['DIEAREA_mm^2', 'TOTAL_POWER'], ascending=[True, True])
   .drop_duplicates(['TOTAL_POWER'])
   .style
   .format({'DIEAREA_mm^2': '{:.8f}', 'PL_TARGET_DENSITY': '{:.2%}', 'TOTAL_POWER': '{:.6f}'})
   .bar(subset=['TOTAL_POWER'], color='pink')
   .background_gradient(subset=['PL_TARGET_DENSITY'], cmap='Greens')
   .bar(color='lightblue', vmin=0.001, subset=['DIEAREA_mm^2']))
```

## Plot experiments

```python
import matplotlib.colors
from matplotlib import pyplot as plt

cool =  matplotlib.colormaps['cool']
cool.set_bad(color='none')
ax = df.plot.scatter(x='DIEAREA_mm^2', y='PL_TARGET_DENSITY', c='TOTAL_POWER',
                cmap=cool, s=50, sharex=False, plotnonfinite=True, alpha=1.0, edgecolor='black')
plt.savefig('{prefix}.png')
ax
```

```python
from matplotlib import pyplot as plt
from matplotlib import animation
from matplotlib import cm

from tqdm import tqdm
from IPython.display import Image

min_total_power = df['TOTAL_POWER'].min()
max_total_power = df['TOTAL_POWER'].max()
fig, ax = plt.subplots()
fig.colorbar(cm.ScalarMappable(matplotlib.colors.Normalize(min_total_power, max_total_power), cmap=cool), 
             label='TOTAL_POWER',
             ax=ax)
ax.set_xlabel('DIEAREA_mm^2')
ax.set_ylabel('PL_TARGET_DENSITY')
plt.close(fig) # hide current figure

def generate_frames():
    for n in range(50, last_trial_id, 50):
        batch = df[0:n]
        yield [ax.scatter(
            batch['DIEAREA_mm^2'], batch['PL_TARGET_DENSITY'], c=batch['TOTAL_POWER'],
            s=50, vmin=min_total_power, vmax=max_total_power, cmap=cool, plotnonfinite=True, edgecolor='black')]

frames = list(generate_frames())
anim = animation.ArtistAnimation(fig, frames)
anim.save('{prefix}.gif', writer=animation.PillowWriter(fps=10))
Image('{prefix}.gif')
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


min_total_power = df['TOTAL_POWER'].min()
max_total_power = df['TOTAL_POWER'].max()

def images_with_power():
    for trial_id, trial in df.dropna().iterrows():
        book = books[f'subservient_out_{trial_id}']
        layout = book.scraps['layout']
        f = io.BytesIO(base64.b64decode(layout.display.data['image/png']))
        img = PIL.Image.open(f)#.convert('L')
        total_power = trial['TOTAL_POWER']
        power = (total_power - min_total_power) / (max_total_power - min_total_power)
        yield trial_id, img, power

size = (500, 500)
fig, ax = plt.subplots(figsize=size)
cool = cm.get_cmap('cool')

def generate_frames():
    for trial_id, img, power in tqdm(images_with_power()):
        img = img.resize(size)
        d = PIL.ImageDraw.Draw(img)
        d.text((10, 10), f'SUBSERVIENT_{trial_id}', fill=(255, 255, 255, 255))
        yield img

frames = list(generate_frames())
frames[0].save('allthe{prefix}.gif', save_all=True, loop=0, append_images=frames[1:])
Image('allthe{prefix}.gif')
```
