# configuration
PROJ = scan2000
TESTBENCHS = scan200_tb
FPGA_PKG = tq144
FPGA_TYPE = hx1k
PCF = scan2000.pcf
ADD_SRC =

all: $(PROJ).rpt $(PROJ).bin

%.json: %.sv $(ADD_SRC)
	@# $@: The file name of the target rule -> example.json
	@# $<: The name of the first prerequisite -> example.sv
	@# $(subst from,to,text) -> removes the '.json' extension
	@# Experimental: Use ABC logic lib version 9 (-abc9) for improved timing
	@# See https://github.com/YosysHQ/yosys/blob/master/techlibs/ice40/synth_ice40.cc for details on the synth_ice40 parameters
	yosys -ql $(subst .json,,$@)-yosys.log -p 'synth_ice40 -abc9 -device hx -top $(subst .json,,$@) -json $@' $< $(ADD_SRC)

%.asc: %.json
	nextpnr-ice40 --${FPGA_TYPE} --freq 16 --package ${FPGA_PKG} --json $< --pcf ${PCF} --pre-pack constraints.py --asc $@

%.rpt: %.asc
	icetime -d ${FPGA_TYPE} -mtr $@ $<

%.bin: %.asc
	icepack $< $@

upload: $(PROJ).bin
	iceprogduino $<

clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).rpt $(PROJ).bin $(PROJ)-yosys.log

%_tb:
	iverilog -g2012 $(ADD_SRC) -o $@.vvp $@.sv
	vvp -N $@.vvp

tests: $(TESTBENCHS)
	@echo 'Run GTKWave and open the vcd file(s)'

.PHONY: all clean

.PRECIOUS: %.json
