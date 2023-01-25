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
OPENROAD_FLOW_VERSION=master
PROVISION_DIR=/provision

SYSTEM_NAME=$(dmidecode -s system-product-name || true)

echo "DaisyStatus: install system dependencies"
apt-get update && apt-get -o DPkg::Lock::Timeout=-1 -yq install locales locales-all time

if [ -n "$(echo ${SYSTEM_NAME} | grep 'Google Compute Engine')" ]; then
echo "DaisyStatus: fetching provisioning script"
DAISY_SOURCES_PATH=$(curl -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/attributes/daisy-sources-path)
mkdir -p ${PROVISION_DIR}
gsutil -m rsync ${DAISY_SOURCES_PATH}/provision/ ${PROVISION_DIR}/ || true
fi

echo "DaisyStatus: installing conda-eda environment"
curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -C /usr/local -xvj bin/micromamba
micromamba create --yes -r /opt/conda -n silicon --file ${PROVISION_DIR}/environment.yml

echo "DaisyStatus: installing OpenROAD Flow"
git clone --depth 1 -b ${OPENROAD_FLOW_VERSION} https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts /OpenROAD-flow-scripts

echo "DaisyStatus: adding profile hook"
cp ${PROVISION_DIR}/profile.sh /etc/profile.d/silicon-design-profile.sh

echo "DaisyStatus: adding papermill launcher"
cp ${PROVISION_DIR}/papermill-launcher /usr/local/bin/
chmod +x /usr/local/bin/papermill-launcher

echo "DaisySuccess: done"
