#!/usr/bin/env bash
set -Eeu

SCRIPT_NAME=demo-jira-release.sh
ROOT_DIR=$(dirname $(readlink -f $0))/..

function print_help
{
    cat <<EOF
Usage: $SCRIPT_NAME <options> [RELEASE-NAME]

Script that will demonstrate a release cycle with Jira. It will pick
up any new tagged version of the jira-multi-repo-back and jira-multi-repo-front

Options are:
  -h          Print this help menu
EOF
}

function check_arguments
{
    while getopts "h" opt; do
        case $opt in
            h)
                print_help
                exit 1
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done
}

function run_gh_workflow
{
    local workflowFile="$1"; shift

    gh workflow run "$workflowFile" --ref main
    sleep 10
    echo -n "Waiting for GitHub Actions to complete "

    while true; do
        result=$(gh run list --workflow="$workflowFile" --limit 1 --json status,conclusion,name)
        status=$(echo "$result" | jq -r '.[0].status')
        if [[ "$status" != "completed" ]]; then
            echo -n "."
            sleep 2
        else
            break
        fi
    done
    echo
    conclusion=$(echo "$result" | jq -r '.[0].conclusion')
    workflow_name=$(echo "$result" | jq -r '.[0].name')
    if [[ "$conclusion" != "success" ]]; then
        echo "*** Workflow '$workflow_name' failed with conclusion: $conclusion" >&2
        return 1
    fi
}


main()
{
    check_arguments "$@"

    echo; echo "*** Make a release candidate"
    run_gh_workflow generate-jira-release.yml

    echo; echo "*** Go to url:"
    echo "https://kosli-team.atlassian.net/projects/MRJP?selectedItem=com.atlassian.jira.jira-projects-plugin%3Arelease-page"
    echo
    echo "Press the version you see in the list. It should only be one that is UNRELEASED"
    echo "On the right hand side press the + next to Approvers"
    echo "Add your self as an approver"
    echo "Change the approval from PENDING to APPROVED"
    echo "After that press 'c' to continue"
    while :; do
      read -n 1 key
      if [[ "$key" == "c" ]]; then
        echo -e "\nContinuing..."
        break
      fi
    done
    echo; echo "*** Check if release has been approved"
    run_gh_workflow release-to-prod.yml
    run_gh_workflow simulate-environment-reporting-prod.yml > /dev/null
    echo; echo "*** You can now check kosli UX to see that correct SW is running and that attestations have been done"
}

main "$@"
