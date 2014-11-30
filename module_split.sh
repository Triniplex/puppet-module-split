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
# ############################################################################ #

# Set globals
BASE="$(pwd)"
declare -a modules=()

print_help() {
    echo -e "\nUsage: `basename $0` options (-r) create_repos "
    echo -e "(-o oauth_key) (-u github_user) (-c config_repo_url) "
    echo -e "(-m merge_repo_url) (-s) sync_repos_only (-h) help\n"
    exit
}

# Get command line options
parse_command_line() {
    while getopts "hso:u:c:m:r" OPTION; do
        case "${OPTION}" in
            h)
                print_help
                ;;
            c)
                CONFIG_REPO=${OPTARG}
                ;;
            m)
                MERGE_REPO_URL=${OPTARG}
                ;;
            r)
                CREATE_REPOS="True"
                ;;
            s)
                SYNC_REPOS="True"
                ;;
            o)
                OAUTH_KEY=${OPTARG}
                ;;
            u)
                GITHUB_USER=${OPTARG}
                ;;
        esac
    done

    if [ -n "${CREATE_REPOS+1}" ] && [ ! -n "${OAUTH_KEY+1}" ]; then
        echo -e "Error parsing options.  If the create_repos option is used, " 
        echo -e "then the oauth_key must be set."
        print_help
    fi

    if [ ! -n "${GITHUB_USER+1}" ]; then
        echo -e "The github user must be specified."
        print_help
    fi

    if [ ! -n "${MERGE_REPO_URL+1}" ]; then
        echo -e "The merge repo must be specified."
        print_help
    fi

    if [ ! -n "${CONFIG_REPO+1}" ]; then
        echo -e "The config repo must be specified."
        print_help
    fi

    if [ -n "${CREATE_REPOS+1}" ]; then
        echo -e "\nThe create repos option will distroy all github puppet "
        echo -e "module repositories for the ${GITHUB_USER} user. "
        echo -e "Continue? Enter yes and press enter, anything else "
        echo -n "will abort: "
        read answer
        if [ "${answer}" != "yes" ]; then
            exit 1
        fi
    fi

    GITHUB_URL=git@github.com:${GITHUB_USER}
    CONFIG_REPO_SUFFIX=$(echo ${CONFIG_REPO} | sed 's/.*\/\(.*\)\.git/\1/')
    MERGE_REPO_SUFFIX=$(echo ${MERGE_REPO_URL} | sed 's/.*\/\(.*\)\.git/\1/')
}

sync_repos() {
    echo "${BASE}/${CONFIG_REPO_SUFFIX}"
    cd "${BASE}/${CONFIG_REPO_SUFFIX}" 2>/dev/null 1>/dev/null
    echo "git checkout master"
    git checkout master 2>/dev/null 1>/dev/null
    echo "git fetch origin"
    git fetch origin 2>/dev/null 1>/dev/null
    lines=$(git log HEAD..origin/master --oneline | wc -l | awk '{print $1}')
    if [ ${lines} -eq 0 ]; then
        echo "no changes to be processed.  exiting ..."
        exit 0
    fi
    commit_hash=$(git log HEAD..origin/master --oneline | awk '{print $1}')
    if [ $(git diff --name-status ${commit_hash} | grep modules 2>/dev/null \
    1>/dev/null && echo $?) -ne 0 ]; then
       echo "modules were not updated.  exiting ..."
       exit 0
    fi
    for module in $(for commit in $(git log HEAD..origin/master -$lines \
    --oneline | awk '{print $1}'); do git diff-tree --no-commit-id \
    --name-only -r $commit | sed -e 's/[a-z]*\/\([a-z]*\).*/\1/'; \
    done); do 
        modules=($(printf "%s\n%s\n" "${modules[@]}" "$module" | sort -u)); 
    done
    echo "The following modules will be updated: ${modules[@]}"
    git pull origin master
    echo "git subtree split --prefix=modules/ --rejoin --branch modules_branch"
    git subtree split --prefix=modules/ --rejoin --branch modules_branch 2>/dev/null 1>/dev/null
    pushd "${BASE}/${MERGE_REPO_SUFFIX}"
    git config receive.denyCurrentBranch ignore
    popd
    git push "${BASE}/${MERGE_REPO_SUFFIX}" modules_branch:master
    for MODULE in "${modules[@]}"; do
        cd "${BASE}"
        if [ -d "${MODULE}-split" ]; then
             rm -rf "${MODULE}-split"
        fi
        git clone "${MERGE_REPO_SUFFIX}" "${MODULE}-split"
        cd "${MODULE}-split"
        git remote rm origin
        git tag -l | xargs git tag -d
        git filter-branch --tag-name-filter cat --prune-empty --subdirectory-filter ${MODULE} -- --all
        git remote add origin ${GITHUB_URL}/puppet-${MODULE}.git
        git push -u origin master
    done
}

merge_repo_setup() {
    cd "${BASE}"
    if [ ! -d "${MERGE_REPO_SUFFIX}" ]; then
        echo "mkdir ${MERGE_REPO_SUFFIX}"
        mkdir "${MERGE_REPO_SUFFIX}" 2>/dev/null 1>/dev/null
        echo "cd ${MERGE_REPO_SUFFIX}"
        cd "${MERGE_REPO_SUFFIX}" 2>/dev/null 1>/dev/null
        echo "git init --bare"
        git init --bare 2>/dev/null 1>/dev/null
        cd "${BASE}/${CONFIG_REPO_SUFFIX}"
        git push "${BASE}/${MERGE_REPO_SUFFIX}" modules_branch:master
        cd "${BASE}/${MERGE_REPO_SUFFIX}"
        git remote add origin "${MERGE_REPO_URL}" 2>/dev/null 1>/dev/null
        echo "git push -u origin master"
        git push -u origin master  2>/dev/null 1>/dev/null
        cd "${BASE}"
        rm -rf "${MERGE_REPO_SUFFIX}"
        git clone "${MERGE_REPO_URL}"
    fi
}

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
        echo "cd ${BASE}/"
        cd "${BASE}/"
        #echo "cd ${BASE}/${MERGE_REPO_SUFFIX}" 
        #cd "${BASE}/${MERGE_REPO_SUFFIX}" 2>/dev/null 1>/dev/null 
        #echo "git subtree split --prefix=${MODULE}/ --rejoin --branch module_${MODULE}_branch"
        #git subtree split --prefix=${MODULE}/ --rejoin --branch module_${MODULE}_branch 2>/dev/null 1>/dev/null
        if [ -d "${MODULE}-split" ]; then
             rm -rf "${MODULE}-split"
        fi
        git clone "${MERGE_REPO_SUFFIX}" "${DEST_REPO}"
        cd "${DEST_REPO}"
        git remote rm origin
        git tag -l | xargs git tag -d
        git filter-branch --tag-name-filter cat --prune-empty --subdirectory-filter ${MODULE} -- --all
        git remote add origin "${GITHUB_URL}/${DEST_REPO}.git" 2>/dev/null 1>/dev/null
        git push -u origin master
     done
        #git remote rm origin
        #git tag -l | xargs git tag -d
        #git filter-branch --tag-name-filter cat --prune-empty --subdirectory-filter ${MODULE} -- --all
        #cd "${BASE}/${MERGE_REPO_SUFFIX}/"
        #git checkout module_${MODULE}_branch
        #git pull "${BASE}/${MODULE}-split/" master
        #echo "cd ${BASE}/"
        #cd "${BASE}/" 2>/dev/null 1>/dev/null
        #echo "mkdir ${DEST_REPO}"
        #mkdir "${DEST_REPO}" 2>/dev/null 1>/dev/null
        #echo "cd ${DEST_REPO}"
        #cd "${DEST_REPO}" 2>/dev/null 1>/dev/null
        #echo "git init"
        #git init 2>/dev/null 1>/dev/null
        #echo "git remote add origin ${GITHUB_URL}/${DEST_REPO}.git"
        #git remote add origin "${GITHUB_URL}/${DEST_REPO}.git" 2>/dev/null 1>/dev/null
        #echo "git pull ${BASE}/${MERGE_REPO_SUFFIX} module_${MODULE}_branch"
        #git pull "${BASE}/${MERGE_REPO_SUFFIX}" module_${MODULE}_branch 2>/dev/null 1>/dev/null
        #git pull "${BASE}/${MODULE}-split/" master
        #echo "git push origin -u master"
        #git push origin -u master 2>/dev/null 1>/dev/null
    #done
    sync_repos
}


# Create the github repos
create_github_repos() {
    echo "cd ${BASE}/${MERGE_REPO_SUFFIX}"
    cd "${BASE}/${MERGE_REPO_SUFFIX}" 2>/dev/null 1>/dev/null
    create_github_repo ${MERGE_REPO_SUFFIX}
    merge_repo_setup
    for MODULE in $(ls "${BASE}/${CONFIG_REPO_SUFFIX}/modules"); do
        create_github_repo "puppet-${MODULE}"
    done
}

create_github_repo() {
    set +x
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
    set -x
}

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
