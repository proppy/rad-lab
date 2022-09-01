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
# Parameter Tuning Sample

```
Copyright 2022 Google LLC.
SPDX-License-Identifier: Apache-2.0
```

This notebook shows how to leverage [Vertex AI hyperparameter tuning](https://cloud.google.com/vertex-ai/docs/training/hyperparameter-tuning-overview) in order to find the right flow parameters value to optimize a given metric.
<!-- #endregion -->

## Define project parameters

```python tags=["parameters"]
import pathlib

worker_image = 'us-east4-docker.pkg.dev/catx-demo-radlab/containers/silicon-design-ubuntu-2004:latest'
staging_bucket = 'catx-demo-radlab-staging'
project = 'catx-demo-radlab'
location = 'us-central1'
machine_type = 'n1-standard-8'
notebook = 'lut.ipynb'
prefix = pathlib.Path(notebook).stem
staging_dir = f'{prefix}-tuning'
last_trial_id = 20
```

## Stage the notebook for the experiment

```python tags=[]
!gsutil cp {notebook} gs://{staging_bucket}/{staging_dir}/{notebook}
```

## Create Parameters and Metrics specs

We want to find the best value for *target density* and *die area* in order optimize *total power* consumption.

Those keys map to the [parameters](https://papermill.readthedocs.io/en/latest/usage-parameterize.html) and [metrics](https://github.com/GoogleCloudPlatform/cloudml-hypertune) advertised by the notebook.

```python tags=[]
from google.cloud.aiplatform import hyperparameter_tuning as hpt

parameter_spec = {
    'pl_target_density': hpt.DoubleParameterSpec(min=0.4, max=0.99, scale='log'),
    'fp_core_util': hpt.DoubleParameterSpec(min=5, max=90, scale='linear'),
}

metric_spec={'power_typical_switching_uW': 'minimize'}
```

## Create Custom Job spec

```python tags=[]
from google.cloud import aiplatform
import pathlib

worker_pool_specs = [{
    'machine_spec': {
        'machine_type': machine_type,
    },
    'replica_count': 1,
    'container_spec': {
        'image_uri': worker_image,
        'args': ['/usr/local/bin/papermill-launcher', 
                 f'gs://{staging_bucket}/{staging_dir}/{notebook}',
                 f'$AIP_MODEL_DIR/{prefix}_out.ipynb',
                 '--run_dir=/tmp']
    }
}]
custom_job = aiplatform.CustomJob(display_name=f'{prefix}-custom-job',
                                  worker_pool_specs=worker_pool_specs,
                                  staging_bucket=staging_bucket,
                                  base_output_dir=f'gs://{staging_bucket}/{staging_dir}')
```

## Run Hyperparameter tuning job

```python tags=[]
from google.cloud import aiplatform
parameters_count = len(parameter_spec.keys())
metrics_count = len(metric_spec.keys())
max_trial_count = 100 * parameters_count * metrics_count
parallel_trial_count = 20

hpt_job = aiplatform.HyperparameterTuningJob(
    display_name=f'{prefix}-tuning-job',
    custom_job=custom_job,
    metric_spec=metric_spec,
    parameter_spec=parameter_spec,
    max_trial_count=max_trial_count,
    parallel_trial_count=parallel_trial_count,
    max_failed_trial_count=max_trial_count)
hpt_job.run(sync=False)
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
books = sb.read_notebooks(str(local_dir))
```

```python tags=[]
import pathlib
import math

import pandas as pd
import tqdm
def metrics():
    for b in tqdm.tqdm(books):
        trial_id = int(pathlib.Path(books[b].filename).stem.split('_')[-1])
        if 'metrics' in books[b].scraps:
            metrics = books[b].scraps['metrics'].data
            yield trial_id, metrics['FP_CORE_UTIL'][0], metrics['PL_TARGET_DENSITY'][0], metrics['power_typical_switching_uW'][0]
        else:
            params = books[b].parameters
            fp_core_util = float(params.fp_core_util)
            pl_target_density = float(params.fp_target_density)
            yield trial_id, fp_core_util, pl_target_density, math.nan
        
df = pd.DataFrame.from_records(metrics(), columns=['TRIAL_ID', 'FP_CORE_UTIL', 'PL_TARGET_DENSITY', 'power_typical_switching_uW'], index='TRIAL_ID').sort_index()
(df.dropna()
   .sort_values(['power_typical_switching_uW'], ascending=[False]).drop_duplicates(['power_typical_switching_uW'])
   .style
   .format({'FP_CORE_UTIL': '{:.2f}', 'PL_TARGET_DENSITY': '{:.2%}', 'TOTAL_POWER': '{:.6f}'})
   .bar(subset=['power_typical_switching_uW'], color='pink')
   .background_gradient(subset=['PL_TARGET_DENSITY'], cmap='Greens')
   .bar(color='lightblue', vmin=0.001, subset=['FP_CORE_UTIL']))
```

## Plot experiments

```python
import matplotlib.colors
from matplotlib import pyplot as plt

cool =  matplotlib.colormaps['cool']
cool.set_bad(color='none')
ax = df.plot.scatter(x='FP_CORE_UTIL', y='PL_TARGET_DENSITY', c='power_typical_switching_uW',
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

min_total_power = df['power_typical_switching_uW'].min()
max_total_power = df['power_typical_switching_uW'].max()
fig, ax = plt.subplots()
fig.colorbar(cm.ScalarMappable(matplotlib.colors.Normalize(min_total_power, max_total_power), cmap=cool), 
             label='power_typical_switching_uW',
             ax=ax)
ax.set_xlabel('FP_CORE_UTIL')
ax.set_ylabel('PL_TARGET_DENSITY')
plt.close(fig) # hide current figure

def generate_frames():
    for n in range(50, last_trial_id, 50):
        batch = df[0:n]
        yield [ax.scatter(
            batch['FP_CORE_UTIL'], batch['PL_TARGET_DENSITY'], c=batch['power_typical_switching_uW'],
            s=50, vmin=min_total_power, vmax=max_total_power, cmap=cool, plotnonfinite=True, edgecolor='black')]

frames = list(generate_frames())
anim = animation.ArtistAnimation(fig, frames)
anim.save('{prefix}.gif', writer=animation.PillowWriter(fps=10))
Image('{prefix}.gif')
```
