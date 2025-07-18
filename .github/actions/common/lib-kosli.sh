#!/usr/bin/env bash

# The following variable must be set before using this script
# export KOSLI_ORG=kosli-public
# export KOSLI_API_TOKEN="xx"
# export DEBUG="true"

function debug_log
{
    if [ "${DEBUG}" == "true" ]; then
        echo -e "$@" >&2
    fi
}

function get_current_running_env_json
{
    local -r envName=$1; shift
    kosli get snapshot ${envName} --output json | jq -r '[.artifacts[] | select(.annotation.now != 0)]'
}

function create_running_sw_short_list_json
{
    local -r snapshotJsonFileName=$1; shift
    jq '[.[] | {
        name,
        fingerprint,
        flow_name: ( .flows[0].flow_name // "" ),
        template_reference_name: ( .flows[0].template_reference_name // "" ),
        git_commit: ( .flows[0].git_commit // "" )
    }]' ${snapshotJsonFileName}
}

function get_newest_commit_sha
{
    local -r envJson=$1; shift
    echo "$envJson" | jq -r '[.[] | .flows[]] | sort_by(.git_commit_info.timestamp) | .[-1].git_commit_info.sha1'
}

function get_oldest_commit_sha
{
    local -r envJson=$1; shift
    echo "$envJson" | jq -r '[.[] | .flows[]] | sort_by(.git_commit_info.timestamp) | .[0].git_commit_info.sha1'
}

function get_commits_between_tags
{
    local -r oldTag=$1; shift
    local -r newTag=$1; shift
    git log --format="%H" --reverse ${oldTag}..${newTag}
}

function get_commits_between_staging_and_prod
{
    local -r stagingEnvName=$1; shift
    local -r prodEnvName=$1; shift

    stagingEnvJson=$(get_current_running_env_json ${stagingEnvName})
    prodEnvJson=$(get_current_running_env_json ${prodEnvName})
    newestCommit=$(get_newest_commit_sha "${stagingEnvJson}")
    oldestCommit=$(get_newest_commit_sha "${prodEnvJson}")
    git log --format="%H" --reverse ${oldestCommit}..${newestCommit}
}

function get_attestation_from_trail
{
    local -r flowName=$1; shift
    local -r trailName=$1; shift
    local -r attestationName=$1; shift

    kosli get attestation ${attestationName} --output json --flow ${flowName} --trail ${trailName}
}


function get_jira_issue_keys_from_trail
{
    local -r flowName=$1; shift
    local -r trailName=$1; shift

    get_attestation_from_trail ${flowName} ${trailName} "work-reference" | jq -r '.[].jira_results[] | select(.issue_exists == true) | .issue_id'
}

function get_all_jira_issue_keys_for_commits
{
    local -r flowName=$1; shift
    local -r commits=$1; shift
    local issueKeys=""
    for commit in ${commits}; do
        issueKey=$(get_jira_issue_keys_from_trail $flowName $commit 2> /dev/null)
        issueKeys+=" ${issueKey^^}"
        debug_log "Issues found: ${issueKey} From commit: ${commit}"
    done
    echo $issueKeys
}


function get_issue_keys_between_staging_and_prod
{
    local -r stagingEnvName=$1; shift
    local -r prodEnvName=$1; shift
    local -r flowName=$1; shift

    commits=$(get_commits_between_staging_and_prod ${stagingEnvName} ${prodEnvName})
    debug_log "Commits between staging and prod:\n${commits}"
    issueKeys=$(get_all_jira_issue_keys_for_commits ${flowName} "${commits}")
    echo ${issueKeys} | tr ' ' '\n' | sort -uV | tr '\n' ' '| sed 's/ *$//'
}

function get_issue_keys_between_commits
{
    local -r oldCommit=$1; shift
    local -r newCommit=$1; shift
    local -r flowName=$1; shift

    commits=$(get_commits_between_tags ${oldCommit} ${newCommit})
    debug_log "Commits between ${oldCommit} ${newCommit}:\n${commits}"
    issueKeys=$(get_all_jira_issue_keys_for_commits ${flowName} "${commits}")
    echo ${issueKeys} | tr ' ' '\n' | sort -uV | tr '\n' ' '| sed 's/ *$//'
}

function get_trails_newer_then
{
    # Return empty array if flowName or trailName is missing
    if [[ $# -lt 2 ]]; then
        echo "[]"
        return
    fi

    local -r flowName=$1; shift
    local -r trailName=$1; shift

    kosli list trails --flow ${flowName} --output json | jq \
        '. as $trails |
         ($trails | map(.name) | index("'${trailName}'")) as $index |
         if $index then $trails[:$index] else $trails end'
}

function get_list_of_artifacts_with_release_flow_info
{
    # Based on a kosli environment snapshot extract out the
    # artifacts, flow and trail based on trail with a name of format v.0.0.0
    local envJsonFile=$1; shift

    jq -c '[
        .[] as $artifact |
        ($artifact.flows | map(select(.trail_name != null and (.trail_name | test("^v\\d+\\.\\d+\\.\\d+")))) | first) as $release_flow |
        if $release_flow then
            {
                name: $artifact.name,
                trail_name: $release_flow.trail_name,
                flow_name: ($release_flow.flow_name // ""),
                template_reference_name: ($release_flow.template_reference_name // ""),
                fingerprint: $artifact.fingerprint
            }
        else
            {
                name: $artifact.name,
                trail_name: "",
                flow_name: "",
                template_reference_name: "",
                fingerprint: $artifact.fingerprint
            }
        end
    ]' ${envJsonFile}
}

function get_artifact_fingerprint_from_trail
{
    local -r flowName=$1; shift
    local -r trailName=$1; shift
    local -r templateReferenceName=$1; shift

    kosli get trail ${trailName} --flow ${flowName} --output json > /tmp/trail-${trailName}.json
    jq -r .compliance_status.artifacts_statuses.${templateReferenceName}.artifact_fingerprint /tmp/trail-${trailName}.json
}
