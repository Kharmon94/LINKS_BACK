# frozen_string_literal: true

module Admin
  class TeamScope
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 200

    def self.call(relation: Team.all, q: nil, personal: nil, page: 1, per_page: DEFAULT_PER_PAGE)
      per_page = per_page.to_i
      per_page = DEFAULT_PER_PAGE if per_page <= 0
      per_page = [per_page, MAX_PER_PAGE].min
      page = [page.to_i, 1].max

      scope = relation
      if q.present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(q.to_s.downcase)}%"
        scope = scope.where("lower(name) LIKE ?", term)
      end
      if personal.present?
        scope = scope.where(personal: ActiveModel::Type::Boolean.new.cast(personal))
      end

      total = scope.count

      teams = scope
        .select("teams.*")
        .select("(SELECT COUNT(*) FROM team_memberships tm WHERE tm.team_id = teams.id) AS members_count")
        .select("(SELECT COUNT(*) FROM workspaces w WHERE w.team_id = teams.id) AS workspaces_count")
        .order(created_at: :desc)
        .offset((page - 1) * per_page)
        .limit(per_page)

      {
        teams: teams,
        meta: {
          page: page,
          perPage: per_page,
          total: total,
          q: q.presence,
          personal: personal.presence
        }.compact
      }
    end
  end
end
