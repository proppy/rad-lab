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
worker_image = 'us-central1-docker.pkg.dev/catx-demo-radlab/containers/silicon-design-ubuntu-2004:latest'
staging_bucket = 'gs://catx-demo-radlab-staging'
project = 'catx-demo-radlab'
location = 'us-central1'
```

## Stage the notebook for the experiment

```python tags=[]
!gsutil mb {staging_bucket}
!gsutil cp inverter.ipynb {staging_bucket}/inverter.ipynb
```

## Create Parameters and Metrics specs

We want to find the best value for *target density* and *die area* in order optimize *total power* consumption.

Those keys map to the [parameters](https://papermill.readthedocs.io/en/latest/usage-parameterize.html) and [metrics](https://github.com/GoogleCloudPlatform/cloudml-hypertune) advertised by the notebook.

```python tags=[]
from google.cloud.aiplatform import hyperparameter_tuning as hpt

parameter_spec = {
    'target_density': hpt.DoubleParameterSpec(min=10, max=100, scale='log'),
    'die_width': hpt.DoubleParameterSpec(min=10, max=300, scale='linear'),
}

metric_spec={'total_power': 'minimize'}
```

## Create Custom Job spec

```python tags=[]
from google.cloud import aiplatform

worker_pool_specs = [{
    'machine_spec': {
        'machine_type': 'n1-standard-4',
    },
    'replica_count': 1,
    'container_spec': {
        'image_uri': worker_image,
        'args': ['/usr/local/bin/papermill-launcher', 
                 f'{staging_bucket}/inverter8.ipynb',
                 '$AIP_MODEL_DIR/inverter_out.ipynb',
                 '--run_dir=/tmp']
    }
}]

custom_job = aiplatform.CustomJob(display_name='inverter-flow-job',
                              worker_pool_specs=worker_pool_specs,
                              staging_bucket=staging_bucket)
```

## Run Hyperparameter tuning job

```python tags=[]
from google.cloud import aiplatform

hpt_job = aiplatform.HyperparameterTuningJob(
    display_name='inverter-tuning-job',
    custom_job=custom_job,
    metric_spec=metric_spec,
    parameter_spec=parameter_spec,
    max_trial_count=200,
    parallel_trial_count=10,
    max_failed_trial_count=200)

hpt_job.run()
```

## Extract experiment notebooks
```python
import scrapbook as sb
from google.cloud import storage
import tqdm

client = storage.Client()
staging_bucket = client.bucket('catx-demo-radlab-staging')
results_bucket = client.bucket('catx-demo-radlab-results')
for i in tqdm.tqdm(range(1, 501)):
    src = staging_bucket.blob(f'aiplatform-custom-job-2022-04-07-16:02:35.153/{i}/model/serv_out.ipynb')
    try:
        blob = staging_bucket.copy_blob(
        staging_bucket.blob(f'aiplatform-custom-job-2022-04-07-16:02:35.153/{i}/model/serv_out.ipynb'),
            results_bucket,
            f'aiplatform-custom-job-2022-04-07-16:02:35.153/serv_out_{i}.ipynb'
        )
    except Exception as e:
        print(f'error extracting experiment {i}:', e)
```

```python tags=[]
import scrapbook as sb
books = sb.read_notebooks('gs://aiplatform-custom-job-2022-04-07-16:02:35.153/')
```

## Aggregate experiments results
```python
import pandas as pd
import tqdm

def metrics():
    for b in tqdm.tqdm(books):
        if 'metrics' in books[b].scraps:
            yield books[b].scraps['metrics'].data
        
df = pd.concat(metrics(), ignore_index=True)
(df.sort_values(['TOTAL_POWER']).style
   .format({'area': '{:.8f}', 'density': '{:.2%}', 'power': '{:.8f}'})
   .bar(subset=['TOTAL_POWER'], color='pink')
   .background_gradient(subset=['PL_TARGET_DENSITY'], cmap='Greens')
   .bar(color='lightblue', vmin=0.001, subset=['DIEAREA_mm^2']))
```

## Plot power against area/density
```python
df.plot.scatter(x='DIEAREA_mm^2', y='PL_TARGET_DENSITY', c='TOTAL_POWER',
                cmap='cool', s=200, sharex=False)
```

## Visualize experiments chronologically
```python
from matplotlib import pyplot as plt
from matplotlib import animation
from tqdm import tqdm
from IPython.display import Image
from time import sleep
import matplotlib.colors

min_total_power = df['TOTAL_POWER'].min()
max_total_power = df['TOTAL_POWER'].max()
fig, ax = plt.subplots()
fig.colorbar(cm.ScalarMappable(matplotlib.colors.Normalize(min_total_power, max_total_power), cmap='cool'), 
             label='TOTAL_POWER',
             ax=ax)
ax.set_xlabel('DIEAREA_mm^2')
ax.set_xlabel('PL_TARGET_DENSITY')

def generate_frames():
    for n in range(10, 500, 10):
        batch = df[0:n]
        yield [ax.scatter(
            batch['DIEAREA_mm^2'], batch['PL_TARGET_DENSITY'], c=batch['TOTAL_POWER'],
            s=50, vmin=min_total_power, vmax=max_total_power, cmap='cool')]
frames = list(generate_frames())
anim = animation.ArtistAnimation(fig, frames)
anim.save('serv.gif', writer=animation.PillowWriter(fps=10))
Image('serv.gif')
```

## Map all the generate layouts
```python
from tqdm import tqdm
import io
import base64
import PIL

fig, axs = plt.subplots(25, 20, figsize=(100, 100))
axs = axs.flatten()

min_total_power = df['TOTAL_POWER'].min()
max_total_power = df['TOTAL_POWER'].max()

def images_with_power(n):
    for i, b in enumerate(books):
        book = books[b]
        if 'layout' in book.scraps:
            metrics = book.scraps['metrics']
            layout = book.scraps['layout']
            f = io.BytesIO(base64.b64decode(layout.display.data['image/png']))
            img = PIL.Image.open(f).convert('L')
            total_power = metrics.data['TOTAL_POWER'][0]
            power = (total_power - min_total_power) / (max_total_power - min_total_power)
            yield img, power
        else:
            yield PIL.Image.new('RGBA', (100, 100)).convert('L'), 0
        if i == n-1:
            break

cool = cm.get_cmap('cool')

for i, (img, power) in tqdm(enumerate(images_with_power(500))):
    color = np.array(cool(power)) * 255
    axs[i].imshow(PIL.ImageOps.colorize(img, (0, 0, 0, 255), color))
fig.savefig('ALLTHESERVs.png')
fig
```
