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

<!-- #region id="N4LqLHCjMD1B" -->
# OpenRAM SKY130 playground

Generate OpenRAM macros with `open_pdks.sky130a`.
<!-- #endregion -->

<!-- #region id="8KOnNeUOMMRp" -->
## Install dependencies

Using conda packages from https://github.com/hdl/conda-eda.
<!-- #endregion -->

```python colab={"base_uri": "https://localhost:8080/"} id="8zaG4mCd4-Ti" outputId="33408422-77f4-4d7b-cc28-086f699bdb87"
!pip install -q condacolab
import condacolab
condacolab.install()
```

```python colab={"base_uri": "https://localhost:8080/"} id="twnZMX905E-U" outputId="cc15b371-edb5-4d09-c4cb-26c41c551031"
import condacolab
condacolab.check()
```

```python colab={"base_uri": "https://localhost:8080/"} id="emiyv2qr6SnS" outputId="544c3046-62e1-4e4b-f0f8-06a848a3bbcd"
!conda install -c LiteX-Hub -y open_pdks.sky130a magic
!conda install -y gdstk cairosvg
```

```python colab={"base_uri": "https://localhost:8080/"} id="Rh8PYcraHuXI" outputId="e2e5ea0a-2403-42e2-8c7b-84acc267b3da"
!conda install https://anaconda.org/LiteX-Hub/netgen/1.5.219_0_ge11dbac/download/linux-64/netgen-1.5.219_0_ge11dbac-20220222_104027.tar.bz2
```

<!-- #region id="LU9DBl5wMXJI" -->
## Get OpenRAM

Get latest release and install requirements from PyPI.
<!-- #endregion -->

```python colab={"base_uri": "https://localhost:8080/"} id="jesuQ3pG5NmR" outputId="d219bfb3-b588-4890-dee9-618bcd3be50c"
!git clone -b v1.1.19 https://github.com/VLSIDA/OpenRAM.git
!python -m pip install -r OpenRAM/requirements.txt
```

```python colab={"base_uri": "https://localhost:8080/"} id="uNqPoSUB5fOS" outputId="64302d22-4a96-47cf-bee5-763f55cc082b"
%%writefile config.py
"""
Pseudo-dual port (independent read and write ports), 8bit word, 1 kbyte SRAM.
Useful as a byte FIFO between two devices (the reader and the writer).
"""
word_size = 8 # Bits
num_words = 1024
human_byte_size = "{:.0f}kbytes".format((word_size * num_words)/1024/8)

# Allow byte writes
#write_size = 8 # Bits

# Dual port
num_rw_ports = 0
num_r_ports = 1
num_w_ports = 1
ports_human = '1r1w'

tech_name = "sky130"
nominal_corner_only = True

# Local wordlines have issues with met3 power routing for now
#local_array_size = 16

route_supplies = "ring"
#route_supplies = "left"
check_lvsdrc = True
uniquify = True
#perimeter_pins = False
#netlist_only = True
#analytical_delay = False

output_name = "sky130_sram_1kbyte_1r1w_8x1024_8"
output_path = "."
```

```python colab={"base_uri": "https://localhost:8080/"} id="RT6Zj3BE5nGS" outputId="0626d1d5-e8e0-4786-e4c0-304882b470fa"
%env OPENRAM_HOME=/content/OpenRAM/compiler
%env OPENRAM_TECH=/content/OpenRAM/technology/sky130
%env PDK_ROOT=/usr/local/share/pdk
%env PYTHONPATH=/env/python:/content/OpenRAM/compiler:/content/OpenRAM/technology:/content/OpenRAM/technology/sky130/modules
!make -C OpenRAM SRAM_GIT_REPO=https://github.com/google/skywater-pdk-libs-sky130_fd_bd_sram.git
!python $OPENRAM_HOME/openram.py config.py
```

```python colab={"base_uri": "https://localhost:8080/", "height": 1000} id="NUSqt4xDL4Iu" outputId="f5cf3b6d-3e64-423d-f83e-7a000b57ec63"
import gdstk
library = gdstk.read_gds("sky130_sram_1kbyte_1r1w_8x1024_8.gds")
top_cells = library.top_level()
top_cells[0].write_svg('sky130_sram_1kbyte_1r1w_8x1024_8.svg')
import cairosvg
cairosvg.svg2png(url='sky130_sram_1kbyte_1r1w_8x1024_8.svg', write_to='sky130_sram_1kbyte_1r1w_8x1024_8.png')
from IPython.display import Image
Image('sky130_sram_1kbyte_1r1w_8x1024_8.png')
```
