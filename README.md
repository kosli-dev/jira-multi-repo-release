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


# Demo
To demo this process do the following steps:

## Create Jira Issues
Go to Jira board https://kosli-team.atlassian.net/jira/software/projects/MRJP/boards/2 and
create 3 ticket. I have put in the values I got in parentheses 
- Demo update frontend (MRJP-37)
- Demo update frontend and backend (MRJP-38)
- Demo update backend (MRJP-39)

## Create tagged version of Frontend
Go to the `jira-multi-repo-front` and run the command with your Jira references
```
./bin/demo-jira-tagged-version.sh MRJP-37 MRJP-38
```
It will now have created two new trails in the `jira-multi-repo-front-source` flow
https://app.kosli.com/kosli-public/flows/jira-multi-repo-front-source/trails/
Each of them with a work-reference to one of the Jira issues (MRJP-37 and 38)

Two trails in the `jira-multi-repo-front-app`
https://app.kosli.com/kosli-public/flows/jira-multi-repo-front-app/trails/
Each of them with an artifact.

One trail in the `jira-multi-repo-front-tagged`
https://app.kosli.com/kosli-public/flows/jira-multi-repo-front-tagged/trails/
In our case it is version `v1.0.15`. The trail contains the artifact and
the list of Jira issues since previous tagged version
https://app.kosli.com/kosli-public/flows/jira-multi-repo-front-tagged/trails/v1.0.15?attestation_id=fcbe18ca-dc01-4cae-898d-acb85dd2


## Create tagged version of Backend
Go to the `jira-multi-repo-back` and run the command with your Jira references
```
./bin/demo-jira-tagged-version.sh MRJP-38 MRJP-39
```

It creates similar trails as the front end one. It creates version `v2.0.15` with 
list of Jira issues MRJP-38 and MRJP-39
https://app.kosli.com/kosli-public/flows/jira-multi-repo-back-tagged/trails/v2.0.15?attestation_id=3d8865e1-910e-4a8a-afc7-777db683


## Release of software to production
Go to the `jira-multi-repo-release` and run the command with your Jira references
```
./bin/demo-jira-release.sh 
```

The script will stop and ask you to approve the Jira release.
https://kosli-team.atlassian.net/projects/MRJP?selectedItem=com.atlassian.jira.jira-projects-plugin%3Arelease-page

In the Jira release note the following:
- Under **Related work** there is a link back to the kosli release trail
- Under **work items** there are links to the 3 Jira issues
- On the right hand side under **Description** is a list of what SW updates that will be included in this
  release (`frontend: v1.0.14 -> v1.0.15` and `backend: v2.0.14 -> v2.0.15`)

Add your self as Approver and set it to APPROVED. You can now continue the script by pressing 'c'.

If you reload the Jira release page after the script has finished you can see on the right
hand side that it has now been marked as **Released**.

It has created a new release in the `jira-multi-repo-release` flow
https://app.kosli.com/kosli-public/flows/jira-multi-repo-release/trails/2025-09-02-06-28-17

The Jira issues contains the Jira issues from both front- and back-end
https://app.kosli.com/kosli-public/flows/jira-multi-repo-release/trails/2025-09-02-06-28-17?attestation_id=8c673db4-9bca-463c-a652-afde9bfb

The SW update plan contains the SW versions that was done in this release
https://app.kosli.com/kosli-public/flows/jira-multi-repo-release/trails/2025-09-02-06-28-17?attestation_id=c5e099d6-c964-47fe-b074-30df0b05

The release approval contains your name as the approver of the release in Jira
https://app.kosli.com/kosli-public/flows/jira-multi-repo-release/trails/2025-09-02-06-28-17?attestation_id=76a1fadc-08b8-44cb-ac90-e40a4d63

The production environment shows the new artifacts that are running
https://app.kosli.com/kosli-public/environments/jira-multi-repo-prod/snapshots/

You can also go back to the tagged versions in front- and back-end.
https://app.kosli.com/kosli-public/flows/jira-multi-repo-front-tagged/trails/v1.0.15
They now contains a release approval.
https://app.kosli.com/kosli-public/flows/jira-multi-repo-front-tagged/trails/v1.0.15?attestation_id=5f2a9946-4108-4cf4-9e43-af849a70
You can also see that the artifact was deployed to jira-multi-repo-prod
