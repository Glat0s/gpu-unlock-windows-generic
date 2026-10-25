# Third-party notices

This project incorporates and modifies work from:

- https://github.com/luizwidmer/gpu-unlock-4090-windows ? Windows UEFI platform, ownership, recovery and firmware preparation code.
- https://github.com/impacifist/Windows-GPU-UNLOCK ? Windows/Ampere port lineage.
- https://github.com/JustAResearcher/gpu-unlock-ada ? Ada unlock research and payload lineage.
- https://github.com/Zagitta/gpu-unlock ? Ampere unlock research and benchmarks.

Source files retain SPDX identifiers and copyright notices. The unlock implementation and its derivatives include GPL-2.0-only code (`LICENSES/GPL-2.0-only.txt`); files marked MIT remain MIT. EDK2 headers use BSD-2-Clause-Patent (`LICENSES/EDK2-BSD-2-Clause-Patent.txt`). Preserve additional embedded copyright notices, including NVIDIA and CMP40HX notices in `LICENSES/`.

NVIDIA driver, boot and GSP firmware have separate NVIDIA license terms (`LICENSES/NVIDIA-Driver.txt`, `LICENSES/NVIDIA-MIT.txt`, and the generated `assets/NVIDIA-LICENSE`). Generated firmware is excluded from the source repository. Check the applicable redistribution terms before distributing a binary package. Repository-level attribution does not replace the individual files' license terms.

Local modifications include runtime target discovery, a GPU PCI catalog, architecture selection, Windows Forms USB creation, benchmark reports and release validation. This project has no NVIDIA endorsement. Upstream functionality or test reports do not establish hardware validation of this derivative.
