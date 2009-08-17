require 'active_record/connection_adapters/sqlite_adapter'

module ActiveRecord
  class Base
    def self.sqlite_connection(config) # :nodoc:
      parse_sqlite_config!(config)

      unless self.class.const_defined?(:SQLite)
        require_library_or_gem(config[:adapter])

        db = SQLite::Database.new(config[:database], 0)
        db.show_datatypes   = "ON" if !defined? SQLite::Version
        db.results_as_hash  = true if defined? SQLite::Version
        db.type_translation = false

        # "Downgrade" deprecated sqlite API
        if SQLite.const_defined?(:Version)
          ConnectionAdapters::SQLite2Adapter.new(db, logger, config)
        else
          ConnectionAdapters::DeprecatedSQLiteAdapter.new(db, logger, config)
        end
      end
    end
  end

  module ConnectionAdapters #:nodoc:
    class SQLite2Adapter < SQLiteAdapter # :nodoc:
      def table_structure(table_name)
        returning structure = execute("PRAGMA table_info(#{quote_table_name(table_name)})") do
          raise(ActiveRecord::StatementInvalid, "Could not find table '#{table_name}'") if structure.empty?
        end
      end

      def rename_table(name, new_name)
        move_table(name, new_name)
      end
    end

    class DeprecatedSQLiteAdapter < SQLite2Adapter # :nodoc:
      def insert(sql, name = nil, pk = nil, id_value = nil)
        execute(sql, name = nil)
        id_value || @connection.last_insert_rowid
      end
    end
  end
end