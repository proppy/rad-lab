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

## Define project parameters

```python tags=["parameters"]
import pathlib

worker_image = 'us-east4-docker.pkg.dev/catx-demo-radlab/containers/silicon-design-ubuntu-2004:latest'
staging_bucket = 'catx-demo-radlab-staging'
project = 'catx-demo-radlab'
location = 'us-central1'
machine_type = 'n1-standard-8'
notebook = 'minimal_job.ipynb'
prefix = pathlib.Path(notebook).stem
staging_dir = f'{prefix}-tuning'
```

## Delete data from previous runs and stage the notebook for the experiment

```python tags=[]
!rm -r {staging_dir}
!gsutil rm -r gs://{staging_bucket}/{staging_dir}/
!gsutil cp {notebook} gs://{staging_bucket}/{staging_dir}/{notebook}
```

## Create Parameters and Metrics specs

We want to find the best value for *target density* and *die area* in order optimize *total power* consumption.

Those keys map to the [parameters](https://papermill.readthedocs.io/en/latest/usage-parameterize.html) and [metrics](https://github.com/GoogleCloudPlatform/cloudml-hypertune) advertised by the notebook.

```python tags=[]
from google.cloud.aiplatform import hyperparameter_tuning as hpt

parameter_spec = {
    'param_1': hpt.DoubleParameterSpec(min=10, max=100, scale='linear'),
    'param_2': hpt.DoubleParameterSpec(min=10, max=300, scale='linear'),
}

metric_spec={'product': 'minimize'}
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

## Check the current state

```python
[(job.display_name, job.done(), job.state) for job in aiplatform.HyperparameterTuningJob.list(filter=f'display_name={prefix}-tuning-job') if not job.done()]
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
for i in tqdm.tqdm(range(1, max_trial_count+1)):
    src = bucket.blob(f'{staging_dir}/{i}/model/{prefix}_out.ipynb')
    if not src.exists():
        break
    dst = local_dir / f'{prefix}_out_{i}.ipynb'
    with dst.open('wb') as f:
        src.download_to_file(f)
```

## Extract metrics from notebooks

```python tags=[]
import scrapbook as sb
books = sb.read_notebooks(str(local_dir))
```

```python
import pathlib
import math
import pandas as pd
import tqdm

def metrics():
    for b in tqdm.tqdm(books):
        trial_id = int(pathlib.Path(books[b].filename).stem.split('_')[-1])
        param_1 = float(books[b].parameters.param_1)
        param_2 = float(books[b].parameters.param_2)
        
        if 'metrics' in books[b].scraps:
            metrics = books[b].scraps['metrics'].data
            yield trial_id, param_1, param_2, metrics['product'][0]
        else:
            yield trial_id, param_1, param_2, math.nan
        
df = pd.DataFrame.from_records(metrics(), columns=['TRIAL_ID', 'param_1', 'param_2', 'product'], index='TRIAL_ID').sort_index()

df.sort_values(['product'], ascending=[True]).style.bar(color='lightblue', vmin=0.001, subset=['product']).background_gradient(subset=['param_1'], cmap='Greens').background_gradient(subset=['param_2'], cmap='Blues')
```

## Plot experiments

```python
import matplotlib.colors
from matplotlib import pyplot as plt

cool =  matplotlib.colormaps['cool']
cool.set_bad(color='none')
ax = df.plot.scatter(x='param_1', y='param_2', c='product',
                cmap=cool, s=50, sharex=False, plotnonfinite=True, alpha=1.0, edgecolor='black')
plt.savefig('{prefix}.png')
ax
```

```python

```
