SHELL  := bash
RELEASE_NAME ?= $(shell date +%Y-%m-%d)

generate_jira_release:
	gh workflow run generate-jira-release.yml --ref main -f release-name="$(RELEASE_NAME)"

check_release_to_prod:
	gh workflow run release-to-prod.yml --ref main

report_all_envs:
	gh workflow run simulate-environment-reporting-prod.yml --ref main
