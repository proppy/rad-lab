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
RUN /opt/conda/bin/conda install --yes --prefix /opt/conda/ mamba
COPY provision/environment.yml $PROVISION_DIR/
RUN /opt/conda/bin/mamba env update --prefix /opt/conda/ --file /tmp/provision/environment.yml

RUN git clone --depth 1 -b ${OPENLANE_VERSION} https://github.com/The-OpenROAD-Project/OpenLane /OpenLane
COPY provision/env.tcl /OpenLane/install/
RUN mkdir -p /OpenLane/install/build/versions
RUN /opt/conda/bin/conda list -c yosys > /OpenLane/install/build/versions/yosys
RUN /opt/conda/bin/conda list -c netgen > /OpenLane/install/build/versions/netgen
RUN sed -i -z 's/}\n\ \ \ \ "/},\n    "/' /opt/conda/share/pdk/sky130A/.config/nodeinfo.json
RUN curl --silent  https://patch-diff.githubusercontent.com/raw/The-OpenROAD-Project/OpenLane/pull/1027.patch | patch -d /OpenLane -p1

COPY provision/profile.sh /etc/profile.d/silicon-design-profile.sh
COPY provision/papermill-launcher /usr/local/bin/

ENV OPENLANE_ROOT=/OpenLane
ENV PATH=$OPENLANE_ROOT:$OPENLANE_ROOT/scripts:$PATH
