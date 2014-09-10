require 'minitest/reporters'
Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)
require 'minitest/autorun'
require 'state_machines/integrations/mongoid'
require 'test/unit/assertions'
include Test::Unit::Assertions
