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

class MachineWithInternationalizationTest < BaseTestCase
    def setup
      I18n.backend = I18n::Backend::Simple.new

      # Initialize the backend
      StateMachines::Machine.new(new_model)
      #I18n.backend.translate(:en, 'mongoid.errors.messages.invalid_transition', :event => 'ignite', :value => 'idling')

      @model = new_model
    end

    def test_should_use_defaults
      I18n.backend.store_translations(:en, {
        :mongoid => {:errors => {:messages => {:invalid_transition => 'cannot %{event}'}}}
      })

      machine = StateMachines::Machine.new(@model)
      machine.state :parked, :idling
      machine.event :ignite

      record = @model.new(:state => 'idling')

      machine.invalidate(record, :state, :invalid_transition, [[:event, 'ignite']])
      assert_equal ['State cannot ignite'], record.errors.full_messages
    end

    def test_should_allow_customized_error_key
      I18n.backend.store_translations(:en, {
        :mongoid => {:errors => {:messages => {:bad_transition => 'cannot %{event}'}}}
      })

      machine = StateMachines::Machine.new(@model, :messages => {:invalid_transition => :bad_transition})
      machine.state :parked, :idling

      record = @model.new(:state => 'idling')

      machine.invalidate(record, :state, :invalid_transition, [[:event, 'ignite']])
      assert_equal ['State cannot ignite'], record.errors.full_messages
    end

    def test_should_allow_customized_error_string
      machine = StateMachines::Machine.new(@model, :messages => {:invalid_transition => 'cannot %{event}'})
      machine.state :parked, :idling

      record = @model.new(:state => 'idling')

      machine.invalidate(record, :state, :invalid_transition, [[:event, 'ignite']])
      assert_equal ['State cannot ignite'], record.errors.full_messages
    end

    def test_should_allow_customized_state_key_scoped_to_class_and_machine
      I18n.backend.store_translations(:en, {
        :mongoid => {:state_machines => {:'mongoid_test/foo' => {:state => {:states => {:parked => 'shutdown'}}}}}
      })

      machine = StateMachines::Machine.new(@model)
      machine.state :parked

      assert_equal 'shutdown', machine.state(:parked).human_name
    end

    def test_should_allow_customized_state_key_scoped_to_class
      I18n.backend.store_translations(:en, {
        :mongoid => {:state_machines => {:'mongoid_test/foo' => {:states => {:parked => 'shutdown'}}}}
      })

      machine = StateMachines::Machine.new(@model)
      machine.state :parked

      assert_equal 'shutdown', machine.state(:parked).human_name
    end

    def test_should_allow_customized_state_key_scoped_to_machine
      I18n.backend.store_translations(:en, {
        :mongoid => {:state_machines => {:state => {:states => {:parked => 'shutdown'}}}}
      })

      machine = StateMachines::Machine.new(@model)
      machine.state :parked

      assert_equal 'shutdown', machine.state(:parked).human_name
    end

    def test_should_allow_customized_state_key_unscoped
      I18n.backend.store_translations(:en, {
        :mongoid => {:state_machines => {:states => {:parked => 'shutdown'}}}
      })

      machine = StateMachines::Machine.new(@model)
      machine.state :parked

      assert_equal 'shutdown', machine.state(:parked).human_name
    end

    def test_should_support_nil_state_key
      I18n.backend.store_translations(:en, {
        :mongoid => {:state_machines => {:states => {:nil => 'empty'}}}
      })

      machine = StateMachines::Machine.new(@model)

      assert_equal 'empty', machine.state(nil).human_name
    end

    def test_should_allow_customized_event_key_scoped_to_class_and_machine
      I18n.backend.store_translations(:en, {
        :mongoid => {:state_machines => {:'mongoid_test/foo' => {:state => {:events => {:park => 'stop'}}}}}
      })

      machine = StateMachines::Machine.new(@model)
      machine.event :park

      assert_equal 'stop', machine.event(:park).human_name
    end

    def test_should_allow_customized_event_key_scoped_to_class
      I18n.backend.store_translations(:en, {
        :mongoid => {:state_machines => {:'mongoid_test/foo' => {:events => {:park => 'stop'}}}}
      })

      machine = StateMachines::Machine.new(@model)
      machine.event :park

      assert_equal 'stop', machine.event(:park).human_name
    end

    def test_should_allow_customized_event_key_scoped_to_machine
      I18n.backend.store_translations(:en, {
        :mongoid => {:state_machines => {:state => {:events => {:park => 'stop'}}}}
      })

      machine = StateMachines::Machine.new(@model)
      machine.event :park

      assert_equal 'stop', machine.event(:park).human_name
    end

    def test_should_allow_customized_event_key_unscoped
      I18n.backend.store_translations(:en, {
        :mongoid => {:state_machines => {:events => {:park => 'stop'}}}
      })

      machine = StateMachines::Machine.new(@model)
      machine.event :park

      assert_equal 'stop', machine.event(:park).human_name
    end

    def test_should_only_add_locale_once_in_load_path
      app_locale = File.dirname(__FILE__) + '/support/en.yml'
      default_locale = File.dirname(__FILE__) + '/../lib/state_machines/integrations/mongoid/locale.rb'

      I18n.load_path = [default_locale, app_locale]
      assert_equal 1, I18n.load_path.select {|path| path =~ %r{mongoid/locale\.rb$}}.length

      # Create another Mongoid model that will triger the i18n feature
      new_model

      assert_equal 1, I18n.load_path.select {|path| path =~ %r{mongoid/locale\.rb$}}.length
    end

    def test_should_add_locale_to_beginning_of_load_path
      @original_load_path = I18n.load_path
      I18n.backend = I18n::Backend::Simple.new

      app_locale = File.dirname(__FILE__) + '/support/en.yml'
      default_locale = File.dirname(__FILE__) + '/../lib/state_machines/integrations/mongoid/locale.rb'
      I18n.load_path = [app_locale]

      StateMachines::Machine.new(@model)

      assert_equal [default_locale, app_locale].map {|path| File.expand_path(path)}, I18n.load_path.map {|path| File.expand_path(path)}
    ensure
      I18n.load_path = @original_load_path
    end

    def test_should_prefer_other_locales_first
      @original_load_path = I18n.load_path
      I18n.backend = I18n::Backend::Simple.new
      I18n.load_path = [File.dirname(__FILE__) + '/support/en.yml']

      machine = StateMachines::Machine.new(@model)
      machine.state :parked, :idling
      machine.event :ignite

      record = @model.new(:state => 'idling')

      machine.invalidate(record, :state, :invalid_transition, [[:event, 'ignite']])
      assert_equal ['State cannot ignite'], record.errors.full_messages
    ensure
      I18n.load_path = @original_load_path
    end
  end
end