# workload-orchestration

The workload-orchestration repo serves to host demos recorded by the team surrounding functionality that is provided by the Kueue component.

## Demos

Our demos are hosted on [asciinema](https://asciinema.org/) but we also provide the raw demo files if users prefer to play them locally. 

E.g.
```
asciinema play demos/demo-folder/demo.cast
```

> [!NOTE]
> You can install asciinema by visiting their [Getting Started](https://docs.asciinema.org/getting-started/#__tabbed_1_1) page.

## Useful Scripts for Contributors
- [update-readme.sh](./hack/update_readme/update-readme.sh) - This script is used to update all the README.md files in the demos directory with the latest YAML files from each resources directory.
This avoids having to copy and paste any changes made in the YAML onto the Readme, which could lead to inconsistencies. For usage details, refer to the [documentation](./hack/update_readme/update-readme.md).
