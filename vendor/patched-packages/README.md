This directory contains patched third-party sdists that PLCreX depends on
but which no longer build cleanly on macOS/arm64 with modern compilers.

Currently included:
- `pyeda-0.29.0-patched.tar.gz`: teaches Espresso's C sources to call qsort
  through a helper with the correct `(const void *, const void *)` comparator
  signature so modern clang builds succeed. Rebuild by extracting the upstream
  sdist, adding `set_ptr_qsort` in `setc.c`, swapping the raw `qsort` calls to
  that helper, and re-tarring the tree.
