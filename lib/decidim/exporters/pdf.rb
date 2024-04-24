# frozen_string_literal: true

module Decidim
  module Exporters
    # Exports a PDF using the provided hash, given a collection and a
    # Serializer. This is an abstract class that should be inherited
    # to create PDF exporters, with each PDF exporter class setting
    # the desired template, layout and orientation.
    #
    class PDF < Exporter
      # Public: Exports a PDF version of the collection by rendering
      # the template into html and then converting it to PDF.
      #
      # Returns an ExportData instance.
      def export
        html = controller.render_to_string(
          template: template,
          layout: layout,
          locals: locals
        )

        document = pdf_from_string(html, orientation: orientation)

        ExportData.new(document, "pdf")
      end

      # may be overwritten if needed
      def orientation
        "Portrait"
      end

      # implementing classes should return a valid ERB path here
      def template
        raise NotImplementedError
      end

      # implementing classes should return a valid ERB path here
      def layout
        raise NotImplementedError
      end

      # This method may be overwritten if the template needs more local variables
      def locals
        { collection: collection }
      end

      protected

      def controller
        raise NotImplementedError
      end

      private

      def pdf_from_string(html, orientation:)
        document = nil

        Dir.mktmpdir do |dir|
          html_path = File.join(dir, "tmp.html")
          File.write(html_path, html)
          url = URI::File.build([nil, html_path])

          browser = Ferrum::Browser.new
          browser.go_to(url)
          document = browser.pdf(path: nil,
                                 encoding: :binary,
                                 landscape: orientation != "Portrait",
                                 printBackground: true,
                                 scale: 0.8,
                                 format: :A4)
        end

        document
      end
    end
  end
end
