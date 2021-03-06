module StaticBlocks
  class Snippet < ActiveRecord::Base
    attr_accessible :content, :status, :title
    after_save :clear_cache
    scope :published, where(:status => 'published')
    translates :content
    validates :title, uniqueness: true

    def to_s
      content
    end

    def clear_cache
      Rails.cache.delete("snippet::"+I18n.locale.to_s+"::"+title)
    end

    def self.to_csv(options = {})
      snippets = self.connection.select_all('select * from static_blocks_snippets')
      snippets_column_names = snippets.first.keys
      CSV.generate(options) do |csv|
        csv << snippets_column_names
        snippets.each do |s|
          csv << s.values_at(*snippets_column_names)
        end
      end
    end

    def self.translations_to_csv(options = {})
      translations = self.connection.select_all('select * from static_blocks_snippet_translations')
      translation_column_names = translations.first.keys
      CSV.generate(options) do |csv|
        csv << translation_column_names
        translations.each do |t|
          csv << t.values_at(*translation_column_names)
        end
      end
    end

    def self.import(file)
      CSV.foreach(file.path, headers: true) do |row|
        snippet = find_by_title(row["title"]) || new
        snippet.attributes = row.to_hash.slice(*accessible_attributes)
        snippet.id = row['id']
        snippet.save!
      end
    end

    def self.import_translations(file)
      CSV.foreach(file.path, headers: true) do |row|
        # find translation
        raw_sql = "SELECT * FROM static_blocks_snippet_translations WHERE id=#{row['id']}"
        translation = ActiveRecord::Base.connection.execute(raw_sql)
        if translation.present?
          # update existing translation
          raw_sql = "
          UPDATE static_blocks_snippet_translations
          SET static_blocks_snippet_id=%d, locale='%s', content='%s', created_at='%s', updated_at='%s'
          WHERE id=%d" % [row['static_blocks_snippet_id'], row['locale'], row['content'], row['created_at'], row['updated_at'], row['id']]
        else
          # create new translation
          raw_sql = "
          INSERT INTO static_blocks_snippet_translations
          ('id', 'static_blocks_snippet_id', 'locale', 'content', 'created_at', 'updated_at') VALUES
          ('%d', '%d', '%s', '%s', '%s', '%s')" % [row['id'], row['static_blocks_snippet_id'], row['locale'], row['content'], row['created_at'], row['updated_at']]
        end
        ActiveRecord::Base.connection.execute(raw_sql)
      end
    end
  end
end
