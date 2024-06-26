# Phoronix Runtime for LLVM Characterization

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

From inside the `phoronix` repository checkout `cd` into the container directory
and run `build.bash`:

```
cd container
./build.bash
```

This will create an image `pts-test:1`.
