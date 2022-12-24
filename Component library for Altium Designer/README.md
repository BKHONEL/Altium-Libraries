# Component library for Altium Designer

![Design](https://habrastorage.org/webt/o2/s8/fw/o2s8fw2golbphnoueufbxm_1svo.png)

## 1. Library structure

* Сomponent library
    >
    * ic-adc-dac-dds
    * ic-fpga
    * ic-gate-driver
    * ic-interface
    * ic-logic
    * ic-mcu
    * ic-memory
    * ic-op-comp
    * ic-power-supply
    * ic-sensor
    * ic-soc-cpu
    >
    * board
    * capacitor
    * conenctor
    * diode
    * electromechanics
    * inductor
    * module
    * optoisolator
    * oscilator
    * resistor
    * transformer
    * transistor
>

* Templates and rules
    >
    * **schematic-page** - template for schematic page
    * **board-pcb** - template for PCB
    * **rules-pcb** - rules for routing PCB
>

* Scripts
    >
    * **logo-creator** - import pictures (bmp) to PCB in the layer

## 2. Use library

Download archive with library or clone repository to your local disk of computer:
```
git clone https://github.com/RedCommissary/altium-library
```

Go to folder *library* and see list files with component library:

![List files](https://habrastorage.org/webt/un/ws/fp/unwsfpfom1csz8czsrtmujv9k2q.png)

Libraries are composed of four files:

* File with extension *.LibPkg* - project for library
* File with extension *.SchLib* - files with components symbols
* *standard-case.PcbLib* - contains footprint for standard case (LQFP48, D2pak, etc)
* *custom-case.PcbLib* - contains footprint for custom case (connectors, transformer, etc)

For installation library open to file with extension ***. LibPkg *** in the Altium Designer and you see 3 files in the project tree:

![Project tree](https://habrastorage.org/webt/ux/dc/7p/uxdc7pctxs16ytibvk4xtvpmxp0.png)

Click right mouse button on project name and select ***Compile Integrated Library***:

![Compilier project](https://habrastorage.org/webt/qx/zw/oo/qxzwoody7nzjxpau4sth7xisoru.png)

After this project to compile, automatically to connect in the Altium Designer and you see in list library:

![Library](https://habrastorage.org/webt/2v/u1/ka/2vu1kazqr9kjn0-km5c-mr1nwv0.png)