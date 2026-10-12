# frozen_string_literal: true

# --eval lets Rake inspect native results even when the engine exits with 0.
gtk = $gtk # rubocop:disable Style/GlobalVars -- DragonRuby exposes its runtime to --eval through $gtk.
require(gtk.cli_arguments[:'test-file'] || 'tests/all_test.rb')

tests = gtk.tests
focused = tests.test_methods_focused.length
expected = focused.positive? ? focused : tests.test_methods.length
tests.start

puts "DESCENT_TEST_RESULTS expected=#{expected} passed=#{tests.passed.length} " \
     "failed=#{tests.failed.length} inconclusive=#{tests.inconclusive.length} focused=#{focused}"
