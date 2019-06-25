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
- DeltaDecoder
	- AdvanceableFifo
	- BitUnpacker
		- BitUnpackerShifter
	- BlockValuesAligner
		- BlockHeaderReader
		- BlockShiftControl
	- DeltaAccumulator
		- DeltaAccumulatorMD
		- DeltaAccumulatorFV
- DeltaLengthDecoder
	- CharBuffer

## Usage
### Modelsim
For any testbench:
1. Source env.sh in fletcher repo
2. vsim
3. do /path/to/fletcher.tcl
4. add_fletcher (if axi_top is also included don't forget to add_sources on the fletcher axi files)
5. compile_sources
6. compile
7. simulate
Many of the testbenches have a corresponding Python script for generating input and validation data

### AWS
#### Project Setup
1. Source hdk_setup.sh in aws-fpga repo
2. Copy any of the existing projects in platforms/aws-f1
3. Change start_build_on_cluster.sh for the correct CL_DIR
4. Change build/scripts/encrypt.tcl to include any additional VHDL files
5. Change verif/scripts/top_vhdl.vivado.f to include any additional VHDL files
6. Run generate_ip.sh

#### Simulate for AWS
For testbenches in verif/tests:
1. Source env.sh in fletcher repo and fast-p2a repo
2. source hdk_setup.sh in aws-fpga repo
3. In verif/scripts make TEST={name_of_sv_testbench}
4. For gui (in verif/sim/vivado/{test_dir}) run xsim tb --gui

#### Synthesize for AWS
1. Source start_build_on_cluster.sh (with or withour -foreground switch in script)
2. Install aws cli tools
3. Run aws s3 cp {design_file} {s3://your_bucket/your_dir} (design_file in build/checkpoints/to_aws (.tar))
4. Run aws ec2 create-fpga-image --name "hw_name" --description "hw_desc" --input_storage_location "Bucket=your_bucket,Key=your_dir/your_designfile" --logs-storage-location "Bucket=your_bucket,Key=your_dir"
