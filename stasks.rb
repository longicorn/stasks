#!/usr/bin/env ruby

# Simple Private Task Manerger

require 'optparse'
require 'pstore'
require 'fileutils'
require 'time'
require 'pp'

option = {}

parser = OptionParser.new
parser.banner = "task.rb is CLI based task management tool by ruby.\n"
parser.banner += "Usage: #{File.basename($0)} {option}"
parser.on("-a", "--add", "add."){
  option[:add] = true
}
parser.on("-u", "--update", "update."){
  option[:update] = true
}
parser.on("-c", "--cancel", "cancel."){
  option[:cancel] = true
}
parser.on("-r", "--ready", "debug task"){
  option[:ready] = true
}
parser.on("-s", "--start", "start task"){
  option[:start] = true
}
parser.on("-f", "--finish", "finish task"){
  option[:finish] = true
}
parser.on("-v", "--view", "view"){
  option[:view] = true
}
parser.on("-d", "--debug", "debug"){
  option[:delete] = true
}

parser.on("-D", "--debug", "debug"){
  option[:debug] = true
}

parser.on("-b", "--belong Name", String, "set belong."){|get_arg|
  option[:belong] = get_arg
}
parser.on("-i", "--id ID", Integer, "id"){|get_arg|
  option[:id] = get_arg
}
parser.on("-k", "--type Name", String, "set type. feature,task"){|get_arg|
  option[:kind] = get_arg
}
parser.on("-t", "--text Name", String, "set text."){|get_arg|
  option[:text] = get_arg
}
parser.on("-p", "--point Point", Integer, "set point."){|get_arg|
  option[:point] = get_arg
}

begin
  parser.parse!
rescue OptionParser::ParseError => err
  $stderr.puts err.message
  $stderr.puts parser.help
  exit 1
end

if option.empty?
  puts parser.help
  exit 1
end

#---------------

class Stasks
  def initialize(name)
    top_path="~/.stasks"
    FileUtils.mkdir_p(top_path)
    path = "#{top_path}/#{name}.db"
    @db = PStore.new(path)
    @@db = @db
  end

  def self.db
    @@db
  end

  def self.find(kind, id)
    kind = kind.to_sym
    case kind
    when :feature
      Feature.find(id)
    when :task
      Task.find(id)
    end
  end

  def self.find_feature(id)
    Feature.find(id)
  end

  def self.find_task(id)
    Task.find(id)
  end

  # 処理単位
  class Block
    def initialize(db, id)
      @db = db
      @id = id
    end

    def self.kind
      self.to_s.split(':')[-1].downcase.to_sym
    end

    def kind
      self.class.to_s.split(':')[-1].downcase.to_sym
    end

    def value
      hash = {}
      @db.transaction do
        break unless @db.root?(:feature)

        hash = @db[kind][@id]
      end
      hash
    end

    def self.list
      db = Stasks.db

      ret = []
      db.transaction do
        break unless db.root?(kind)
        db[kind].each do |id, hash|
          ret << new(db, id)
        end
      end
      ret
    end

    def view
    end

    def move
    end

    def update(hash)
      @db.transaction do
        [:belong, :point, :text].each do |key|
          next unless hash.has_key?(key)
          @db[kind][@id][key] = hash[key]
        end
      end
    end

    def delete
      @db.transaction do
        case kind
        when :feature
          @db[:feature].delete(@id)
        when :task
          @db[:task]&.delete(@id)
          @db[:wait]&.delete(@id)
          @db[:ready]&.delete(@id)
          @db[:doing]&.delete(@id)
          @db[:done]&.delete(@id)
        end
      end
    end
  end

  class Feature < Block
    def self.find(id)
      Feature.new(Stasks.db, id)
    end

    def view
      hash = self.value
      puts "#{@id}: #{hash[:text]}"
    end
  end

  class Task < Block
    def self.find(id)
      Task.new(Stasks.db, id)
    end

    def value
      hash = {}
      @db.transaction do
        break unless @db.root?(:task)
        hash = @db[:task][@id]
      end
      hash
    end

    def view
      hash = self.value
      feature = Feature.find(hash[:belong])
      feature_text = feature.value&.dig(:text)
      hash.delete(:belong)
      point = "#{hash[:point]}P"

      puts "#{@id}:[#{feature_text}][#{point}] #{hash[:text]}"
    end

    def move(from, to, hash=nil)
      @db.transaction do
        task = @db[:task][@id]
        raise if task.nil?
        raise unless @db[from].include?(@id)
        raise if @db[to] and @db[to].include?(@id)

        @db[from].delete(@id)
        @db[to] ||= []
        @db[to] << @id

        hash[:belong] = hash[:belong].to_i if hash.has_key?(:belong)

        unless hash.nil?
          task = task.merge(hash)
          @db[:task][@id] = task
        end
      end
    end

    def wait?
      ret=nil

      @db.transaction do
        ret = @db[:wait]&.include?(@id)
      end

      ret
    end

    def ready?
      ret=nil

      @db.transaction do
        ret = @db[:ready]&.include?(@id)
      end

      ret
    end

    def ready!
      raise unless self.wait?
      self.move(:wait, :ready)
    end

    def doing?
      ret=nil

      @db.transaction do
        ret = @db[:doing]&.include?(@id)
      end

      ret
    end

    def doing!
      # ここでFeatureのチェックを行う
      # すでに同じFeatureがdoingになっていたら順番がおかしいはず...
      raise unless self.ready?
      self.move(:ready, :doing, {start_at:Time.now})
    end

    def done?
      ret=nil

      @db.transaction do
        ret = @db[:done]&.include?(@id)
      end

      ret
    end

    def done!
      raise unless self.doing?
      self.move(:doing, :done, {end_at:Time.now})
    end
  end

  def add(kind, *hash)
    kind = kind.to_sym
    hash = hash[0]

    @db.transaction do
      id_key = "#{kind}_id".to_sym
      @db[id_key] ||= 0
      id = @db[id_key] + 1

      @db[kind] ||= {}
      @db[kind][id] = hash

      @db[id_key] = id

      if kind == :task
        @db[:wait] ||= []
        @db[:wait] << id
      end
    end
  end

  def view
    # 後ほどクラスの方へ移動
    # belongも展開する
    def view_feature
      puts "# features"
      feature = Feature.list
      feature.each do |feature|
        print '- '
        feature.view
      end
    end

    def view_task
      # doneに関しては、1iteration以内のデータのみで良いかも
      puts "# tasks"
      tasks = Task.list
      [:wait, :ready, :doing, :done].each do |name|
        puts "- #{name}"
        method = "#{name}?".to_sym
        tasks.select(&method).each do |task|
          print '-- '
          task.view
        end
        puts ''
      end
    end

    view_feature
    puts ''
    view_task
  end

  def debug
    @db.transaction do
      pp @db
    end
    puts '------'
    view
  end
end

stasks = Stasks.new("tasks")

option.each do |key, val|
  case key
  when :add
    kind = option[:kind].to_sym
    keys = []
    case kind
    when :feature, :f
      keys = [:text]
    when :task, :t
      keys = [:belong, :point, :text]
    else
      raise
    end

    raise if keys.map{|k|option.has_key?(k)}.include?(false)
    hash = keys.inject({}){|h, k|h[k] = option[k]; h}
    stasks.add(kind, hash)
    stasks.view
  when :cancel
    raise if [:id].map{|k|option.has_key?(k)}.include?(false)
    id = option[:id].to_i

    task = Stasks.find_task(id)
    if task.ready?
      task.move(:ready, :wait)
    elsif task.doing?
      task.move(:doing, :ready)
    elsif task.done?
      task.move(:done, :doing)
    end
    stasks.view
  when :delete
    raise if [:id].map{|k|option.has_key?(k)}.include?(false)
    id = option[:id].to_i
    task = Stasks.find_task(id)
    task.delete
    stasks.view
  when :update
    raise if [:id, :kind].map{|k|option.has_key?(k)}.include?(false)
    kind = option[:kind].to_sym
    id = option[:id].to_i

    obj = Stasks.find(kind, id)
    obj.update(option)
    obj.view
  when :ready
    # wait -> ready
    raise if [:id].map{|k|option.has_key?(k)}.include?(false)
    id = option[:id].to_i

    task = Stasks.find_task(id)
    task.ready!
    stasks.view
  when :start
    # ready -> doing
    raise if [:id].map{|k|option.has_key?(k)}.include?(false)
    id = option[:id].to_i

    task = Stasks.find_task(id)
    task.doing!
    stasks.view
  when :finish
    # doing -> done
    raise if [:id].map{|k|option.has_key?(k)}.include?(false)
    id = option[:id].to_i

    task = Stasks.find_task(id)
    task.done!
    stasks.view
  when :view
    stasks.view
  when :draw
    #図にしたい
    #PostScriptとかでお絵かき?
  when :debug
    stasks.debug
  end
end
