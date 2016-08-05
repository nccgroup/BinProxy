module BinProxy
  class ClassLoader
    include BinProxy::Logger

    def initialize(root_path)
      @root_path = root_path
    end

    def load_class(class_name, explicit_file_path = nil)
      #unload top-level module for old class
      #XXX This is a bit aggressive, maybe need a manual param to tune it?
      top_level_name = class_name.split('::')[0]
      old_const = Object.send(:remove_const, top_level_name) if Object.const_defined?(top_level_name)
      try_load_class(class_name, explicit_file_path)
    rescue StandardError
      Object.const_set(top_level_name, old_const) if old_const
      raise
    end

    private
    def try_load_class(class_name, explicit_file_path)
      file_path = explicit_file_path.presence || find_file_for_class(class_name)
      log.info "Loading class file: #{File.absolute_path(file_path)}"
      load File.absolute_path(file_path)
      return class_name.constantize
    rescue LoadError => e
      log.error "Unexpected LoadError: #{e}" # This shouldn't happen except in weird cases like bad permissions or races
      raise StandardError.new "Couldn't load class file '#{file_path}'"
    rescue NameError => e
      raise StandardError.new "Loaded file '#{file_path}' successfully, but class '#{class_name}' not found."
    end

    def unstack_path(p,arr)
      arr << p
    end

    def find_file_for_class(class_name)
      un = class_name.underscore + ".rb"
      names = [un.dup]
      loop do
        m = un.match %r|^(.+)/[^/]+\.rb$|
        break unless m
        un = m[1] + ".rb"
        names << un
      end
      # this does some extra work
      fn = names.map {|n| find_file(n) }.find {|f| f }
      unless fn
        raise StandardError.new "Could not find any of #{names.inspect} for #{class_name}"
      end
      return fn
    end

    def find_file(fn)
      [
        "./#{fn}",
        "./lib/#{fn}",
        "#{@root_path}/lib/binproxy/parsers/#{fn}",
        "#{@root_path}/test/#{fn}"
      ].find {|f| File.exists? f}
    end

  end
end
