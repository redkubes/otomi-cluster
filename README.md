# Otomi cluster

Used to create Otomi Container Platform compatible clusters. The cluster creation scripts use the cloud native cli to create preferred, suggested architectures, as found in the offerings of the public cloud providers.

## Rationale

Why "Yet Another Cluster Creator"?

The creation scripts you will find here are only using cloud native cli. This has the following benefits:

- Assuming the cloud provider core devs know best how to create their managed cluster offerings under a unified CLI, we can abstain from creating complex solutions targeting cluster components "under the hood" (like with ARM/CloudFormation/TerraForm).
- It prevents taking on technical debt (we prefer to use THE FORCE as is)
- The code is DRY and simple and not as susceptible to rot

Overall it warrants more simplicity, stability, predictability, maintainability, but also time to market.
  
Downsides:  
- The scripts do not allow much tweaking or advanced architectures.
- Moves focus to cli know-how, so no more knowledge benefit from tinkering under the hood (but we think that is a good thing).
 
Most of the times the architectures offered here are suitable enough for lots of use cases, and clusters become much more manageable when it comes to lifecycle maintenance. If you want a customized setup with fine grained control over everything, there are plenty of solutions out there to choose from.

## Usage

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Gcloud CLI](https://cloud.google.com/sdk/gcloud#what_is_the_gcloud_command-line_tool)
- [eksctl](https://eksctl.io)
- Cloud access?

### Setup

Please start by creating an empty git folder and installing the `.demo/*` files there, and configure to your liking. Example:
```bash
export ENVC_DIR=$PWD/../otomi-clusters
mkdir $ENVC_DIR
cp -r .demo/* $ENVC_DIR/
cp -r .demo/.* $ENVC_DIR/
git init $ENVC_DIR
```

Any time you want to work on a clusters repo, always make sure you export `ENVC_DIR`:
```bash
export ENVC_DIR=$PWD/../otomi-clusters
```

Now you can generate cluster creation scripts into `$ENVC_DIR/build/$CLOUD/$CLUSTER/create.sh` with a dry run:
```bash
bin/create.sh azure dev 1
```

Or just drop the last argument, which will execute the creation script as well.

### Configuration

Cloud specific configuration is found in `clouds/$CLOUD/default.yaml`. Cluster specific configuration is found in `clouds/$CLOUD/$CLUSTER.yaml` files.
Please inspect the demo files to see what is possible. We might publish a jsonschema later, but we have more focus on [otomi-core](https://github.com/redkubes/otomi-core) right now.

### Deployment