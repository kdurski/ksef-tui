class CreateKsefLoginRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :ksef_login_requests do |t|
      t.integer :status, null: false, default: 0
      t.string :profile_id
      t.string :profile_name
      t.string :nip, null: false
      t.string :seed_token, null: false
      t.string :host, null: false
      t.string :access_token
      t.string :refresh_token
      t.string :access_token_valid_until
      t.string :refresh_token_valid_until
      t.text :error_message
      t.datetime :completed_at

      t.timestamps
    end

    add_index :ksef_login_requests, :status
    add_index :ksef_login_requests, :profile_id
  end
end
