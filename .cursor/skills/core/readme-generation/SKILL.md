---
name: readme-generation
description: Generate comprehensive README.md files from actual implemented code following constitution standards. Use when generating README.md, creating service documentation, building PII inventory, or documenting sensitive data. Always generate from real code in Phase 7, never from placeholders.
---

# README Generation Patterns

## README Structure (Mandatory Sections)

1. **Service Name & Description** -- What the service does
2. **Architecture Overview** -- Layer breakdown, external dependencies
3. **API Endpoints** -- Table of all endpoints with methods and descriptions
4. **Configuration** -- Config keys, environment-specific config
5. **External Dependencies** -- APIs called, with URLs and purposes
6. **Sensitive Data & PII Inventory** (MANDATORY) -- See below
7. **Testing** -- How to run component tests
8. **Deployment** -- Environment-specific notes

## Sensitive Data & PII Inventory (MANDATORY)

This section MUST list ALL sensitive data handled by the service:

```markdown
## Sensitive Data & PII Inventory

| Data Field | Classification | Location | Protection |
|------------|---------------|----------|------------|
| User Email | PII | Provider Response | Masked in logs |
| API Key | Secret | ConfigurationProvider | Stored in secret vault, hashed in logs |
| Access Token | Secret | Auth Header | Hashed in logs |
| User ID | PII | Auth Result | Not logged directly |
```

## Generation Rules

- README MUST be generated from **actual implemented code** (Phase 7 -- after all code is done)
- MUST match the real endpoints, dependencies, and configuration
- MUST NOT contain aspirational or planned features
- MUST NOT contain placeholder/template content

## Forbidden README Patterns

| FORBIDDEN | Why |
|-----------|-----|
| Listing endpoints not yet implemented | README must match code |
| "TODO: add description" | No placeholders |
| Copying template README without updates | Must reflect actual service |
| Missing PII inventory | Mandatory section |
| Missing external dependencies | Must list all |

## AI Generation Process

1. Read all controller files to list endpoints
2. Read all provider files to list external dependencies
3. Read ConfigurationProvider for config keys
4. Scan for sensitive data annotations on DTOs for PII inventory
5. Generate README from actual code analysis
