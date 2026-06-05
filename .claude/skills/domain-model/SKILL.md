# Skill: domain-model

## Entity Hierarchy

```
User
  └── WorkspaceMemberships  (role: super_admin | admin | collaborator)
        └── Workspace
              └── Apps
                    ├── Reviews   (raw, deduplicated by external_id)
                    └── Reports   (versioned JSONB output)

Notifications  (belongs to User + Report)
```

## Ownership Rules

- Content (Apps, Reviews, Reports) belongs to the **Workspace**, not the user who created it
- Removing a user from a workspace does not affect any workspace data
- A user can belong to multiple workspaces with different roles in each

## Schema

### users
| Column | Type | Notes |
|---|---|---|
| email | string | not null, unique |
| name | string | |
| avatar_url | string | |
| provider | string | not null — always `"google_oauth2"` |
| uid | string | not null — Google's user ID |
| remember_created_at | datetime | Devise |
| sign_in_count | integer | Devise trackable |
| current/last_sign_in_at | datetime | Devise trackable |
| current/last_sign_in_ip | string | Devise trackable |

Unique index on `(provider, uid)`.

### workspaces
| Column | Type | Notes |
|---|---|---|
| name | string | not null |
| slug | string | not null, unique — auto-generated from name |

### workspace_memberships
| Column | Type | Notes |
|---|---|---|
| user_id | integer | FK users |
| workspace_id | integer | FK workspaces |
| role | integer | enum: collaborator=0, admin=1, super_admin=2 |
| invited_by_user_id | integer | nullable FK users |
| joined_at | datetime | null = pending invite |

Unique index on `(user_id, workspace_id)`.

### apps
| Column | Type | Notes |
|---|---|---|
| workspace_id | integer | FK workspaces |
| name | string | not null |
| app_store_id | string | nullable |
| app_store_country | string | nullable, default: `"us"` |
| play_store_id | string | nullable |
| created_by_user_id | integer | FK users |

Validation: at least one of `app_store_id` or `play_store_id` must be present.

### reviews
| Column | Type | Notes |
|---|---|---|
| app_id | integer | FK apps |
| store | integer | enum: app_store=0, play_store=1 |
| external_id | string | not null — original ID from the store |
| author | string | |
| rating | integer | 1–5 |
| title | string | nullable — Play Store has no titles |
| body | text | |
| reviewed_at | datetime | |
| fetched_at | datetime | |

Unique index on `(app_id, store, external_id)` — enables upsert via `insert_all`.

### reports
| Column | Type | Notes |
|---|---|---|
| app_id | integer | FK apps |
| generated_by_user_id | integer | FK users |
| status | integer | enum: pending=0, fetching=1, analyzing=2, complete=3, failed=4 |
| failure_reason | text | nullable |
| structured_output | jsonb | nullable — the full LLM analysis |
| total_reviews_analyzed | integer | default: 0 |
| reviews_fetched_at | datetime | nullable |

### notifications
| Column | Type | Notes |
|---|---|---|
| user_id | integer | FK users |
| workspace_id | integer | FK workspaces |
| report_id | integer | FK reports |
| message | string | not null |
| read_at | datetime | nullable — null = unread |

Index on `(user_id, read_at)` for fast unread count queries.