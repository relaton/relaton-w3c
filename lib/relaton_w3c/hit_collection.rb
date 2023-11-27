module RelatonW3c
  class HitCollection < RelatonBib::HitCollection
    def initialize(rows)
      @array = rows.map { |r| Hit.new(**r) }
    end
  end
end
