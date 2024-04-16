#!/usr/bin/env python3

#
# OpenLane2 build script to harden the tt_top macro inside
# the classic user_project_wrapper
#
# Copyright (c) 2023 Sylvain Munaut <tnt@246tNt.com>
# SPDX-License-Identifier: Apache-2.0
#

import argparse
import json
import os

from openlane.common import get_opdks_rev
from openlane.flows.misc import OpenInKLayout
from openlane.flows.classic import VHDLClassic
import volare

if __name__ == '__main__':
	parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument("--open-in-klayout", action="store_true", help="Open last run in KLayout")

	args = parser.parse_args()
	config = vars(args)

	pdk_root =  volare.get_volare_home(os.getenv('PDK_ROOT'))
	volare.enable(pdk_root, "sky130", get_opdks_rev())

	# Load fixed required config for UPW
	flow_cfg = json.loads(open('config.json', 'r').read())

	# Run flow
	flow_class = OpenInKLayout if args.open_in_klayout else VHDLClassic
	flow = flow_class(
		flow_cfg,
		design_dir = ".",
		pdk_root   = pdk_root,
		pdk        = "sky130A",
	)

	flow.start(tag = "wokwi")
