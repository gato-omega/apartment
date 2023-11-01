# frozen_string_literal: true

module Apartment
  module Spec
    module Setup
      # rubocop:disable Metrics/AbcSize
      def self.included(base)
        base.instance_eval do
          let(:db1) { Apartment::Test.next_db }
          let(:db2) { Apartment::Test.next_db }
          let(:connection) { ActiveRecord::Base.connection }

          # This around ensures that we run these hooks before and after
          # any before/after hooks defined in individual tests
          # Otherwise these actually get run after test defined hooks
          around(:each) do |example|
            def config
              db = RSpec.current_example.metadata.fetch(:database, :postgresql)

              Apartment::Test.config['connections'][db.to_s].symbolize_keys
            end

            # before
            Apartment::Tenant.reload!(config)
            ActiveRecord::Base.establish_connection config

            example.run

            # after
            if Rails.configuration.respond_to?(:database_configuration=)
              Rails.configuration.database_configuration = {} # Cannot assign, no writer!???
            else
              # Check https://github.com/rails/rails/blob/v7.0.8/activerecord/lib/active_record/railtie.rb
              # Check https://github.com/rails/rails/blob/v7.1.1/activerecord/lib/active_record/railtie.rb
              # ActiveRecord.configurations = {}
            end

            if Apartment::Spec::Setup.activerecord_below_7_1?
              ActiveRecord::Base.clear_all_connections!
            else
              ActiveRecord::Base.connection_handler.clear_all_connections!
            end

            Apartment.excluded_models.each do |model|
              klass = model.constantize

              if Apartment::Spec::Setup.activerecord_below_7_1?
                Apartment.connection_class.remove_connection(klass)
              else
                klass.remove_connection
              end

              if Apartment::Spec::Setup.activerecord_below_7_1?
                klass.clear_all_connections!
              else
                klass.connection_handler.clear_all_connections!
              end

              klass.reset_table_name
            end
            Apartment.reset
            Apartment::Tenant.reload!
          end
        end
      end
      # rubocop:enable Metrics/AbcSize

      def self.activerecord_below_5_2?
        ActiveRecord.version.release < Gem::Version.new('5.2.0')
      end

      def self.activerecord_below_6_0?
        ActiveRecord.version.release < Gem::Version.new('6.0.0')
      end

      def self.activerecord_below_7_1?
        ActiveRecord.version.release < Gem::Version.new('7.1.0')
      end
    end
  end
end
