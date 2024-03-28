# Linter Waiver ###############################################################

# Important note: To apply these waivers, you should run the following tcl command in the Tcl Console:
#                           source constr/lint_waivers.xdc


create_waiver -type LINT -id ASSIGN-6  -description {no needs to be fixed}
create_waiver -type LINT -id ASSIGN-10 -description {no needs to be fixed}

create_waiver -type LINT -id ASSIGN-5 -rtl_file {axis_async_fifo.v} -description {Third Party codes should not be modified}
create_waiver -type LINT -id ASSIGN-5 -rtl_file {okLibrary.v} -description {Third Party codes should not be modified}

create_waiver -type LINT -id ASSIGN-8 -rtl_name {==} -rtl_hierarchy {xgmii_axis_bridge_rx_64b} -rtl_file {xgmii_axis_bridge_rx_64b.sv} -user ehsan -description {Needs to be fixed later}