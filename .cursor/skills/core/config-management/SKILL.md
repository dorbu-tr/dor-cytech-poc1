---
name: config-management
description: Configuration management principles covering secrets classification, configuration provider pattern, and appsettings structure. Use when implementing configuration provider, secrets management, application settings, or deciding where config values belong (secret vault vs distributed config).
---

# Configuration Management Principles

## Configuration Provider (NON-NEGOTIABLE)

Every service MUST have a centralized configuration provider that manages all config access. The specific implementation pattern (single nested class, typed config classes, etc.) is defined by your team — see team skill `config-ccm`.

## Secrets Classification

| Data Type | Store In | Examples |
|-----------|----------|----------|
| Passwords, credentials | **Secret vault** | DB passwords, service account credentials |
| API keys, client secrets | **Secret vault** | Third-party API keys, OAuth client secrets |
| Tokens, certificates | **Secret vault** | Signing keys, encryption certificates |
| Connection strings | **Secret vault** | Database URIs with credentials |
| Base URLs | **Distributed config** | `https://int-payment-api.dev.local` |
| Timeouts, thresholds | **Distributed config** | `5000` (ms), `100` (max page size) |
| Feature flags | **Distributed config** | `true` / `false` |

## Application Settings Pattern

The `appsettings.json` MUST contain ONLY bootstrap configuration for your config management system. **FORBIDDEN:** Application-specific config, logging config, connection strings in appsettings.json.

## External API Configuration

Each external API needs dedicated configuration covering at minimum:
- Base URL
- Timeout
- Circuit breaker / resilience settings

The specific structure (nested interface, typed class, etc.) is team-specific — see team skill `config-ccm`.

## Backend-to-Backend Authentication Configuration

For services that expose API key-protected endpoints, store API keys in the secret vault (NOT distributed config). See team skill `config-ccm` for the specific pattern.

## Anti-Patterns

| Anti-Pattern | Correct Pattern |
|-------------|----------------|
| Hardcoded secrets in code | All secrets via config management / secret vault |
| Config values in appsettings.json | Only bootstrap config in appsettings.json |
| Missing config for external APIs | Every external API needs BaseUrl, Timeout, resilience config |
| Secrets in distributed config | Secrets MUST go in secret vault |
