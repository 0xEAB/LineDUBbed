# LineDUBbed

**LineDUBbed** is a DUB package compilation tester prototype.


## Build

As simple as:
```sh
dub build --build=io
```


## Usage

```sh
./linedubbed --help
```

### DUB registry

In case you're planning to playing around a bit, please set up your own registry "mirror" (in fact, you only need `/api/packages/search`),
so you don't DoS the registry by letting generate the package list over and over.
The registry base URL is passes this way: `--registry=http://127.0.0.1:12345`

### Package cache

When using `--cache=local` (default) make sure to run *LineDUBbed* in an empty directory.
Since this app passes this arg to DUB, DUB will use the working directory as package cache.
