module RelatonW3c
  class Hit
    def initialize(rows)
      @array = rows.map { |r| Hit.new(**r) }
    end
  end
end
