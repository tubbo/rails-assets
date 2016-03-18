# DumpUtil provides a dump routine and methods to process
# the dumps it creates
module DumpUtil
  module_function

  def dump(path = Dir.pwd)
    Thread.new do
      require 'objspace'
      ObjectSpace.trace_object_allocations_start
      GC.start
      File.open(dump_filename(path), 'w') do |f|
        ObjectSpace.dump_all(output: f)
      end
    end.join
  end

  private

  def dump_filename(path = Dir.pwd)
    File.join(
      path,
      "#{Socket.gethostname}-#{Process.pid}-#{Time.now.to_i}.json"
    )
  end
end
