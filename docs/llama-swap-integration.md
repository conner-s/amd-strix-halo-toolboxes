# llama-swap Integration

This document explains the llama-swap integration architecture and usage.

## Overview

[llama-swap](https://github.com/mostlygeek/llama-swap) is a utility for automatically stopping the llama-server application and restarting it with a new model. It has been integrated into all AMD Strix Halo toolbox images as an optional component.

## Architecture

### Multi-Stage Build Approach

The integration uses Docker's multi-stage build with llama-swap as the final optional stage:

1. **`Dockerfile.llama-swap`**: Standalone Dockerfile that downloads and extracts llama-swap binary
   - Downloads from GitHub releases (supports versioning)
   - Works for both x86_64 (amd64) and aarch64 (arm64)
   - Exports binary at `/tmp/llama-swap`

2. **Toolbox Dockerfiles**: Multi-stage structure with llama-swap as final stage
   - `runtime` stage: Complete working image without llama-swap
   - `llama-swap-import` stage: Imports from external build context
   - `runtime-with-llamaswap` stage: Final stage with llama-swap added
   - Binary placed in `/usr/local/bin/llama-swap`

### Build Context Flow

```
Dockerfile.llama-swap (external context)
    ↓
    [llama-swap-builder stage]
    ↓
    /tmp/llama-swap binary
    ↓
Toolbox Dockerfile has three key stages:
    ↓
    [runtime stage] ← Build stops here with --target runtime (no llama-swap)
    ↓
    [llama-swap-import stage] ← Imports from external context
    ↓
    [runtime-with-llamaswap stage] ← Final stage (default build target)
    ↓
/usr/local/bin/llama-swap
```

## Usage

### Local Builds

#### Without llama-swap (stops at `runtime` stage):
```bash
cd toolboxes
podman build --target runtime -f Dockerfile.rocm-7.1-rocwmma -t my-image .
```

This builds only up to the `runtime` stage and doesn't require the llama-swap build context.

#### With llama-swap (builds all stages including final):
```bash
cd toolboxes
podman build \
  --build-context llama-swap=Dockerfile.llama-swap \
  -f Dockerfile.rocm-7.1-rocwmma \
  -t my-image .
```

This builds all stages including the final `runtime-with-llamaswap` stage.

#### With specific llama-swap version:
```bash
cd toolboxes
podman build \
  --build-context llama-swap=Dockerfile.llama-swap \
  --build-arg LLAMA_SWAP_VERSION=v0.5.0 \
  -f Dockerfile.rocm-7.1-rocwmma \
  -t my-image .
```

### CI/CD (GitHub Actions)

The workflow supports an `include_llama_swap` input:

1. Go to **Actions** → **Build & Publish AMD Strix Halo Toolboxes**
2. Click **Run workflow**
3. Select backends to build
4. Set `include_llama_swap` to:
   - **false** (default): Builds with `--target runtime` (no llama-swap)
   - **true**: Builds complete image including llama-swap stage

Images with llama-swap get `-llamaswap` appended to their tag:
- Standard: `rocm-7.1-rocwmma` (built with `--target runtime`)
- With llama-swap: `rocm-7.1-rocwmma-llamaswap` (built without `--target`)

## Implementation Details

### Modified Files

All 16 toolbox Dockerfiles were modified:
- `Dockerfile.vulkan-radv`
- `Dockerfile.vulkan-amdvlk`
- `Dockerfile.rocm-6.4.2` through `Dockerfile.rocm-7rc-rocwmma`

### Changes Per Dockerfile

1. **Runtime stage**: Named as `runtime` to allow targeting
   ```dockerfile
   FROM registry.fedoraproject.org/fedora-minimal:43 AS runtime
   ```

2. **llama-swap import stage**: Added after runtime stage
   ```dockerfile
   FROM llama-swap:llama-swap-builder AS llama-swap-import
   ```

3. **Final stage**: Added as `runtime-with-llamaswap`
   ```dockerfile
   FROM runtime AS runtime-with-llamaswap
   COPY --from=llama-swap-import /tmp/llama-swap /usr/local/bin/llama-swap
   RUN chmod +x /usr/local/bin/llama-swap
   ```

This structure allows:
- Building with `--target runtime` to stop before llama-swap (no build context needed)
- Building without `--target` to include llama-swap (requires build context)

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

1. **Truly optional**: Build context only required when actually building with llama-swap
2. **No conditional FROM**: Using `--target` flag avoids Docker limitation with conditional FROM statements
3. **Clean separation**: llama-swap as final stage keeps core image clean
4. **Flexible**: Users can choose to include llama-swap or not with simple flag
5. **Maintainable**: Single source (`Dockerfile.llama-swap`) for llama-swap
6. **Version control**: Can pin specific llama-swap versions
7. **CI/CD ready**: Easy to toggle in automated builds with `--target` flag

### Alternatives Considered

- **Conditional FROM in middle**: Would always require build context (Docker limitation)
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
