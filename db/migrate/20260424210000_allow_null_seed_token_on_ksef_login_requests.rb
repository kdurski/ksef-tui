class AllowNullSeedTokenOnKsefLoginRequests < ActiveRecord::Migration[8.1]
  def change
    change_column_null :ksef_login_requests, :seed_token, true
  end
end
