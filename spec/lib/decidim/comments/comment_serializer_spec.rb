# frozen_string_literal: true

require "rails_helper"

module Decidim
  module Comments
    describe CommentSerializer do
      let(:comment) { create(:comment) }

      subject { described_class.new(comment) }

      before do
        # Stub root_commentable_url because the dummy component from decidim-dev
        # doesn't have its routes mounted in the host app's test environment
        allow_any_instance_of(described_class).to receive(:root_commentable_url).and_return("http://example.org/dummy_url") # rubocop:disable RSpec/AnyInstance
      end

      describe "#serialize" do
        it "includes the id" do
          expect(subject.serialize).to include(id: comment.id)
        end

        it "includes the creation date" do
          expect(subject.serialize).to include(created_at: comment.created_at)
        end

        it "includes the body" do
          expect(subject.serialize).to include(body: comment.body.values.first)
        end

        it "includes the body locale" do
          expect(subject.serialize).to include(locale: comment.body.keys.first)
        end

        it "includes the author" do
          expect(subject.serialize[:author]).to(
            include(id: comment.author.id, name: comment.author.name)
          )
        end

        it "includes the alignment" do
          expect(subject.serialize).to include(alignment: comment.alignment)
        end

        it "includes the depth" do
          expect(subject.serialize).to include(depth: comment.depth)
        end

        it "includes the root commentable's url" do
          expect(subject.serialize[:root_commentable_url]).to match(/http/)
        end

        context "when the author is a deleted user" do
          before do
            Decidim::DestroyAccount.call(Decidim::DeleteAccountForm.from_params({}).with_context({ current_user: comment.author }))
          end

          it "serializes without error" do
            serialized = subject.serialize
            expect(serialized[:author]).to eq(id: comment.decidim_author_id, name: "")
          end
        end
      end
    end
  end
end
