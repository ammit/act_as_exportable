require 'csv'
require 'act_as_exportable'

module ActAsExportable
  module ActiveRecordModelExtension
    extend ActiveSupport::Concern

    class_methods do
      def act_as_exportable(args = {})
        @_attributes = args.try(:[], :attributes) || []

        @required_columns = args.try(:[], :required_columns) || []

        unless @_attributes.any?  
          raise ArgumentError, args[:attributes]
        end


        def copy_to path = nil, options = {}
          options = {:delimiter => ",", :format => :csv, :header => true}
          options_string = if options[:format] == :binary
                             "BINARY"
                           else
                             "DELIMITER '#{options[:delimiter]}' CSV #{options[:header] ? 'HEADER' : ''}"
                           end

          if path
            raise "You have to choose between exporting to a file or receiving the lines inside a block" if block_given?
            connection.execute "COPY (#{self.all.to_sql}) TO '#{sanitize_sql(path)}' WITH #{options_string}"
          else
            connection.raw_connection.copy_data "COPY (#{self.all.to_sql}) TO STDOUT WITH #{options_string}" do
              while line = connection.raw_connection.get_copy_data do
                yield(line) if block_given?
              end
            end
          end
          return self
        end

        def to_csv_file
          temp_dir = Dir.mktmpdir

          # TODO: classname and datetime export
          csv_path = File.join(temp_dir, 'export.csv')

          File.open(csv_path, 'w') do |f|
            limit(false).offset(false).select(@_attributes).copy_to  do |line|
              f.write line
            end
          end

          csv_path
        end

        def import_csv(csv_file_path, company_id, uniq_column)
          options = {:delimiter => ",", :format => :csv, :header => true, :quote => '"'}
          options_string = if options[:format] == :binary
                             "BINARY"
                           else
                             quote = options[:quote] == "'" ? "''" : options[:quote]
                             null = options.key?(:null) ? "NULL '#{options[:null]}'" : ''
                             "DELIMITER '#{options[:delimiter]}' QUOTE '#{quote}' #{null} CSV"
                           end

          raise 'Import File Not Provided' unless csv_file_path.present?
          raise 'Company Id Not Found' unless company_id.present?

          return unless csv_file_path.present?

          table = quoted_table_name

          io = File.open(csv_file_path, 'r')
          line = io.gets
          columns_list = options[:columns] || line.strip.split(options[:delimiter])
          _columns_list_2 = columns_list.dup

          # Check if required columns are in import
          if (@required_columns - columns_list).any?
            raise 'Required columns missing from csv'
          end

          ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS tmp_x;')
          ActiveRecord::Base.connection.execute("CREATE TEMP TABLE tmp_x AS SELECT * FROM #{table} LIMIT 0;")

          # Hack to mass assign created_at to current time stamp
          ActiveRecord::Base.connection.execute("ALTER TABLE tmp_x 
            ALTER COLUMN created_at SET DEFAULT now(), 
            ALTER COLUMN updated_at SET DEFAULT now(), 
            ADD UNIQUE (#{uniq_column}),
            ALTER COLUMN company_id SET DEFAULT #{company_id};")
          _columns_list_2 << 'created_at'
          _columns_list_2 << 'updated_at'
          _columns_list_2 << 'company_id'


          columns_string = columns_list.size > 0 ? "(\"#{columns_list.join('","')}\")" : ""
          _columns_string_2 = _columns_list_2.size > 0 ? "(\"#{_columns_list_2.join('","')}\")" : ""

          connection.raw_connection.copy_data %{COPY tmp_x #{columns_string} FROM STDIN #{options_string}} do
            if options[:format] == :binary
              bytes = 0
              begin
                while line = io.readpartial(10240)
                  connection.raw_connection.put_copy_data line
                  bytes += line.bytesize
                end
              rescue EOFError
              end
            else
              while line = io.gets do
                next if line.strip.size == 0
                if block_given?
                  row = CSV.parse_line(line.strip, {:col_sep => options[:delimiter]})
                  yield(row)
                  next if row.all?{|f| f.nil? }
                  line = CSV.generate_line(row, {:col_sep => options[:delimiter]})
                end

                # additinal commans added for blank values
                connection.raw_connection.put_copy_data line
              end
            end
          end

          _settts = columns_list.map{|c| "#{c} = tmp_x.#{c}"}.join(', ')
          _settts_excluded = columns_list.map{|c| "#{c} = excluded.#{c}"}.join(', ')

          begin  
            ActiveRecord::Base.transaction do  
              sanitized_sql = "INSERT INTO #{table} #{_columns_string_2}
                SELECT DISTINCT on (code) #{_columns_list_2.join(', ')} FROM tmp_x;"
              ActiveRecord::Base.connection.execute(sanitized_sql)
            end
           rescue Exception => exc 
             raise exc.message
           end
        end

        # path_or_io can be file path or direct io string
        def copy_from(path_or_io)
          # options = {:delimiter => ",", :format => :csv, :header => true, :quote => '"'}
          # options_string = if options[:format] == :binary
          #                    "BINARY"
          #                  else
          #                    quote = options[:quote] == "'" ? "''" : options[:quote]
          #                    null = options.key?(:null) ? "NULL '#{options[:null]}'" : ''
          #                    "DELIMITER '#{options[:delimiter]}' QUOTE '#{quote}' #{null} CSV"
          #                  end

          # path_or_io = '/Users/amit/Downloads/export_customers.csv'

          # io = path_or_io.instance_of?(String) ? File.open(path_or_io, 'r') : path_or_io

          # if options[:format] == :binary
          #   columns_list = options[:columns] || []
          # elsif options[:header]
          #   line = io.gets
          #   columns_list = options[:columns] || line.strip.split(options[:delimiter])
          # else
          #   columns_list = options[:columns]
          # end

          # table = if options[:table]
          #           connection.quote_table_name(options[:table])
          #         else
          #           quoted_table_name
          #         end

          # columns_list = columns_list.map{|c| options[:map][c.to_s] } if options[:map]
          # columns_string = columns_list.size > 0 ? "(\"#{columns_list.join('","')}\")" : ""


          # ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS tmp_x;')
          # ActiveRecord::Base.connection.execute("CREATE TEMP TABLE tmp_x AS SELECT * FROM #{table} LIMIT 0;")

          # connection.raw_connection.copy_data %{COPY tmp_x #{columns_string} FROM STDIN #{options_string}} do
          #   if options[:format] == :binary
          #     bytes = 0
          #     begin
          #       while line = io.readpartial(10240)
          #         connection.raw_connection.put_copy_data line
          #         bytes += line.bytesize
          #       end
          #     rescue EOFError
          #     end
          #   else
          #     while line = io.gets do
          #       next if line.strip.size == 0
          #       if block_given?
          #         row = CSV.parse_line(line.strip, {:col_sep => options[:delimiter]})
          #         yield(row)
          #         next if row.all?{|f| f.nil? }
          #         line = CSV.generate_line(row, {:col_sep => options[:delimiter]})
          #       end
          #       connection.raw_connection.put_copy_data line
          #     end
          #   end
          # end

          # _settts = columns_list.map{|c| "#{c} = tmp_x.#{c}"}.join(', ')
          # _settts_excluded = columns_list.map{|c| "#{c} = excluded.#{c}"}.join(', ')

          # # excluded

          # # ActiveRecord::Base.connection.execute("
          # #   UPDATE #{table}
          # #   SET #{_settts}
          # #   FROM tmp_x
          # #   WHERE tmp_x.id = #{table}.id;"
          # # )

          # ActiveRecord::Base.connection.execute("
          #   INSERT INTO #{table} #{columns_string}
          #   SELECT DISTINCT on (id) #{columns_list.join(', ')} FROM tmp_x
          #   ON CONFLICT (id) DO UPDATE SET #{_settts_excluded};
          # ")

          # true
        end
      end
    end
  end
end