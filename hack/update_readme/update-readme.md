# Update Readme Script

## What is 'make update-readme' used for?
This script is used to update all the README.md files in the demos directory with the latest YAML files from each resources directory. This avoids having to copy and paste any changes made in the YAML onto the Readme, which could lead to inconsistencies.

## How to use Script?
1. Add the following snippet to the README.md file where you want the YAML to be inserted:
```go
<!-- YAML-START: <path-to-yaml> -->
<!-- YAML-END -->
```

2. Run the following command:
```bash
make update-readme
```

3. See the changes in the README.md file.

## Example
![Tutorial][tutorial]

[tutorial]: update-readme-script-demo.webp
