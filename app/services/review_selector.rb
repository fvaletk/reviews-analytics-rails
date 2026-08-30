# frozen_string_literal: true

# Selects a bounded, diagnostically-sound sample of reviews for LLM analysis.
#
# 1. Filters out low-information reviews (blank, too short, or exact
#    near-duplicate bodies within an app + store).
# 2. Stratifies the remaining reviews per store into rating bands (negative,
#    mixed, positive) so the sample isn't dominated by whichever sentiment
#    happens to be most recent. Underfilled bands release their remainder to
#    other bands in the same store. Unrated reviews are never dropped — they
#    fill any leftover per-store headroom.
# 3. Applies BRA-82's cross-store spillover on top, so a single-store app
#    still receives up to MAX_REVIEWS_TOTAL reviews.
#
# Also computes the TRUE rating distribution over the full, unfiltered corpus
# so the LLM prompt can state real-world frequency instead of letting the
# model infer it from the (much smaller) sample.
class ReviewSelector
  Result = Struct.new(:app_store, :play_store, :metadata, keyword_init: true)

  MAX_REVIEWS_TOTAL     = 500
  MAX_REVIEWS_PER_STORE = 250
  MIN_BODY_LENGTH       = 12

  BANDS = {
    negative: { ratings: [ 1, 2 ], share: 0.45 },
    mixed:    { ratings: [ 3 ],    share: 0.25 },
    positive: { ratings: [ 4, 5 ], share: 0.30 }
  }.freeze

  def self.select(scope)
    new(scope).select
  end

  def initialize(scope)
    @scope = scope
  end

  def select
    distribution = compute_distribution
    filtered_reviews, filtered_out = filter_noise

    app_store_pool  = filtered_reviews.select { |r| r.store == "app_store" }
    play_store_pool = filtered_reviews.select { |r| r.store == "play_store" }

    app_store_selection  = select_for_store(app_store_pool)
    play_store_selection = select_for_store(play_store_pool)

    app_store_selected  = app_store_selection[:selected]
    play_store_selected = play_store_selection[:selected]

    apply_store_spillover(
      app_store_selected: app_store_selected,
      play_store_selected: play_store_selected,
      app_store_pool: app_store_pool,
      play_store_pool: play_store_pool,
      app_store_bands: app_store_selection[:bands],
      play_store_bands: play_store_selection[:bands]
    )

    Result.new(
      app_store: app_store_selected,
      play_store: play_store_selected,
      metadata: {
        filtered_out: filtered_out,
        distribution: distribution,
        selected: {
          app_store: app_store_selection[:bands],
          play_store: play_store_selection[:bands]
        }
      }
    )
  end

  private

  attr_reader :scope

  def compute_distribution
    raw_counts = scope.group(:rating).count

    (1..5).each_with_object({}) { |r, h| h[r.to_s] = raw_counts[r] || 0 }.tap do |distribution|
      distribution["unrated"] = raw_counts[nil] || 0
    end
  end

  def filter_noise
    reviews = scope.to_a.sort_by { |r| r.reviewed_at || Time.at(0) }.reverse
    seen_bodies = { "app_store" => Set.new, "play_store" => Set.new }
    filtered_out = { empty: 0, too_short: 0, duplicate: 0 }
    kept = []

    reviews.each do |review|
      if review.body.blank?
        filtered_out[:empty] += 1
        next
      end

      normalized = normalize(review.body)

      if normalized.length < MIN_BODY_LENGTH
        filtered_out[:too_short] += 1
        next
      end

      store_seen = seen_bodies[review.store]

      if store_seen.include?(normalized)
        filtered_out[:duplicate] += 1
        next
      end

      store_seen << normalized
      kept << review
    end

    [ kept, filtered_out ]
  end

  def normalize(body)
    body.to_s.downcase.gsub(/[^\p{Alnum}\s]/, "").gsub(/\s+/, " ").strip
  end

  # Given a store's recency-ordered, noise-filtered pool of reviews, fills
  # band quotas (with same-store band spillover), then fills leftover
  # per-store headroom from unrated reviews.
  #
  # Returns the selected reviews plus band counts, and the pool of reviews
  # from this store that were NOT selected (recency-ordered), for use by
  # cross-store spillover.
  def select_for_store(pool)
    banded = { negative: [], mixed: [], positive: [] }
    unrated = []

    pool.each do |review|
      band = BANDS.find { |_, cfg| cfg[:ratings].include?(review.rating) }&.first
      band ? banded[band] << review : unrated << review
    end

    quotas = BANDS.transform_values { |cfg| (MAX_REVIEWS_PER_STORE * cfg[:share]).round }

    taken = {}
    BANDS.each_key { |band| taken[band] = banded[band].first(quotas[band]) }

    deficit = BANDS.each_key.sum { |band| [ quotas[band] - taken[band].size, 0 ].max }

    if deficit > 0
      BANDS.each_key do |band|
        break if deficit <= 0

        surplus_pool = banded[band][taken[band].size..] || []
        extra = surplus_pool.first(deficit)
        taken[band] += extra
        deficit -= extra.size
      end
    end

    rated_selected = taken.values.flatten
    per_store_remaining = MAX_REVIEWS_PER_STORE - rated_selected.size
    unrated_selected = per_store_remaining > 0 ? unrated.first(per_store_remaining) : []

    selected = rated_selected + unrated_selected

    {
      selected: selected,
      bands: {
        negative: taken[:negative].size,
        mixed: taken[:mixed].size,
        positive: taken[:positive].size,
        unrated: unrated_selected.size
      }
    }
  end

  def apply_store_spillover(app_store_selected:, play_store_selected:, app_store_pool:, play_store_pool:, app_store_bands:, play_store_bands:)
    remaining = MAX_REVIEWS_TOTAL - app_store_selected.size - play_store_selected.size
    return if remaining <= 0

    app_store_remaining_pool = app_store_pool - app_store_selected
    extra_app_store = app_store_remaining_pool.first(remaining)
    remaining -= extra_app_store.size

    play_store_remaining_pool = play_store_pool - play_store_selected
    extra_play_store = remaining > 0 ? play_store_remaining_pool.first(remaining) : []

    app_store_selected.concat(extra_app_store)
    play_store_selected.concat(extra_play_store)

    absorb_spillover(app_store_bands, extra_app_store)
    absorb_spillover(play_store_bands, extra_play_store)
  end

  def absorb_spillover(bands, extra_reviews)
    extra_reviews.each do |review|
      band = BANDS.find { |_, cfg| cfg[:ratings].include?(review.rating) }&.first || :unrated
      bands[band] += 1
    end
  end
end
