#! /bin/bash
# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# =============================================================================
# Authors:				  Patrick Lehmann
#
# Entity:				 	  STDOUT Post-Processor and Filter
#
# Description:
# -------------------------------------
# TODO: documentation
#
#
# License:
# =============================================================================
# Copyright 2017-2020 Patrick Lehmann - Boetzingen, Germany
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================
#
# ANSI color codes
ANSI_RED="\e[31m"
ANSI_NOCOLOR="\e[0m"

# colored texts
COLORED_ERROR="${ANSI_RED}[ERROR]"

# command line argument processing
COMMAND=2
INDENT=""
while [[ $# > 0 ]]; do
	key="$1"
	case $key in
		-i|--indent)
			INDENT=$2; shift
			;;
		-h|--help)
			COMMAND=0
			;;
		*)		# unknown option
			echo 1>&2 -e "${COLORED_ERROR} Unknown command line option '$key'.${ANSI_NOCOLOR}"
			COMMAND=1
		;;
	esac
	shift # past argument or value
done

if [ $COMMAND -le 1 ]; then
	test $COMMAND -eq 1 && echo 1>&2 -e "\n${COLORED_ERROR} No command selected.${ANSI_NOCOLOR}"
	echo ""
	echo "Synopsis:"
	echo "  Script to indent outputs."
	echo ""
	echo "Usage:"
	echo "  filter.sh [-v][-d] [--help] [--indent <pattern>]"
	echo ""
	echo "Common commands:"
	echo "  -h --help             Print this help page."
	echo "  -i --indent <pattern> Indent all lines with this pattern."
	echo ""
	exit $COMMAND
fi


while read -r line
do
	echo -e "$INDENT$TIMECODE$line"
done < "/dev/stdin"
