
# Building Containers Locally

If you want to build or customize the toolbox containers yourself (rather than using the pre-built Docker Hub images), this guide explains the process. Local builds are useful if you want to:

* Use a patched or forked version of llama.cpp
* Add additional tools or libraries
* Change the Fedora base image (Rawhide vs. stable)
* Audit every installed dependency

---

## 1. Prerequisites

* **Podman** (recommended on Fedora) or **Docker** (also fine)

---

## 2. Build an Image

Each backend has its own subdirectory and Dockerfile in `toolboxes/`.

**Example: Build the Vulkan RADV toolbox image**

```sh
cd toolboxes
podman build --no-cache -t llama-vulkan-radv -f Dockerfile.vulkan-radv .
```

**Example: Build the ROCm 6.4.2 toolbox image**

```sh
cd toolboxes
podman build --no-cache -t llama-rocm-6.4.2 -f Dockerfile.rocm-6.4.2 .
```

> You can use `docker build` if you prefer Docker.

---

## 3. Building with llama-swap Support

All toolbox images support optional inclusion of [llama-swap](https://github.com/mostlygeek/llama-swap), a utility for automatically stopping the llama-server application and restarting it with a new model.

The Dockerfiles use multi-stage builds with llama-swap as the final stage. You can choose whether to include it:

**Example: Build WITHOUT llama-swap (default, stops at `runtime` stage)**

```sh
cd toolboxes
podman build \
  --target runtime \
  -f Dockerfile.rocm-7.1-rocwmma \
  -t rocm-llama:latest .
```

**Example: Build WITH llama-swap (builds complete image including final stage)**

```sh
cd toolboxes
podman build \
  --build-context llama-swap=Dockerfile.llama-swap \
  -f Dockerfile.rocm-7.1-rocwmma \
  -t rocm-llama-with-swap:latest .
```

**What's happening:**

* The Dockerfiles have a `runtime` stage (without llama-swap) and a `runtime-with-llamaswap` stage (with llama-swap)
* Using `--target runtime` stops at the stage without llama-swap and doesn't require the llama-swap build context
* Building without `--target` builds all stages including the final `runtime-with-llamaswap` stage
* `--build-context llama-swap=Dockerfile.llama-swap` provides the llama-swap builder as an external build context (only needed when building the full image)
* The llama-swap binary is downloaded from the [official GitHub releases](https://github.com/mostlygeek/llama-swap/releases) and placed in `/usr/local/bin/llama-swap`

**Using Docker instead of Podman:**

```sh
cd toolboxes
# Without llama-swap
docker build --target runtime -f Dockerfile.rocm-7.1-rocwmma -t rocm-llama:latest .

# With llama-swap
docker build --build-context llama-swap=Dockerfile.llama-swap -f Dockerfile.rocm-7.1-rocwmma -t rocm-llama:latest .
```

**Specifying a llama-swap version:**

You can specify a specific version of llama-swap using the `LLAMA_SWAP_VERSION` build argument when building the llama-swap context:

```sh
cd toolboxes
podman build \
  --build-context llama-swap=Dockerfile.llama-swap \
  --build-arg LLAMA_SWAP_VERSION=v0.5.0 \
  -f Dockerfile.rocm-7.1-rocwmma \
  -t rocm-llama:latest .
```

If `LLAMA_SWAP_VERSION` is not specified, it defaults to `latest`.

---

## 4. Customizing the Build

* **llama.cpp version**: Change the `git clone` or `git checkout` line in the Dockerfile.
* **Extra dependencies**: Add them to the Dockerfile as needed.
* **Other customizations**: Install tools, patch scripts, or swap to a different base image.

---

## 5. Using the Custom Image with Toolbx

Create a new toolbox using your freshly built image:

```sh
toolbox create llama-vulkan-radv --image localhost/llama-vulkan-radv \
  -- --device /dev/dri --group-add video --security-opt seccomp=unconfined
```

Replace the backend/image name and device/group options as needed (see main README Section 2.1).

---

## 6. CI/CD Integration

The GitHub Actions workflow (`build_and_publish.yml`) supports building images with llama-swap included:

1. Navigate to **Actions** → **Build & Publish AMD Strix Halo Toolboxes** in the GitHub repository
2. Click **Run workflow**
3. Set **include_llama_swap** to **true** to build all images with llama-swap (builds complete image)
4. Set **include_llama_swap** to **false** to build images without llama-swap (uses `--target runtime`)
5. Images built with llama-swap will have `-llamaswap` appended to their tag (e.g., `rocm-7.1-rocwmma-llamaswap`)

**Default behavior:** Images are built WITHOUT llama-swap (using `--target runtime`).

**Note:** Building with llama-swap creates separate image tags, so both versions can coexist on Docker Hub:
- Standard: `docker.io/kyuz0/amd-strix-halo-toolboxes:rocm-7.1-rocwmma` (built with `--target runtime`)
- With llama-swap: `docker.io/kyuz0/amd-strix-halo-toolboxes:rocm-7.1-rocwmma-llamaswap` (built without `--target`, includes final stage)

---

## 7. Troubleshooting

* **Build fails (ROCm images especially):** Try building with more memory or swap.
* **Toolbox can't access GPU:** Make sure you pass the correct device/group options.
* **llama-swap not found in container:** Make sure you built without `--target runtime` and provided `--build-context llama-swap=Dockerfile.llama-swap`.
* **"llama-swap" build context not found:** The `--build-context` flag requires Docker BuildKit. Ensure you're using a recent version of Docker/Podman. If you don't want llama-swap, use `--target runtime`.

---

## 8. References

* [Fedora Toolbox Documentation](https://docs.fedoraproject.org/en-US/fedora-silverblue/toolbox/)
* [Podman Build Reference](https://docs.podman.io/en/latest/markdown/podman-build.1.html)
* [Docker Build Reference](https://docs.docker.com/engine/reference/commandline/build/)


