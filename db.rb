require 'sqlite3'

# Import into sqlite database the files containing
# the classified images
class DBImporter
  def initialize(db_path)
    @db = SQLite3::Database.open(db_path)
    begin
      create_tables
    rescue
      puts 'tables exist'
    end
  end

  def create_tables()
    @db.execute("""
      CREATE TABLE cls_tag(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tag TEXT
      )""")
    @db.execute('CREATE INDEX cls_tag_id_IDX ON cls_tag(tag)')

    @db.execute("""
      CREATE TABLE classification(
               post_id INTEGER NOT NULL,
               rank INTEGER,
               tag_id INTEGER not NULL,
               score REAL,
               PRIMARY KEY(post_id, rank, tag_id),
               FOREIGN KEY(tag_id) REFERENCES cls_tag(id)
              )
              """)
  end

  def find_tag_id(tag)
    result = @db.get_first_value('select * from cls_tag where tag = :tag', tag)
    return result unless result.nil?

    @db.execute('insert or ignore into cls_tag(tag) values (:tag)', tag)
    @db.last_insert_row_id
  end

  def insert_file(path)
    # select * from cls_tag='value' returns no records
    # if the file is open without encoding
    lines = File.open(path, 'r:UTF-8').read.split(/\n/)
    post_id = lines[0].match(/(\d+).jpg/)[1].to_i
    lines.drop(1).each do |line|
      m = line.match(/^score (\d+): (.*) \(score = (.*)\)/)
      rank = m[1].to_i
      score = m[3].to_f
      m[2].split(/\s*,\s*/).each do |t|
        tag_id = find_tag_id(t.downcase)
        @db.execute('insert or ignore into classification(post_id, rank, tag_id, score) values(:post_id, :rank, :tag_id, :score)',
                    post_id, rank, tag_id, score)
      end
    end
  end

  def import_directory(root_path)
    Dir.glob(root_path).each do |path|
      puts path
      insert_file(path)
    end
  end
end

DBImporter.new('classification.db')
          .import_directory('results/**/*.txt')
