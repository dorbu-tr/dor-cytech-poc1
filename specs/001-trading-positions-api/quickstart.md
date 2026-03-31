# Quickstart: Trading Positions API

**Branch**: `001-trading-positions-api` | **Date**: 2026-03-31

## Prerequisites

- .NET 8.0 SDK
- Access to eToro VPN (for upstream API connectivity in Integration)
- STS token for testing (or use component tests with mocks)

## Build & Run

```bash
# Build the solution
dotnet build dor-cytech-poc1.Api.sln

# Run component tests (locally — mocked dependencies)
dotnet test --filter "Category=ComponentTests"

# Run the API locally (requires VPN for upstream APIs)
dotnet run --project src/dor-cytech-poc1.Api
```

## Endpoints

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/positions` | List open positions (paginated) |
| GET | `/api/v1/positions/{positionId}` | Get position details |
| POST | `/api/v1/positions/{positionId}/close` | Close a position |
| GET | `/health` | Health check (upstream connectivity) |

## Authentication

All endpoints require an STS token in the `Authorization` header (raw token, no Bearer prefix).

```bash
# Example: List positions
curl -X GET "http://localhost:5000/api/v1/positions?pageSize=10" \
  -H "Authorization: <your-sts-token>"

# Example: Get position detail
curl -X GET "http://localhost:5000/api/v1/positions/12345678" \
  -H "Authorization: <your-sts-token>"

# Example: Close position with reason
curl -X POST "http://localhost:5000/api/v1/positions/12345678/close" \
  -H "Authorization: <your-sts-token>" \
  -H "Content-Type: application/json" \
  -d '{"closeReason": "UserRequested"}'
```

## Query Parameters

### GET /api/v1/positions

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| cursor | string | No | — | Pagination cursor from previous response |
| pageSize | int | No | 20 (CCM) | Items per page (1–100) |
| instrumentId | int | No | — | Filter by instrument |

## Configuration (CCM)

Key configuration values managed via CCM (etcd):

| Key | Default | Description |
|-----|---------|-------------|
| PositionsApi.BaseUrl | `http://int-tapi-real.dev.local` | Upstream Positions API base URL |
| PositionsApi.TimeoutMs | 2000 | Request timeout in milliseconds |
| InstrumentsApi.BaseUrl | `http://int-tapi-real.dev.local` | Upstream Instruments API base URL |
| InstrumentsApi.TimeoutMs | 1000 | Request timeout in milliseconds |
| Pagination.DefaultPageSize | 20 | Default page size |
| Pagination.MaxPageSize | 100 | Maximum allowed page size |

## Upstream Dependencies

| Service | Base URL (Integration) | Health Check |
|---------|----------------------|--------------|
| Positions API | `http://int-tapi-real.dev.local` | HTTP GET health endpoint |
| Instruments API | `http://int-tapi-real.dev.local` | HTTP GET health endpoint |

## Architecture

```
Client (STS token)
    │
    ▼
┌─────────────────────────┐
│  Trading Positions API   │  ← This service
│  (Aggregator)            │
├─────────────────────────┤
│  PositionsController     │  GET list, GET detail, POST close
│  PositionsService        │  Orchestration, pagination, enrichment
│  PositionsApiProvider    │  HttpClient + Polly → Positions API
│  InstrumentsApiProvider  │  HttpClient + Polly → Instruments API
└──────────┬──────────────┘
           │
    ┌──────┴──────┐
    ▼             ▼
┌─────────┐ ┌───────────┐
│Positions│ │Instruments│   ← Upstream APIs (trading-api)
│  API    │ │   API     │
└─────────┘ └───────────┘
```

## Testing

```bash
# Component tests only (run locally)
dotnet test --filter "Category=ComponentTests"

# System tests — DO NOT run locally (CI/CD only)
# They target real Integration environment
```

## Project Structure

```
src/
├── dor-cytech-poc1.Api/           # Controllers, DTOs, Validators, Bootstrap
├── dor-cytech-poc1.Application/   # Service, Parameters, Results, Exceptions
├── dor-cytech-poc1.Domain/        # Enumerations (PositionStatus, CloseReason)
└── dor-cytech-poc1.Infrastructure/# Providers (Positions API, Instruments API)

Tests/
├── dor-cytech-poc1.Tests.Component/  # Component tests (run locally)
└── dor-cytech-poc1.Tests.System/     # System tests (CI/CD only)
```
