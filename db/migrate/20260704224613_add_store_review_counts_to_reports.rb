class AddStoreReviewCountsToReports < ActiveRecord::Migration[8.0]
  def change
    add_column :reports, :app_store_reviews_count, :integer, default: 0, null: false
    add_column :reports, :play_store_reviews_count, :integer, default: 0, null: false
  end
end
