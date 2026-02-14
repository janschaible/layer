# Installation


```
yosys -p "
read_verilog top.v
synth_xilinx -top top -family xc7
write_json top.json
"
```

```
nextpnr-xilinx \
  --chipdb $CONDA_PREFIX/share/nextpnr/xilinx-chipdb/artix7/xc7a100t.bin \
  --xdc arty.xdc \
  --json top.json \
  --fasm top.fasm
```
