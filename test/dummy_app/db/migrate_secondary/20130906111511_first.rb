class First < ActiveRecord::Migration[6.0]
  def up
    TestingState.up << :first
  end

  def down
    TestingState.down << :first
  end
end
