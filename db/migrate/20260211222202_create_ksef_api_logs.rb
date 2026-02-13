class CreateKsefApiLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :ksef_api_logs do |t|
      t.datetime :timestamp
      t.string :http_method
      t.string :path
      t.integer :status
      t.float :duration
      t.json :request_headers
      t.text :request_body
      t.json :response_headers
      t.text :response_body
      t.text :error

      t.timestamps
    end
  end
end
