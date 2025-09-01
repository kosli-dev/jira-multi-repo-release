# jira-multi-repo-release

This is part of a collection of 3 repos
jira-multi-repo-back
jira-multi-repo-front
jira-multi-repo-release

The purpose is to show an example of the release of multiple services
together to production using tagged versions and Jira.

## Development and tagged versions
Each team does their development in their repo and when the SW has release quality
they make a tagged version `v*.*.*` as described in the [jira-multi-repo-back](https://github.com/kosli-dev/jira-multi-repo-back/blob/main/README.md)
and [jira-multi-repo-front](https://github.com/kosli-dev/jira-multi-repo-front/blob/main/README.md)

## Creating a release candidate
When the release manager decide that a new release shall be made they run the [Generate Jira Realase](https://github.com/kosli-dev/jira-multi-repo-release/actions/workflows/generate-jira-release.yml)
workflow. This will generate a [release in Jira](https://kosli-team.atlassian.net/projects/MRJP?selectedItem=com.atlassian.jira.jira-projects-plugin%3Arelease-page)
and a trail for the [release in Kosli](https://app.kosli.com/kosli-public/flows/jira-multi-repo-release/trails/)

In the Jira release the release-approvers have to be manually added. 

The release trail in Kosli contains a set of attestations:
- Currently running SW in production
- SW-update-plan with information about what is the current and next SW version for all artifacts
- A list of all Jira-issues that has been worked on since previous release to production. This combined
list has been collected from the list of **jira-issues** in each of the tagged SW versions
- A missing release-approval which will be attested later when the release is approved

The SW that is ready for next release should be tested. If one of the components has to make new tagged version
the release manager will run the [Generate Jira Realase](https://github.com/kosli-dev/jira-multi-repo-release/actions/workflows/generate-jira-release.yml)
again which will update the Jira issue and the Kosli release trail.

## Release of SW
When the SW has been tested and is ready for release the different approvers will set the Jira release to
APPROVED in Jira.

The release manager will now start the actual release process by running the [Check for release to prod](https://github.com/kosli-dev/jira-multi-repo-release/actions/workflows/release-to-prod.yml)
workflow. This workflow will do the following:
- Verify that there is at least one approver and that all approvers has set the Jira release to APPROVED
- Attest to the Kosli release trail the list of approvers
- For each artifact that is updated in this release:
  - Attest to Kosli that this artifact with this fingerprint has been approved for running in production. [release-approval](https://app.kosli.com/kosli-public/flows/jira-multi-repo-back-tagged/trails/v2.0.11?attestation_id=1f34af8a-8c5e-4997-bcbd-777d49c8)
- Deploy the SW to production. This function is not doing anything in this example.
- Set the Jira release to **Released**

