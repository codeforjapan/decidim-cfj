class EnablePgBigmExtension < ActiveRecord::Migration[6.1]
  def up
    enable_extension 'pg_bigm'
  end

  def down
    disable_extension 'pg_bigm'
  end
end
