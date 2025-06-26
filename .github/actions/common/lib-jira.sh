#!/usr/bin/env bash

# The following variable must be set before using this script
# export JIRA_BASE_URL="https://kosli-team.atlassian.net"
# export JIRA_USERNAME="tore@kosli.com"
# export JIRA_API_TOKEN="xx"
# export DEBUG="true"

function debug_log
{
    if [ "${DEBUG}" == "true" ]; then
        echo -e "$@" >&2
    fi
}

function loud_curl
{
    # curl that prints the server traceback if the response
    # status code is not in the range 200-299
    local -r method=$1; shift  # eg GET/POST
    local -r url=$1; shift
    local -r jsonPayload=$1; shift
    local -r userArg=$1;shift

    local -r outputFile=$(mktemp)

    set +e
    if [ "${method}" == "GET" ]; then
        HTTP_CODE=$(curl --header 'Content-Type: application/json' \
            --user "${userArg}" \
            --output "${outputFile}" \
            --write-out "%{http_code}" \
            --request "${method}" \
            --silent \
            ${url})
    else
        HTTP_CODE=$(curl --header 'Content-Type: application/json' \
            --user "${userArg}" \
            --output "${outputFile}" \
            --write-out "%{http_code}" \
            --request "${method}" \
            --silent \
            --data "${jsonPayload}" \
            ${url})
    fi
    set -e
    
    if [[ ${HTTP_CODE} -lt 200 || ${HTTP_CODE} -gt 299 ]] ; then
    >&2 cat ${outputFile}  # Request failed so send output to stderr
    >&2 echo
    rm ${outputFile}
    exit 2
    fi
    cat ${outputFile}  # Correct response send to stdout
    echo
    rm ${outputFile}
}

function loud_curl_jira
{
    local -r userArg=""${JIRA_USERNAME}:${JIRA_API_TOKEN}""
    loud_curl "$@" ${userArg}
}

function create_release
{
    local -r projectId=$1; shift
    local -r releaseName=$1; shift
    local -r startDate=$(date -u "+%Y-%m-%d")

    local -r url="${JIRA_BASE_URL}/rest/api/3/version"
    local -r data='{
         "description": "Release '${releaseName}'",
         "name": "'${releaseName}'",
         "projectId": '${projectId}',
         "startDate": "'${startDate}'"
    }'
    debug_log "Created release:\n${data}"
    loud_curl_jira POST "${url}" "${data}"
}

function set_release_to_released
{
    local -r releaseId=$1; shift
    local -r releaseDate=$(date -u "+%Y-%m-%d")

    local -r url="${JIRA_BASE_URL}/rest/api/3/version/${releaseId}"
    local -r data='{
         "releaseDate": "'${releaseDate}'",
         "released": true
    }'
    debug_log "Set release ${releaseId} to released:\n${data}"
    loud_curl_jira PUT "${url}" "${data}"
}

function get_current_release_candidate
{
    local -r projectId=$1; shift

    local -r url="${JIRA_BASE_URL}/rest/api/3/project/${projectId}/version?status=unreleased"
    loud_curl_jira GET "${url}" {}
}

function get_release
{
    local -r releaseId=$1; shift

    local -r url="${JIRA_BASE_URL}/rest/api/3/version/${releaseId}?expand=approvers"
    loud_curl_jira GET "${url}" {}
}

function set_release_description
{
    local -r releaseId=$1; shift
    local -r description=$1; shift

    local -r url="${JIRA_BASE_URL}/rest/api/3/version/${releaseId}"
    local -r data='{
         "description": "'${description}'"
    }'
    debug_log "Set release ${releaseId} to released:\n${data}"
    loud_curl_jira PUT "${url}" "${data}"
}

function fetch_user_details
{
    local -r accountId=$1; shift
    local url="${JIRA_BASE_URL}/rest/api/3/user?accountId=${accountId}"
    loud_curl_jira GET "${url}" {}
}

function get_approvers_in_release
{
    local -r releaseId=$1; shift
    get_release ${releaseId} | jq '.approvers'
}

function add_approver_name_and_email
 {
    # In list of approvers it only includes the accountId
    # This function uses accountId to look up displayName and email and
    # adds it to the input file.
    local releaseJsonFile=$1; shift
    local releaseJson=$(cat "${releaseJsonFile}")
    local updatedApprovers accountId userJson email displayName

    updatedApprovers=$(echo "${releaseJson}" | jq -c '.approvers[]' | while read -r approver; do
        accountId=$(echo "${approver}" | jq -r '.accountId')
        userJson=$(fetch_user_details "${accountId}")

        email=$(echo "${userJson}" | jq -r '.emailAddress // empty')
        displayName=$(echo "${userJson}" | jq -r '.displayName // empty')

        echo "${approver}" | jq --arg email "${email}" --arg name "${displayName}" \
            '. + {emailAddress: $email, displayName: $name}'
    done | jq -s '.')

    echo "${releaseJson}" | jq --argjson approvers "${updatedApprovers}" '.approvers = $approvers' > "${releaseJsonFile}"
}


function get_issues_in_release
{
    local -r releaseId=$1; shift

    local -r url="${JIRA_BASE_URL}/rest/api/3/search?jql=fixVersion='${releaseId}'"
    loud_curl_jira GET "${url}" {}
}

function get_issue_keys_in_release
{
    local -r releaseId=$1; shift
    get_issues_in_release ${releaseId} | jq -r '[.issues[].key] | join(" ")'
}

function add_issue_to_release()
{
    local -r issueKey=$1; shift
    local -r releaseId=$1; shift

    local -r url="${JIRA_BASE_URL}/rest/api/3/issue/${issueKey}"
    local -r data='{
        "fields": {
            "fixVersions": [{
                "id": "'${releaseId}'"
            }]
        }
    }'
    loud_curl_jira PUT "${url}" "${data}"
}

function get_issue
{
    local -r issueKey=$1; shift

    local -r url="${JIRA_BASE_URL}/rest/api/3/issue/${issueKey}"
    loud_curl_jira GET "${url}" {}
}

function add_trail_link_to_release
{
    local -r releaseId=$1; shift
    local -r trailUrl=$1;
    local -r url="${JIRA_BASE_URL}/rest/api/3/version/${releaseId}/relatedwork"
    local -r data='{
      "category": "Audit",
      "title": "Kosli Trail",
      "url": "'${trailUrl}'"
    }'
    debug_log "Add related work to release ${releaseId}:\n${data}"
    loud_curl_jira POST "${url}" "${data}"
}

# Jira has no API to add an approver to a release. This must be done in the UX
# See https://community.developer.atlassian.com/t/add-approver-to-version-through-rest-api/76975

function get_project_id
{
    local -r projectKey=$1; shift

    local -r url="${JIRA_BASE_URL}/rest/api/3/project/${projectKey}"
    loud_curl_jira GET "${url}" {} | jq -r .id
}
