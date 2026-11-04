# frozen_string_literal: true

require "rails_helper"

describe "ImageMagick policy" do
  let(:dir) { Pathname(Dir.mktmpdir) }
  let(:output) { dir.join("out.png") }
  let(:msl) { dir.join("input.msl") }

  before do
    msl.write(%(<?xml version="1.0" encoding="UTF-8"?><image><read filename="rose:"/><write filename="#{output}"/></image>))
  end

  after { FileUtils.remove_entry(dir) }

  it "puts config/imagemagick first in MAGICK_CONFIGURE_PATH" do
    expect(ENV.fetch("MAGICK_CONFIGURE_PATH").split(File::PATH_SEPARATOR).first)
      .to eq(Rails.root.join("config/imagemagick").to_s)
  end

  it "does not run MSL input" do
    expect { MiniMagick::Tool::Convert.new { |c| c << "msl:#{msl}" << "null:" } }.to raise_error(MiniMagick::Error)
    expect(output).not_to exist
  end

  it "still converts ordinary images" do
    MiniMagick::Tool::Convert.new { |c| c << "rose:" << output.to_s }

    expect(MiniMagick::Image.open(output.to_s).type).to eq("PNG")
  end
end
