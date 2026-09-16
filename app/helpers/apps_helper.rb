module AppsHelper
  # Groups an app's ICP signals by their raw role_hint string, ordered by
  # group size descending. No normalisation or case-folding is applied —
  # two hints differing only in case remain separate groups.
  #
  # Returns an array of [role_hint, signals] pairs, or [] when the app has
  # no ICP, or its ICP carries no signals.
  def icp_signal_groups(app)
    signals = app.icp&.dig("signals")
    return [] if signals.blank?

    signals.group_by { |signal| signal["role_hint"] }
           .sort_by { |(_role_hint, group_signals)| -group_signals.size }
  end
end
