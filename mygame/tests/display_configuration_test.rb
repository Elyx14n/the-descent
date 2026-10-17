# frozen_string_literal: true

class DisplayConfigurationTests
  def test_hd_stays_disabled_for_lighting_performance(_args, assert)
    assert.false! Grid.hd?
    assert.equal! Grid.render_scale, 1
    assert.equal! [Grid.w, Grid.h], [320, 180]
  end
end
