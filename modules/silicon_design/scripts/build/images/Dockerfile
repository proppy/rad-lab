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

FROM gcr.io/deeplearning-platform-release/base-cpu
RUN apt-get update && apt-get -yq install locales locales-all

ENV OPENLANE_VERSION=master
ENV PROVISION_DIR=/tmp/provision
RUN cd /opt/conda && curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
RUN rm /opt/conda/.condarc
RUN /opt/conda/bin/micromamba install -vvv --yes --strict-channel-priority -p /opt/conda -c litex-hub -c main openroad=2.0_3976* open_pdks.sky130a=1.0.313* magic netgen yosys=0.17* iverilog
RUN /opt/conda/bin/micromamba install -vvv --yes --strict-channel-priority -p /opt/conda -c litex-hub -c conda-forge xls gdstk pyspice tcllib pymeep=*=mpi_mpich_*
RUN /opt/conda/bin/python -m pip install pyyaml click pandas gdsfactory klayout scrapbook[gcs] google-cloud-aiplatform cloudml-hypertune
RUN git clone --depth 1 -b ${OPENLANE_VERSION} https://github.com/The-OpenROAD-Project/OpenLane /OpenLane
COPY provision/env.tcl /OpenLane/install/
RUN curl --silent  https://patch-diff.githubusercontent.com/raw/The-OpenROAD-Project/OpenLane/pull/1027.patch | patch -d /OpenLane -p1

COPY provision/profile.sh /etc/profile.d/silicon-design-profile.sh
COPY provision/papermill-launcher /usr/local/bin/

ENV OPENLANE_ROOT=/OpenLane
ENV PATH=$OPENLANE_ROOT:$OPENLANE_ROOT/scripts:$PATH
