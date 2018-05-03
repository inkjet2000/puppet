require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the max function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  let(:logs) { [] }
  let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }

  it 'errors if not give at least one argument' do
    expect{ compile_to_catalog("max()") }.to raise_error(/Wrong number of arguments need at least one/)
  end

  context 'compares numbers' do
    { [0, 1]    => 1,
      [-1, 0]   => 0,
      [-1.0, 0] => 0,
    }.each_pair do |values, expected|
      it "called as max(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        expect(compile_to_catalog("notify { String( max(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'compares strings that are not numbers without deprecation warning' do
    it "string as number is deprecated" do
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        expect(compile_to_catalog("notify { String( max('a', 'b') == 'b'): }")).to have_resource("Notify[true]")
      end
      expect(warnings).to_not include(/auto conversion of .* is deprecated/)
    end
  end

  context 'compares strings as numbers if possible (deprecated)' do
    {
      [20, "'100'"]     => "'100'",
      ["'20'", "'100'"] => "'100'",
      ["'20'", 100]     => "100",
      [20, "'100x'"]    => "20",
      ["20", "'100x'"]  => "20",
      ["'20x'", 100]    => "'20x'",
    }.each_pair do |values, expected|
      it "called as max(#{values[0]}, #{values[1]}) results in the value #{expected} and issues deprecation warning" do
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect(compile_to_catalog("notify { String( max(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
        end
        expect(warnings).to include(/auto conversion of .* is deprecated/)
      end
    end
  end

  context 'compares all except numeric and string by conversion to string (deprecated)' do
    {
      [[20], "'a'"]                  => "'a'",            # after since '[' is before 'a'
      ["{'a' => 10}", "'a'"]         => "{'a' => 10}",    # after since '{' is after 'a'
      [false, 'fal']                 => "false",          # the boolean since text 'false' is longer
      ['/b/', "'(?-mix:c)'"]         => "'(?-mix:c)'",    # because regexp to_s is a (?-mix:b) string
      ["Timestamp(1)", "'1980 a.d'"] => "'1980 a.d'",     # because timestamp to_s is a date-time string here starting with 1970
      ["Semver('2.0.0')", "Semver('10.0.0')"] => "Semver('2.0.0')", # "10.0.0" is lexicographically before "2.0.0"
    }.each_pair do |values, expected|
      it "called as max(#{values[0]}, #{values[1]}) results in the value #{expected} and issues deprecation warning" do
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect(compile_to_catalog("notify { String( max(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
        end
        expect(warnings).to include(/auto conversion of .* is deprecated/)
      end
    end
  end

  it "accepts a lambda that takes over the comparison (here avoiding the string as number conversion)" do
    src = <<-SRC
      $val = max("2", "10") |$a, $b| { compare($a, $b) }
      notify { String( $val == "2"): }
    SRC
    expect(compile_to_catalog(src)).to have_resource("Notify[true]")
  end

end
