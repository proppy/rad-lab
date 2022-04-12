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
