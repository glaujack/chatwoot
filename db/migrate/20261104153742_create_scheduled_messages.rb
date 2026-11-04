class CreateScheduledMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :scheduled_messages do |t|
      t.references :account, null: false, index: true
      t.references :conversation, null: false, index: true
      t.references :user, null: false, index: true
      t.text :content, null: false
      t.datetime :next_run_at, null: false
      t.integer :recurrence, null: false, default: 0
      t.string :time_zone, null: false, default: 'UTC'
      t.integer :status, null: false, default: 0
      t.integer :attempts, null: false, default: 0
      t.datetime :last_run_at
      t.string :last_error
      t.timestamps
    end
    add_index :scheduled_messages, [:status, :next_run_at]
  end
end
