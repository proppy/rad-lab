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
import os

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
    'target_density': hpt.DoubleParameterSpec(min=10, max=100, scale='log'),
    'die_width': hpt.DoubleParameterSpec(min=10, max=300, scale='linear'),
}

metric_spec={'total_power': 'minimize'}
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
                 '--run_path=/tmp']
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
