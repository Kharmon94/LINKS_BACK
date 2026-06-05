# frozen_string_literal: true

module Admin
  class UserScope
    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 200

    def self.call(relation: User.all, q: nil, role: nil, page: 1, per_page: DEFAULT_PER_PAGE)
      per_page = per_page.to_i
      per_page = DEFAULT_PER_PAGE if per_page <= 0
      per_page = [per_page, MAX_PER_PAGE].min
      page = [page.to_i, 1].max

      scope = relation
      if q.present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(q.to_s.downcase)}%"
        scope = scope.where("lower(email) LIKE ? OR lower(name) LIKE ?", term, term)
      end
      if role.present? && %w[owner admin member].include?(role.to_s)
        scope = scope.where(role: role)
      end

      total = scope.count
      users = scope.order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)

      {
        users: users,
        meta: {
          page: page,
          perPage: per_page,
          total: total,
          q: q.presence,
          role: role.presence
        }.compact
      }
    end
  end
end
