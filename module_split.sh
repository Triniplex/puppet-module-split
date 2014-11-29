#!/bin/bash 

# ############################################################################ #
#                                                                              #
#   Created by Steve Weston (steve.weston@triniplex.com)                       #
#   Copyright (c) 2014 Triniplex                                               #
#                                                                              #
#                                                                              #
#    Licensed under the Apache License, Version 2.0 (the "License"); you may   #
#    not use this file except in compliance with the License. You may obtain   #
#    a copy of the License at                                                  #
#                                                                              #
#         http://www.apache.org/licenses/LICENSE-2.0                           #
#                                                                              #
#    Unless required by applicable law or agreed to in writing, software       #
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT #
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the  #
#    License for the specific language governing permissions and limitations   #
#    under the License.                                                        #
#                                                                              #
#         USAGE:  ./module_split.sh -cr create_repos -o oauth_key              #
#                 -u github_user -c config_repo_url -m merge_repo_url          #
#                 -s sync_repos_only -h help                                   #
#                                                                              #
#   DESCRIPTION:  Puppet Module Split Script                                   #
#   Todo: add other options in                                                 #
#                                                                              #
# ############################################################################ #

# Set globals
GITHUB_USER="Triniplex"
GITHUB_URL=git@github.com:${GITHUB_USER}
#CONFIG_REPO="https://github.com/openstack-infra/system-config.git"
CONFIG_REPO="https://github.com/Triniplex/system-config.git"
CONFIG_REPO_SUFFIX=$(echo ${CONFIG_REPO} | sed 's/.*\/\(.*\)\.git/\1/')
MERGE_REPO="${GITHUB_URL}/puppet-modules.git"
MERGE_REPO_SUFFIX=$(echo ${MERGE_REPO} | sed 's/.*\/\(.*\)\.git/\1/')
BASE="$(pwd)"

declare -a sargs=()

# Helper function for argument parsing
read_s_args() {
    while (($#)) && [[ $1 != -* ]]; do 
        sargs+=("$1"); 
        shift; 
    done
}

print_help() {
    echo -n "Usage: `basename $0` options (-cr) create_repos "
    echo -n "(-o oauth_key) (-u github_user) (-c config_repo_url) "
    echo -n "(-m merge_repo_url) (-s) sync_repos_only (-h) help"
    exit 
}

# Get command line options
parse_command_line() {
    while (($#)); do
        case "$1" in
            -o) read_s_args "${@:2}"
                if [ ${#sargs[@]} -ne 1 ]; then
                    echo "No OAuth Key found"
                    print_help
                else
                    OAUTH_KEY="${sargs[@]:0:1}"
                fi
                ;;
            -s) read_s_args "${@:2}"
                SYNC_REPOS="True"
                ;;
            -h) read_s_args "${@:2}"
                print_help
                ;;
        esac
        shift
    done
}

# Synchronize the repositories
sync_repos() {
    echo "${BASE}/${CONFIG_REPO_SUFFIX}"
    cd "${BASE}/${CONFIG_REPO_SUFFIX}" 2>/dev/null 1>/dev/null
    echo "git checkout master"
    git checkout master 2>/dev/null 1>/dev/null
    echo "git fetch origin"
    git fetch origin 2>/dev/null 1>/dev/null
    echo "git subtree split --prefix=modules/ --rejoin --branch modules_branch"
    git subtree split --prefix=modules/ --rejoin --branch modules_branch 2>/dev/null 1>/dev/null
    echo "cd ${BASE}/${MERGE_REPO_SUFFIX}"
    cd "${BASE}/${MERGE_REPO_SUFFIX}" 2>/dev/null 1>/dev/null
    echo "git pull ${BASE}/${CONFIG_REPO_SUFFIX} modules_branch"
    git pull "${BASE}/${CONFIG_REPO_SUFFIX}" modules_branch 2>/dev/null 1>/dev/null
    echo "git push origin -u master"
    git push origin -u master 2>/dev/null 1>/dev/null
    for MODULE in $(ls "${BASE}/${CONFIG_REPO_SUFFIX}/modules"); do
        echo "cd ${BASE}/${MERGE_REPO_SUFFIX}"
        cd "${BASE}/${MERGE_REPO_SUFFIX}" 2>/dev/null 1>/dev/null
        echo "git subtree split --prefix=${MODULE}/ --rejoin --branch module_${MODULE}_branch"
        git subtree split --prefix=${MODULE}/ --rejoin --branch module_${MODULE}_branch 2>/dev/null 1>/dev/null
        echo "cd ${BASE}/${DEST_REPO}"
        cd "${BASE}/${DEST_REPO}" 2>/dev/null 1>/dev/null
        echo "git pull ${BASE}/${MERGE_REPO_SUFFIX}/ module_${MODULE}_branch"
        git pull "${BASE}/${MERGE_REPO_SUFFIX}/" module_${MODULE}_branch 2>/dev/null 1>/dev/null
        echo "git push origin -u master"
        git push origin -u master 2>/dev/null 1>/dev/null
    done
}

# Set up the merge repository
merge_repo_setup() {
    cd "${BASE}"
    if [ ! -d "${MERGE_REPO_SUFFIX}" ]; then
        echo "mkdir ${MERGE_REPO_SUFFIX}"
        mkdir "${MERGE_REPO_SUFFIX}" 2>/dev/null 1>/dev/null
        echo "cd ${MERGE_REPO_SUFFIX}"
        cd "${MERGE_REPO_SUFFIX}" 2>/dev/null 1>/dev/null
        echo "git init"
        git init 2>/dev/null 1>/dev/null
        echo "git pull ${BASE}/${CONFIG_REPO_SUFFIX} modules_branch"
        git pull "${BASE}/${CONFIG_REPO_SUFFIX}" modules_branch 2>/dev/null 1>/dev/null
        echo "git remote add origin git@github.com:Triniplex/puppet-modules.git"
        git remote add origin git@github.com:Triniplex/puppet-modules.git 2>/dev/null 1>/dev/null
        echo "git push origin -u master"
        git push origin -u master  2>/dev/null 1>/dev/null
    fi
}

# Set up the config repository
config_repo_setup() {
    cd "${BASE}"
    if [ ! -d "${CONFIG_REPO_SUFFIX}" ]; then
        echo "git clone ${CONFIG_REPO}"
        git clone "${CONFIG_REPO}" 2>/dev/null 1>/dev/null
        echo "cd ${CONFIG_REPO_SUFFIX}"
        cd "${CONFIG_REPO_SUFFIX}" 2>/dev/null 1>/dev/null
        echo "git subtree split --prefix=modules/ --rejoin --branch modules_branch"
        git subtree split --prefix=modules/ --rejoin --branch modules_branch 2>/dev/null 1>/dev/null
    fi
}


# Create the local repositories
create_repos() {
    merge_repo_setup
    echo "cd ${BASE}/"
    cd "${BASE}/"
    for MODULE in $(ls "${BASE}/${CONFIG_REPO_SUFFIX}/modules"); do
        DEST_REPO="puppet-${MODULE}"
        echo "cd ${BASE}/${MERGE_REPO_SUFFIX}" 
        cd "${BASE}/${MERGE_REPO_SUFFIX}" 2>/dev/null 1>/dev/null 
        echo "git subtree split --prefix=${MODULE}/ --rejoin --branch module_${MODULE}_branch"
        git subtree split --prefix=${MODULE}/ --rejoin --branch module_${MODULE}_branch 2>/dev/null 1>/dev/null
        echo "cd ${BASE}/"
        cd "${BASE}/" 2>/dev/null 1>/dev/null
        echo "mkdir ${DEST_REPO}"
        mkdir "${DEST_REPO}" 2>/dev/null 1>/dev/null
        echo "cd ${DEST_REPO}"
        cd "${DEST_REPO}" 2>/dev/null 1>/dev/null
        echo "git init"
        git init 2>/dev/null 1>/dev/null
        echo "git remote add origin ${GITHUB_URL}/${DEST_REPO}.git"
        git remote add origin "${GITHUB_URL}/${DEST_REPO}.git" 2>/dev/null 1>/dev/null
        echo "git pull ${BASE}/${MERGE_REPO_SUFFIX} module_${MODULE}_branch"
        git pull "${BASE}/${MERGE_REPO_SUFFIX}" module_${MODULE}_branch 2>/dev/null 1>/dev/null
        echo "git push origin -u master"
        git push origin -u master 2>/dev/null 1>/dev/null
    done
    sync_repos
}

# Helper function to loop through repositories
create_github_repos() {
    echo "cd ${BASE}/${MERGE_REPO_SUFFIX}"
    cd "${BASE}/${MERGE_REPO_SUFFIX}" 2>/dev/null 1>/dev/null
    create_github_repo ${MERGE_REPO_SUFFIX}
    merge_repo_setup
    for MODULE in $(ls "${BASE}/${CONFIG_REPO_SUFFIX}/modules"); do
        create_github_repo "puppet-${MODULE}"
    done
}

# Create the github repositories
create_github_repo() {
    DEST_REPO=$1
    RECREATE_REPO=0
    REPOS=$(curl -s -H "Authorization: token ${OAUTH_KEY}" https://api.github.com/orgs/${GITHUB_USER}/repos)
    echo $REPOS | grep "${DEST_REPO}" 2>/dev/null 1>/dev/null
    if [ $? -eq 0 ]; then
        echo "Repository ${DEST_REPO} exists! Deleting ..."
        RESPONSE=""
        RESPONSE=$(curl -s -X DELETE -H "Authorization: token ${OAUTH_KEY}" \
        https://api.github.com/repos/${GITHUB_USER}/${DEST_REPO})
        if [ "${RESPONSE+1}" ]; then
            echo "Repository ${DEST_REPO} has been deleted.  Recreating ..."
            RECREATE_REPO=1
        fi
    else
        RECREATE_REPO=1
    fi
    if [ ${RECREATE_REPO} -eq 1 ]; then
        echo "Creating repository ${DEST_REPO} ..."
        RESPONSE=""
        RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"name\":\"${DEST_REPO}\"" \
                        -H "Authorization: token ${OAUTH_KEY}" https://api.github.com/orgs/${GITHUB_USER}/repos)
        echo $RESPONSE | grep "id" 2>/dev/null 1>/dev/null
        if [ $? -eq 0 ]; then
            echo "Repository ${DEST_REPO} successfully created!"
        fi
    fi
}

# Helper function to create the repositories necessary for the split
create_setup_repos() {
    cd "${BASE}"
    if [ ! -d "${BASE}/${CONFIG_REPO_SUFFIX}/" ]; then
        config_repo_setup
    fi
}

# Where it all starts
main() {
    if [ -n "${OAUTH_KEY+1}" ]; then
        create_setup_repos
        create_github_repos 
    fi
    if [ -n "${SYNC_REPOS+1}" ]; then
        sync_repos
    else
        create_repos
    fi
}

# Execute the functions
parse_command_line $@
time main
