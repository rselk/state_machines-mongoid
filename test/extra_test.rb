require_relative 'helper'


# Establish database connection
Mongoid.connect_to('test')

module MongoidTest
  class BaseTestCase < Minitest::Test
    def default_test
    end

    def teardown
      if @table_names
        db = Mongoid::Sessions.default
        db.collections.each {|c| c.drop if @table_names.include?(c.name)}
      end
    end

    protected
      # Creates a new Mongoid model (and the associated table)
      def new_model(name = :foo, &block)
        table_name = "#{name}_#{rand(1000000)}"
        @table_names ||= []
        @table_names << table_name

        model = Class.new do
          (class << self; self; end).class_eval do
            define_method(:name) { "MongoidTest::#{name.to_s.capitalize}" }
            define_method(:to_s) { self.name }
          end
        end

        model.class_eval do
          include Mongoid::Document
          include Mongoid::Attributes::Dynamic

          store_in collection: table_name

          field :state, :type => String
        end
        model.class_eval(&block) if block_given?
        model
      end
=begin
      # Creates a new Mongoid observer
      def new_observer(model, &block)
        observer = Class.new(Mongoid::Observer) do
          attr_accessor :notifications

          def initialize
            super
            @notifications = []
          end
        end

        (class << observer; self; end).class_eval do
          define_method(:name) do
            "#{model.name}Observer"
          end
        end

        observer.observe(model)
        observer.class_eval(&block) if block_given?
        observer
      end
=end
  end
 class MachineWithEventAttributesOnValidationTest < BaseTestCase
    def setup
      @model = new_model
      @machine = StateMachines::Machine.new(@model)
      @machine.event :ignite do
        transition :parked => :idling
      end

      @record = @model.new
      @record.state = 'parked'
      @record.state_event = 'ignite'
    end

    def test_should_fail_if_event_is_invalid
      @record.state_event = 'invalid'
      assert_raises(IndexError) { @record.state?(:invalid)}
    end

    def test_should_fail_if_event_has_no_transition
      @record.state = 'idling'
      assert_raises(IndexError) { @record.state?(:invalid)}
    end

    def test_should_be_successful_if_event_has_transition
      assert @record.valid?
    end

    def test_should_run_before_callbacks
      ran_callback = false
      @machine.before_transition { ran_callback = true }

      assert @record.valid?
      assert ran_callback
    end

    def test_should_run_around_callbacks_before_yield
      ran_callback = false
      @machine.around_transition do |block| 
        ran_callback = true; 
        block.call 
      end

      @record.save!
      assert ran_callback
    end


    def test_should_not_run_after_callbacks
      ran_callback = false
      @machine.after_transition { ran_callback = true }

      @record.valid?
      assert !ran_callback
    end

    def test_should_not_run_after_callbacks_with_failures_disabled_if_validation_fails
      @model.class_eval do
        attr_accessor :seatbelt
        validates_presence_of :seatbelt
      end

      ran_callback = false
      @machine.after_transition { ran_callback = true }

      @record.valid?
      assert !ran_callback
    end

    def test_should_not_run_around_callbacks_after_yield
      ran_callback = false
      @machine.around_transition {|block| block.call; ran_callback = true }

      begin
        @record.valid?
      rescue ArgumentError
        raise if StateMachines::Transition.pause_supported?
      end
      assert !ran_callback
    end

    def test_should_not_run_around_callbacks_after_yield_with_failures_disabled_if_validation_fails
      @model.class_eval do
        attr_accessor :seatbelt
        validates_presence_of :seatbelt
      end

      ran_callback = false
      @machine.around_transition {|block| block.call; ran_callback = true }

      @record.valid?
      assert !ran_callback
    end

    def test_should_run_failure_callbacks_if_validation_fails
      @model.class_eval do
        attr_accessor :seatbelt
        validates_presence_of :seatbelt
      end

      ran_callback = false
      @machine.after_failure { ran_callback = true }

      @record.valid?
      assert ran_callback
    end
  end
end