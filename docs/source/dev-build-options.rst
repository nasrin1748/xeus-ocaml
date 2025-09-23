..  Copyright (c) 2025,    

   Distributed under the terms of the GNU General Public License v3.  

   The full license is in the file LICENSE, distributed with this software.

Build and configuration
=======================

General Build Options
---------------------

Building the xeus-ocaml library
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``xeus-ocaml`` build supports the following options:

- ``XEUS_OCAML_BUILD_SHARED``: Build the ``xeus-ocaml`` shared library. **Enabled by default**.
- ``XEUS_OCAML_BUILD_STATIC``: Build the ``xeus-ocaml`` static library. **Enabled by default**.


- ``XEUS_OCAML_USE_SHARED_XEUS``: Link with a `xeus` shared library (instead of the static library). **Enabled by default**.

Building the kernel
~~~~~~~~~~~~~~~~~~~

The package includes two options for producing a kernel: an executable ``xocaml`` and a Python extension module, which is used to launch a kernel from Python.

- ``XEUS_OCAML_BUILD_EXECUTABLE``: Build the ``xocaml``  executable. **Enabled by default**.


If ``XEUS_OCAML_USE_SHARED_XEUS_OCAML`` is disabled, xocaml  will be linked statically with ``xeus-ocaml``.

Building the Tests
~~~~~~~~~~~~~~~~~~

- ``XEUS_OCAML_BUILD_TESTS ``: enables the tets  **Disabled by default**.

