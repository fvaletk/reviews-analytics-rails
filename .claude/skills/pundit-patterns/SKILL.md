# Skill: pundit-patterns

## Role Reference

Roles live on `WorkspaceMembership`, not on `User`.
A user's role is always workspace-scoped.

```
collaborator  → view only
admin         → view + generate reports
super_admin   → view + generate + invite/remove members
```

## Helper in ApplicationController

```ruby
# Returns current user's role in a workspace, or nil if not a member
def membership_in(workspace)
  current_user.workspace_memberships.find_by(workspace: workspace)
end
```

## Policy Structure

```ruby
class WorkspacePolicy < ApplicationPolicy
  # record = workspace instance

  def show?
    member?
  end

  def invite?
    super_admin?
  end

  def generate_report?
    admin? || super_admin?
  end

  class Scope < Scope
    def resolve
      scope.joins(:workspace_memberships)
           .where(workspace_memberships: { user: user })
    end
  end

  private

  def membership
    @membership ||= user.workspace_memberships.find_by(workspace: record)
  end

  def member?
    membership.present?
  end

  def admin?
    membership&.admin?
  end

  def super_admin?
    membership&.super_admin?
  end
end
```

## Usage in Controllers

```ruby
class WorkspacesController < ApplicationController
  def show
    @workspace = Workspace.find_by!(slug: params[:id])
    authorize @workspace         # calls WorkspacePolicy#show?
  end

  def index
    @workspaces = policy_scope(Workspace)   # calls WorkspacePolicy::Scope
  end
end
```

## Usage in Views

```erb
<% if policy(@workspace).invite? %>
  <%= link_to "Invite member", new_workspace_membership_path(@workspace) %>
<% end %>
```

## Handling Not Authorized

In `ApplicationController`:

```ruby
rescue_from Pundit::NotAuthorizedError do
  render file: Rails.root.join("public/404.html"), status: :not_found
end
```

Return 404 not 403 — don't confirm resource existence to unauthorized users.

## Rules

- `authorize` must be called in every controller action — `after_action :verify_authorized` enforces this
- Scope must be used in every index action — `after_action :verify_policy_scoped` enforces this
- Never pass role checks in controllers directly — always go through policy
- One policy file per model