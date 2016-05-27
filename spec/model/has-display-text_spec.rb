require 'spec_helper'

describe Libertree::Model::HasDisplayText do
  subject { Struct.new(:text).new(text).extend(Libertree::Model::HasDisplayText) }

  describe '#glimpse' do
    let(:retval) { subject.glimpse(length) }

    context 'when the text is shorter than the glimpse length' do
      let(:length) { 60 }
      let(:text) { 'short text' }

      it 'returns the full text' do
        expect(retval).to eq text
      end
    end

    context 'when the text is longer than the glimpse length' do
      let(:length) { 10 }
      let(:text) { 'fairly long text' }

      it 'returns an abbreviation of the text with an ellipsis' do
        expect(retval).to eq 'fairly lon...'
      end
    end

    context 'when text has newlines' do
      let(:length) { 10 }
      let(:text) { "here\nare\nsome\nlines" }

      it 'turns the newlines to spaces' do
        expect(retval).to eq 'here are s...'
      end
    end

    context 'when the text has some quoted text at the end' do
      let(:length) { 10 }
      let(:text) { "abcde\n\n> 1234" }

      it 'strips the quoted text' do
        expect(retval).to eq 'abcde'
      end
    end

    context 'when the text has some quoted text at the beginning' do
      let(:length) { 10 }
      let(:text) { "> 12345\n\nabcde" }

      it 'strips the quoted text' do
        expect(retval).to eq 'abcde'
      end
    end

    context 'when the text has some quoted text in the middle' do
      let(:length) { 10 }
      let(:text) { "abcde\n\n> 1234\n\nfghij" }

      it 'strips the quoted text' do
        expect(retval).to eq "abcde    f..."
      end
    end
  end
end
