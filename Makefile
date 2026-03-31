.PHONY: select-team select-team-dry-run list-teams sync-rules sync-rules-clean sync-rules-dry-run

# Team selection (run ONCE when setting up a new project)
select-team:
ifndef TEAM
	$(error TEAM is required. Usage: make select-team TEAM=infra)
endif
	@.specify/scripts/sh/select-team.sh $(TEAM)

select-team-dry-run:
ifndef TEAM
	$(error TEAM is required. Usage: make select-team-dry-run TEAM=infra)
endif
	@.specify/scripts/sh/select-team.sh --dry-run $(TEAM)

list-teams:
	@.specify/scripts/sh/select-team.sh --list

# Multi-IDE sync (run after editing .cursor/ canonical source)
sync-rules:
	@.specify/scripts/sh/sync-ai-rules.sh

sync-rules-dry-run:
	@.specify/scripts/sh/sync-ai-rules.sh --dry-run

sync-rules-clean:
	@.specify/scripts/sh/sync-ai-rules.sh --clean
