# fast-p2a
## Status
### Finished
### Work in Progress
Metadata interpreter

## Usage
### Modelsim
1. Source env.sh in fletcher repo
2. vsim
3. do /path/to/fletcher.tcl
4. add_fletcher (if axi_top is also included don't forget to add_sources on the fletcher axi files)
5. compile_sources
6. compile
7. simulate

### Simulate everything for AWS
1. Source env.sh in fletcher repo and fast-p2a repo