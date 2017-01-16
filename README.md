# Testing ARM on x86 with QEMU

First, build the docker image:

```
docker build .
```

Next, run the docker image:

```
docker run -it $image
```

Finally, test it out:

```
docker exec -it $container \
    testd/target/release/testc \
    testd/target/arm-unknown-linux-gnueabihf/release/hello
```

This command will ship the `hello` binary to the emulator, run it, then receive
back the test results and print them out.
