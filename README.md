# Otomi cluster

Used to create Otomi Container Platform compatible clusters. The cluster creation scripts use the cloud native cli to create preferred, suggested architectures, as found in the offerings of the public cloud providers.

## Rationale

Why "Yet Another Cluster Creator"?

The creation scripts you will find here are only using cloud native cli. This has the following benefits:

- Assuming the cloud provider core devs know best how to create their managed cluster offerings under a unified CLI, we can abstain from creating complex solutions targeting cluster components "under the hood" (like with ARM/CloudFormation/TerraForm).
- It prevents taking on technical debt (we prefer to use THE FORCE as is)
- The code is DRY and simple and not as susceptible to rot
- Many less configuration parameters

Overall it warrants more simplicity, stability, predictability maintainability, but also time to market.
  
Downsides:  
- The scripts do not allow much tweaking or advanced architectures.
- Moves focus to cli know-how, so no more knowledge benefit from tinkering under the hood (but we think that is a good thing, as clis become more robust as )
 
Most of the times the architectures offered here are suitable enough for lots of use cases, and clusters become much more manageable when it comes to lifecycle maintenance. If you want a customized setup with fine grained control over everything, there are plenty of solutions out there to choose from.

## Usage

### Prerequisites

- Docker

### Setup

Please start by cloning an empty git folder and install the demo files:

```bash
# initialize new git repo
mkdir otomi-values && cd $_ && git init .
# and copy over all the files from this repos `demo` folder
cp -r ../otomi-clusters/.demo/* .
```

### Configuration

Cloud specific configuration is found in `clouds/$CLOUD/default.yaml`. Cluster specific configuration is found in `clouds/$CLOUD/$CLUSTER.yaml` files.
Please inspect the demo files to see what is possible. We might publish a jsonschema later, but we have more focus on [otomi-core](https://github.com/redkubes/otomi-core) right now.

### Deployment