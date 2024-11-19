# Phoronix Runtime Container for LLVM Characterization

This Phoronix, container based, test environment is used to calibrate
performance impact due to LLVM changes. The current environment is targeted
toward the X86_64 architecture, but others may work.

Tests have been selected as to allow for use of the Clang compiler that are known
to produce repeatable results.

The container is provisioned to prevent the inadvertent use of the GNU C and C++
compilers. Test execution is performed using the `pts` user with password locked
`sudo`.

## System Requirements

* Docker installation

## Environment Setup

To checkout the repository and its associated submodules:
```
# Git >= 2.13:
git clone --recurse-submodules https://github.com/jmciver/phoronix-undef-to-poison.git phoronix

# Git < 2.13:
git clone --recursive https://github.com/jmciver/phoronix-undef-to-poison.git phoronix

# Git < 1.8:
git clone https://github.com/jmciver/phoronix-undef-to-poison.git phoronix && \
  cd phoronix && \
  git submodule update --init
```

## Container Build

From inside the `phoronix` repository `cd` into the container directory
and run `build.bash`:

```
cd container
./build.bash
```

This will create an image `pts-test:1` with UID and GID set to match that of the
user building the container.

## Running the Container

### Basics
Container based building and performance benchmarking is accomplished using
`run-pts.bash`:
```
usage: run-pts.bash [-h|--help] [--interactive] [--no-cpu-checks] [--cpu-set] [--cpu-unset] [--cpu-info] --llvm=PATH -- ENTRY_POINT_OPTIONS

ENTRY_POINT_OPTIONS are:

Alive2 Build:
[--build-alive2] build Alive2 using LLVM release1 build
[--test-alive2]  run translational validation on llvm-lit tests

LLVM Build & Test:
[-b|--build]     build a bootstrap version of the llvm project
[--build-target] build a specific target from CMakePresets.json file
[-t|--test]      run llvm release2 check-all target

Phoronix:
[-p|--phoronix] to run Phoronix tests
```
### Advanced

The container instance is designed to be single use. All data added to
`$HOME/.phoronix-test-suite` during container execution is deemed
temporary.

Three bind mounts are used by the container and set by the container run script
(`run-pts.bash`):

| Bind mount | Internal Container Path | External Path Defaults |
| ---------- | ----------------------- | ---------------------- |
| Build of Clang and LLVM to be tested | `/llvm-project` | Must be specified: `run-pts.bash --llvm=PATH`|
| Repository for Phoronix test configuration | `/pts/phoronix` | Detected by container run script |
| Phoronix build and test results | `/pts/pts-install` | `/tmp/pts-install` |

### Server Performance

CPU frequency governance needs to be set to performance. This can be
accomplished using OS utilities (BIOS permitting) or via the BIOS or using
`run-pts.bash` option `--cpu-set` (requires `sudo`). Server BIOSs may have
power/performance profiles based on baseboard management controller (BMC). This
will need to be set to some form of OS performance control.

Options currently being set:
* CPU frequency governor set to performance
* Disable turbo boost
* Disable hyper threading

### How Niceness is Handled

Niceness is used by Phoronix during test invocation. Because we are using an
specified non-root USER in the container the use of `--cap-add SYS_NICE` is
blocked by invoking `nice` as a non-root user. Furthermore the setting of
security limits for the USER does not effect `nice` as the container shell is
not invoked through PAM. To allow the USER access to `nice` we `setcap` the
executable.

### How Taskset is Handled

The Phoronix test invocation uses `taskset` for CPU affinity. This is correctly
honored by the host (Linux) OS and can be verified using `ps`:

```
ps -o pid,psr,comm -p PROCESS_ID
```

## References

* [cpupower command](https://wiki.archlinux.org/title/CPU_frequency_scaling)
