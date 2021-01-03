﻿# How to keep your VM templates up-to-date using packer
https://www.cviorel.com/2020/11/23/how-to-keep-your-vm-templates-up-to-date-using-packer/


| Script         | Description                                                              |
|----------------|--------------------------------------------------------------------------|
| envPrep.ps1    | Allows you to add the packer.exe to your path and enable logging         |
| Get-Packer.ps1 | Checks the version of packer.exe on your system and updates if necessary |
| packer.ps1     | Wrapper script to run the validate and build                             |


## Note
Make sure you update the variables inside the `json\vars.json` file to match your environment.


## Disclaimer
The MIT License

Copyright © 2020 Viorel Ciucu

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.