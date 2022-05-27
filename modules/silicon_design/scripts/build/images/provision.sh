#!/bin/bash
#
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
trap "echo DaisyFailure: trapped error" ERR

env
OPENLANE_VERSION=master
PROVISION_DIR=/tmp/provision

echo "DaisyStatus: fetching provisioning script"
DAISY_SOURCES_PATH=$(curl -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/attributes/daisy-sources-path)
mkdir -p ${PROVISION_DIR}
gsutil -m rsync ${DAISY_SOURCES_PATH}/provision/ ${PROVISION_DIR}/ || true

echo "DaisyStatus: installing conda-eda environment"
<<<<<<< HEAD
curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -C /usr/local -xvj bin/micromamba
micromamba create --yes -r /opt/conda -n silicon --file ${PROVISION_DIR}/environment.yml
=======
cd /opt/conda && curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
/opt/conda/bin/micromamba install -vvv --yes -p /opt/conda --strict-channel-priority -c litex-hub -c main openroad=2.0_3818_g2ae9162aa open_pdks.sky130a magic netgen yosys=0.17 iverilog xls
/opt/conda/bin/micromamba install -vvv --yes -p /opt/conda --strict-channel-priority -c conda-forge gdstk ngspice-lib tcllib
/opt/conda/bin/python -m pip install pyyaml click pandas pyspice gdsfactory klayout scrapbook[gcs] google-cloud-aiplatform cloudml-hypertune
>>>>>>> fe96f30 (switch to micromamba)

echo "DaisyStatus: installing OpenLane"
git clone --depth 1 -b ${OPENLANE_VERSION} https://github.com/The-OpenROAD-Project/OpenLane /OpenLane

echo "DaisyStatus: patching OpenLane"
cp ${PROVISION_DIR}/install.tcl /OpenLane/configuration/
echo ' install.tcl' >> /OpenLane/configuration/load_order.txt
mkdir -p /OpenLane/install/build/versions
<<<<<<< HEAD
for tool in yosys netgen
do
  /opt/conda/bin/conda list -c ${tool} > /OpenLane/install/build/versions/${tool}
done
=======
cp ${PROVISION_DIR}/env.tcl /OpenLane/install/
# https://github.com/The-OpenROAD-Project/OpenLane/pull/1027
curl --silent  https://patch-diff.githubusercontent.com/raw/The-OpenROAD-Project/OpenLane/pull/1027.patch | patch -d /OpenLane -p1
>>>>>>> fe96f30 (switch to micromamba)

echo "DaisyStatus: adding profile hook"
cp ${PROVISION_DIR}/profile.sh /etc/profile.d/silicon-design-profile.sh

echo "DaisyStatus: adding papermill launcher"
cp ${PROVISION_DIR}/papermill-launcher /usr/local/bin/
chmod +x /usr/local/bin/papermill-launcher

echo "DaisySuccess: done"
