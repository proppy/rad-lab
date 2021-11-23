#!/usr/bin/python3

# Copyright 2021 Google LLC
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


import os
import sys
import setuptools 
from colorama import Fore, Back, Style

os.system("pip3 install --no-cache-dir -r requirements.txt")

# Installing Pre-requisites.
print(Fore.YELLOW + Style.BRIGHT +"\nINSTALLATION STARTED: Pre-requisites (like terraform binaries, cloud sdk & kubectl)\n"+ Style.RESET_ALL)

try:
    os.system("pip3 install --no-cache-dir -r "+os.getcwd()+"/rad/requirements.txt")
    os.system("python3 "+os.getcwd()+"/rad/terraform_installer.py")
    os.system("python3 "+os.getcwd()+"/rad/cloudsdk_kubectl_installer.py")

    print(Fore.GREEN + Style.BRIGHT +"\nINSTALLTION COMPLETED: Pre-requisites\n"+ Style.RESET_ALL)

except:
    sys.exit(Fore.RED + Style.BRIGHT +"\nINSTALLTION FAILED: Pre-requisites\n"+ Style.RESET_ALL)

# Installing 'rad' command line tool
print(Fore.YELLOW + Style.BRIGHT +"\nINSTALLATION STARTED: 'rad' Command Line Tool\n"+ Style.RESET_ALL)

try:
    setuptools.setup( 
        name='rad', 
        version='1.0', 
        description='Command Line Tool for spinning up RAD Lab modules', 
        packages=setuptools.find_packages(), 
        entry_points={ 
            'console_scripts': [ 
                'rad = rad.radlab:main' 
            ] 
        }, 
        classifiers=[ 
            'Programming Language :: Python :: 3', 
            'License :: OSI Approved :: Apache-2.0 License', 
            'Operating System :: OS Independent', 
        ], 
    )

    print(Fore.GREEN + Style.BRIGHT +"\nINSTALLATION COMPLETED: 'rad' Command Line Tool\n"+ Style.RESET_ALL)
except:
    sys.exit(Fore.RED + Style.BRIGHT +"\nINSTALLTION FAILED: 'rad' Command Line Tool\n"+ Style.RESET_ALL)
