require 'libertree/render'

module Libertree
  module Model
    # Provides a "glimpse" instance method to objects that have a "text" field.
    module HasDisplayText
      def glimpse( length = 60 )
        t = self.text.lines.reject { |l| l =~ /^> / }.join("\n")
        if t.strip.empty?
          t = self.text
        end
        t.strip!

        if t.length <= length
          t
        else
          t[0...length] + '...'
        end
      end

      def text_as_html
        Render.to_html_nodeset(self.text)
      end
    end
  end
end
