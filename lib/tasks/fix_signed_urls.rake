# frozen_string_literal: true

require_relative "../decidim/cfj/url_converter"

namespace :decidim do
  namespace :cfj do
    desc "Fix signed URLs in rich text content by converting them to permanent blob URLs or Global IDs"
    task fix_signed_urls: :environment do
      puts "Starting signed URL fix task..."

      # Pattern to match signed S3 URLs that might be in content

      # Also pattern for blob URLs that might have expired signatures

      # Counter for tracking changes
      fixed_count = 0
      total_checked = 0

      # Function to find and fix URLs in text
      def fix_urls_in_text(text, fixed_count, total_checked)
        return [text, fixed_count, total_checked] if text.blank?

        total_checked += 1
        original_text = text.dup

        # Strategy 1: Convert Rails blob URLs to Global IDs (preferred)
        text = text.gsub(%r{/rails/active_storage/blobs/[^"'\s]+}) do |match|
          global_id = Decidim::Cfj::UrlConverter.rails_url_to_global_id(match)
          if global_id
            puts "  ✓ Converted Rails URL to Global ID: #{match.split("/").last}"
            global_id
          else
            puts "  ⚠ Failed to convert Rails URL: #{match}"
            match
          end
        end

        # Strategy 2: Convert S3 URLs to Global IDs
        text = text.gsub(%r{https://[^/]+\.s3[^/]*\.amazonaws\.com/[^?"'\s]+}) do |match|
          global_id = Decidim::Cfj::UrlConverter.s3_url_to_global_id(match)
          if global_id
            puts "  ✓ Converted S3 URL to Global ID: #{match[0..50]}..."
            global_id
          else
            puts "  ⚠ Failed to convert S3 URL: #{match[0..50]}..."
            match
          end
        end

        # Strategy 3: Convert any remaining blob URLs to permanent Rails URLs
        text = text.gsub(%r{https://[^"'\s]+\.(jpg|jpeg|png|gif|webp|svg)(\?[^"'\s]*)?}i) do |match|
          # Try to convert any image URL that might be a blob URL
          global_id = Decidim::Cfj::UrlConverter.url_to_global_id(match)
          if global_id
            puts "  ✓ Converted image URL to Global ID: #{match.split("/").last}"
            global_id
          else
            match
          end
        end

        fixed_count += 1 if original_text != text

        [text, fixed_count, total_checked]
      end

      # Process Blog Posts
      puts "\nProcessing Blog Posts..."
      Decidim::Blogs::Post.find_each do |post|
        post.title.each do |locale, title|
          new_title, fixed_count, total_checked = fix_urls_in_text(title, fixed_count, total_checked)
          post.title[locale] = new_title if new_title != title
        end

        post.body.each do |locale, body|
          new_body, fixed_count, total_checked = fix_urls_in_text(body, fixed_count, total_checked)
          post.body[locale] = new_body if new_body != body
        end

        if post.changed?
          post.save!
          puts "  Updated blog post: #{post.title["ja"] || post.title["en"]}"
        end
      end

      # Process Proposals
      puts "\nProcessing Proposals..."
      Decidim::Proposals::Proposal.find_each do |proposal|
        proposal.title.each do |locale, title|
          new_title, fixed_count, total_checked = fix_urls_in_text(title, fixed_count, total_checked)
          proposal.title[locale] = new_title if new_title != title
        end

        proposal.body.each do |locale, body|
          new_body, fixed_count, total_checked = fix_urls_in_text(body, fixed_count, total_checked)
          proposal.body[locale] = new_body if new_body != body
        end

        if proposal.changed?
          proposal.save!
          puts "  Updated proposal: #{proposal.title["ja"] || proposal.title["en"]}"
        end
      end

      # Process other content types that might have rich text
      # Add more models as needed...

      puts "\n#{("=" * 50)}"
      puts "Signed URL fix task completed!"
      puts "Total items checked: #{total_checked}"
      puts "Items fixed: #{fixed_count}"
      puts "=" * 50
    end

    desc "List content with potential signed URLs"
    task list_signed_urls: :environment do
      puts "Scanning for content with potential signed URLs..."

      # Pattern to match signed URLs
      signed_url_pattern = %r{https://[^/]+\.s3[^/]*\.amazonaws\.com/[^?]+\?[^"'\s]+}

      # Check Blog Posts
      puts "\nBlog Posts with signed URLs:"
      Decidim::Blogs::Post.find_each do |post|
        post.body.each do |locale, body|
          puts "  Blog Post ID #{post.id} (#{locale}): #{post.title[locale]}" if body.match?(signed_url_pattern)
        end
      end

      # Check Proposals
      puts "\nProposals with signed URLs:"
      Decidim::Proposals::Proposal.find_each do |proposal|
        proposal.body.each do |locale, body|
          puts "  Proposal ID #{proposal.id} (#{locale}): #{proposal.title[locale]}" if body.match?(signed_url_pattern)
        end
      end
    end
  end
end
