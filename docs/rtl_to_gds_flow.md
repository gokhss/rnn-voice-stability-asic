# Reproducible implementation flow

1. Run `make test lint` with Icarus Verilog and/or Verilator installed locally.
   Python model checks have no third-party dependencies. Simulation produces VCD.
2. Copy config/tech_config.example.mk to ignored config/tech_config.mk and set
   actual local tools and technology files. Never commit PDK files/private paths.
3. Run `make synth`: Genus reads Liberty, RTL and SDC, elaborates, checks,
   synthesizes/maps, reports timing/area/power, writes netlist and mapped SDC.
4. Run `make sta`: Tempus loads the mapped netlist, Liberty and SDC; post-route
   STA additionally reads SPEF when present. Reports setup and hold paths.
5. Run `make pnr`: Innovus initializes libraries/MMMC, floorplans, creates PG
   rings/stripes, places pins/cells, optimizes, runs CTS and routes, writes
   reports/SPEF/netlist/database and exports GDS using your layer map.
6. Run `make gds`: requires PnR output then executes configured DRC and LVS
   wrappers against licensed rule decks. A nonzero exit blocks completion.
   Tool success alone is not proof of zero violations: inspect signoff reports.
7. Run `make reports` to aggregate available metrics, leaving unavailable values
   NOT RUN. No fabricated metrics or signoff artifacts are generated.

Cadence command dialects differ by release. These scripts use Genus Common UI
and Innovus legacy commands. They are unexecuted templates until validated
against your installed release. Configure PG nets, routing layers, CTS cells,
RC technology, GDS map and signoff wrappers for the actual platform. RC and
physical libraries cannot be inferred. Screenshots require a graphical session.

The initial environment exposes Python 3.6.8 on Linux x86_64, Bash, no EDA
executables on PATH and no accessible technology files. RTL simulation, lint,
synthesis, STA, PnR, DRC/LVS and GDS export are therefore NOT RUN / BLOCKED.
Python checks are reported separately after execution. No signoff claim is made.
