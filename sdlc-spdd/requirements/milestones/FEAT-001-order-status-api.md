---
work_id: "FEAT-001-order-status-api"
jira_key: "DOG-1"
github_number: ""
milestone: "milestone-1"
---

# FEAT-001: Order Status Search API

**Work ID:** FEAT-001-order-status-api  
**Milestone:** Milestone 1  
**Status:** Ready For Coding  
**Date:** 2026-08-29

## User / Business Goal

Operations users search orders by customer email so support lookups stay fast.

## Scope

### IN SCOPE

- `GET /api/orders?email=`
- 400 on invalid email
- 200 with an empty list when nothing matches
- Thin controller, service owns lookup

### NOT IN SCOPE

- Pagination
- Auth changes (`AuthFilter` / `/api/admin/**`)
- Schema migration

## Acceptance Criteria

- [x] Matching email returns the orders
- [x] Invalid email returns 400
- [x] Unknown email returns 200 `[]`
- [x] Tests cover controller and auth safeguard

## Jira

- Key: DOG-1
- Issue type: Story
- Summary: Order status search by email
