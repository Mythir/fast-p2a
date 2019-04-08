# fast-p2a
## Status
### Finished
- Metadata interpreter
	- VarIntDecoder
- Ingester
- DataAligner
	- ShifterRecombiner
	- HistoryBuffer
- ValuesDecoder
	- PlainDecoder
		- ValBuffer

### Work in Progress
- DeltaLengthByteArray decoder

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
2. source hdk_setup.sh in aws-fpga repo
3. Execute project-generate.sh in fletcher repo
4. Copy resulting directory to desired location (and include missing files reported by project-generate)
5. Change makefile to $(C_SRC_DIR)/test_dram_dma_common.c
6. set CL_DIR environment variable to top level of simulation project
7. source generate_ip.sh
8. make TEST={name_of_sv_testbench}