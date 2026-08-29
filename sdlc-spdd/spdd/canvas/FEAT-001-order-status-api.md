# REASONS Canvas: FEAT-001-order-status-api - Order Status Search API

## Metadata

- Work ID: FEAT-001-order-status-api
- Work Type: Feature
- Status: Ready For Coding
- Readiness: Ready For Coding
- Created: 2026-08-29
- Updated: 2026-08-29
- Owner: dogfood
- Target Project: dogfood-api
- Stack: Java, Spring Boot, Maven

## R - Requirements

### User Goal

Search orders by customer email via REST API.

### Business / Product Goal

Reduce support response time for order lookup requests.

### Acceptance Criteria

- [x] `GET /api/orders?email=` returns matching orders
- [x] Invalid email format returns 400
- [x] Empty result returns 200 with empty list
- [x] Tests cover service and controller behavior

### Non-Goals

- Pagination
- Auth changes
- Schema migration

### Assumptions

- Order entity already has `customerEmail` field
- Existing repository pattern can add finder method

## E - Entities

### Domain Entities

- Order

### Files Likely Affected

- `src/main/java/com/jmjava/dogfood/api/OrderController.java`
- `src/main/java/com/jmjava/dogfood/service/OrderService.java`
- `src/main/java/com/jmjava/dogfood/persist/OrderRepository.java`

## O - Operations

### T01 - Add repository and service lookup

- Status: Complete
- Description: Add `findByCustomerEmail` and service method

### T02 - Add REST endpoint

- Status: Complete
- Description: Expose GET `/api/orders?email=` with validation

### T03 - Document API behavior

- Status: Not Started
- Description: Update README or OpenAPI if the project uses it

## N - Norms

### Java / Spring Boot

- Constructor injection
- No business logic in controller
- Preserve package boundaries

## S - Safeguards

- Do not change auth behavior
- Do not change unrelated API endpoints
- Do not add dependencies without justification
