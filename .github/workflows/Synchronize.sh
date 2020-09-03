#! /bin/bash
# EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
# vim: tabstop=2:shiftwidth=2:noexpandtab
# kate: tab-width 2; replace-tabs off; indent-width 2;
# =============================================================================
# Authors:				  Patrick Lehmann
#
# Entity:				 	  Upstream repository synchronizer for forked GitHub repositories
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
ANSI_RED="\e[31m"
ANSI_GREEN="\e[32m"
ANSI_YELLOW="\e[33m"
ANSI_CYAN="\e[36m"
ANSI_DARK_GRAY="\e[90m"
ANSI_NOCOLOR="\e[0m"

# colored texts
COLORED_ERROR="${ANSI_RED}[ERROR]"
COLORED_WARNING="${ANSI_YELLOW}[WARNING]"
COLORED_DONE="${ANSI_GREEN}[DONE]${ANSI_NOCOLOR}"

# set bash options
set -o pipefail

# command line argument processing
COMMAND=0
USER=""; REPOSITORY=""; UPSTREAM_SLUG=""
BRANCH="master"
UPSTREAM_BRANCH=""
TAGS=0
VERBOSE=0; DEBUG=0; DRYRUN=0
while [[ $# > 0 ]]; do
	key="$1"
	case $key in
		-u|--user)
			COMMAND=2
			USER=$2
			shift
			;;
		-r|--repository)
			REPOSITORY=$2
			shift
			;;
		-s|--slug|--upstream)
			COMMAND=2
			UPSTREAM_SLUG=$2
			shift
			;;
		-b|--branch)
			BRANCH=$2
			shift
			;;
		-B|--upstream-branch)
			UPSTREAM_BRANCH=$2
			shift
			;;
		-T|--token)
			GITHUB_TOKEN=$2
			shift
			;;
		-t|--with-tags)
			TAGS=1
			;;
		-v|--verbose)
			VERBOSE=1
			;;
		-d|--debug)
			VERBOSE=1
			DEBUG=1
			;;
		-D|--dry-run)
			DRYRUN=1
			;;
		-h|--help)
			COMMAND=0
			;;
		*)		# unknown option
			echo ""
			echo 1>&2 -e "${COLORED_ERROR} Unknown command line option '$1'.${ANSI_NOCOLOR}"
			COMMAND=1
			;;
	esac
	shift # past argument or value
done

if [ $COMMAND -le 1 ]; then
	echo ""
	echo "Synopsis:"
	echo "  Script to synchronize repositories."
	echo ""
	echo "Usage:"
	echo "  Synthesize.sh [-v][-d][-n] [--help|--slug]"
	echo ""
	echo "Common commands:"
	echo "  -h --help                     Print this help page."
	echo ""
	echo "Common options:"
	echo "  -v --verbose                  Print verbose messages."
	echo "  -d --debug                    Print debug messages."
	echo ""
	echo "Parameters:"
	echo "  -u --user <user>              Username or organisation name of the upstream repository."
	echo "  -r --repo <repo>              Repository name of the upstream repository."
	echo "  -s --slug <user>/<repo>       SLUG: Combinded username and repository name."
	echo "  -T --token <token>            GitHub TOKEN for authentication."
	echo "  -b --branch <branch>          Branch to synchronize."
	echo "  -B --upstream-branch <branch> Branch to synchronize."
	echo "  -t --with-tags                Also synchronize tags."
	echo ""
	exit $COMMAND
fi

if [[ $USER == "" ]]; then
	if [[ $UPSTREAM_SLUG == "" ]]; then
		echo -e "${COLORED_ERROR} No username or SLUG specified.${ANSI_NOCOLOR}"
		exit 1
	fi
else
	if [[ $REPOSITORY == "" ]]; then
		echo -e "${COLORED_ERROR} Username, but no repository specified.${ANSI_NOCOLOR}"
		exit 1
	else
		UPSTREAM_SLUG=$USER/$REPOSITORY
	fi
fi

if [[ $UPSTREAM_BRANCH == "" ]]; then
	echo -e "${ANSI_YELLOW}No upstream branch specified. Using branch '$BRANCH'.${ANSI_NOCOLOR}"
	UPSTREAM_BRANCH="$BRANCH"
fi

UPSTREAM_REPO="https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${UPSTREAM_SLUG}.git"


# Add upstream repository as an additional remote
echo -e "${ANSI_CYAN}Add '${UPSTREAM_REPO}' as additional remote ...${ANSI_NOCOLOR}"
# Check if upstream repository is already configured as a remote
if git config remote.upstream.url > /dev/null; then
	echo -e "${COLORED_WARNING} Remote 'upstream' is already configured as a remote.${ANSI_NOCOLOR}"
else
	test $DEBUG -eq 1 &&   echo -e "  ${ANSI_DARK_GRAY}git remote add upstream \"${UPSTREAM_REPO}\"${ANSI_NOCOLOR}"
	git remote add upstream "${UPSTREAM_REPO}" 2>&1
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${COLORED_ERROR} While adding new remote.${ANSI_NOCOLOR}"
		exit 2;
	fi
fi

# Fetch data from upstream repository
echo -e "${ANSI_CYAN}Fetching changes from upstream ...${ANSI_NOCOLOR}"
test $DEBUG -eq 1 &&   echo -e "  ${ANSI_DARK_GRAY}git fetch upstream 2>&1 | .github/workflows/filter.sh --indent \"  \"${ANSI_NOCOLOR}"
#git fetch upstream 2>&1
git fetch upstream 2>&1 | .github/workflows/filter.sh --indent "  "
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${COLORED_ERROR} While loading changes from upstream.${ANSI_NOCOLOR}"
	exit 2;
fi

# Check for new data
echo -e "${ANSI_CYAN}Check for new data ...${ANSI_NOCOLOR}"
test $DEBUG -eq 1 &&   echo -e "  ${ANSI_DARK_GRAY}git rev-parse origin/$BRANCH${ANSI_NOCOLOR}"
LOCAL_COMMIT_HASH=$(git rev-parse origin/$BRANCH)
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${COLORED_ERROR} While reading hash of latest commit.${ANSI_NOCOLOR}"
	exit 2;
else
	test $DEBUG -eq 1 &&   echo -e "  => origin/$BRANCH = $LOCAL_COMMIT_HASH$"
	git log -1 $LOCAL_COMMIT_HASH | .github/workflows/filter.sh --indent "    "
fi

test $DEBUG -eq 1 &&   echo -e "  ${ANSI_DARK_GRAY}git rev-parse upstream/$UPSTREAM_BRANCH${ANSI_NOCOLOR}"
UPSTREAM_COMMIT_HASH=$(git rev-parse upstream/$UPSTREAM_BRANCH)
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${COLORED_ERROR} While reading hash of latest upstream commit.${ANSI_NOCOLOR}"
	exit 2;
else
	test $DEBUG -eq 1 &&   echo -e "  => upstream/$UPSTREAM_BRANCH = $UPSTREAM_COMMIT_HASH"
	git log -1 $UPSTREAM_COMMIT_HASH | .github/workflows/filter.sh --indent "    "
fi

if [[ "${LOCAL_COMMIT_HASH}" == "${UPSTREAM_COMMIT_HASH}" ]]; then
	# if tags are not pushed, script can stop here.
	if [[ $TAGS -eq 0 ]]; then
		echo -e "${COLORED_DONE} No new commits to synchronize.${ANSI_NOCOLOR}"
		exit 0
	else
		echo -e "${ANSI_GREEN}  No new commits to synchronize.${ANSI_NOCOLOR}"
	fi
fi

# Move branch to the latest version on remote
echo -e "${ANSI_CYAN}Update reference of '$BRANCH' to $UPSTREAM_COMMIT_HASH ...${ANSI_NOCOLOR}"
test $DEBUG -eq 1 && echo -e "  ${ANSI_DARK_GRAY}git update-ref refs/heads/$BRANCH $UPSTREAM_COMMIT_HASH${ANSI_NOCOLOR}"
git update-ref refs/heads/$BRANCH $UPSTREAM_COMMIT_HASH
if [ $? -ne 0 ]; then
	echo 1>&2 -e "${COLORED_ERROR} While updating branch.${ANSI_NOCOLOR}"
	exit 2;
fi

# Log changes since last synchronization
if [[ $VERBOSE -eq 1 ]]; then 
	echo -e "${ANSI_CYAN}Get changelog ...${ANSI_NOCOLOR}"
	echo -e "  New commits since last synchronization:"
	echo -e "  ================================================================================"
	test $DEBUG -eq 1 &&   echo -e "  ${ANSI_DARK_GRAY}git log upstream/$BRANCH $LOCAL_COMMIT_HASH..$UPSTREAM_COMMIT_HASH --pretty=oneline 2>&1 | .github/workflows/filter.sh --indent \"    \"${ANSI_NOCOLOR}"
	git log upstream/$BRANCH $LOCAL_COMMIT_HASH..$UPSTREAM_COMMIT_HASH --pretty=oneline 2>&1 | .github/workflows/filter.sh --indent "    "
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${COLORED_WARNING} While printing changes since last synchronization.${ANSI_NOCOLOR}"
		exit 2;
	else
		echo -e "  ================================================================================"
	fi
fi

# Push changes to repository
echo -e "${ANSI_CYAN}Pushing branch to repository ...${ANSI_NOCOLOR}"
test $DEBUG -eq 1 &&   echo -e "  ${ANSI_DARK_GRAY}git push --porcelain --progress --recurse-submodules=check origin refs/heads/$BRANCH:refs/heads/$BRANCH 2>&1 | .github/workflows/filter.sh --indent \"  \"${ANSI_NOCOLOR}"
if [[ $DRYRUN -eq 0 ]]; then
	git push --porcelain --progress --recurse-submodules=check origin refs/heads/$BRANCH:refs/heads/$BRANCH 2>&1 | .github/workflows/filter.sh --indent "  "
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${COLORED_ERROR} While pushing changes to the repository.${ANSI_NOCOLOR}"
		exit 2;
	fi
else
	echo -e "${ANSI_YELLOW}[DRYRUN] Branch not uploaded.${ANSI_NOCOLOR}"
fi

# Pushing tags to repository
echo -e "${ANSI_CYAN}Pushing tags to repository ...${ANSI_NOCOLOR}"
test $DEBUG -eq 1 &&   echo -e "  ${ANSI_DARK_GRAY}git push origin --tags 2>&1 | .github/workflows/filter.sh --indent \"  \"${ANSI_NOCOLOR}"
if [[ $DRYRUN -eq 0 ]]; then
	git push origin --tags 2>&1 | .github/workflows/filter.sh --indent "  "
	if [ $? -ne 0 ]; then
		echo 1>&2 -e "${COLORED_ERROR} While pushing tags to the repository.${ANSI_NOCOLOR}"
		exit 2;
	fi
else
	echo -e "${ANSI_YELLOW}[DRYRUN] Tags not uploaded.${ANSI_NOCOLOR}"
fi

echo ""
echo -e "${COLORED_DONE} Synchronization of '$UPSTREAM_SLUG' branch '$UPSTREAM_BRANCH' -> '$BRANCH'.${ANSI_NOCOLOR}"
