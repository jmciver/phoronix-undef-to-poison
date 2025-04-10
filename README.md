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
Usage: run-pts.bash [OPTION]... [-- ENTRY_POINT_OPTIONS]
  -h, --help                  Help message

      --no-cpu-checks         Do not fail, just warn, on CPU governance checks
      --cpu-set               Set CPU governance to performance, disable turbo
                              boost and Hyper threading for Phoronix runs
      --cpu-unset             Undo --cpu-set

      --container-type=TYPE   The type can be docker or apptainer
      --tag                   Container tag/version
      --interactive           Start container in interactive mode,
                              ENTRY_POINT_OPTIONS have not effect

      --list-jobs             List jobs/tests specified in categorized-profiles.txt

      --llvm=PATH             Path to llvm-project, also where alive2 is located
      --scratch=PATH          Path to temporary (fast) storage for building Phoronix tests

ENTRY_POINT_OPTIONS are:

Usage: build-and-run.bash [OPTION]...
  -h, --help               Help message

      --number-of-cores=N   Number of CPU cores to build with
      --number-of-threads=N Number of threads to provide to the Alive2
                            job server

  -b, --build              Build phase 1 and 2 of LLVM bootstrap build
      --build-target=NAME  Build specific CMakePresets.json target name
      --build-alive2       Build Alive2

  -t, --test               Run check-all using phase 2
      --test-alive2=PATH   Execute alive2 TV run using llvm-lit path

  -p, --phoronix                Run Phoronix testsuite
      --list-jobs               List jobs/tests specified in
                                categorized-profiles.txt
      --pts-alive2=ID           Build Phoronix test using ID# obtained
                                from --list-jobs
      --pts-make-download-cache Generate download cache for all categorized
                                tests
```

### Alive2 Analysis at TACC

The job IDs are mapped to the following processor architecture on TACC
Stampede 3:

| Architecture | Queue | Job Ids |
|--------------|-------|---------|
| Skylake | skx | 4,6,9,10,12,14,15,16,17,19,20,22 |
| Sapphire Rapids | spr | 0,1,2,3,5,7,8,11,13,18,21 |

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
* [HPC and containers tutorial](https://containers-at-tacc.readthedocs.io/en/latest/containers/00.overview.html)