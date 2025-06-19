SHELL  := bash

report_all_envs:
	gh workflow run simulate-environment-reporting-prod.yml --ref main
