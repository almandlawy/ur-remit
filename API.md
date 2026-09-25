# API contract

Canonical prefixes:

- Public app: `/api/v1/mobile`
- Administration: `/api/v1/admin`
- Operational health: `/api/v1/health`

Every response includes `requestId`. Rate resources include `updatedAt`, `sourceTimestamp`, and `version`. Errors use stable codes and localized presentation remains a client concern.

## Public endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | service and dependency health |
| GET | `/mobile/rates` | active routes and rates |
| GET | `/mobile/rates/:id` | one active rate |
| GET | `/mobile/rates/history` | bounded public history |
| GET | `/mobile/countries` | supported countries |
| GET | `/mobile/cities` | supported cities |
| GET | `/mobile/routes` | active corridors |
| GET | `/mobile/offices` | active verified offices |
| GET | `/mobile/app-config` | safe remote configuration |
| GET | `/mobile/notices` | published notices |
| GET | `/mobile/agents/verify` | minimal agent verification |
| GET | `/mobile/transfers/:reference/status` | privacy-minimized status |

No endpoint in the public app namespace initiates or modifies a financial transaction.

