# Phoronix Runtime Container for LLVM Characterization

This Phoronix, container based, test environment is used to calibrate
performance impact due to LLVM changes. The current environment is targeted
toward the X86_64 architecture, but others may work.

Tests have been selected as to allow for use of the Clang compiler that are known
to produce repeatable results.

The container is provisioned to prevent the inadverant use of the GNU C and C++
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

## Server Performance

CPU frequency governance needs to be set to performance. This can be
accomplished using OS utilities (BIOS permitting) or via the BIOS.

## Running the Container

The container instance is designed to be single use. All data added to
`$HOME/.phoronix-test-suite` during container execution is deemed
temporary.

Three bind mounts are used by the container and set by the container run script:

| Bind mount | Internal Container Path | External Path Defaults |
| ---------- | ----------------------- | ---------------------- |
| Build of Clang and LLVM to be tested | `/llvm-project` | Must be specified |
| Repository for Phoronix test configuration | `/pts/phoronix` | Detected by container run script |
| Phoronix build and test results | `/pts/pts-install` | `/tmp/pts-install` |

### How Niceness is Handled

Niceness is used by Phoronix during test invocation. Because we are using an
specified non-root USER in the container the use of `--cap-add SYS_NICE` is
blocked by invoking `nice` as a non-root user. Furthermore the setting of
security limits for the USER does not effect `nice` as the container shell is
not invoked through PAM. To allow the USER access to `nice` we setcap the
executable.

### How Taskset is Handled

The Phoronix test invocation uses `taskset` for CPU affinity. Further
investigation is required on how to best handle this in a container.
