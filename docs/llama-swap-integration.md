# llama-swap Integration

This document explains the llama-swap integration architecture and usage.

## Overview

[llama-swap](https://github.com/mostlygeek/llama-swap) is a utility for managing swap space for large language models. It has been integrated into all AMD Strix Halo toolbox images as an optional component.

## Architecture

### Multi-Stage Build Approach

The integration uses Docker's multi-stage build with external build contexts:

1. **`Dockerfile.llama-swap`**: Standalone Dockerfile that downloads and extracts llama-swap binary
   - Downloads from GitHub releases (supports versioning)
   - Works for both x86_64 (amd64) and aarch64 (arm64)
   - Exports binary at `/tmp/llama-swap`

2. **Toolbox Dockerfiles**: Import llama-swap conditionally
   - Import stage references external build context
   - Conditional installation based on `INCLUDE_LLAMA_SWAP` build arg
   - Binary placed in `/usr/local/bin/llama-swap` when enabled

### Build Context Flow

```
Dockerfile.llama-swap (external context)
    ↓
    [llama-swap-builder stage]
    ↓
    /tmp/llama-swap binary
    ↓
Toolbox Dockerfile imports as "llama-swap-import"
    ↓
Conditional COPY to runtime stage
    ↓
/usr/local/bin/llama-swap (if INCLUDE_LLAMA_SWAP=1)
```

## Usage

### Local Builds

#### Without llama-swap (default):
```bash
cd toolboxes
podman build -f Dockerfile.rocm-7.1-rocwmma -t my-image .
```

#### With llama-swap:
```bash
cd toolboxes
podman build \
  --build-context llama-swap=Dockerfile.llama-swap \
  --build-arg INCLUDE_LLAMA_SWAP=1 \
  -f Dockerfile.rocm-7.1-rocwmma \
  -t my-image .
```

#### With specific llama-swap version:
```bash
cd toolboxes
podman build \
  --build-context llama-swap=Dockerfile.llama-swap \
  --build-arg INCLUDE_LLAMA_SWAP=1 \
  --build-arg LLAMA_SWAP_VERSION=v0.5.0 \
  -f Dockerfile.rocm-7.1-rocwmma \
  -t my-image .
```

### CI/CD (GitHub Actions)

The workflow supports an `include_llama_swap` input:

1. Go to **Actions** → **Build & Publish AMD Strix Halo Toolboxes**
2. Click **Run workflow**
3. Select backends to build
4. Set `include_llama_swap` to **true**

Images with llama-swap get `-llamaswap` appended to their tag:
- Standard: `rocm-7.1-rocwmma`
- With llama-swap: `rocm-7.1-rocwmma-llamaswap`

## Implementation Details

### Modified Files

All 16 toolbox Dockerfiles were modified:
- `Dockerfile.vulkan-radv`
- `Dockerfile.vulkan-amdvlk`
- `Dockerfile.rocm-6.4.2` through `Dockerfile.rocm-7rc-rocwmma`

### Changes Per Dockerfile

1. **Builder stage**: Added `ARG INCLUDE_LLAMA_SWAP=0`
2. **Import stage**: Added between builder and runtime
   ```dockerfile
   FROM llama-swap:llama-swap-builder AS llama-swap-import
   ```
3. **Runtime stage**: Added `ARG INCLUDE_LLAMA_SWAP=0`
4. **Installation**: Added conditional COPY and cleanup
   ```dockerfile
   COPY --from=llama-swap-import /tmp/llama-swap /usr/local/bin/llama-swap
   RUN if [ "${INCLUDE_LLAMA_SWAP}" = "1" ]; then \
         chmod +x /usr/local/bin/llama-swap && \
         echo "llama-swap installed successfully"; \
       else \
         rm -f /usr/local/bin/llama-swap && \
         echo "llama-swap not included in this build"; \
       fi
   ```

## Testing

A test script is provided: `toolboxes/test-llama-swap-build.sh`

```bash
cd toolboxes
./test-llama-swap-build.sh
```

This validates:
1. llama-swap Dockerfile builds successfully
2. Images build without llama-swap (default)
3. Images build with llama-swap when enabled
4. llama-swap binary is present/absent as expected

## Why This Approach?

### Benefits

1. **Non-invasive**: Default builds unchanged, no extra binary in standard images
2. **Flexible**: Users can choose to include llama-swap or not
3. **Maintainable**: Single source (`Dockerfile.llama-swap`) for llama-swap
4. **Version control**: Can pin specific llama-swap versions
5. **CI/CD ready**: Easy to toggle in automated builds

### Alternatives Considered

- **Always include**: Would bloat standard images unnecessarily
- **Separate Dockerfiles**: Would require maintaining 32 Dockerfiles instead of 16
- **Runtime installation**: Would require network access in containers
- **Static URL in each Dockerfile**: Would duplicate download logic 16 times

## Future Enhancements

Potential improvements:

1. **Automated llama-swap updates**: CI job to check for new releases
2. **Multi-version support**: Build matrix for different llama-swap versions
3. **Verification**: Add checksum validation for downloaded binaries
4. **Documentation**: Add llama-swap usage examples in README

## References

- [llama-swap GitHub Repository](https://github.com/mostlygeek/llama-swap)
- [Docker BuildKit Build Contexts](https://docs.docker.com/build/building/context/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
