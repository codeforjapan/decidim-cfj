# frozen_string_literal: true

require "rails_helper"

# Backport of decidim/decidim#16545. See
# config/initializers/content_renderers_context_override.rb for the why and the
# removal steps.
RSpec.describe "content renderers context override" do
  describe Decidim::ContentRenderers::BaseRenderer do
    let(:renderer_class) do
      Class.new(described_class) do
        def render(skip_ancestor_tags: %w(code pre script style), on_missing: "", raise_on_match: false)
          replace_pattern_by_context(content, /TOKEN/, skip_ancestor_tags:, on_missing:) do |_match, context|
            raise ActiveRecord::RecordNotFound if raise_on_match

            context.attribute? ? "ATTR" : "<strong>TEXT</strong>"
          end
        end
      end
    end

    let(:renderer) { renderer_class.new(content) }

    describe "#replace_pattern_by_context" do
      context "with default skip_ancestor_tags" do
        let(:content) do
          <<~HTML.squish
            <p>TOKEN</p>
            <a href="TOKEN">link</a>
            <code data-reference="TOKEN"><span data-reference="TOKEN">TOKEN</span></code>
            <pre>TOKEN</pre>
            <script>var token = "TOKEN";</script>
            <style>.sample{content:"TOKEN";}</style>
          HTML
        end

        it "replaces in text and attributes outside skipped tags" do
          rendered = Loofah.fragment(renderer.render)

          expect(rendered.at_css("p > strong").text).to eq("TEXT")
          expect(rendered.at_css("a")["href"]).to eq("ATTR")
        end

        it "does not replace inside skipped ancestor tags" do
          rendered = Loofah.fragment(renderer.render)

          expect(rendered.at_css("code").text).to eq("TOKEN")
          expect(rendered.at_css("code")["data-reference"]).to eq("TOKEN")
          expect(rendered.at_css("code span").text).to eq("TOKEN")
          expect(rendered.at_css("code span")["data-reference"]).to eq("TOKEN")
          expect(rendered.at_css("pre").text).to eq("TOKEN")
          expect(rendered.at_css("script").text).to include("TOKEN")
          expect(rendered.at_css("style").text).to include("TOKEN")
        end
      end

      context "with custom skip_ancestor_tags" do
        let(:content) do
          <<~HTML.squish
            <blockquote>TOKEN</blockquote>
            <code>TOKEN</code>
          HTML
        end

        it "respects the custom skipped tag list" do
          rendered = Loofah.fragment(renderer.render(skip_ancestor_tags: %w(blockquote)))

          expect(rendered.at_css("blockquote").text).to eq("TOKEN")
          expect(rendered.at_css("code > strong").text).to eq("TEXT")
        end
      end

      context "when text node contains escaped HTML alongside a token" do
        let(:content) { "<p>&lt;script&gt;alert(1)&lt;/script&gt; TOKEN</p>" }

        it "keeps escaped html as plain text and does not promote it to live markup" do
          rendered = Loofah.fragment(renderer.render)
          p_node = rendered.at_css("p")

          expect(p_node.at_css("script")).to be_nil
          expect(p_node.text).to include("<script>alert(1)</script>")
          expect(p_node.at_css("strong").text).to eq("TEXT")
        end
      end

      context "when replacement raises RecordNotFound" do
        let(:content) { "<p>TOKEN</p>" }

        it "uses static on_missing fallback" do
          expect(renderer.render(raise_on_match: true, on_missing: "MISSING")).to eq("<p>MISSING</p>")
        end

        it "uses callable on_missing fallback" do
          on_missing = ->(match, _context) { "missing:#{match.downcase}" }

          expect(renderer.render(raise_on_match: true, on_missing:)).to eq("<p>missing:token</p>")
        end
      end
    end
  end

  describe Decidim::ContentRenderers::BlobRenderer do
    let(:renderer) { described_class.new(content) }
    let(:blob_gid) { "gid://decidim-app/ActiveStorage::Blob/1" }

    describe "#render" do
      subject { renderer.render }

      context "when the blob GID is inside a code tag" do
        let(:content) { "<p><code>#{blob_gid}</code></p>" }

        it "does not replace the blob GID" do
          expect(Loofah.fragment(subject).at_css("code").text).to eq(blob_gid)
        end
      end

      context "when the blob GID is inside a pre tag" do
        let(:content) { "<pre>Image URL: #{blob_gid}</pre>" }

        it "does not replace the blob GID" do
          expect(Loofah.fragment(subject).at_css("pre").text).to include(blob_gid)
        end
      end

      context "when the blob GID is inside a script tag" do
        let(:content) { %(<script>var blobId = "#{blob_gid}";</script>) }

        it "does not replace the blob GID" do
          expect(Loofah.fragment(subject).at_css("script").text).to include(blob_gid)
        end
      end

      context "when the blob GID is inside a style tag" do
        let(:content) { %(<style>.bg { background: url('#{blob_gid}'); }</style>) }

        it "does not replace the blob GID" do
          expect(Loofah.fragment(subject).at_css("style").text).to include(blob_gid)
        end
      end

      context "when the blob GID is a text node outside skipped tags" do
        let(:content) { %(<p class="document-url">#{blob_gid}</p>) }

        it "removes the missing blob GID instead of raising" do
          expect(subject).to eq(%(<p class="document-url"></p>))
        end
      end
    end
  end

  describe Decidim::ContentRenderers::ResourceRenderer do
    let(:renderer_class) do
      Class.new(described_class) do
        def regex
          %r{gid://[\w-]+/Decidim::Proposals::Proposal/\d+}
        end
      end
    end

    let(:proposal) { create(:proposal) }
    let(:renderer) { renderer_class.new(content) }
    let(:proposal_path) { Decidim::ResourceLocatorPresenter.new(proposal).path }

    describe "#render" do
      context "when the resource GID is inside an anchor href" do
        let(:content) { %(<a href="#{proposal.to_global_id}">Proposal link</a>) }

        it "converts the resource GID in href to the resource path" do
          link = Loofah.fragment(renderer.render).at_css("a")

          expect(link["href"]).to eq(proposal_path)
          expect(link.text).to eq("Proposal link")
        end
      end

      context "when the resource GID is inside a code tag" do
        let(:content) { "<code>#{proposal.to_global_id}</code>" }

        it "does not replace the resource GID" do
          expect(Loofah.fragment(renderer.render).at_css("code").text).to eq(proposal.to_global_id.to_s)
        end
      end

      context "when the resource GID is invalid" do
        let(:content) { "Invalid proposal: gid://decidim-app/Decidim::Proposals::Proposal/999999" }

        it "replaces it with the tilde notation" do
          expect(renderer.render).to include("~999999")
        end
      end
    end
  end

  describe Decidim::ContentRenderers::UserRenderer do
    let(:user) { create(:user, :confirmed) }
    let(:renderer) { described_class.new(content) }
    let(:profile_path) { Decidim::UserPresenter.new(user).profile_path }

    describe "#render" do
      context "when the user GID is inside an anchor href" do
        let(:content) { %(<a href="#{user.to_global_id}">Link to user</a>) }

        it "converts the user GID in href to the profile path" do
          link = Loofah.fragment(renderer.render).at_css("a")

          expect(link["href"]).to eq(profile_path)
          expect(link.text).to eq("Link to user")
        end
      end

      context "when the user GID is inside an anchor href in editor mode" do
        let(:content) { %(<a href="#{user.to_global_id}">Link to user</a>) }

        it "converts the user GID in href to the profile path" do
          link = Loofah.fragment(renderer.render(editor: true)).at_css("a")

          expect(link["href"]).to eq(profile_path)
        end
      end

      context "when the user GID is inside a code tag" do
        let(:content) { "<code>#{user.to_global_id}</code>" }

        it "does not replace the user GID" do
          expect(Loofah.fragment(renderer.render).at_css("code").text).to eq(user.to_global_id.to_s)
        end
      end
    end
  end
end
