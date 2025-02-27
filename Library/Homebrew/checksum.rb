# typed: strict
# frozen_string_literal: true

# A formula's checksum.
class Checksum
  extend Forwardable

  sig { returns(T.any(String, Symbol)) }
  attr_reader :hexdigest

  sig { params(hexdigest: T.any(String, Symbol)).void }
  def initialize(hexdigest)
    @hexdigest = T.let(hexdigest.downcase, T.any(String, Symbol))
  end

  delegate [:empty?, :to_s, :length, :[]] => :@hexdigest

  sig { params(other: T.any(String, Checksum, Symbol)).returns(T::Boolean) }
  def ==(other)
    case other
    when String
      to_s == other.downcase
    when Checksum
      hexdigest == other.hexdigest
    else
      false
    end
  end
end
