require 'libertree/render'

module Libertree
  module Model
    # Provides a "glimpse" instance method to objects that have a "text" field.
    module HasDisplayText
      def glimpse( length = 60 )
        set_without_blockquotes = text_to_nodeset
        set_without_blockquotes.xpath('.//blockquote').each(&:remove)
        plain_text = set_without_blockquotes.inner_text.strip

        if plain_text.empty?
          plain_text = text_to_nodeset.inner_text.strip
        end

        plain_text = plain_text.gsub("\n", ' ')
        snippet = plain_text[0...length]
        if plain_text.length > length
          snippet += '...'
        end

        snippet
      end

      def text_as_html
        Render.to_html_nodeset(self.text)
      end

      def text_to_nodeset
        Render.to_html_nodeset(self.text, [:no_images, :filter_html])
      end
    end
  end
end
