# UMI Injector

**umi-injector** integrates UMI sequences from a separate FastQ file into the read headers of a single or paired FastQ.

## Building the containerized versions

### Building locally

To build the image locally, Docker (e.g. [Docker Desktop](https://docs.docker.com/desktop)) needs to be installed on your system. You can build the CPU version of the image directly off this Git repository. Specify a tag name with the `-t` parameter.

```bash
docker build https://github.com/NationalGenomicsInfrastructure/umi-injector.git -t umi-injector
```

Alternatively, you can also clone this repository beforehand

```bash
git clone https://github.com/NationalGenomicsInfrastructure/umi-injector.git && cd umi-injector
docker build . --file Dockerfile -t umi-injector
```

### Building on Github Actions

This repository also contains a Github Action workflow to build the container image.

To run the workflow successfully, you need to fork the repository and create your own repository secrets. Navigate to *Settings* and then to *Secrets*, where you need to create the two secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`. Both will be needed by the workflow to upload the finished container image to Docker Hub.  

The workflow can be dispatched manually in the *Actions* tab. Choose the desired settings in the dialogue and launch the workflow run.

## Running containerized umi-injector

To run the containerized version of umi-injector, invoke the container like so

```bash
docker run --rm -itv $(pwd):$(pwd) -w $(pwd) umi-injector
```

Replace `umi-injector` with whatever tag you specified to the `-t` parameter when building the container image.

To simplify the invocation, you can also declare an alias, which can be perpetuated in your `~/.bashrc` respectively `~/.zshrc`.

```bash
alias umi-injector="docker run --rm -itv $(pwd):$(pwd) -w $(pwd) umi-injector"
```
## License

The code is released under the MIT License and so are the contents of this repository. See [LICENSE](LICENSE) for further details.
