class Second < ActiveRecord::Migration[6.0]
  def up
    TestingState.up << :second
  end

  def down
    TestingState.down << :second
  end
end
