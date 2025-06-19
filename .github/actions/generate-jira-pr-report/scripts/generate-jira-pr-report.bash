#!/usr/bin/env bash

set -Eeu

SCRIPT_NAME=generate-jira-pr-report.bash
ROOT_DIR=$(dirname $(readlink -f $0))
RESULT_DIR=""
KOSLI_FLOW=""
START_DATE=""
END_DATE=""

source ${ROOT_DIR}/../../../../scripts/lib-kosli.sh

function print_help
{
    cat <<EOF
Usage: $SCRIPT_NAME <result-dir> <flow-name> [start-date] [end-date]

Create a csv report documenting all commits, pull-requests
and jira issue references for a period.

The result end up in ${SOURCE_REPORT_FILE}

Required date format: YYYY-MM-DD

The end-date is not included, so the following
will give you everything that happened in April 2025

$SCRIPT_NAME /tmp/audit-report jira-example-source 2025-04-01 2025-05-01

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

    # Remove options from command line
    shift $((OPTIND-1))

    if [ $# -ne 4 ]; then
        echo "Missing arguments"
        exit 1
    fi
    RESULT_DIR=$1; shift
    KOSLI_FLOW=$1; shift
    START_DATE=$1; shift
    END_DATE=$1; shift

    SOURCE_REPORT_DIR=${RESULT_DIR}/source
    SOURCE_REPORT_FILE=${RESULT_DIR}/source.csv
}

main()
{
    check_arguments "$@"
    commits=$(git log --format="%H %ad" --date=format:"%Y-%m-%d" --after="${START_DATE}T00:00:00" --before="${END_DATE}T00:00:00")
    mkdir -p ${SOURCE_REPORT_DIR}
    echo "commit,date,commit-author,pr-approver,jira-issue" > ${SOURCE_REPORT_FILE}
    
    while IFS=' ' read -r sha date; do
        mkdir -p ${SOURCE_REPORT_DIR}/${sha}
        get_attestation_from_trail ${KOSLI_FLOW} ${sha} pull-request | jq . > ${SOURCE_REPORT_DIR}/${sha}/pull-request.json || true
        get_attestation_from_trail ${KOSLI_FLOW} ${sha} work-reference | jq . > ${SOURCE_REPORT_DIR}/${sha}/work-reference.json || true
    
        echo ${sha} | tr '\n' ',' >> ${SOURCE_REPORT_FILE}
        echo ${date} | tr '\n' ',' >> ${SOURCE_REPORT_FILE}
            
        jq -r '[.[].git_commit_info.author] | join(",") + ","' ${SOURCE_REPORT_DIR}/${sha}/pull-request.json | tr -d '\n' >> ${SOURCE_REPORT_FILE}
        jq -r '[.[].pull_requests[].approvers[]] | unique | join(",") + ","' ${SOURCE_REPORT_DIR}/${sha}/pull-request.json | tr -d '\n' >> ${SOURCE_REPORT_FILE}
        jq -r '[.[] | .jira_results[] | select(.issue_exists == true) | .issue_id] | join(",") + ","' ${SOURCE_REPORT_DIR}/${sha}/work-reference.json | tr -d '\n' >> ${SOURCE_REPORT_FILE}

        echo >> ${SOURCE_REPORT_FILE}
    done <<< "$commits"
}

main "$@"
