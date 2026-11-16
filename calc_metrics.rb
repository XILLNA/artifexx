# encoding: utf-8
# ==============================================================================
# Kampánymetriai Kalkulátor (kepvis_ossz és engagement arányok)
# ==============================================================================

module CampaignMetrics
  # Kódkönyv szerinti súlyozott elérés:
  # Facebook: 2 * komment + 2 * megosztás + like
  # Instagram: 2 * komment + like (mivel IG-n nincs natív megosztásszám a nyilvános API-ban)
  def self.calculate_kepvis_ossz(platform, comments, shares, likes)
    c = comments.to_f
    s = shares.to_f
    l = likes.to_f

    if platform.to_s.downcase.include?("facebook") || platform.to_s.downcase == "fb"
      (2 * c) + (2 * s) + l
    else
      (2 * c) + l
    end
  end

  # Engagement ráta kalkuláció
  def self.engagement_distribution(rows)
    return {} if rows.empty?
    total_kepvis = rows.map { |r| r[:kepvis_ossz].to_f }.sum
    avg_kepvis = (total_kepvis / rows.size).round(1)

    by_type = rows.group_by { |r| r[:tipus] }.map do |type, items|
      avg = (items.map { |i| i[:kepvis_ossz].to_f }.sum / items.size).round(1)
      [type, { count: items.size, avg_kepvis: avg }]
    end.to_h

    by_emotion = rows.group_by { |r| r[:mores_emotion] }.map do |emo, items|
      avg = (items.map { |i| i[:kepvis_ossz].to_f }.sum / items.size).round(1)
      [emo, { count: items.size, avg_kepvis: avg }]
    end.to_h

    {
      total_posts: rows.size,
      total_kepvis: total_kepvis.to_i,
      avg_kepvis: avg_kepvis,
      by_type: by_type,
      by_emotion: by_emotion
    }
  end
end
